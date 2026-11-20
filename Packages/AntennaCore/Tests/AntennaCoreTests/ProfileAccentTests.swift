import AntennaCore
import Foundation
import Testing

/// The accent each profile carries and the contrast every accent keeps.
@Suite struct ProfileAccentTests {
    @Test("design-system/one-accent-color-per-profile: five accents, Blue first and the default")
    func theSet() {
        #expect(ProfileAccent.allCases == [.blue, .teal, .amber, .pink, .violet])
        #expect(ProfileAccent.blue.rgb == 0x5BB8FF, "the reference's accent blue")
        #expect(Profile.main().accent == .blue)
        #expect(Profile(id: UUID(), name: "Kids", colorIndex: 5, sortOrder: 1, createdAt: .distantPast).accent == .blue)
        for accent in ProfileAccent.allCases {
            #expect(Profile.colors.contains(accent.rgb), "\(accent) is one of the circle colors")
        }
    }

    @Test("design-system/one-accent-color-per-profile: every accent reaches 4.5:1 on every dark surface")
    func contrast() {
        for accent in ProfileAccent.allCases {
            for surface in ProfileAccent.surfaces {
                let ratio = Contrast.ratio(accent.rgb, surface)
                #expect(ratio >= 4.5, "\(accent) on #\(String(surface, radix: 16)) is \(ratio)")
            }
        }
        // The table in the change's design.md.
        #expect(abs(Contrast.ratio(ProfileAccent.blue.rgb, 0x0B0E13) - 8.97) < 0.01)
        #expect(abs(Contrast.ratio(0x2C2C2E, ProfileAccent.pink.rgb) - 5.26) < 0.01)
        #expect(abs(Contrast.ratio(0xFFFFFF, 0x000000) - 21) < 0.001)
    }

    @Test("profiles/profiles-sync-between-devices: a missing or unknown stored accent reads as Blue")
    func stored() {
        #expect(ProfileAccent(stored: nil) == .blue)
        #expect(ProfileAccent(stored: "teal") == .teal)
        #expect(ProfileAccent(stored: "chartreuse") == .blue, "a newer build's accent")
    }

    @Test("profiles/adding-a-profile: a new profile keeps the accent picked, Blue otherwise")
    func adding() throws {
        let list = ProfileList(stored: [])
        let picked = try #require(list.adding(name: "Kids", colorIndex: 5, accent: .amber))
        #expect(picked.map(\.accent) == [.blue, .amber], "Main stays Blue")
        let plain = try #require(list.adding(name: "Kids", colorIndex: 5))
        #expect(plain.last?.accent == .blue)
    }
}
