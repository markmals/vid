// swift-tools-version: 6.3

import PackageDescription

let sharedSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
]

let package = Package(
    name: "vid",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CommandExecution", targets: ["CommandExecution"]),
        .library(name: "FFmpeg", targets: ["FFmpeg"]),
        .library(name: "FFprobe", targets: ["FFprobe"]),
        .library(name: "MediaDiscovery", targets: ["MediaDiscovery"]),
        .library(name: "MediaProcessing", targets: ["MediaProcessing"]),
        .library(name: "MediaConversion", targets: ["MediaConversion"]),
        .library(name: "MediaEncoding", targets: ["MediaEncoding"]),
        .library(name: "MediaRemux", targets: ["MediaRemux"]),
        .library(name: "MediaRepair", targets: ["MediaRepair"]),
        .library(name: "MediaSubtitles", targets: ["MediaSubtitles"]),
        .executable(name: "vid", targets: ["vid"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            from: "1.8.2",
        ),
        .package(
            url: "https://github.com/swiftlang/swift-docc-plugin",
            from: "1.4.5",
        ),
        .package(
            url: "https://github.com/swiftlang/swift-subprocess.git",
            revision: "0.5",
        ),
    ],
    targets: [
        .target(
            name: "CommandExecution",
            dependencies: [
                .product(name: "Subprocess", package: "swift-subprocess"),
            ],
            swiftSettings: sharedSwiftSettings,
        ),
        .target(
            name: "FFmpeg",
            dependencies: ["CommandExecution"],
            swiftSettings: sharedSwiftSettings,
        ),
        .target(
            name: "FFprobe",
            dependencies: ["CommandExecution"],
            swiftSettings: sharedSwiftSettings,
        ),
        .target(
            name: "MediaDiscovery",
            swiftSettings: sharedSwiftSettings,
        ),
        .target(
            name: "MediaProcessing",
            dependencies: ["FFmpeg", "FFprobe"],
            swiftSettings: sharedSwiftSettings,
        ),
        .target(
            name: "MediaConversion",
            dependencies: ["FFprobe", "MediaDiscovery", "MediaProcessing"],
            swiftSettings: sharedSwiftSettings,
        ),
        .target(
            name: "MediaEncoding",
            dependencies: ["FFprobe", "MediaProcessing"],
            swiftSettings: sharedSwiftSettings,
        ),
        .target(
            name: "MediaRemux",
            dependencies: ["FFprobe", "MediaProcessing"],
            swiftSettings: sharedSwiftSettings,
        ),
        .target(
            name: "MediaRepair",
            dependencies: ["FFprobe", "MediaProcessing"],
            swiftSettings: sharedSwiftSettings,
        ),
        .target(
            name: "MediaSubtitles",
            dependencies: ["FFprobe", "MediaProcessing"],
            swiftSettings: sharedSwiftSettings,
        ),
        .executableTarget(
            name: "vid",
            dependencies: [
                "FFprobe",
                "MediaConversion",
                "MediaDiscovery",
                "MediaEncoding",
                "MediaProcessing",
                "MediaRemux",
                "MediaRepair",
                "MediaSubtitles",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: sharedSwiftSettings,
        ),
        .testTarget(
            name: "VidTests",
            dependencies: [
                "CommandExecution",
                "FFmpeg",
                "FFprobe",
                "MediaConversion",
                "MediaDiscovery",
                "MediaEncoding",
                "MediaProcessing",
                "MediaRemux",
                "MediaRepair",
                "MediaSubtitles",
                "vid",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: sharedSwiftSettings,
        ),
        .testTarget(
            name: "VidIntegrationTests",
            dependencies: [
                "CommandExecution",
                "FFmpeg",
                "FFprobe",
                "MediaConversion",
                "MediaDiscovery",
                "MediaEncoding",
                "MediaProcessing",
                "MediaRemux",
                "MediaRepair",
                "MediaSubtitles",
                "vid",
            ],
            swiftSettings: sharedSwiftSettings,
        ),
    ]
)
