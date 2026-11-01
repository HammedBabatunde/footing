// swift-tools-version: 6.0
import PackageDescription

// ReceiptKit holds the logic that turns receipt text into structured spending.
// It has no UI and no network code, so it can be tested on a Mac with `swift test`.
let package = Package(
    name: "ReceiptKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "ReceiptKit", targets: ["ReceiptKit"])
    ],
    targets: [
        .target(name: "ReceiptKit"),
        .testTarget(name: "ReceiptKitTests", dependencies: ["ReceiptKit"])
    ]
)
