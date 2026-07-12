# BankSecure (Demo)

Educational iOS banking client built with **SwiftUI**, **SwiftData**, and optional **CloudKit** sync. It is **not** a licensed bank app and does **not** move real money.

## What this app is

- A full-featured **demo** of mobile banking UX: accounts, transfers, UPI-style pay, bill pay, cards, FDs, loans, map locator, profile, and an on-device assistant.
- Data lives **on device** (SwiftData). Optional private CloudKit sync for the same iCloud user.
- Passcode is hashed (SHA-256 + salt) in the **Keychain**; biometrics and inactivity lock are supported.
- UI shows a persistent **Demo mode** banner so users never confuse sample balances with real funds.

## What this app is not

- Not connected to a core banking system, UPI/NPCI, or card networks.
- Not PCI-DSS certified. Cards store **last four digits only** (never full PAN/CVV).
- No backend or network dependency: `NetworkingService` was removed, and there is no server component in this repo.

## Requirements

- Xcode 16+ recommended
- iOS 17+ (Liquid Glass helpers target iOS 26 with Material fallback)
- Apple Developer account if enabling CloudKit (`iCloud` capability + container)

## Project layout

```
Banking Application/
├── BankApp.swift                 # App entry, onboarding → passcode → login → tabs
├── Models/                       # SwiftData models (Account, Transaction, Card, …)
├── Views/                        # SwiftUI screens + DesignSystem + Components
├── ViewModels/                   # MVVM state for accounts, transfers, bills, …
├── Services/                     # Auth, Keychain, Crypto, Persistence, Settings, AI
├── Utilities/                    # CurrencyFormatter (INR)
```

Unit tests live in the sibling folder `Banking ApplicationTests/` (outside the app target so XCTest is not linked into the app binary).

## Key features

| Area | Behavior |
|------|----------|
| Auth | 4-digit passcode (Keychain hash), Face ID/Touch ID (user toggle), lockout, background + inactivity lock |
| Home | Balance (hide/show), charts, quick actions, AI insight, demo banner |
| Transfer / bills / UPI | Local balance updates + transaction records |
| Cards | Masked last4, real daily/monthly spend vs limit progress |
| Settings | Preferences persisted via `AppSettings` |

## Security notes (demo)

- Passcode hash + salt + session token: Keychain, `WhenUnlockedThisDeviceOnly`
- CVV: `@Transient` only
- Card number field: last four digits only
- Preferences (biometrics on/off, notification toggles, hide balances): `UserDefaults` via `AppSettings`

## Running

1. Open `Banking Application.xcodeproj` in Xcode.
2. Select a simulator or device.
3. Build & run. First launch: onboarding → create passcode → demo data is seeded automatically.
4. Optional: enable iCloud → CloudKit and set a real container ID in Signing & Capabilities.

## Tests

Pure unit tests live under `../Banking ApplicationTests/`:

- `CryptoServiceTests` — hash + constant-time compare
- `CardModelTests` — last-four normalization + limit progress
- `CurrencyFormatterTests` — INR formatting
- `TransferValidationTests` — form validation

In Xcode: **File → New → Target → Unit Testing Bundle**, name it `Banking ApplicationTests`, add those Swift files, set `@testable import Banking_Application`, then **Product → Test**.

## Disclaimer

BankSecure is for learning, portfolios, and UI/architecture experimentation only. Do not use it to store real banking credentials or card data.
