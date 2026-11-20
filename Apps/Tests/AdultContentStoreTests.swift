import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// The adult content switch on the profile record and the adult marks on
/// the group records, against an in-memory store.
@MainActor
@Suite struct AdultContentStoreTests {
    let container: ModelContainer
    let source = UUID()

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
    }

    private var context: ModelContext { container.mainContext }

    private var channels: [Channel] {
        Channel.tagged(
            [
                Channel(id: "1", name: "News One", streamURL: URL(filePath: "/1"), group: "News", number: 1),
                Channel(id: "2", name: "Night One", streamURL: URL(filePath: "/2"), group: "XXX", number: 2),
                Channel(id: "3", name: "Late One", streamURL: URL(filePath: "/3"), group: "Late", number: 3),
            ], sourceID: source)
    }

    private func profiles() throws -> [ProfileRecord] {
        try context.fetch(FetchDescriptor<ProfileRecord>())
    }

    private func catalogue(_ profile: UUID = Profile.mainID) throws -> Catalogue<PersistentIdentifier> {
        let rules = GroupStore.rules(
            groups: try context.fetch(FetchDescriptor<GroupRecord>()), members: [], hidden: [], profile: profile, locksOpen: false,
            showsAdult: ProfileStore.showsAdult(profile, in: try profiles()))
        return .shell(channels: channels, favorites: [], profile: profile, rules: rules)
    }

    private func names(_ catalogue: Catalogue<PersistentIdentifier>) -> [String] {
        catalogue.rows(in: .all).compactMap { catalogue.channel(for: $0)?.name }
    }

    @Test("adult-content/show-adult-content-with-the-passcode the switch is stored on Main's record, made on first use")
    func mainProfile() throws {
        #expect(names(try catalogue()) == ["News One", "Late One"])
        ProfileStore.setShowsAdult(Profile.mainID, true, in: context)
        #expect(try profiles().count == 1)
        #expect(ProfileStore.showsAdult(Profile.mainID, in: try profiles()))
        #expect(names(try catalogue()) == ["News One", "Night One", "Late One"])
        #expect(!ProfileStore.list(try profiles()).showsPicker, "one profile still opens without the picker")
        ProfileStore.setShowsAdult(Profile.mainID, false, in: context)
        #expect(names(try catalogue()) == ["News One", "Late One"])
    }

    @Test("profiles/what-each-profile-keeps adult content shows only in the profile that turned it on, and a new profile starts off")
    func perProfile() throws {
        let kids = try #require(ProfileStore.add(name: "Kids", colorIndex: 2, in: context))
        ProfileStore.setShowsAdult(Profile.mainID, true, in: context)
        #expect(names(try catalogue()).contains("Night One"))
        #expect(!names(try catalogue(kids.id)).contains("Night One"))
        let later = try #require(ProfileStore.add(name: "Guest", colorIndex: 3, in: context))
        #expect(!ProfileStore.showsAdult(later.id, in: try profiles()))
    }

    @Test("adult-content/correct-a-group a mark on the group record hides or shows a group for every profile")
    func marks() throws {
        let late = CatalogueGroup.named(source, "Late")
        let xxx = CatalogueGroup.named(source, "XXX")
        GroupStore.setAdult(late, true, in: context)
        GroupStore.setAdult(xxx, false, in: context)
        #expect(names(try catalogue()) == ["News One", "Night One"])
        GroupStore.setAdult(late, nil, in: context)
        #expect(names(try catalogue()) == ["News One", "Night One", "Late One"])
        GroupStore.setAdult(.all, true, in: context)
        #expect(try catalogue().rows(in: .all).count == 3, "All channels takes no mark")
    }

    @Test("group-management/changes-follow-you-to-every-device the adult mark sits on the synced group record")
    func markIsSynced() throws {
        GroupStore.setAdult(.named(source, "Late"), true, in: context)
        let records = try context.fetch(FetchDescriptor<GroupRecord>())
        #expect(records.count == 1)
        #expect(records.first?.adult == true)
    }
}
