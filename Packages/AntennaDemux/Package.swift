// swift-tools-version: 6.2
import PackageDescription

// The FFmpeg playback path: reads a stream over HTTP, unpacks it with
// FFmpeg and turns its packets into CMSampleBuffers for Apple's decoders
// and renderers (add-playback-engine, design.md "The FFmpeg path").
let package = Package(
    name: "AntennaDemux",
    platforms: [.iOS(.v26), .tvOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "AntennaDemux", targets: ["AntennaDemux"])
    ],
    dependencies: [
        .package(path: "../AntennaCore"),
        .package(path: "../FFmpeg"),
    ],
    targets: [
        .target(
            name: "AntennaDemux",
            dependencies: [.product(name: "AntennaCore", package: "AntennaCore"), .product(name: "FFmpeg", package: "FFmpeg")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "AntennaDemuxTests",
            dependencies: ["AntennaDemux", .product(name: "AntennaTestSupport", package: "AntennaCore")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
