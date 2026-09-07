// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "vc-funding",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "vc-funding", targets: ["CodingAgentPercentage"])
    ],
    targets: [
        .executableTarget(
            name: "CodingAgentPercentage",
            resources: [.copy("Resources/Icons")]
        ),
        .testTarget(
            name: "CodingAgentPercentageTests",
            dependencies: ["CodingAgentPercentage"]
        )
    ]
)
