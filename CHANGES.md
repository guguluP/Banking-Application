# What changed

## 2026-07-12 — Review follow-up (executed)

- **AppSettings** — biometrics, passcode lock, notification prefs, hide balances
  all persist and are shared by Profile, Privacy & Security, Login, Lock, and
  Notifications screens (no more cosmetic-only toggles).
- **Demo mode banner** on home, login, and profile; copy clarified for local data.
- **Cards** — store last four digits only; migrate legacy full-PAN rows on launch;
  daily/monthly spend progress is real (`dailySpent` / `monthlySpent`).
- **Home** — hide/show balance control on the total balance card.
- **Background lock** respects “App Passcode Lock” setting.
- **Backend** — JWT/DB secrets via env placeholders only; README + `.gitignore`
  updated; iOS README rewritten for demo + SwiftData reality.
- **Unit tests** added under `Banking ApplicationTests/` (add XCTest target in
  Xcode to run). App **build succeeded** on device SDK without simulator.

---

This earlier pass rewrote the app's data/security foundation and fixed the bugs found
in the original review.

## 1. Bugs fixed
- `AccountViewModel` silently swallowed load failures — now surfaces `error`.
- `TransferView` and `BillPayView`/`BillPayEmbedded` only simulated a delay and
  never moved any money or wrote a transaction. They now perform a real,
  balance-checked, atomic update against SwiftData.
- `EditProfileView` never loaded the current profile and never saved edits —
  now reads/writes the real `User` record.
- Siri Shortcuts (`PayBillerIntent`, `TransferMoneyIntent`) always returned a
  canned "success" string without touching any data, and their
  `BillerQuery`/`AccountQuery` always returned empty lists (Siri could never
  actually offer a biller/account). Both intents now execute real,
  balance-checked transactions and the queries return live data.
- The app never re-locked itself when backgrounded — `MainTabView` now locks
  on `scenePhase == .background` via a dedicated `isLocked` flag (kept
  separate from `isAuthenticated` so it doesn't tear down the tab state).
- `CardManagementView`/`BillPayView` used hardcoded, duplicated mock arrays
  instead of the shared data store; both now read from SwiftData.

## 2. Apple Intelligence (Foundation Models)
- `AIAssistantService` (root of the project, matching its existing location)
  now checks `SystemLanguageModel.default.availability` and falls back to a
  simple on-device heuristic summary if Apple Intelligence isn't available/
  enabled, instead of failing outright.
- Added `spendingInsight(categories:totalAvailableBalance:)`, used by a new
  **AI Insight** card on the accounts screen that turns the week's spending
  into a one-line, on-device summary. No transaction data leaves the device.
- Siri Shortcuts (`SummarizeTextIntent`, plus the two above) are wired to real
  app data end-to-end.
- **Verify against the current FoundationModels SDK** — the exact API shape
  (`SystemLanguageModel`, `LanguageModelSession.respond`) was written from the
  existing code's pattern and public documentation, not compiled/tested here.

## 3. Security
- Passcode is no longer stored anywhere. Only `SHA256(passcode + per-install
  salt)` is kept, in the Keychain (`KeychainService`) with
  `.whenUnlockedThisDeviceOnly` — never `UserDefaults`.
- Comparison is constant-time (`CryptoService.constantTimeEquals`).
- 5 failed attempts trigger an exponentially increasing lockout (30s → 60s →
  120s → … capped at 15 min), enforced before any comparison runs.
- `Card.cvv` is `@Transient` — it is never persisted or synced, matching
  PCI-DSS's rule that CVV must not be stored after authorization.
- First launch now forces passcode creation (`PasscodeSetupView`) instead of
  accepting "any 4 digits" (the previous `AuthenticationService` stub).
- App auto-locks when backgrounded (see above).
- Added an `.entitlements` file for the iCloud/CloudKit capability. **You
  still need to enable "iCloud → CloudKit" in Xcode's Signing & Capabilities
  and point it at a container you own** — the placeholder ID
  (`iCloud.com.banksecure.app`) won't resolve to your account.

## 4. UI / fluidness
- Added a success overlay + spring animation to `TransferView`.
- Added staggered entrance animation for the recent-transactions list.
- Added a lockout banner with a live countdown and disabled the keypad/
  biometric button during lockout on `LoginView`.
- Added `PasscodeSetupView`, styled to match `LoginView`.
- Fixed the dead "See All" button on the accounts screen (now opens a real,
  searchable transaction list) and the dead "Refresh" action.
- This pass touched the highest-traffic screens directly (login, passcode
  setup, transfer, bill pay, accounts overview, cards, profile). Screens not
  explicitly listed above were left as-is; apply the same GlassCard/spring-
  animation patterns if you want the same treatment everywhere.

## 5. Reduced non-Swift dependencies
- Removed `NetworkingService` and the app's runtime dependency on the
  separate Spring Boot backend (`banking-backend/` is left in the zip but is
  no longer used by the app — keep it only if you still want a server-side
  system of record, otherwise it can be deleted).
- All account/transaction/card/biller/beneficiary data now lives in SwiftData
  on-device, with CloudKit handling multi-device sync — no custom HTTP client
  or JSON Codable plumbing required.

## 6. SwiftData + CloudKit
- `PersistenceController` defines the schema (`User`, `Account`,
  `Transaction`, `Card`, `Beneficiary`, `Biller`, `UPITransaction`) and a
  `ModelContainer` configured with `cloudKitDatabase: .automatic`, syncing
  through the user's **private** CloudKit database only.
- Every model has default values and no `.unique` constraints, as required
  for CloudKit-backed SwiftData.
- A first-run seed creates two demo accounts, sample transactions, one card,
  and three billers so the app is usable immediately.

## Known gaps / next steps
- **Not compiled.** No Swift toolchain was available in this environment;
  review the diff in Xcode and resolve any type/API mismatches, especially
  around the FoundationModels APIs noted above.
- CloudKit requires a real container ID + Apple Developer account
  configuration that only you can provide.
- `PrivacyAndSecurityView`'s toggles (Face ID, notifications, etc.) are still
  cosmetic — wire them to the app's real settings source of truth if you want
  them to do anything.
- Several secondary screens (Onboarding, Notifications, Appearance, Language)
  were left untouched — they didn't have security or data-correctness issues,
  but weren't given the animation/UI pass either.
