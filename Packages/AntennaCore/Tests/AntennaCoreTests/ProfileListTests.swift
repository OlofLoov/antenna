import AntennaCore
import Foundation
import Testing

/// Profiles on one set of sources: order, duplicates, adding, deleting and the current profile.
@Suite struct ProfileListTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func profile(_ name: String, order: Int, id: UUID = UUID(), at offset: TimeInterval = 0, color: Int = 0) -> Profile {
        Profile(id: id, name: name, colorIndex: color, sortOrder: order, createdAt: start.addingTimeInterval(offset))
    }

    @Test("profiles/who-s-watching-at-launch one profile opens straight away, two or more ask")
    func picker() {
        let none = ProfileList(stored: [])
        #expect(none.isImplicit)
        #expect(none.profiles.map(\.name) == ["Main"])
        #expect(!none.showsPicker)
        #expect(none.current(stored: nil)?.id == Profile.mainID, "with one profile it is current without asking")

        let dad = profile("Dad", order: 0)
        let kids = profile("Kids", order: 1)
        let two = ProfileList(stored: [kids, dad])
        #expect(two.profiles.map(\.name) == ["Dad", "Kids"], "in the user's order")
        #expect(two.showsPicker)
        #expect(two.current(stored: nil) == nil, "the picker has to ask")
        #expect(two.current(stored: kids.id) == kids, "the device's last profile")
        #expect(two.current(stored: UUID()) == nil, "a deleted profile means asking")
        #expect(two.focusedOnPicker(stored: kids.id) == kids)
        #expect(two.focusedOnPicker(stored: nil) == dad)
    }

    @Test("profiles/who-s-watching-at-launch each tile shows the name's initial and color")
    func initialsAndColors() {
        #expect(profile("kids", order: 0).initial == "K")
        #expect(profile("  2nd", order: 0).initial == "2")
        #expect(profile("!!", order: 0).initial == "?")
        #expect(profile("A", order: 0, color: 5).color == 0xA3E635)
        #expect(profile("A", order: 0, color: 42).color == 0x5BB8FF, "an unknown color reads as the first")
        #expect(Profile.colors.count == 8)
    }

    @Test("profiles/adding-a-profile the second profile brings Main along")
    func addingTheSecond() throws {
        let none = ProfileList(stored: [])
        let added = try #require(none.adding(name: "  Kids ", colorIndex: 5, now: start))
        #expect(added.map(\.name) == ["Main", "Kids"])
        #expect(added[0].id == Profile.mainID)
        #expect(added[1].sortOrder > added[0].sortOrder)
        let after = ProfileList(stored: added)
        #expect(!after.isImplicit)
        #expect(after.showsPicker)
        let third = try #require(after.adding(name: "Mum", colorIndex: 4, now: start))
        #expect(third.map(\.name) == ["Mum"], "Main is stored already")
        #expect(third[0].sortOrder > added[1].sortOrder)
    }

    @Test("profiles/adding-a-profile a name is needed and eight is the most")
    func limits() {
        #expect(ProfileList.validName("   ") == nil)
        #expect(ProfileList.validName("") == nil)
        #expect(ProfileList.validName(String(repeating: "a", count: 31)) == nil)
        #expect(ProfileList.validName(" Kids ") == "Kids")
        let none = ProfileList(stored: [])
        #expect(none.adding(name: " ", colorIndex: 0) == nil)
        let eight = ProfileList(stored: (0..<8).map { profile("P\($0)", order: $0) })
        #expect(!eight.canAdd)
        #expect(eight.adding(name: "Ninth", colorIndex: 0) == nil)
    }

    @Test("profiles/editing-and-deleting-a-profile the last profile stays")
    func deleting() {
        let dad = profile("Dad", order: 0)
        let kids = profile("Kids", order: 1)
        let two = ProfileList(stored: [dad, kids])
        #expect(two.canDelete(kids.id))
        #expect(!two.canDelete(UUID()))
        let one = ProfileList(stored: [dad])
        #expect(!one.canDelete(dad.id), "the last profile cannot be deleted")
        #expect(!ProfileList(stored: []).canDelete(Profile.mainID))
    }

    @Test("profiles/profiles-sync-between-devices two Main records from two devices become one")
    func duplicates() {
        let mainA = Profile.main(createdAt: start)
        let kidsA = profile("Kids", order: 1, at: 1)
        let mainB = Profile.main(createdAt: start.addingTimeInterval(30))
        let mumB = profile("Mum", order: 1, at: 31)
        let synced = [mainB, mumB, mainA, kidsA]
        let list = ProfileList(stored: synced)
        #expect(list.profiles.map(\.name) == ["Main", "Kids", "Mum"], "one Main, both new profiles")
        #expect(list.profiles[0].createdAt == start, "the earliest Main wins")
        #expect(ProfileList.duplicates(in: synced) == [0], "the later Main is the one to delete")
        #expect(ProfileList.duplicates(in: [mainA, mainA]) == [1], "an exact copy loses too")
    }

    @Test("profiles/what-each-profile-keeps records with no profile id are Main's")
    func ownership() {
        let kids = UUID()
        #expect(ProfileList.storedID(for: Profile.mainID) == nil)
        #expect(ProfileList.storedID(for: kids) == kids)
        #expect(ProfileList.owns(Profile.mainID, recordProfile: nil))
        #expect(ProfileList.owns(Profile.mainID, recordProfile: Profile.mainID))
        #expect(!ProfileList.owns(kids, recordProfile: nil))
        #expect(ProfileList.owns(kids, recordProfile: kids))
    }

    @Test("profiles/editing-and-deleting-a-profile a device on a deleted profile asks again or opens on the one left")
    func deletedElsewhere() {
        let dad = profile("Dad", order: 0)
        let kids = profile("Kids", order: 1)
        let mum = profile("Mum", order: 2)
        #expect(ProfileList(stored: [dad, kids, mum]).staying(on: kids.id) == kids.id)
        #expect(ProfileList(stored: [dad, mum]).staying(on: kids.id) == nil, "two or more left: ask again")
        #expect(ProfileList(stored: [dad]).staying(on: kids.id) == dad.id, "one left: open on it")
        #expect(ProfileList(stored: []).staying(on: kids.id) == Profile.mainID)
    }
}
