// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "List",
    products: [
        .executable(name: "list", targets: ["List"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            .upToNextMajor(from: "1.5.0")
        )
    ],
    targets: [
        .executableTarget(
            name: "List",
            dependencies: [
               .product(name: "ArgumentParser", package: "swift-argument-parser"),
           ],
           path: "Sources"
        ),
    ]
)
