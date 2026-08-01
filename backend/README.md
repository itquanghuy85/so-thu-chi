# Sổ Thu Chi Backend (MVP — Sprint 1-4)

NestJS + TypeORM + PostgreSQL backend for Sổ Thu Chi, a cash-flow management app for shop owners and families (Vietnamese market). This is the MVP scope only: Auth, Workspaces, Vaults, Categories, Transactions (double-entry), Customers/Debt, and a minimal cashflow Report.

## Stack

- NestJS 11 (TypeScript)
- TypeORM 1.x + `pg` driver, target PostgreSQL 15
- `class-validator` / `class-transformer` for DTO validation
- `@nestjs/jwt` + `@nestjs/passport` + `passport-jwt` for auth, `bcrypt` for password hashing
- `@nestjs/config` for env vars

## Running locally

1. Install dependencies:
   ```bash
   npm install
   ```
2. Copy the env template and adjust if needed:
   ```bash
   cp .env.example .env
   ```
3. Start Postgres (and Adminer, optional DB UI at http://localhost:8080):
   ```bash
   docker compose up -d
   ```
4. Start the API in watch mode:
   ```bash
   npm run start:dev
   ```
   The API listens on `http://localhost:3000`, all routes under the `/v1` prefix.

5. Build only (no DB required):
   ```bash
   npm run build
   ```

> **Firebase (Google/Apple sign-in):** `POST /auth/social-login` needs a service account key at `backend/firebase-service-account.json` (path configurable via `FIREBASE_SERVICE_ACCOUNT_PATH` in `.env`, git-ignored). It was generated for the `sothuchi-d055a` Firebase project via `gcloud iam service-accounts keys create`, granted the `roles/firebaseauth.admin` role. If this key is ever lost/rotated, generate a new one from Firebase Console → Project settings → Service accounts → Generate new private key, or re-run the `gcloud` command against the `sothuchi-backend` service account.

> **Schema management (MVP simplification):** `synchronize: true` is enabled whenever `NODE_ENV !== 'production'` (see `src/config/typeorm.config.ts`), so TypeORM creates/updates tables directly from the entities on boot. This is convenient for this MVP pass but is **not** safe for production — replace it with real TypeORM migrations (`typeorm migration:generate` / `migration:run`) and set `synchronize: false` before deploying against real data.

## Implemented endpoints (prefix `/v1`)

**Auth**
- `POST /auth/register` — `{ email, password, full_name, phone? }`
- `POST /auth/login` — `{ email, password }`
- `POST /auth/refresh` — `{ refresh_token }`
- `POST /auth/social-login` — `{ id_token, provider: 'google'|'apple' }`; verifies the Firebase ID token (`firebase-admin`) and finds-or-creates the user by email
- `GET /auth/me` (auth required)

**Workspaces**
- `GET /workspaces` (auth) — workspaces the current user belongs to
- `POST /workspaces` — `{ name, type: 'shop'|'family' }`; auto-creates the owner membership, the two internal virtual vaults ("Doanh thu" / "Chi phí"), the seeded default categories, and the seeded default achievement rows (see Gamification)
- `GET /workspaces/:id` (member only) — includes `invite_code` and each member's `email`
- `POST /workspaces/join` — `{ invite_code }`; joins as `role: 'member'`, awards the owner `member_invite` XP
- `POST /workspaces/:id/invite-code` (owner only) — rotates and returns a new invite code
- `DELETE /workspaces/:id/members/:userId` (owner only) — cannot remove the owner

**Vaults**
- `GET /workspaces/:id/vaults` (member only) — excludes `type='virtual'`
- `POST /workspaces/:id/vaults` — `{ name, type: 'cash'|'bank'|'ewallet', initial_balance? }`
- `POST /vaults/:id/reconcile` — `{ actual_balance, reason? }`; awards `reconcile_match` XP + the `perfect_reconcile` achievement (first time only) if the actual balance matches exactly

**Categories**
- `GET /workspaces/:id/categories?group=income|expense`
- `POST /workspaces/:id/categories` — `{ name, group_name, icon? }`
- `PATCH /workspaces/:id/categories/:categoryId` — `{ name }`
- `DELETE /workspaces/:id/categories/:categoryId` — `CONFLICT` if any transaction references the category

**Transactions**
- `GET /transactions?workspace_id=&type=&vault_id=&from_date=&to_date=&page=&limit=` — `from_date`/`to_date` are inclusive ISO bounds on `created_at`, added for the mobile Reports screens (period filtering) but usable generally
- `POST /transactions` — body shape depends on `type` (`income`, `expense`, `transfer`, `debt_increase`, `debt_decrease`); optional `source: 'manual'|'voice'` (default `manual`) grants extra `voice_input` XP; see `src/modules/transactions/dto/create-transaction.dto.ts`
- `POST /transactions/:id/void`

**Customers**
- `GET /workspaces/:id/customers` — includes `debt_balance` (joined from the customer's debt vault) and `created_at`
- `POST /workspaces/:id/customers` — `{ name, phone? }`; auto-creates a `debt_customer` vault
- `GET /customers/:id/debt-history`

**Reports**
- `GET /reports/cashflow?workspace_id=&period=this_week|this_month|this_year`

**Gamification** (Mục 9 — XP, levels, weekly quest, achievements)
- `GET /gamification/profile?workspace_id=` — `{ xp, level, xp_current_level_floor, xp_next_level, quest, achievements }` for the current user in that workspace
- `POST /gamification/claim-quest` — `{ workspace_id }`; claims the weekly quest reward once its target is met, `CONFLICT` if already claimed this week, `VALIDATION_ERROR` if not yet complete
- XP is awarded server-side as a best-effort call *after* the triggering action's own transaction commits (never blocks or rolls back the core action if awarding XP fails): `transaction_create` (+5, daily cap 50), `voice_input` (+5, daily cap 25, additive on top of `transaction_create`), `reconcile_match` (+30), `debt_decrease` (+20), `member_invite` (+50), `quest_reward` (+100, one-time per week)
- Levels follow a quadratic curve: `xp_required(level) = 100 * (level-1)^2` (see `gamification.constants.ts`)
- The weekly quest is a single fixed quest ("Tạo 20 giao dịch trong tuần", +100 XP), computed on-demand from a transaction-count query against a Monday-aligned week window — no cron/scheduler
- Achievements are seeded per-workspace on creation (`founder`, `ten_transactions`, `perfect_reconcile`); `founder` unlocks immediately for the creator

**Budgets** (Mục — monthly spending limits)
- `GET /workspaces/:id/budgets` — each row includes `spent_this_month`/`remaining`/`over_budget`, computed live from this calendar month's completed expense transactions (no period field — always "this month", see `Budget` entity doc comment)
- `POST /workspaces/:id/budgets` — `{ category_id?, limit_amount }`; omit `category_id` for a workspace-wide total-spend budget; `CONFLICT` if one already exists for that category (or the global one)
- `PATCH /workspaces/:id/budgets/:budgetId` — `{ limit_amount }`
- `DELETE /workspaces/:id/budgets/:budgetId`

**Recurring transactions** (Mục — no server cron; materialized on client trigger)
- `GET /workspaces/:id/recurring`
- `POST /workspaces/:id/recurring` — same shape as `POST /transactions` plus `{ frequency: 'daily'|'weekly'|'monthly', start_date }`
- `PATCH /workspaces/:id/recurring/:id` — `{ active }` (pause/resume)
- `DELETE /workspaces/:id/recurring/:id`
- `POST /workspaces/:id/recurring/run-due` — materializes every occurrence whose `next_run_date` has passed (via the same `TransactionsService.create` a manual entry uses), catching up up to 24 missed occurrences per entry; called opportunistically by the mobile Dashboard on load, not a cron job

**Shifts** (Mục — ca làm việc)
- `GET /workspaces/:id/shifts` — closed + open shifts, each with `income_during_shift`/`expense_during_shift` derived from transactions created in `[opened_at, closed_at)`
- `GET /workspaces/:id/shifts/current` — the caller's own open shift, or `null`
- `POST /workspaces/:id/shifts/open` — `{ note? }`; snapshots every non-virtual vault's balance; `CONFLICT` if the caller already has one open
- `POST /workspaces/:id/shifts/:shiftId/close` — `{ note? }`; snapshots again; only the shift's own opener may close it

**Notifications** (Mục — push, Firebase Cloud Messaging)
- `PATCH /notifications/fcm-token` — `{ token }`; registers this device's FCM token against the current user (single token per user — a fresh login/refresh overwrites it)
- `DELETE /notifications/fcm-token` — called at mobile logout
- No inbox/log endpoint — sends are fire-to-FCM only, triggered best-effort (never blocks or fails the triggering request) from: `TransactionsService.create` (new-transaction ping to other workspace members, and a "budget just crossed its limit" ping the moment an expense pushes spend from at-or-under to over), and `RecurringService.runDue` (a summary ping when occurrences are materialized)

All error responses use the shape:
```json
{ "error": { "code": "VALIDATION_ERROR", "message": "...", "details": [{ "field": "amount", "message": "..." }] } }
```

## Business logic notes

- Money amounts are stored as `bigint` (whole đồng, no decimals) across `vaults.current_balance`, `transactions.amount`, `transaction_entries.amount` to avoid float rounding.
- Every workspace gets two internal `type='virtual'` vaults ("Doanh thu" for income, "Chi phí" for expense) used as the counter-party leg of double-entry postings. Their balances are never adjusted — they exist purely so every transaction has a debit and a credit leg in `transaction_entries` for audit history.
- Vault balances (`current_balance`) are updated directly by `TransactionsService` per the rules in the spec (not derived by summing `transaction_entries`).
- `POST /transactions/:id/void` reverses the balance effect and appends mirrored reversal entries (side flipped) rather than deleting the original ones, keeping the full audit trail.

## Not implemented yet / next sprint (explicitly out of scope for this pass)

- Cloud/AI voice commands (OCR receipt scanning, forecast AI, cloud NLU fallback) — the mobile app's voice input uses on-device speech recognition + a rule-based parser instead, see `mobile/README.md`
- A Leon wardrobe/outfit system — the "Game Leon" visual theme itself (mascot, alternate dashboard/nav/achievements skin) and the underlying XP/level/quest/achievement system are both implemented, mobile-side only (no backend changes needed), see `mobile/README.md`
- Subscriptions / ads
- Audit log
- Offline-sync API
- WebSocket realtime updates
- Full roles/permissions JSONB system (this pass uses a simple `role` enum column: `owner`|`manager`|`cashier`|`member`)
