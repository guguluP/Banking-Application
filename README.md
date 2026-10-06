# BankSecure

[![Platform](https://img.shields.io/badge/platform-iOS%2026%2B-lightgrey)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-6-orange)](#requirements)
[![UI](https://img.shields.io/badge/UI-SwiftUI-blue)](#tech-stack)
[![Status](https://img.shields.io/badge/status-demo%20%2F%20educational-yellow)](#disclaimer)

An educational **mobile banking client** built with SwiftUI and SwiftData. Data lives on-device with no backend server, though it isn't fully offline — see the network note below. BankSecure demonstrates production-style architecture, security patterns, and polish for a consumer banking app — accounts, transfers, UPI-style payments, bill pay, cards, fixed deposits, loans, and an on-device AI assistant — without connecting to any real bank, card network, or payment rail.

> **This is a demo app.** It does not move real money, is not PCI-DSS certified, and is not affiliated with any financial institution. See [Disclaimer](#disclaimer).

---

## Screenshots

| Home | Cards | Sign In |
|---|---|---|
| ![Home dashboard](docs/screenshots/01-home.png) | ![Metallic card management](docs/screenshots/02-cards.png) | ![Passcode sign in](docs/screenshots/03-login.png) |

| Transfer | Notifications |
|---|---|
| ![Transfer money](docs/screenshots/04-transfer.png) | ![Notifications](docs/screenshots/05-notifications.png) |

## Demo videos

Two screen recordings walking through the app's flows are included in [`docs/videos`](docs/videos). GitHub doesn't autoplay video inline in a README, so click a thumbnail below to open/download the clip.

[![Demo video 1](docs/screenshots/demo-1-thumb.png)](docs/videos/demo-1.mov)
[![Demo video 2](docs/screenshots/demo-2-thumb.png)](docs/videos/demo-2.mp4)

> **Repo size note:** these recordings are ~55 MB combined. That's under GitHub's 100 MB hard limit but well past its "large file" warning threshold. If you'd rather keep the repo lean, consider [Git LFS](https://git-lfs.com) for `docs/videos/`, or upload the clips to YouTube/an external host and link to them here instead.

---



## Table of contents

- [Screenshots](#screenshots)
- [Demo videos](#demo-videos)
- [Features](#features)
- [Tech stack](#tech-stack)
- [Project structure](#project-structure)
- [Requirements](#requirements)
- [Getting started](#getting-started)
- [CloudKit setup (optional)](#cloudkit-setup-optional)
- [Security model](#security-model)
- [Testing](#testing)
- [Disclaimer](#disclaimer)
- [License](#license)

---

## Features

| Area | Details |
|---|---|
| **Onboarding & Auth** | Guided onboarding, 4-digit passcode (Keychain-hashed), Face ID / Touch ID, lockout after repeated failures, background + inactivity auto-lock |
| **Home** | Balance overview with hide/show toggle, spending charts, quick actions, AI-generated spending insight, persistent demo-mode banner |
| **Transfers & Payments** | Internal transfers, UPI-style payments, bill pay — all backed by real local balance updates and transaction records |
| **Cards** | Card management with masked (last-4) numbers, live daily/monthly spend vs. limit tracking |
| **Fixed Deposits & Loans** | FD creation with rate cards, loan tracking with an amortization calculator |
| **Beneficiaries & Billers** | Add/manage payees and billers, IFSC lookup for bank transfers |
| **AI Assistant** | On-device chatbot for account insights and support (Apple Intelligence / Foundation Models where available, with graceful fallback) |
| **Siri & Spotlight** | App Intents for quick actions and Spotlight search integration |
| **Settings** | Appearance, language & region, notifications, privacy & security — all backed by persisted `AppSettings` |
| **Sync** | On-device SwiftData only. CloudKit, Push, App Groups, and the Data Protection entitlement are not in the signed app, because a free Personal Team cannot provision them |

## Tech stack

- **SwiftUI** — declarative UI across all screens
- **SwiftData** — on-device persistence for accounts, transactions, cards, beneficiaries, billers, FDs, and loans (`cloudKitDatabase: .none`)
- **Keychain Services** — passcode hash, salt, and session token storage
- **PrivacyInfo.xcprivacy** — App Store privacy manifest. The app does not track. UserDefaults is declared for app preferences (`CA92.1`)
- **App Intents** — Siri shortcuts and Spotlight indexing
- **Foundation Models / Apple Intelligence** — on-device AI assistant, with fallback for unsupported devices/OS versions

No analytics or ad SDKs are included, and there is no backend server in this repository. The one exception is `IFSCLookupService`, which calls a free public third-party API (Razorpay's IFSC directory) to resolve bank branch details — see [What this app is not](Banking%20Application/README.md) for exactly what it sends.

## Project structure

```
Banking Application/
├── Banking Application.xcodeproj/     # Xcode project
├── Banking Application/               # App target
│   ├── BankApp.swift                  # Entry point — onboarding → passcode → login → tabs
│   ├── Banking Application.entitlements
│   ├── Models/                        # SwiftData models (Account, Transaction, Card, Loan, …)
│   ├── ViewModels/                    # MVVM state (Account, Transfer, BillPay, FixedDeposit, Loan, …)
│   ├── Views/                         # SwiftUI screens
│   │   ├── Components/                # Reusable UI components
│   │   └── DesignSystem/              # Shared styling, typography, GlassCard, etc.
│   ├── Services/                      # Auth, Keychain, Crypto, Persistence, Settings, AI chatbot
│   ├── Managers/                      # Spotlight indexing, etc.
│   ├── Intents/                       # Siri / App Intents
│   ├── Utilities/                     # Currency formatting (INR), helpers
│   └── Assets.xcassets/               # App icon, colors, images
└── Banking ApplicationTests/           # XCTest unit tests (separate target)
```

## Requirements

- **Xcode 26** or later
- **iOS 26+** target device or simulator (the project's `IPHONEOS_DEPLOYMENT_TARGET` is 26.0; earlier-OS Material-style fallback code exists in a few places like `LiquidGlass.swift` and `AIChatbotService` but is currently unreachable at this deployment target — lower it only after confirming those paths still build and behave correctly)
- A free Apple Personal Team can run the app. Paid capabilities (Push, iCloud, App Groups, the Data Protection entitlement) are not enabled

## Getting started

1. Clone the repository and open `Banking Application.xcodeproj` in Xcode.
2. Select a simulator or a physical device as the run destination.
3. Build and run (`⌘R`).
4. On first launch: complete onboarding → create a passcode → demo data (sample accounts, transactions, cards, and billers) is seeded automatically.
5. A **Demo Mode** banner is shown throughout the app to make clear that no real financial data is involved.

No environment variables, API keys, or backend setup are required to run the app locally.

## Signing on a free team

The entitlements files are empty. A free Personal Team cannot provision these capabilities, so they are not in the app:

- Push Notifications (`aps-environment`)
- iCloud / CloudKit, including the old `iCloud.com.banksecure.app` container
- App Groups (`group.com.piyushpatnaik.Banking-Application`)
- The Data Protection entitlement (`com.apple.developer.default-data-protection`)

SwiftData stays on device. File protection is still applied with `FileManager.setAttributes` where the store is written, which does not need that entitlement. After pulling these changes, use Product → Clean Build Folder so Xcode regenerates the provisioning profile.

The Messages filter (`BankSMSFilter`) records a bank SMS only after you turn it on once in Settings → Messages → Unknown & Spam → BankSecure. Without an App Group, that extension and the app do not share an inbox, so automatic import from the filter waits on a paid Developer Program membership. The Shortcut intent `ImportBankSMSIntent` is still in the app.

## Security model

BankSecure follows realistic mobile banking security patterns, scoped appropriately for a demo:

- **Passcode** — 4-digit passcode, stored as PBKDF2-HMAC-SHA256 (`pbkdf2$120000$` plus 32 bytes) with a random salt in the Keychain (`WhenUnlockedThisDeviceOnly`). Older salted SHA-256 hashes still verify and are replaced with PBKDF2 on the next successful check. Failed attempts use an exponential lockout measured with `ProcessInfo.systemUptime` and a stored boot anchor, so changing the wall clock does not clear it.
- **Step-up** — paying asks for the passcode or biometrics again and does not treat that success as a fresh login.
- **Decoy passcode** — a second code opens an empty home and blocks money movement.
- **Biometrics** — optional Face ID / Touch ID, user-toggleable, with the app passcode as the fallback.
- **Session handling** — background lock and inactivity timeout, governed by the "App Passcode Lock" setting.
- **Card data** — only the last four digits of a card number are ever stored; the CVV field is marked `@Transient` and is never persisted.
- **Imports** — bank SMS and the sandbox Account Aggregator share one pipeline (parse, dedupe, review under confidence 0.7, then post). The parser keeps fields and a hash, not the raw SMS. OTP-style texts are dropped.
- **Network** — `IFSCLookupService` sends only the IFSC code you type to Razorpay's public branch API. The Account Aggregator screen talks to `http://127.0.0.1:8787` when `aggregator-backend/server.js` is running. That server is a local stand-in: one demo debit, deleted after the first fetch. It is not Setu, Finvu, or Anumati.

This is a portfolio/architecture demonstration, **not** a PCI-DSS or SOC 2 certified system, and should not be used to store real card numbers, CVVs, or banking credentials.

## Testing

Unit tests live in the separate `Banking ApplicationTests/` target (kept out of the app target so XCTest is never linked into the shipped binary):

| Test file | Coverage |
|---|---|
| `CryptoServiceTests` | Passcode hashing and constant-time comparison |
| `CardModelTests` | Card number normalization (last-4) and spend/limit progress |
| `CurrencyFormatterTests` | INR currency formatting |
| `TransferValidationTests` | Transfer form validation logic |
| `PaymentServiceTests` | Internal credit, frozen accounts, failed-save rollback, SMS parse, lockout clock |

The unit-test target is already in the Xcode project and in the shared scheme. Product → Test (`⌘U`) runs it. This Mac had no iOS Simulator runtime installed, so the last check here was a simulator compile only.

The optional `aggregator-backend` folder is a sandbox stand-in for Account Aggregator consent. It is not a core-banking server. Day-to-day accounts still live in SwiftData.

## Disclaimer

BankSecure is built for **learning, portfolio demonstration, and UI/architecture experimentation only**.

- It is **not** a licensed bank, e-money, or payments product.
- It is **not** connected to any core banking system, UPI/NPCI network, or card scheme.
- It does **not** move, hold, or transmit real money.
- Do **not** enter real banking credentials, real card numbers, or any real personal financial data into this app.

## License

Add your preferred license here (e.g. MIT) before making this repository public.
