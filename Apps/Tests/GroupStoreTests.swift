import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// Group records against an in-memory store: what the catalogue shows once
/// they are read back as rules.
@MainActor
@Suite struct GroupStoreTests {
    let container: ModelContainer
    let source = UUID()
    let kids = UUID()

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
    }

    private var context: ModelContext { container.mainContext }

    private var channels: [Channel] {
        Channel.tagged(
            [
                Channel(id: "1", name: "Sport One", streamURL: URL(filePath: "/1"), group: "Sport", number: 1),
                Channel(id: "2", name: "News One", streamURL: URL(filePath: "/2"), group: "News", number: 2),
                Channel(id: "3", name: "Sport Two", streamURL: URL(filePath: "/3"), group: "Sport", number: 3),
            ], sourceID: source)
    }

    private func rules(profile: UUID = Profile.mainID, locksOpen: Bool = false) throws -> GroupRules {
        GroupStore.rules(
            groups: try context.fetch(FetchDescriptor<GroupRecord>()), members: try context.fetch(FetchDescriptor<GroupMemberRecord>()),
            hidden: try context.fetch(FetchDescriptor<HiddenGroupRecord>()), profile: profile, locksOpen: locksOpen)
    }

    private func catalogue(profile: UUID = Profile.mainID, favorites: [FavoriteRecord] = []) throws -> Catalogue<PersistentIdentifier> {
        .shell(channels: channels, favorites: favorites, profile: profile, rules: try rules(profile: profile))
    }

    @Test("group-management/give-a-group-your-own-name every screen reads the new name, and favorites and order stay")
    func rename() throws {
        let sport = CatalogueGroup.named(source, "Sport")
        let favorite = FavoriteRecord(channelID: "3", sourceID: source)
        context.insert(favorite)
        GroupStore.reorder([.all, .named(source, "News"), sport], in: context)
        #expect(GroupStore.rename(sport, to: "  Football ", in: context))
        let renamed = try catalogue(favorites: [favorite])
        #expect(renamed.label(of: sport) == "Football")
        #expect(renamed.groups == [.favorites, .all, .named(source, "News"), sport])
        #expect(renamed.rows(in: .favorites).map(\.id) == ["3"])
        #expect(LiveSession.Group(sport).group == sport)

        #expect(GroupStore.rename(sport, to: "   ", in: context))
        #expect(try catalogue().label(of: sport) == "Sport")
    }

    @Test("group-management/give-a-group-your-own-name an own group refuses an empty name")
    func renameOwn() throws {
        let id = try #require(GroupStore.create(named: "Weekend", after: [], in: context))
        #expect(!GroupStore.rename(.own(id), to: " ", in: context))
        #expect(GroupStore.rename(.own(id), to: "Match day", in: context))
        #expect(try catalogue().label(of: .own(id)) == "Match day")
        #expect(GroupStore.create(named: "  ", after: [], in: context) == nil)
    }

    @Test("group-management/hide-groups-you-never-watch hiding is kept per profile")
    func hiddenPerProfile() throws {
        let news = CatalogueGroup.named(source, "News")
        GroupStore.setHidden(news, true, profile: kids, in: context)
        #expect(!(try catalogue(profile: kids).groups.contains(news)))
        #expect(try catalogue().groups.contains(news))
        GroupStore.removeProfile(kids, in: context)
        #expect(try context.fetch(FetchDescriptor<HiddenGroupRecord>()).isEmpty)
    }

    @Test("group-management/build-your-own-group-from-any-playlist members keep their order and leave with their playlist")
    func ownGroupMembers() throws {
        let id = try #require(GroupStore.create(named: "Mine", after: [], in: context))
        let other = UUID()
        let theirs = Channel.tagged([Channel(id: "9", name: "Kids", streamURL: URL(filePath: "/9"))], sourceID: other)
        let m3u = Channel.tagged([Channel(id: "x#http://host/u/p/1.ts", name: "M3U", streamURL: URL(filePath: "/x"))], sourceID: other)
        GroupStore.setMembers(of: id, to: [channels[2], theirs[0], m3u[0], channels[0]], in: context)
        let built = Catalogue<PersistentIdentifier>.shell(channels: channels + theirs, favorites: [], rules: try rules())
        #expect(built.rows(in: .own(id)).map(\.id) == ["3", "9", "1"])

        GroupStore.removeSource(other, in: context)
        try context.save()
        let after = Catalogue<PersistentIdentifier>.shell(channels: channels, favorites: [], rules: try rules())
        #expect(after.rows(in: .own(id)).map(\.id) == ["3", "1"])
        #expect(after.groups.contains(.own(id)))
    }

    @Test("group-management/settings-for-groups-that-are-gone duplicates keep the earliest record and Remove clears them")
    func duplicatesAndRemove() throws {
        let gone = CatalogueGroup.named(source, "Old")
        let early = GroupRecord(group: gone, now: .distantPast)
        early.locked = true
        let late = GroupRecord(group: gone, now: .now)
        late.customName = "Later"
        context.insert(late)
        context.insert(early)
        context.insert(GroupRecord(group: .all))
        let malformed = GroupRecord(group: .all)
        malformed.kindRaw = "nonsense"
        context.insert(malformed)
        try context.save()
        let records = try context.fetch(FetchDescriptor<GroupRecord>())
        #expect(GroupStore.duplicates(records).map(\.customName) == ["Later"])
        let rules = try rules()
        #expect(rules.locked == [gone] && rules.names.isEmpty)
        #expect(try catalogue().orphanedGroups == [gone])

        GroupStore.remove(gone, in: context)
        #expect(try catalogue().orphanedGroups.isEmpty)
    }

    @Test("group-management/put-groups-in-your-order the Groups screen's data for 400 groups builds well within a second")
    func fourHundredGroups() {
        let many = Channel.tagged(
            (0..<20_000).map { Channel(id: "\($0)", name: "C\($0)", streamURL: URL(filePath: "/\($0)"), group: "G\($0 % 400)") },
            sourceID: source)
        for index in 0..<400 where index.isMultiple(of: 4) {
            GroupStore.setLocked(.named(source, "G\(index)"), true, in: context)
        }
        let records = (try? context.fetch(FetchDescriptor<GroupRecord>())) ?? []
        let elapsed = ContinuousClock().measure {
            let data = GroupsData(channels: many, groups: records, members: [], hidden: [], sources: [], profile: Profile.mainID)
            #expect(data.groups.count == 401)
            #expect(data.orphans.isEmpty)
        }
        #expect(elapsed < .milliseconds(500), "took \(elapsed)")
    }

    @Test("group-management/lock-a-group-with-a-passcode All channels and Favorites cannot be locked")
    func locks() throws {
        GroupStore.setLocked(.all, true, in: context)
        GroupStore.setLocked(.favorites, true, in: context)
        GroupStore.setLocked(.named(source, "News"), true, in: context)
        #expect(try rules().locked == [.named(source, "News")])
    }
}
