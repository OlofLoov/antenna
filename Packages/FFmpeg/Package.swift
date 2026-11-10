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
            url: "https://github.com/OlofLoov/antenna/releases/download/ffmpeg-7.1.3-1/FFmpeg.xcframework.zip",
            checksum: "cf21205f8f931df3e0aaf5d5e916b5052c8d8d191eda0677d63f848926782165"
        ),
        .testTarget(
            name: "FFmpegTests",
            dependencies: ["FFmpeg", .product(name: "AntennaTestSupport", package: "AntennaCore")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
