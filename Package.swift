// swift-tools-version: 6.0
import PackageDescription

// The app is compiled by `scripts/build_app.sh` (a bare `swiftc` invocation), NOT
// by SwiftPM — see AGENTS.md §4. This manifest exists so the pure-logic layers can
// be exercised by `swift test`, and it is not used for shipping builds.
//
// `swiftLanguageMode(.v5)` is REQUIRED, not a preference. Under the default Swift 6
// mode every `static let shared` singleton in the app is a hard
// `#MutableGlobalVariable` error, and the package would not build at all. The
// singletons are the app's deliberate architecture (AGENTS.md §2.1), so the language
// mode is relaxed instead — which also matches the language mode the `swiftc` build
// path actually uses, so the two paths cannot disagree about what compiles.
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
            path: "Sources/DynamicIsland",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Pure-logic regression tests. Only types that are free of AppKit / SwiftUI
        // runtime dependencies belong here — see AGENTS.md §3, "Testability Is a
        // Design Constraint". Tests that need a running app do not belong in this target.
        .testTarget(
            name: "DynamicIslandTests",
            dependencies: ["DynamicIsland"],
            path: "Tests/DynamicIslandTests"
        )
    ]
)
