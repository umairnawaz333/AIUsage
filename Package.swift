// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AIUsage",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AIUsage",
            path: "Sources/AIUsage",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "AIUsageTests",
            dependencies: ["AIUsage"],
            path: "Tests/AIUsageTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
