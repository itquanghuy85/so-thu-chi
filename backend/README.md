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

> **Schema management (MVP simplification):** `synchronize: true` by default, including in production (see `src/config/typeorm.config.ts`), so TypeORM creates/updates tables directly from the entities on boot — no hand-written migrations exist yet. Fine for this pass (single-tenant shop app); set `DB_SYNC=false` once real TypeORM migrations (`typeorm migration:generate` / `migration:run`) are added.

## Deploying to the cloud

Running the backend on a personal machine only works while that machine is on **and** on the same network as the phone — not viable for a shop that needs the app to work anywhere, anytime. This section deploys the same backend to a free always-on host instead. Two free services, no credit card needed for either at this scale:

- **[Neon](https://neon.tech)** — managed Postgres, free tier has no time limit (unlike some competitors' 30/90-day free trials).
- **[Render](https://render.com)** — runs the NestJS app itself, free web service tier (cold-starts after ~15 min idle — the first request after a quiet period takes a few extra seconds, every request after that is normal speed).

Both support signing up with a GitHub account directly — the same account this repo lives on.

**1. Database (Neon)**
1. Sign up at neon.tech (Continue with GitHub).
2. Create a new project — any name/region.
3. On the project dashboard, copy the **connection string** (looks like `postgresql://user:password@ep-xxxx.aws.neon.tech/dbname?sslmode=require`). Keep this tab open, it's needed in step 2 below.

**2. API (Render)**
1. Sign up at render.com (Continue with GitHub), and grant it access to this repo when asked (it's private).
2. **New +** → **Web Service** → pick this repo.
3. Settings:
   - **Root Directory**: `backend`
   - **Runtime**: Node
   - **Build Command**: `npm install && npm run build`
   - **Start Command**: `npm run start:prod`
   - **Instance Type**: Free
4. Under **Environment**, add:
   ```
   NODE_ENV=production
   DATABASE_URL=<the Neon connection string from step 1>
   DB_SSL=true
   JWT_ACCESS_SECRET=<a long random string — see below>
   JWT_REFRESH_SECRET=<a different long random string>
   JWT_ACCESS_EXPIRES=15m
   JWT_REFRESH_EXPIRES=30d
   FIREBASE_SERVICE_ACCOUNT_JSON=<paste the entire contents of firebase-service-account.json>
   ```
   Generate the two JWT secrets locally with `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"` (run it twice, once per secret) — never reuse the placeholder values from `.env.example`.
5. Deploy. Render builds and starts the app, then gives a public URL like `https://<service-name>.onrender.com`. First boot also creates every table (`synchronize: true`, see above) — no separate migration step needed.
6. Point the mobile app at it: build with `flutter run --dart-define=API_BASE_URL=https://<service-name>.onrender.com/v1` (or update the default in `mobile/lib/core/constants/api_endpoints.dart` to make it permanent — see `mobile/README.md`).

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
- `GET /transactions?workspace_id=&type=&vault_id=&from_date=&to_date=&page=&limit=` — `from_date`/`to_date` are inclusive ISO bounds on `created_at`, added for the mobile Reports screens (period filtering) but usable generally; each row's `customer` field (for `debt_increase`/`debt_decrease`) is resolved by looking up which `Customer` owns the debt vault on that transaction's ledger leg
- `POST /transactions` — body shape depends on `type` (`income`, `expense`, `transfer`, `debt_increase`, `debt_decrease`); optional `source: 'manual'|'voice'` (default `manual`) grants extra `voice_input` XP; see `src/modules/transactions/dto/create-transaction.dto.ts`
- `POST /transactions/:id/void` — `{ reason? }`; flips `status` to `'voided'` and posts mirrored reversal entries, never a hard delete; the optional `reason` is recorded on the audit log entry only
- `PATCH /transactions/:id` — `{ type, amount, category_id?, from_vault_id?, to_vault_id?, customer_id?, note?, reason? }` ("sửa giao dịch"): never mutates the original row — internally voids it (same as above) and creates a fresh transaction with these values, so the ledger shows exactly what changed. Returns `{ voided_transaction_id, transaction }`. Both the void and the edit are recorded as separate audit log entries

**Customers**
- `GET /workspaces/:id/customers` — includes `debt_balance` (joined from the customer's debt vault) and `created_at`
- `POST /workspaces/:id/customers` — `{ name, phone? }`; auto-creates a `debt_customer` vault
- `GET /customers/:id/debt-history`

**Reports**
- `GET /reports/cashflow?workspace_id=&period=this_week|this_month|this_year`
- `GET /reports/daily-summary?workspace_id=&from_date=&to_date=` — per-calendar-day `{ date, income, expense, profit }` rows (Mục — "tính lãi/lỗ hàng ngày"), a real `GROUP BY date_trunc('day', created_at)` — not a scheduled snapshot job; the ledger already is the history, so this is computed on demand every call (max 400-day range). Days with no transactions simply have no row. Powers both the Dashboard's "today" stat and the mobile Reports "Lợi nhuận" screen's chart/table for any period

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

**Daily closings** (Mục — "chốt sổ cuối ngày")
- `GET /workspaces/:id/daily-closings` — history, newest first
- `GET /workspaces/:id/daily-closings/today` — `{ closed: boolean, closing: {...} | null }` for the current calendar day
- `POST /workspaces/:id/daily-closings` — `{ entries: [{ vault_id, actual_balance }], note? }`; once per workspace per calendar day (`CONFLICT` on a second attempt same day). For each entry, calls the existing `VaultsService.reconcile` (the same per-vault "Kiểm kê" action) to apply the actual-vs-book correction, then bundles the results — `book_balance`/`actual_balance`/`variance` per vault plus a `total_variance` — into one historical row. Not a second source of truth for balances, purely the record of the event

**Audit logs** (Mục — "mọi thao tác sửa/xóa đều ghi log")
- `GET /workspaces/:id/audit-logs?entity_type=&entity_id=&page=&limit=` — append-only; `action` is one of `transaction_edit` | `transaction_void` | `daily_closing`, each row has `before`/`after` JSON snapshots (whatever the acting service already builds as its own DTO — not a generic diffing engine) plus `user_name` and `created_at`. Written by `AuditService.record`, called best-effort (a logging failure never blocks the mutation it's describing) from `TransactionsService.void`/`.edit` and `DailyClosingsService.close`

All error responses use the shape:
```json
{ "error": { "code": "VALIDATION_ERROR", "message": "...", "details": [{ "field": "amount", "message": "..." }] } }
```

## Business logic notes

- Money amounts are stored as `bigint` (whole đồng, no decimals) across `vaults.current_balance`, `transactions.amount`, `transaction_entries.amount` to avoid float rounding.
- Every workspace gets two internal `type='virtual'` vaults ("Doanh thu" for income, "Chi phí" for expense) used as the counter-party leg of double-entry postings. Their balances are never adjusted — they exist purely so every transaction has a debit and a credit leg in `transaction_entries` for audit history.
- Vault balances (`current_balance`) are updated directly by `TransactionsService` per the rules in the spec (not derived by summing `transaction_entries`).
- `POST /transactions/:id/void` reverses the balance effect and appends mirrored reversal entries (side flipped) rather than deleting the original ones, keeping the full audit trail.
- "Sửa giao dịch" (`PATCH /transactions/:id`) is deliberately two ledger events, not one: void the original, then create a fresh transaction with the edited values. This keeps every transaction row immutable once created and reuses the exact same balance/reversal logic void already has, rather than adding a second code path that mutates amounts/vaults in place.

## Not implemented yet / next sprint (explicitly out of scope for this pass)

- Cloud/AI voice commands (OCR receipt scanning, forecast AI, cloud NLU fallback) — the mobile app's voice input uses on-device speech recognition + a rule-based parser instead, see `mobile/README.md`
- A Leon wardrobe/outfit system — the "Game Leon" visual theme itself (mascot, alternate dashboard/nav/achievements skin) and the underlying XP/level/quest/achievement system are both implemented, mobile-side only (no backend changes needed), see `mobile/README.md`
- Subscriptions / ads
- Offline-sync API
- WebSocket realtime updates
- Full roles/permissions JSONB system (this pass uses a simple `role` enum column: `owner`|`manager`|`cashier`|`member`)
