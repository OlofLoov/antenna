import Foundation
import Testing

@testable import AntennaCore

/// The profile names "Format not supported" shows, read from hvcC and avcC
/// records.
struct VideoProfileTests {
    /// A version 1 hvcC record with no parameter-set arrays.
    static func hvcC(profile: UInt8, chroma: UInt8, bitDepth: UInt8, arrays: UInt8 = 0) -> Data {
        var bytes = [UInt8](repeating: 0, count: 23)
        bytes[0] = 1
        bytes[1] = profile
        bytes[16] = 0xFC | chroma
        bytes[17] = 0xF8 | (bitDepth - 8)
        bytes[18] = 0xF8 | (bitDepth - 8)
        bytes[22] = arrays
        return Data(bytes)
    }

    @Test(
        "player-controls-and-playback-errors/format-not-supported-names-the-profile HEVC is named with its chroma format and bit depth",
        arguments: [
            (1 as UInt8, 1 as UInt8, 8 as UInt8, "hevc"), (2, 1, 10, "hevc 10-bit"), (4, 2, 10, "hevc 4:2:2 10-bit"),
            (4, 3, 8, "hevc 4:4:4"), (4, 1, 12, "hevc 12-bit"), (4, 0, 8, "hevc 4:0:0"),
        ])
    func hevcNames(profile: UInt8, chroma: UInt8, bitDepth: UInt8, name: String) throws {
        let record = try #require(HEVCConfiguration(hvcC: Self.hvcC(profile: profile, chroma: chroma, bitDepth: bitDepth)))
        #expect(record.codecName == name)
        #expect(record.appleReadsInFiles == (chroma == 1 && bitDepth <= 10))
    }

    @Test("playback-engine/hevc-plays-wherever-the-device-decodes-it a record too short to read is no record")
    func shortRecord() {
        #expect(HEVCConfiguration(hvcC: Data([1, 1, 0])) == nil)
        #expect(HEVCConfiguration(hvcC: Data(repeating: 0, count: 23)) == nil)
        #expect(HEVCConfiguration(hvcC: Self.hvcC(profile: 1, chroma: 1, bitDepth: 8, arrays: 3))?.parameterSetArrays == 3)
    }

    @Test(
        "player-controls-and-playback-errors/format-not-supported-names-the-profile H.264 is named by its profile",
        arguments: [(100 as UInt8, "h264"), (110, "h264 10-bit"), (122, "h264 4:2:2"), (244, "h264 4:4:4")])
    func h264Names(profile: UInt8, name: String) {
        #expect(H264Profile.codecName(avcC: Data([1, profile, 0, 40])) == name)
    }

    @Test("player-controls-and-playback-errors/format-not-supported-names-the-profile the message keeps the profile")
    func message() {
        let message = FailureMessage(.cannotDecode(codec: "hevc 4:2:2 10-bit"), source: "Acme TV", device: .other, locale: .english)
        #expect(
            message.explanation
                == "This stream uses HEVC 4:2:2 10-bit, which this device cannot play. Trying again will not help. Pick another channel or ask the provider for a stream in a supported format."
        )
        #expect(CodecName.display("hevc") == "HEVC")
        #expect(CodecName.display("h264 10-bit") == "H.264 10-bit")
        #expect(CodecName.display("dolby vision") == "Dolby Vision")
    }
}
