// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "coding-agent-percentage",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "coding-agent-percentage", targets: ["CodingAgentPercentage"])
    ],
    targets: [
        .executableTarget(name: "CodingAgentPercentage"),
        .testTarget(
            name: "CodingAgentPercentageTests",
            dependencies: ["CodingAgentPercentage"]
        )
    ]
)
