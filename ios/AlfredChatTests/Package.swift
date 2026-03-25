// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AlfredChatTests",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "AlfredChatKit", path: "Sources/AlfredChatKit"),
        .testTarget(name: "AlfredChatTests", dependencies: ["AlfredChatKit"], path: "Sources/AlfredChatTests"),
    ]
)
