# Sổ Thu Chi — Mobile (Flutter)

Cash-flow management app for shop owners and families (Vietnamese market).
This is the **MVP pass** (Sprint 1-4): auth, workspace picker, and the main
app shell (Dashboard / Transactions / Vaults / Debt / Reports) with a
Classic theme, restyled to match a supplied set of reference screens
(gradient header, card-based summaries, category icon grid, charts). See
`readme.md` at the repo root for the full product spec.

## Requirements

- Flutter 3.41.4 (Dart 3.11.1) or compatible.
- A running instance of the backend (NestJS) — see `../backend`. The API
  contract this app was built against is documented inline in
  `lib/core/constants/api_endpoints.dart` and the repo's `readme.md`.

## Running

```bash
flutter pub get

# Android emulator (default — 10.0.2.2 maps to the host machine's localhost):
flutter run

# iOS Simulator / web / a backend on a different host:
flutter run --dart-define=API_BASE_URL=http://localhost:3000/v1

# Physical device on the same Wi-Fi as the backend:
flutter run --dart-define=API_BASE_URL=http://<host-lan-ip>:3000/v1
```

Verify the build without running an emulator:

```bash
flutter analyze          # should report 0 errors (a few informational lints are OK)
flutter build apk --debug
```

## Building on macOS (iOS)

