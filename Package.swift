// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OhMyIsland",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.4.0"),
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.4.0"),
    
    ],
    targets: [
        .target(
            name: "OhMyIslandCore",
            path: "Sources/OhMyIslandCore"
        ),
        .executableTarget(
            name: "OhMyIsland",
            dependencies: [
                "OhMyIslandCore",
                .product(name: "Lottie", package: "lottie-spm"),
                .product(name: "Markdown", package: "swift-markdown"),
            
            ],
            path: "Sources/OhMyIsland",
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .executableTarget(
            name: "ohmyisland-bridge",
            dependencies: ["OhMyIslandCore"],
            path: "Sources/OhMyIslandBridge"
        ),
        .testTarget(
            name: "OhMyIslandCoreTests",
            dependencies: ["OhMyIslandCore"],
            path: "Tests/OhMyIslandCoreTests"
        ),
        .testTarget(
            name: "OhMyIslandTests",
            dependencies: ["OhMyIsland"],
            path: "Tests/OhMyIslandTests"
        ),
    ]
)
