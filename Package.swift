// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodeIsland",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.4.0"),
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.4.0"),
    
    ],
    targets: [
        .target(
            name: "CodeIslandCore",
            path: "Sources/CodeIslandCore"
        ),
        .executableTarget(
            name: "CodeIsland",
            dependencies: [
                "CodeIslandCore",
                .product(name: "Lottie", package: "lottie-spm"),
                .product(name: "Markdown", package: "swift-markdown"),
            
            ],
            path: "Sources/CodeIsland",
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .executableTarget(
            name: "codeisland-bridge",
            dependencies: ["CodeIslandCore"],
            path: "Sources/CodeIslandBridge"
        ),
        .testTarget(
            name: "CodeIslandCoreTests",
            dependencies: ["CodeIslandCore"],
            path: "Tests/CodeIslandCoreTests"
        ),
        .testTarget(
            name: "CodeIslandTests",
            dependencies: ["CodeIsland"],
            path: "Tests/CodeIslandTests"
        ),
    ]
)
