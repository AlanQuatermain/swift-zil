// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-zil",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0"),
        .watchOS("26.0"),
        .tvOS("26.0"),
        .visionOS("26.0")
    ],
    products: [
        // Core library for ZIL compilation and Z-Machine execution
        .library(
            name: "ZEngine",
            targets: ["ZEngine"]
        ),
        // Unified command-line tool
        .executable(
            name: "zil",
            targets: ["zil"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-testing", from: "6.2.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.0.0")
    ],
    targets: [
        // Core library target
        .target(
            name: "ZEngine",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ]
        ),

        // Unified command-line tool target
        .executableTarget(
            name: "zil",
            dependencies: [
                "ZEngine",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),

        // Test targets
        .testTarget(
            name: "ZEngineTests",
            dependencies: [
                "ZEngine",
                .product(name: "Testing", package: "swift-testing"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
    ]
)
