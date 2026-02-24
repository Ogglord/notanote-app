// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotaNote",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "Models",
            path: "Sources/Models"
        ),
        .target(
            name: "Services",
            dependencies: ["Models"],
            path: "Sources/Services"
        ),
        .target(
            name: "Networking",
            dependencies: ["Models"],
            path: "Sources/Networking"
        ),
        .target(
            name: "MCP",
            dependencies: ["Models", "Services", "Networking"],
            path: "Sources/MCP"
        ),
        .executableTarget(
            name: "NotaNote",
            dependencies: ["Models", "Services", "Networking", "MCP"],
            path: "Sources/App",
            resources: [
                .copy("Resources")
            ]
        ),
    ]
)
