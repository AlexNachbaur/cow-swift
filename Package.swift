// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "cow-swift",
    products: [
        .library(name: "CopyOnWrite", targets: ["CopyOnWrite"])
    ],
    targets: [
        .target(name: "CopyOnWrite"),
        .testTarget(name: "CopyOnWriteTests", dependencies: ["CopyOnWrite"])
    ]
)
