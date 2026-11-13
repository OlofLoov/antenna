import Foundation
import Testing

/// The app icons and their sources, read from the files at the repository root.
/// `scripts/render-icons.sh` rebuilds everything checked here from `design/icon`.
@Suite struct AppIconTests {
    static let root = WebsiteTests.root
    static let sources = ["waves", "mast", "tv-back", "tv-middle", "tv-front", "topshelf", "topshelf-wide"]
    static let icon = "Apps/Mobile/AppIcon.icon"
    static let brand = "Apps/TV/Assets.xcassets/App Icon & Top Shelf Image.brandassets"

    private func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: Self.root.appending(path: path).path)
    }

    private func json(_ path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: Self.root.appending(path: path))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// Width and height from a PNG's header.
    private func pngSize(_ path: String) throws -> (width: Int, height: Int) {
        let data = try Data(contentsOf: Self.root.appending(path: path))
        try #require(data.count > 24 && data.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]))
        let number = { (offset: Int) in data[offset..<offset + 4].reduce(0) { $0 << 8 | Int($1) } }
        return (number(16), number(20))
    }

    @Test("app-release/every-app-shows-its-icon: every SVG source is in design/icon")
    func sourcesExist() {
        for name in Self.sources {
            #expect(exists("design/icon/\(name).svg"), "missing design/icon/\(name).svg")
        }
        #expect(exists("scripts/render-icons.sh"))
    }

    @Test("design-system/one-accent-color: the mark layers draw in the accent and nothing else")
    func markColor() throws {
        for name in ["waves", "mast", "tv-middle", "tv-front"] {
            let svg = try String(contentsOf: Self.root.appending(path: "design/icon/\(name).svg"), encoding: .utf8)
            let colors = Set(svg.matches(of: /#[0-9A-Fa-f]{6}\b/).map { $0.output.uppercased() })
            #expect(colors == ["#5BB8FF"], "\(name).svg uses \(colors.sorted())")
            #expect(!svg.contains("rgb("), "\(name).svg")
        }
    }

    @Test("app-release/the-icon-follows-the-home-screen-appearance: the Icon Composer file has its layers and a dark ground")
    func iconComposerFile() throws {
        let document = try json("\(Self.icon)/icon.json")
        let groups = try #require(document["groups"] as? [[String: Any]])
        let images = groups.flatMap { ($0["layers"] as? [[String: Any]]) ?? [] }.compactMap { $0["image-name"] as? String }
        #expect(Set(images) == ["waves.svg", "mast.svg"])
        for image in images {
            let layer = try String(contentsOf: Self.root.appending(path: "\(Self.icon)/Assets/\(image)"), encoding: .utf8)
            let source = try String(contentsOf: Self.root.appending(path: "design/icon/\(image)"), encoding: .utf8)
            #expect(layer == source, "\(image) differs from design/icon; run scripts/render-icons.sh")
        }
        let specializations = try #require(document["fill-specializations"] as? [[String: Any]])
        #expect(specializations.contains { $0["appearance"] as? String == "dark" })
    }

    @Test("app-release/every-app-shows-its-icon: the Apple TV brand assets hold every image at its size")
    func appleTVAssets() throws {
        let stacks = [("App Icon", 400, 240, [1, 2]), ("App Icon - App Store", 1280, 768, [1])]
        for (stack, width, height, scales) in stacks {
            for layer in ["back", "middle", "front"] {
                for scale in scales {
                    let folder = "\(Self.brand)/\(stack).imagestack/\(layer.capitalized).imagestacklayer"
                    let path = "\(folder)/Content.imageset/\(layer)@\(scale)x.png"
                    let size = try pngSize(path)
                    #expect(size.width == width * scale && size.height == height * scale, "\(path)")
                }
            }
        }
        for (set, file, width) in [("Top Shelf Image", "topshelf", 1920), ("Top Shelf Image Wide", "topshelf-wide", 2320)] {
            for scale in [1, 2] {
                let size = try pngSize("\(Self.brand)/\(set).imageset/\(file)@\(scale)x.png")
                #expect(size.width == width * scale && size.height == 720 * scale, "\(set) @\(scale)x")
            }
        }
    }

    @Test("app-release/every-app-shows-its-icon: project.yml names the icon on both apps")
    func projectWiring() throws {
        let project = try String(contentsOf: Self.root.appending(path: "project.yml"), encoding: .utf8)
        #expect(project.contains("ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon\n"))
        #expect(project.contains("ASSETCATALOG_COMPILER_APPICON_NAME: App Icon & Top Shelf Image\n"))
    }
}