This project has only ever been built for Android so far (developed on
Windows, which can't target iOS at all). The `ios/` folder is a standard
Flutter iOS project — everything Firebase/permissions-related that *can* be
prepared without a Mac has already been done from this environment:

- **Firebase iOS app already registered** (project `sothuchi-d055a`) and its
  config downloaded to `ios/Runner/GoogleService-Info.plist` (bundle id
  `com.moneyflow.mobile`, matching the Android app).
- **`ios/Runner/Info.plist`** already has the Google Sign-In URL scheme
  (`CFBundleURLTypes` → the `REVERSED_CLIENT_ID` from that plist) and the
  usage-description strings iOS requires at runtime for `speech_to_text`
  (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`)
  and `local_auth` Face ID (`NSFaceIDUsageDescription`).

What still needs a real Mac + Xcode, in order:

1. Install Xcode (App Store) + CocoaPods (`sudo gem install cocoapods` or
   `brew install cocoapods`).
2. `cd mobile && flutter pub get` — on first run for iOS, Flutter generates
   `ios/Podfile` itself (it doesn't exist yet in this repo, since it's only
   ever created/updated by an actual iOS build).
3. Open `ios/Runner.xcworkspace` in Xcode (not the `.xcodeproj`) and:
   - Add `GoogleService-Info.plist` to the `Runner` target if Xcode doesn't
     already show it in the Runner group (it's on disk, but a file sitting
     in the folder isn't automatically part of the build until a project
     file references it — right-click the Runner group → "Add Files to
     Runner…" → select `ios/Runner/GoogleService-Info.plist` → check
     "Copy items if needed" is **off** (it's already in place) and the
     Runner target **on**).
   - Set your own Signing Team under Runner → Signing & Capabilities (a
     free Apple ID works for simulator/local device builds; a paid Apple
     Developer Program account is required for **Sign in with Apple** and
     for distributing to a real device via TestFlight/App Store).
   - **Sign in with Apple**: Signing & Capabilities → "+ Capability" → "Sign
     in with Apple" (needs the paid Developer account above). Then in
     [Firebase Console](https://console.firebase.google.com) → this
     project → Authentication → Sign-in method → enable **Apple**. Until
     both of those are done, the Apple button will keep showing its
     friendly "chưa khả dụng" message — that's the existing, intentional
     fallback (see `social_sign_in_buttons.dart`), not a bug.
   - **Google Sign-In SHA note doesn't apply to iOS** (that's Android-only);
     nothing else is needed for Google Sign-In beyond the URL scheme
     already in `Info.plist`.
4. `flutter run` (Simulator) or `flutter run -d <device-id>` (physical
   iPhone, needs the signing team set above) — same
   `--dart-define=API_BASE_URL=...` flags as Android apply.
5. `flutter build ios` for a release archive once ready to distribute.

Everything else in this README (endpoints, known simplifications, project
structure) applies identically on iOS — the Dart code and API contract
aren't platform-specific.

## Implemented (this pass)

- **Splash** → checks for a stored session (`GET /auth/me`) and routes to
  Login, the Workspace Picker, or straight into the app.
- **Login / Register** (`features/auth`) — email/password, plus **Google
  sign-in** (Firebase Auth + `google_sign_in`, wired to `POST
  /auth/social-login` on the backend, which verifies the Firebase ID token
  and finds-or-creates the user by email). An **Apple sign-in** button is
  also wired (`sign_in_with_apple`, same backend endpoint) but will not
  actually work until Apple is configured in the Firebase project — see
  "Apple Sign-In" below. No OTP email verification (not in the given API
  contract).
- **Workspace Picker** (`features/workspace`) — list, create (Shop/Gia
  đình), select; selection persisted in secure storage.
- **Main shell** with bottom navigation (5 tabs: Tổng quan / Giao dịch / Túi
  tiền / Công nợ / Báo cáo):
  - **Dashboard** (`features/dashboard`) — gradient header with greeting,
    avatar, total balance with a hide/show toggle and a **real** (not
    fabricated) day-over-day % change derived from today's net cashflow;
    Thu/Chi/Thuần stat row; vault carousel with a per-vault progress bar;
    4 quick actions **Thu / Chi / Chuyển / Kiểm kê** (Kiểm kê opens a real
    vault-picker → reconcile flow via `VaultRepository.reconcile()`); 5
    most recent transactions with "Xem tất cả".
  - **Transactions** (`features/transaction`) — infinite-scroll list
    (`page`/`limit=20`), tap for detail + void, FAB opens the create sheet
    with **Thu / Chi / Chuyển tiền / Công nợ** tabs (icon tab bar; Thu/Chi
    now show a category **icon grid** instead of a dropdown; every amount
    field shows a live "amount in words" helper, e.g. `1000000` →
    "Một triệu đồng"; Công nợ has **Bán thiếu / Trả nợ** sub-tabs with a
    "Trả hết" quick-fill button).
  - **Vaults** (`features/vault`) — total-balance header, list, create
    vault with optional initial balance; tapping a vault (here or from the
    Dashboard carousel) opens a **Vault Detail** screen: balance, a 14-day
    trend chart, and the vault's transaction history — see "Vault Detail
    trend chart" below for how the trend is derived.
  - **Debt/Customers** (`features/debt`) — search, Tất cả/Đang nợ/Quá hạn
    filter chips with real counts, summary row, colored initials avatars;
    tapping a customer opens a **detail screen** (debt amount, "Thông tin
    khác" derived from real debt-history totals, full history timeline,
    "Tạo đơn bán thiếu"/"Ghi nhận trả nợ" actions).
  - **Reports** (`features/reports`, new) — overview grid (Dòng tiền /
    Lợi nhuận / Tổng tài sản / Công nợ tiles, each backed by real data —
    see "Reports data notes" below), a monthly overview card, and a mini
    net-cashflow line chart. "Dòng tiền" drills into a detail screen with
    period tabs (Tuần/Tháng/Năm), a real income/expense bar chart
    (`fl_chart`, bucketed client-side from the period's transactions), the
    server-aggregated summary (`GET /reports/cashflow`), and a category
    breakdown list.
  - **Transactions tab filter bar**: period chips (Tất cả/Hôm nay/Tuần/
    Tháng, mapped to `from_date`) + type chips (Thu/Chi/Chuyển), both
    server-side filters via `GET /transactions`.
- **Settings** (`features/settings`) — workspace/user info card;
  **Thành viên** (`features/workspace/presentation/member_management_screen.dart`):
  view/copy/regenerate the workspace's invite code, list members, owner-only
  remove; **Danh mục thu/chi**: view/add/rename/delete (delete is blocked
  server-side with a friendly message if the category is used by a
  transaction); **PIN / Vân tay** (`features/security`, see below); switch
  workspace; logout.
- **Join a workspace by invite code** — the Workspace Picker screen has a
  "Tham gia bằng mã mời" action (app bar icon + empty-state button) wired
  to `POST /workspaces/join`.
- **Voice input** (`features/voice`) — Mục 10: a 5th "Nói" quick action on
  the Dashboard opens a mic sheet using on-device speech recognition
  (`speech_to_text`, no cloud API/key). The transcript is parsed by a
  **rule-based** Vietnamese NLU (`voice_nlu_parser.dart` — keyword/regex
  matching for intent, amount incl. `k`/`nghìn`/`triệu`/`tỷ`/`rưỡi`
  shorthand, and substring matching against the workspace's real vault/
  category names), then always shown as an **editable confirmation form**
  (never auto-saves) before calling the same transaction endpoints the
  manual create sheet uses. See "Voice input notes" below for what this
  simplifies from the spec's original on-device-TFLite + cloud-GPT-4o-mini
  design.
- **App lock (PIN / biometric)** (`features/security`) — Mục 14: set a
  6-digit PIN in Settings → Bảo mật; the app auto-locks after 5+ minutes in
  the background (`AppLockGate`, a `WidgetsBindingObserver` wrapping the
  whole app in `app.dart`) or on a fresh cold start with a PIN configured.
  Fingerprint/Face unlock (`local_auth`) is offered as a shortcut when the
  device has biometrics enrolled, but the PIN is always the fallback. The
  PIN is stored directly in `flutter_secure_storage` (Android Keystore /
  iOS Keychain) — see "App lock notes" below for why that's fine here.
- **Offline-first** (`core/offline`) — Mục 14: a local SQLite cache
  (`sqflite`) plus a pending-operations outbox, so the app stays usable on a
  bad or absent connection instead of just erroring:
  - **Read-through cache**: `GET` responses for vaults, categories,
    customers, and the first page of transactions are cached on every
    successful fetch; if a later fetch fails for connectivity reasons
    (`ApiException` code `CONNECTION_ERROR`/`TIMEOUT`), the repository
    serves the last cached response instead of throwing. The session itself
    (`/auth/me`) and the workspace list are cached the same way, so a **cold
    app start while offline** still restores the logged-in session and
    lands in the app instead of forcing a Login screen the user has no way
    to act on.
  - **Write queue**: creating a transaction while offline doesn't fail — it's
    queued in a local outbox (`SyncQueueService`) and an optimistic "Chờ
    đồng bộ" (pending sync) echo appears immediately in the transaction
    list/Dashboard. `connectivity_plus` watches for the device coming back
    online and automatically flushes the queue, replaying each queued
    mutation through the exact same `POST /transactions` call a live create
    would have made — the backend, not the client, remains the source of
    truth for balances/XP. A queued item that fails for a real server
    reason (not connectivity) once retried is dropped with its error
    recorded, rather than blocking every later item behind it.
  - An `OfflineBanner` (shown in the main shell) surfaces both states: "no
    network" and "N transactions pending sync".
  - **What's deliberately not built**: a full local mirror of every entity
    with two-way sync/conflict resolution. For a double-entry bookkeeping
    app, reimplementing balance math offline (optimistic local vault
    balances, then reconciling against the server's real numbers) is a
    correctness risk out of proportion to the value here — vault/customer
    balances always reflect the last-synced server state, not un-synced
    local writes. Only transaction *creation* is queued; void/reconcile/
    vault-create still require connectivity. Only the first page of each
    cached list is stored (no offline pagination).
- **Excel export** (`core/export/excel_export_service.dart`) — a download
  icon in the AppBar on **Giao dịch**, **Công nợ**, and **Báo cáo** generates
  a real `.xlsx` workbook (via the `excel` package — actual numeric cells,
  not just formatted text) and opens the OS share sheet (`share_plus`) so it
  can be saved or handed straight to a bookkeeper (Zalo, email, Drive, ...):
  - Giao dịch: every transaction matching the screen's current period/type
    filter (fetches every page, not just what's scrolled into view) —
    ngày giờ, loại, số tiền (signed), túi/danh mục, ghi chú, trạng thái.
  - Công nợ: the full customer list — tên, số điện thoại, số dư nợ, ngày tạo.
  - Báo cáo: this month's summary — tổng thu/chi/lợi nhuận (from the same
    server-aggregated `GET /reports/cashflow` the overview screen shows),
    tổng tài sản, công nợ phải thu.
- **Gamification** (`features/gamification`) — Mục 9: a "Lv.N" badge in the
  Dashboard header (tap to open) links to a dedicated **Thành tích** screen
  showing XP/level progress, the current weekly quest (dynamically computed
  server-side, no cron) with a "Nhận thưởng" claim button once complete, and
  an achievement grid (locked ones shown greyed-out with a lock icon). Backs
  onto `GET /gamification/profile` / `POST /gamification/claim-quest`. XP is
  awarded server-side as a best-effort call after each core action commits
  (transaction create, voice input, debt payoff, perfect reconcile, member
  invited).
- **"Game Leon" visual style** (`core/theme/visual_style_provider.dart`,
  `shared/widgets/leon_mascot.dart`, `shared/widgets/game/`) — Mục 16.2: an
  alternate dark arcade skin, switchable per-device in Settings → Giao diện
  (persisted in secure storage), built around **Leon**, a lion mascot drawn
  entirely with `CustomPainter` (no image assets — see `leon_mascot.dart`'s
  doc comment) with idle breathing/blink animation and mood states (happy/
  excited/sleepy/proud) that react to XP progress and quest state. Applies
  to three screens: **Dashboard** (`game_dashboard_body.dart` — Leon +
  glowing XP bar in the hero, vaults rendered as "treasure chest" cards,
  quick actions as chunky neon arcade buttons, recent transactions as a
  "quest log"), the **bottom nav** (dark bar, selected tab glows), and
  **Thành tích** (`game_gamification_body.dart` — Leon front and center,
  the weekly quest as a mission card with a pulsing gold claim button,
  achievements as glowing medals). Every other screen (forms, lists,
  settings) intentionally stays Classic regardless of this setting — a full
  reskin of dense data/entry screens would hurt usability for a bookkeeping
  app, so the game skin is scoped to the screens actually meant to feel
  playful. Both skins read the exact same providers/data; only presentation
  differs.
- **Onboarding tour** (`features/onboarding`) — a 5-slide `PageView` shown
  once on first launch after login (gated in `app.dart`'s router redirect,
  state persisted in secure storage via `onboardingSeen`), with Skip/Next/
  "Bắt đầu ngay". Doesn't re-appear after being seen or skipped.
- **Budgets** (`features/budget`) — Mục — set a monthly spending limit
  either per-category or for total spend (Settings → Ngân sách). Always
  implicit "this calendar month" (no period picker/history — see
  `Budget.entity.ts`'s doc comment on the backend). The Dashboard shows a
  warning banner (both Classic and Game Leon skins) once any budget crosses
  80% of its limit, tapping it opens the Budget screen.
- **Recurring transactions** (`features/recurring`) — Mục — set up a
  template (type, amount, vault/category/customer, daily/weekly/monthly
  frequency, start date) from Settings → Giao dịch định kỳ; due occurrences
  are **materialized lazily**, not via a server cron: the Dashboard calls
  `POST .../recurring/run-due` as a best-effort step on every load (see
  `dashboard_notifier.dart`), which creates any transactions whose
  `next_run_date` has passed (catches up on up to 24 missed occurrences if
  the app hasn't been opened in a while) using the exact same
  `TransactionsService.create` a manual entry would.
- **Shifts / ca làm việc** (`features/shift`) — Mục — "Mở ca" snapshots
  every real-money vault's balance; the shift stays open until "Kết thúc
  ca", which snapshots again. Income/expense-during-shift is derived
  server-side from transactions created in that time window — no separate
  ledger. History list shows past closed shifts with thu/chi/ròng per shift.
- **Push notifications** (`core/notifications`, backend
  `modules/notifications`) — Mục — Firebase Cloud Messaging. The app
  registers its FCM token (`PATCH /notifications/fcm-token`) once signed in
  with a workspace selected, and unregisters at logout. The backend sends
  (best-effort, never blocks the triggering request) on: a new transaction
  (to other workspace members, not the creator), a budget just crossing its
  limit (the exact moment spend goes from at-or-under to over, not on every
  later expense), and recurring transactions materializing. In the
  foreground, `flutter_local_notifications` shows a heads-up banner
  (Android/iOS suppress the system tray for a foregrounded app by default);
  backgrounded/terminated relies on the OS's own system-tray display for the
  FCM `notification` payload. Tapping a notification deep-links via
  `go_router` (`/transactions` or `/budgets`). iOS needs an APNs key from an
  Apple Developer account to actually receive pushes on a real device — not
  available here (see "Building on macOS"); the Android path is fully wired
  and testable.
- **Networking**: `dio` client with an interceptor that attaches the bearer
  token and transparently refreshes on `401` via `POST /auth/refresh`
  (concurrent 401s share one refresh call); forces the user back to Login
  if refresh also fails.
- **Currency input**: `CurrencyInputFormatter` (live dot-grouped thousands,
  e.g. `1000000` → `1.000.000`) used on every amount field, per spec Mục
  19.1.1.
- **Validation**: email format, password strength (register), amount > 0,
  note ≤ 500 chars, name 1-100 chars — inline `TextFormField` validators.
- **Error handling**: the backend's `{ error: { code, message, details } }`
  envelope is parsed into `ApiException` and shown via `SnackBar`.

## Google / Apple sign-in (Firebase project `sothuchi-d055a`)

- Firebase project, Android app (`com.moneyflow.mobile`), debug-keystore
  SHA-1/SHA-256, and `android/app/google-services.json` are already set up.
  Google sign-in is enabled in Firebase Authentication and works end-to-end
  on Android.
- **iOS app registered too** (`ios/Runner/GoogleService-Info.plist`, same
  bundle id) — see "Building on macOS" above for the remaining Xcode-side
  steps a Mac needs to actually build and run it.
- **Apple Sign-In is not functional yet.** It requires an Apple Developer
  Program account (paid) to create a Services ID + Sign in with Apple key,
  which then gets registered in Firebase Console → Authentication → Sign-in
  method → Apple, plus the "Sign in with Apple" capability added in Xcode
  (needs a Mac — see "Building on macOS" above). The button/code path exists
  (`SocialAuthService.signInWithApple`) and will show a friendly "chưa khả
  dụng" message until that's done.
- If a **release** (signed, not debug) APK/AAB is built later, its signing
  certificate's SHA-1/SHA-256 must also be added to the Firebase Android
  app, or Google sign-in will fail on release builds with `DEVELOPER_ERROR`.

## Known simplifications / deviations from the full spec

- **Dashboard "today" income/expense is an approximation**: there is no
  `GET /transactions?date=today` endpoint, so it's derived by filtering the
  most recent 20 transactions (assumed newest-first) to those created today
  (device-local date). Documented in `dashboard_notifier.dart`.
- **"Bán thiếu" has no due-date picker** — the `debt_increase` endpoint
  only accepts `{ workspace_id, customer_id, amount, note }`, no due date
  field, so it was omitted client-side too. This is also why the Debt
  tab's "Quá hạn" filter/summary and the customer detail screen show no
  overdue badge — there's no due date to compare against.
- **Categories are now seeded by the backend** (`DEFAULT_CATEGORIES` in
  `backend/src/modules/categories/categories.constants.ts`, 7 income + 7
  expense categories with a stable `icon` key mapped to a Material icon in
  `category_icons.dart`) so the new category grid isn't empty for new
  workspaces. There's still no UI to create/edit a category with a custom
  icon — only the seeded ones show in the grid, plus whatever a future
  category-management screen creates (it'll fall back to a generic icon).
- **Reports data notes** (`features/reports`):
  - "Lợi nhuận" (profit) on the overview grid is shown as **net cashflow**
    (thu − chi). The backend has no separate cost-of-goods/giá vốn
    tracking in this MVP pass, so true profit isn't derivable — this is a
    labeled approximation, not a bug.
  - The cashflow detail screen's bar chart and category breakdown are
    computed **client-side** from a same-period transaction fetch (up to
    300 rows, using the `from_date`/`to_date` params added to
    `GET /transactions` for this purpose) — the backend's
    `GET /reports/cashflow` only returns totals, not a bucketed/category
    breakdown. The summary numbers shown alongside (Tổng thu/Tổng chi/Dòng
    tiền thuần) are the real server-aggregated ones.
  - **Tuần/Tháng/Năm** map straight to the 3 periods `GET /reports/cashflow`
    supports server-side (always relative to "now"). A 4th **Tùy chọn**
    chip opens a date-range picker; since the server endpoint can't do
    arbitrary ranges, that path (`customCashflowDetailProvider`) computes
    the summary/chart/breakdown **entirely client-side** from a fetched
    transaction batch instead of calling `GET /reports/cashflow` at all —
    still real data, just not server-aggregated. No "Quý" chip or prev/next
    arrows on the fixed periods.
- **Vault Detail trend chart**: there's no per-vault balance-history
  endpoint, so the 14-day line is reconstructed client-side by walking
  backward from the vault's current (real) balance, undoing each of that
  vault's own transactions in `vault_detail_screen.dart`'s
  `_BalanceTrendChart`. This is exact for the transactions the client can
  see (up to the last 100 for that vault) — if a vault has more than 100
  transactions in the 14-day window the oldest days in the chart could be
  slightly off; acceptable for a shop-scale MVP.
- **Voice input notes**: the spec's Mục 10 design is on-device TensorFlow
  Lite NLU with a cloud GPT-4o mini fallback for low-confidence/complex
  utterances — that needs a trained model and an AI API key, neither of
  which exist in this environment. `voice_nlu_parser.dart` is a plain
  deterministic keyword/regex parser instead: it handles the common single-
  transaction phrasings from the spec's own examples ("thu 500k tiền mặt
  bán hàng") but won't reliably parse the multi-transaction or highly
  colloquial examples in Mục 10.4/10.6 ("hôm qua thu 500k... chi 200k...",
  regional slang like "cắc"/"đồng gộp"). Every parse is shown as an
  editable form before saving specifically because of this — nothing is
  silently trusted. Speech recognition itself is the device OS's own
  engine (`speech_to_text` → Android `SpeechRecognizer`), so its Vietnamese
  accuracy depends on the device/OS, not on anything this app controls.
- **App lock notes**: the PIN gates the *app*, not a specific account — it
  isn't cleared on logout, so if the device is shared and a second person
  logs into a different account, they'd still need the first person's PIN
  to get past the lock screen. This matches common "app lock" patterns
  (not tied to server auth) and is a deliberate simplification, not a bug.
  `MainActivity.kt` was switched from `FlutterActivity` to
  `FlutterFragmentActivity` (required by `local_auth` for the biometric
  prompt) and `minSdk` is pinned to 23 (already required by Firebase Auth).
- Classic theme colors (`lib/core/constants/app_colors.dart`) are an
  original choice — the spec only defines a palette for the "Game Leon"
  theme (Mục 16.2).
- **Gamification notes**: the backend XP/level/quest/achievement system
  (Mục 9) is fully implemented and live — see "Gamification" above, and the
  "Game Leon" visual style (Dashboard/nav/Thành tích skin, hand-painted Leon
  mascot) is implemented too — see "Game Leon visual style" above. What's
  **not** built is a wardrobe/outfit system for Leon (no such data exists
  server-side to hang it off) and a fully-independent alternate app (every
  other screen — forms, lists, settings — stays Classic; see that section
  for why). The weekly quest is a single fixed quest ("Tạo 20 giao dịch
  trong tuần") rather than a rotating pool, computed on-demand from a
  transaction count query (no cron/scheduler infrastructure) rather than
  pre-generated.

## Explicitly out of scope this pass (next sprint+)

Per the MVP scope for this pass, none of the following are implemented —
no stub folders were left for them:

- AI assistant / wake word / cloud NLU fallback (see "Voice input notes").
- A Leon wardrobe/outfit system — see "Gamification notes" above. The
  underlying XP/level/quest/achievement system and the "Game Leon" visual
  style itself are both implemented.
- Ads (AdMob) and in-app purchases / Pro gating.
- OCR (receipt scanning).
- i18n / multi-language — all strings are hardcoded Vietnamese, no `.arb`
  files.
- Bank/e-wallet integrations, notification settings, backup & restore,
  forgot-password (no email-sending infra configured — would need real
  SMTP/provider credentials from the project owner, similar to the Apple
  Sign-In situation).
- "Tổng tài sản" and "Công nợ" report tiles are shortcuts into the existing
  Vaults/Debt tabs rather than dedicated report pages with their own
  breakdowns/history — building those out is a natural next step once
  there's appetite for it.

## Project structure

Feature-first, per spec Mục 18.2:

```
lib/
  main.dart / app.dart          # entry point, GoRouter + MaterialApp setup
  core/                         # constants, network (dio + auth interceptor),
                                 # utils (currency formatter), typed API errors,
                                 # offline/ (SQLite cache + sync queue, Mục 14)
  features/
    auth/ workspace/ dashboard/ vault/ transaction/ debt/ category/ reports/
    settings/ gamification/ voice/ security/
      data/        # repositories talking to the backend
      domain/      # plain model classes
      presentation/ # screens, sheets, Riverpod notifiers
  shared/
    widgets/       # EmptyStateWidget, AmountTextField, InitialsAvatar, MainShellScreen
    providers/     # dioProvider, secureStorageProvider, currentWorkspace*
```
