import Foundation
import Testing

/// The page Safari shows for a setup link on an iPhone without Antenna,
/// `Web/setup/index.html` at the repository root.
@Suite struct SetupPageTests {
    let html: String

    init() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        html = try String(contentsOf: root.appending(path: "Web/setup/index.html"), encoding: .utf8)
    }

    private func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap {
            Range($0.range(at: $0.numberOfRanges - 1), in: text).map { String(text[$0]) }
        }
    }

    @Test("iphone-as-setup-device/an-iphone-without-antenna-gets-a-plain-page: what Antenna does and one App Store link")
    func plainPage() throws {
        let body = try #require(matches("<body[^>]*>(.*)</body>", in: html).first)
        let text = body.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        #expect(text == "Antenna sets up your Apple TV from your iPhone. Get Antenna on the App Store")
        let links = matches("<a\\s[^>]*href=\"([^\"]+)\"", in: html)
        #expect(links.count == 1)
        #expect(links.first.flatMap { URL(string: $0)?.host() } == "apps.apple.com")
    }

    @Test("iphone-as-setup-device/an-iphone-without-antenna-gets-a-plain-page: no scripts, images or third-party content")
    func nothingLoaded() throws {
        for tag in ["<script", "<iframe", "<img", "<link"] {
            #expect(!html.lowercased().contains(tag), "\(tag) on the page")
        }
        let head = try #require(matches("<head>(.*)</head>", in: html).first)
        let tags = matches("<([a-z]+)", in: head)
        #expect(Set(tags).isSubset(of: ["meta", "title"]))
    }
}
