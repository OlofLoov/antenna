import AntennaCore
import Foundation
import Testing

/// The app icons and their sources, read from the files at the repository root.
/// `scripts/render-icons.sh` rebuilds everything checked here from `design/icon`.
@Suite struct AppIconTests {
    static let root = WebsiteTests.root
    static let sources = ["glow", "letter", "tips", "tv-back", "tv-middle", "tv-front", "topshelf", "topshelf-wide"]
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

    /// The six-digit colors in an SVG; the masks' `#fff` and `#000` are not counted.
    private func colors(_ path: String) throws -> Set<String> {
        let svg = try String(contentsOf: Self.root.appending(path: path), encoding: .utf8)
        return Set(svg.matches(of: /#[0-9A-Fa-f]{6}\b/).map { $0.output.uppercased() })
    }

    @Test("design-system/one-accent-color-per-profile: the standard icon is the near-white a with teal tips")
    func markColor() throws {
        #expect(try colors("design/icon/letter.svg") == ["#F2F4F8"])
        #expect(try colors("design/icon/tv-middle.svg") == ["#F2F4F8"])
        #expect(try colors("design/icon/tips.svg") == ["#4FD1C5"])
        #expect(try colors("design/icon/tv-front.svg") == ["#F2F4F8", "#4FD1C5"])
        #expect(try colors("design/icon/glow.svg") == ["#1A2A44", "#0B0E13"])
    }

    @Test("design-system/the-antuna-mark: the icon layers cut the play triangle and the mouth out of the a")
    func markShapes() throws {
        for name in ["letter", "tv-middle", "topshelf", "topshelf-wide"] {
            let svg = try String(contentsOf: Self.root.appending(path: "design/icon/\(name).svg"), encoding: .utf8)
            #expect(svg.contains(MarkGeometry.playHole) && svg.contains(MarkGeometry.mouth), "\(name).svg")
            #expect(svg.contains("<mask"), "\(name).svg cuts with a mask")
        }
    }

    @Test("app-release/the-icon-follows-the-home-screen-appearance: the Icon Composer file has its layers and a dark ground")
    func iconComposerFile() throws {
        let document = try json("\(Self.icon)/icon.json")
        let groups = try #require(document["groups"] as? [[String: Any]])
        let images = groups.flatMap { ($0["layers"] as? [[String: Any]]) ?? [] }.compactMap { $0["image-name"] as? String }
        #expect(Set(images) == ["tips.svg", "letter.svg", "glow.svg"])
        for image in images {
            let layer = try String(contentsOf: Self.root.appending(path: "\(Self.icon)/Assets/\(image)"), encoding: .utf8)
            let source = try String(contentsOf: Self.root.appending(path: "design/icon/\(image)"), encoding: .utf8)
            #expect(layer == source, "\(image) differs from design/icon; run scripts/render-icons.sh")
        }
        let specializations = try #require(document["fill-specializations"] as? [[String: Any]])
        #expect(specializations.contains { $0["appearance"] as? String == "dark" })
        let layers = groups.flatMap { ($0["layers"] as? [[String: Any]]) ?? [] }
        let glow = try #require(layers.first { $0["image-name"] as? String == "glow.svg" })
        let hidden = (glow["hidden-specializations"] as? [[String: Any]] ?? []).compactMap { $0["appearance"] as? String }
        #expect(Set(hidden) == ["dark", "tinted"], "the system's own dark and tinted grounds show")
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

    @Test("app-release/alternate-icons-keep-the-mark: six alternates, each the a with its tips in one color on a plain ground")
    func alternates() throws {
        let alternates = AppIconChoice.allCases.compactMap(\.alternateName)
        #expect(
            alternates == ["AppIcon-Mono", "AppIcon-Light", "AppIcon-Blue", "AppIcon-Amber", "AppIcon-Pink", "AppIcon-Violet"])
        for icon in AppIconChoice.allCases {
            guard let name = icon.alternateName else { continue }
            let (ink, tip) = (String(format: "#%06X", icon.ink), String(format: "#%06X", icon.tip))
            #expect(try colors("Apps/Mobile/\(name).icon/Assets/letter.svg") == [ink], "\(name) letter.svg")
            #expect(try colors("Apps/Mobile/\(name).icon/Assets/tips.svg") == [tip], "\(name) tips.svg")
            let document = try json("Apps/Mobile/\(name).icon/icon.json")
            let groups = try #require(document["groups"] as? [[String: Any]])
            #expect(groups.count == 2, "\(name) has the tips and the letter, no glow")
            let fill = try #require((document["fill"] as? [String: Any])?["solid"] as? String)
            let ground = [16, 8, 0].map { String(format: "%.5f", Double((icon.ground >> UInt32($0)) & 0xFF) / 255) }
            #expect(fill == "srgb:\(ground.joined(separator: ",")),1.00000", "\(name) ground")
            for layer in ["back", "middle", "front"] {
                for scale in [1, 2] {
                    let folder = "Apps/TV/Assets.xcassets/\(name).imagestack/\(layer.capitalized).imagestacklayer"
                    let path = "\(folder)/Content.imageset/\(layer)@\(scale)x.png"
                    let size = try pngSize(path)
                    #expect(size.width == 400 * scale && size.height == 240 * scale, "\(path)")
                }
            }
        }
        let project = try String(contentsOf: Self.root.appending(path: "project.yml"), encoding: .utf8)
        let names = alternates.joined(separator: " ")
        #expect(project.contains("ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES[sdk=iphone*]: \(names)\n"), "iPhone and iPad")
        #expect(project.contains("ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES: \(names)\n"), "Apple TV")
    }

    @Test("sources-and-settings/pick-the-app-icon-on-this-device: the system's icon name maps back to a choice")
    func choiceFromTheSystem() {
        #expect(AppIconChoice(alternateName: nil) == .standard)
        #expect(AppIconChoice(alternateName: "AppIcon-Blue") == .blue)
        #expect(AppIconChoice(alternateName: "AppIcon-Sepia") == .standard, "a name this build does not ship")
        #expect(AppIconChoice.standard.alternateName == nil)
    }

    @Test("app-release/alternate-icons-keep-the-mark: a device that had the Teal icon shows the standard one, which is teal")
    func tealIsTheStandardIcon() {
        #expect(AppIconChoice(alternateName: "AppIcon-Teal") == .standard)
        #expect(AppIconChoice.standard.tip == ProfileAccent.teal.rgb && AppIconChoice.standard.glows)
        #expect(AppIconChoice.light.ground == 0xF2F4F8 && AppIconChoice.light.ink == 0x0B0E13 && AppIconChoice.light.tip == 0x119C8F)
        #expect(AppIconChoice.mono.tip == AppIconChoice.mono.ink)
        #expect(AppIconChoice.allCases.filter(\.glows) == [.standard])
    }
}
