# SpendScan

An iPhone app for tracking spending in the UK. Scan a receipt with the camera, pick a photo, or import a PDF, and SpendScan reads every item and price in pounds, sorts it into Food, Utilities, Health, Transport or Other, and shows what you spend each week, month, quarter and year.

**Everything runs on the iPhone and works with no internet.** Receipts are read with Apple's on-device text recognition (Vision), categorised by on-device AI (Apple Intelligence, with built-in rules as a fallback), and stored on the phone with SwiftData. No account is needed.

**Back up and restore (offline).** Deleting the app deletes its receipts. In Settings → Backup, "Back up to a file" saves every receipt (with photos, items and categories) and your category choices as one JSON file wherever you pick, such as Files, iCloud Drive or AirDrop to a Mac. "Restore from a backup" loads it back, skipping receipts already in the app. No internet needed.

**Optional Notion backup.** In Settings → Notion sync you can connect a Notion page. About once a week, when the app is opened with internet, new receipts (merchant, date, total, VAT, payment, categories and every item) are copied to a "SpendScan receipts" database there. Deleted receipts are moved to Notion's trash. If there's no internet, nothing changes and it tries again next time. This is the only network code in the app, and it only talks to `api.notion.com`.

## Security

- The Notion secret is stored in the iOS Keychain (this device only, not backed up), never in files or settings.
- Notion requests use HTTPS with an ephemeral session, so nothing is cached on disk.
- Optional Face ID lock (falls back to the passcode). When it's on, the app is hidden in the app switcher.
- CSV exports are protected while the iPhone is locked, and text cells are escaped so a receipt can't inject spreadsheet formulas.
- PDF import is limited to 25 MB and 10 pages, and password-protected PDFs are rejected.

## Appearance

Settings → Appearance switches between Automatic, Light and Dark. Every colour in `DesignSystem/Theme.swift` has a light and a dark value that match the Figma variables.

- Plan: https://claude.ai/artifact/WkQx5kbizbFzseyfJVVanV
- Designs (Figma): https://www.figma.com/design/Q7kfCzIU5tXDHGyMXVqEMc
- Setup guide: https://claude.ai/artifact/6bHoeZNDRW8zMiBsVnQZ2h

## Requirements

- Xcode 26 on macOS 15.6 or later
- iOS 18 or later (Apple Intelligence categorisation needs iOS 26 on an iPhone 15 Pro or newer)
- No third-party dependencies

## Run it

1. Open `SpendScan.xcodeproj` in Xcode.
2. Pick the iPhone 16 Pro Max simulator and press Run (Cmd + R).
3. In the app, go to Settings → Developer → Add sample receipts to see the dashboards filled in.
4. To run on your own iPhone, set your Team under the SpendScan target → Signing & Capabilities.

The camera scanner only works on a real iPhone. In the simulator, use "Choose from Photos" or "Import a PDF".

## Project layout

```
SpendScan/                      the iOS app
  App/                          app entry, tab bar, sample data
  Models/                       SwiftData models: Receipt, LineItem, UserCategoryRule
  DesignSystem/                 colours and components from the Figma file
  Capture/                      Vision OCR, PDF text, document camera, on-device AI engines
  Features/                     one folder per screen: Home, Capture, Review, Receipts, Analytics, Settings
Packages/ReceiptKit/            pure Swift logic, no UI, fully unit-tested
  Sources/ReceiptKit/
    Parsing/                    money, dates, receipt rows → items and totals
    Categorising/               UK merchant list, keyword rules, Categoriser
    Analytics/                  weekly / monthly / quarterly / yearly totals
  Tests/ReceiptKitTests/        tests, including the Tesco receipt from the designs
```

## Tests

In Xcode, select the ReceiptKit package scheme and press Cmd + U, or from Terminal:

```
cd Packages/ReceiptKit && swift test
```

When a real receipt is read wrongly, paste its text into a new test in `ReceiptParserTests.swift`, then fix the parser until it passes.
