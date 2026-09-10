// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "DragShelf",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "DragShelf",
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        )
    ]
)
