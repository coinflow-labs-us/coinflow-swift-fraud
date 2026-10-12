// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CoinflowFraud",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "CoinflowFraud",
            targets: ["CoinflowFraud"]
        )
    ],
    // Core only: the signal SDKs are CocoaPods dependencies (see CoinflowFraud.podspec), so a SwiftPM
    // build has no adapters and exists for running the unit tests.
    targets: [
        .target(
            name: "CoinflowFraud",
            path: "Sources/CoinflowFraud"
        ),
        .testTarget(
            name: "CoinflowFraudTests",
            dependencies: ["CoinflowFraud"],
            path: "Tests/CoinflowFraudTests"
        )
    ]
)
