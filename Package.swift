// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DynamicIsland",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DynamicIsland", targets: ["DynamicIsland"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DynamicIsland",
            dependencies: [],
            path: "Sources/DynamicIsland"
        )
    ]
)
