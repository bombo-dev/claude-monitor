// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "ClaudeMonitor",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "ClaudeMonitor",
            path: "Sources/ClaudeMonitor",
            exclude: ["App/Info.plist", "App/ClaudeMonitor.entitlements"]
        ),
        .testTarget(
            name: "ClaudeMonitorTests",
            dependencies: ["ClaudeMonitor"],
            path: "Tests/ClaudeMonitorTests"
        ),
    ]
)
