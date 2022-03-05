// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "Storage",
    platforms: [.iOS(.v13), .macOS(.v10_15), .watchOS(.v6), .tvOS(.v13)],
    products: [
        .library(
            name: "Storage",
            targets: ["Storage"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Storage",
            dependencies: []),
        .testTarget(
            name: "StorageTests",
            dependencies: ["Storage"]),
    ]
)
