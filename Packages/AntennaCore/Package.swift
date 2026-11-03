// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AntennaCore",
    platforms: [.iOS(.v17), .tvOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AntennaCore", targets: ["AntennaCore"]),
    ],
    targets: [
        .target(
            name: "AntennaCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "AntennaCoreTests",
            dependencies: ["AntennaCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
