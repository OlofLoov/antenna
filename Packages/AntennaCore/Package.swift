// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AntennaCore",
    platforms: [.iOS(.v26), .tvOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "AntennaCore", targets: ["AntennaCore"]),
        .library(name: "AntennaTestSupport", targets: ["AntennaTestSupport"]),
    ],
    targets: [
        .target(
            name: "AntennaCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "AntennaTestSupport",
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "AntennaCoreTests",
            dependencies: ["AntennaCore", "AntennaTestSupport"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
