// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "vid",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            from: "1.8.2",
        ),
        .package(
            url: "https://github.com/swiftlang/swift-subprocess.git",
            revision: "0.5",
        ),
    ],
    targets: [
        .executableTarget(
            name: "vid",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Subprocess", package: "swift-subprocess"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "VidTests",
            dependencies: ["vid"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ]
)
