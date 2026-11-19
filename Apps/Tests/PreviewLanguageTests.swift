import Foundation
import Testing

@testable import Antenna

/// The fixture times Arabic previews show come from the formatter the app
/// uses, on a fixed day in UTC.
@Suite struct PreviewLanguageTests {
    // localization/times-and-dates-follow-the-user-s-region
    @Test("localization/times-and-dates-follow-the-user-s-region Saudi Arabia writes a 12-hour time")
    func arabicTime() {
        let time = PreviewLanguage.arabic.time(21, 34)
        #expect(time.contains("٩:٣٤"), "\(time)")
        #expect(!time.contains("٢١"), "\(time) is a 12-hour time")
        #expect(time == PreviewLanguage.arabic.time(21, 34))
    }
}
