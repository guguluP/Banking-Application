// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BankThinkingOrbs",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "BankThinkingOrbs", targets: ["BankThinkingOrbs"]),
    ],
    targets: [
        .target(name: "BankThinkingOrbs", path: "Sources/ThinkingOrbsKit"),
    ]
)
