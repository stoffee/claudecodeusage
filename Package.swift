// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "claudecodeusage",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClaudeUsage", targets: ["ClaudeUsage"]),
        .executable(name: "BobUsage", targets: ["BobUsage"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LanesCore",
            path: "LanesCore"
        ),
        .testTarget(
            name: "LanesCoreTests",
            dependencies: ["LanesCore"],
            path: "LanesCoreTests"
        ),
        .executableTarget(
            name: "ClaudeUsage",
            dependencies: ["LanesCore"],
            path: "ClaudeUsage",
            exclude: ["Info.plist"]
        ),
        .executableTarget(
            name: "BobUsage",
            dependencies: [],
            path: "bobusage",
            exclude: ["BobUsage.xcodeproj", "Assets.xcassets", "README.md"]
        )
    ]
)