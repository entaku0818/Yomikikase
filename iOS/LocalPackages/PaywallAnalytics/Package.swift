// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PaywallAnalytics",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "PaywallAnalytics", targets: ["PaywallAnalytics"]),
    ],
    targets: [
        .target(name: "PaywallAnalytics"),
        .testTarget(
            name: "PaywallAnalyticsTests",
            dependencies: ["PaywallAnalytics"]
        ),
    ]
)
