// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HaByLo",
    // Lowest deployment targets supported by Swift 6 + swift-crypto 3.x across all
    // Apple platforms. Non-Apple Swift 6 platforms (Linux, Android, Windows, WASI)
    // are not declared here — SPM only models Apple OS minimums.
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1),
        .macCatalyst(.v13),
    ],
    products: [
        .library(
            name: "HaByLo",
            targets: ["HaByLo"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.87.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "HaByLo",
            dependencies: [
                .product(
                    name: "NIOCore",
                    package: "swift-nio"),
                .product(
                    name: "Logging",
                    package: "swift-log"),
                .product(
                    name: "Crypto",
                    package: "swift-crypto"),
            ]),
        .testTarget(
            name: "HaByLoTests",
            dependencies: ["HaByLo"]),
    ],
    swiftLanguageModes: [.v6]
)
