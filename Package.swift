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
        .executableTarget(
            name: "ClaudeUsage",
            dependencies: [],
            path: "ClaudeUsage"
        ),
        .executableTarget(
            name: "BobUsage",
            dependencies: [],
            path: "bobusage",
            exclude: ["BobUsage.xcodeproj", "Assets.xcassets", "README.md"]
        )
    ]
)