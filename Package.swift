// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlappyBirdMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FlappyBirdMac", targets: ["FlappyBirdMac"])
    ],
    targets: [
        .executableTarget(
            name: "FlappyBirdMac",
            resources: [
                .copy("Assets")
            ]
        )
    ]
)
