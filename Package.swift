// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-cow",
    products: [
        .library(
            name: "CopyOnWrite",
            targets: ["CopyOnWrite"]),
    ],
    dependencies: [
        .package(url: "https://github.com/codergirl-dev/swift-lock", branch: "main")
    ],
    targets: [
        .target(
            name: "CopyOnWrite",
            dependencies: [.product(name: "Lock", package: "swift-lock")]),
        .testTarget(
            name: "CopyOnWriteTests",
            dependencies: ["CopyOnWrite"]
        ),
    ]
)
