// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "DropoverClone",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "DropoverClone",
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        )
    ]
)
