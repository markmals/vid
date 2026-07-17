// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "vid",
    targets: [
        .executableTarget(
            name: "vid",
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
