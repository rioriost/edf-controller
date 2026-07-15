// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "EdifierController",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "EdifierCore", targets: ["EdifierCore"]),
        .executable(name: "EdifierController", targets: ["EdifierController"]),
    ],
    targets: [
        .target(name: "EdifierCore"),
        .executableTarget(
            name: "EdifierController",
            dependencies: ["EdifierCore"]
        ),
        .testTarget(
            name: "EdifierCoreTests",
            dependencies: ["EdifierCore"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
