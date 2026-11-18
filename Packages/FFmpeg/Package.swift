// swift-tools-version: 6.2
import PackageDescription

// The LGPL FFmpeg build for the FFmpeg playback path, published by
// .github/workflows/ffmpeg.yml from scripts/build-ffmpeg.sh. A new build
// gets a new ffmpeg-* tag; update the url and checksum here to use it.
let package = Package(
    name: "FFmpeg",
    platforms: [.iOS(.v26), .tvOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "FFmpeg", targets: ["FFmpeg"])
    ],
    dependencies: [
        .package(path: "../AntennaCore")
    ],
    targets: [
        .binaryTarget(
            name: "FFmpeg",
            url: "https://github.com/OlofLoov/antenna/releases/download/ffmpeg-7.1.3-3/FFmpeg.xcframework.zip",
            checksum: "0b3a19bd6d444ca47de349c9faf831321010b9a8faf01e8b528117f885f6cc86"
        ),
        .testTarget(
            name: "FFmpegTests",
            dependencies: ["FFmpeg", .product(name: "AntennaTestSupport", package: "AntennaCore")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
