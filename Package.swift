// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clippy",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Clippy",
            dependencies: ["Yams", "ClippyShared"],
            path: "Clippy"
        ),
        .executableTarget(
            name: "ClippyHelper",
            dependencies: ["Yams", "ClippyShared"],
            path: "ClippyHelper"
        ),
        .target(
            name: "ClippyShared",
            dependencies: ["Yams"],
            path: "ClippyShared"
        ),
        .testTarget(
            name: "ClippyTests",
            dependencies: ["ClippyShared", "Yams"],
            path: "Tests/ClippyTests"
        ),
    ]
)
