# SpendScan

An iPhone app for tracking spending in the UK. Scan a receipt with the camera, pick a photo, or import a PDF, and SpendScan reads every item and price in pounds, sorts it into Food, Utilities, Health, Transport or Other, and shows what you spend each week, month, quarter and year.

**Everything runs on the iPhone and works with no internet.** Receipts are read with Apple's on-device text recognition (Vision), categorised by on-device AI (Apple Intelligence, with built-in rules as a fallback), and stored only on the phone with SwiftData. The app has no network code and no accounts.

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
