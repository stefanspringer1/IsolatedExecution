// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IsolatedExecution",
    products: [
        .library(
            name: "IsolatedExecution",
            targets: ["IsolatedExecution"]),
        .executable(
            name: "IsolatedExecutionDemo",
            targets: ["IsolatedExecutionDemo"]
        )
    ],
    dependencies: [
        //.package(url: "https://github.com/apple/swift-distributed-actors", from: "0.7.0")
    ],
    targets: [
        .target(
            name: "IsolatedExecution",
            dependencies: []),
        .executableTarget(
            name: "IsolatedExecutionDemo",
            dependencies: ["IsolatedExecution",
            "DistributedCluster"],
            path: "Sources/Sample"
        )
    ]
)
