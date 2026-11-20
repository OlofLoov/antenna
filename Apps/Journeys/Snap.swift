import XCTest

/// One screenshot walk-through: the app launched on seeded data, and a
/// numbered screenshot per step. CI exports the screenshots from the result
/// bundle as `<device>/<test>/<nn>-<step>.png` (add-app-screenshots-ci).
@MainActor
final class Journey {
    private(set) var app = XCUIApplication()
    private let test: XCTestCase
    private var steps = 0

    /// Launches the app with `-ui-screenshots <scenario>`.
    convenience init(_ test: XCTestCase, scenario: String) {
        self.init(test, arguments: ["-ui-screenshots", scenario])
    }

    /// Launches the app with `arguments` and `environment`, for a scenario
    /// another UI test target already seeds, such as `-ui-testing-shell loading`.
    init(_ test: XCTestCase, arguments: [String], environment: [String: String] = [:]) {
        self.test = test
        launch(arguments, environment: environment)
    }

    /// Ends the running app and starts it again with `arguments`. Step
    /// numbers carry on.
    func launch(_ arguments: [String], environment: [String: String] = [:]) {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = arguments + Self.storeLanguage
        app.launchEnvironment = environment
        if arguments.contains(Self.storeShots) {
            Self.waitForRoomInTheMinute()
            launchMinute = Self.minute()
        } else {
            launchMinute = nil
        }
        app.launchInEnglish()
        #if os(macOS)
            // A CI runner's Mac can start the app with no window open;
            // File > New Window opens one, in any language.
            if !app.windows.firstMatch.waitForExistence(timeout: 5) {
                app.typeKey("n", modifierFlags: .command)
            }
        #endif
    }

    /// `-AppleLanguages` and `-AppleLocale` from the runner's `STORE_LANGUAGE`
    /// and `STORE_REGION`, which the store screenshot run sets per language
    /// (add-store-localization). Empty when they are not set, so the walk
    /// runs in English.
    static var storeLanguage: [String] {
        let environment = ProcessInfo.processInfo.environment
        guard let language = environment["STORE_LANGUAGE"], !language.isEmpty else { return [] }
        let region = environment["STORE_REGION"] ?? language.replacingOccurrences(of: "-", with: "_")
        return ["-AppleLanguages", "(\(language))", "-AppleLocale", region] + layoutDirection(for: language)
    }

    /// Whether the runner's `STORE_LANGUAGE` reads right to left.
    static var storeLanguageIsRightToLeft: Bool {
        guard let language = ProcessInfo.processInfo.environment["STORE_LANGUAGE"], !language.isEmpty else { return false }
        return Locale.Language(identifier: language).characterDirection == .rightToLeft
    }

    /// `-AppleTextDirection YES` for a right-to-left language on a Mac.
    /// AppKit takes the layout direction from that default, which follows
    /// the Mac's own language and not `-AppleLanguages`, so on an English
    /// runner an Arabic launch would lay out left to right. iPhone, iPad
    /// and Apple TV take the direction from the launch language.
    private static func layoutDirection(for language: String) -> [String] {
        #if os(macOS)
            Locale.Language(identifier: language).characterDirection == .rightToLeft ? ["-AppleTextDirection", "YES"] : []
        #else
            []
        #endif
    }

    static let storeShots = "-ui-testing-store-shots"

    /// The minute, counted from 1970, the last store-shot launch started in;
    /// nil after any other launch.
    private var launchMinute: Int?

    private static func minute(_ date: Date = Date()) -> Int {
        Int(date.timeIntervalSince1970 / 60)
    }

    /// A store-shot app reads 9:41 for the minute it launched in and 9:42
    /// from the next one (`UITestingStoreShots.pinClock`). When fewer than
    /// `room` seconds of this minute are left, waits for the next minute,
    /// so the steps up to the next launch run inside one.
    private static func waitForRoomInTheMinute(room: TimeInterval = 40) {
        let left = 60 - Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 60)
        guard left < room else { return }
        RunLoop.current.run(until: Date().addingTimeInterval(left + 0.5))
    }

    /// Waits up to `timeout` seconds for the element with `identifier` to
    /// go away, and carries on either way.
    func waitUntilGone(_ identifier: String, timeout: TimeInterval = 10) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element(identifier))
        _ = XCTWaiter().wait(for: [gone], timeout: timeout)
    }

    /// Waits up to 10 seconds until the screenshot a quarter of the way across
    /// and halfway down is not black, so the store clip has drawn a frame
    /// on the player. Carries on either way.
    func waitForPicture() {
        for _ in 0..<20 {
            if brightness(at: CGPoint(x: 0.25, y: 0.5)) > 12 { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
    }

    /// The sum of red, green and blue, 0 to 765, of the screen's pixel at
    /// `point`, given as fractions of its width and height.
    private func brightness(at point: CGPoint) -> Int {
        #if os(macOS)
            guard let image = screenshot().image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return 0 }
        #else
            guard let image = screenshot().image.cgImage else { return 0 }
        #endif
        var pixel = [UInt8](repeating: 0, count: 4)
        let drawn = pixel.withUnsafeMutableBytes { bytes -> Bool in
            guard
                let context = CGContext(
                    data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            let x = CGFloat(image.width) * point.x
            let y = CGFloat(image.height) * (1 - point.y)
            context.draw(image, in: CGRect(x: -x, y: -y, width: CGFloat(image.width), height: CGFloat(image.height)))
            return true
        }
        return drawn ? Int(pixel[0]) + Int(pixel[1]) + Int(pixel[2]) : 0
    }

    /// The whole screen on iPhone, iPad and Apple TV; the app's window on
    /// a Mac, as the Mac App Store shows it.
    private func screenshot() -> XCUIScreenshot {
        #if os(macOS)
            app.windows.firstMatch.screenshot()
        #else
            XCUIScreen.main.screenshot()
        #endif
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Waits up to 10 seconds for the element with identifier `anchor`, then
    /// attaches a screenshot named `<nn>-<step>`. Fails the test when the
    /// anchor never appears, with the accessibility tree attached.
    func snap(_ step: String, anchor: String, file: StaticString = #filePath, line: UInt = #line) {
        guard element(anchor).waitForExistence(timeout: 10) else {
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "tree-\(step)"
            tree.lifetime = .keepAlways
            test.add(tree)
            XCTFail("step \(step): \(anchor) never appeared", file: file, line: line)
            return
        }
        // store-listing/store-screenshots-in-every-ready-language: every
        // store picture shows 9:41, so it is taken in the launch's minute.
        if let launchMinute, Self.minute() != launchMinute {
            XCTFail("step \(step): the clock passed 9:41 before the screenshot", file: file, line: line)
            return
        }
        steps += 1
        let attachment = XCTAttachment(screenshot: screenshot())
        attachment.name = String(format: "%02d-%@", steps, step)
        attachment.lifetime = .keepAlways
        test.add(attachment)
    }
}
