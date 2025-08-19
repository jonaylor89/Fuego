// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Fuego",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Fuego",
            targets: ["Fuego"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Fuego",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Sources/Fuego",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "FuegoTests",
            dependencies: ["Fuego"],
            path: "Tests/FuegoTests"
        )
    ]
)