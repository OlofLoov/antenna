import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import AntennaTV

/// Profiles and what each keeps, against an in-memory store and a scratch `UserDefaults`.
@MainActor
@Suite struct ProfileStoreTests {
    let container: ModelContainer
    let defaults: UserDefaults
    let source = UUID()

    init() throws {
        let schema = Schema(AntennaSchema.models)
        container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        defaults = try #require(UserDefaults(suiteName: "profile-store-\(UUID().uuidString)"))
    }

    private var context: ModelContext { container.mainContext }

    private func profiles() throws -> ProfileList {
        ProfileStore.list(try context.fetch(FetchDescriptor<ProfileRecord>()))
    }

    private var channels: [Channel] {
        Channel.tagged(
            ["a", "b"].map { Channel(id: $0, name: "Channel \($0)", streamURL: URL(fileURLWithPath: "/\($0).ts")) }, sourceID: source)
    }

    private func catalogue(for profile: UUID) throws -> Catalogue<PersistentIdentifier> {
        .shell(channels: channels, favorites: try context.fetch(FetchDescriptor<FavoriteRecord>()), profile: profile)
    }

    @Test("profiles/adding-a-profile the second profile stores Main and the new one")
    func adding() throws {
        #expect(try profiles().isImplicit)
        let kids = try #require(ProfileStore.add(name: " Kids ", colorIndex: 5, in: context))
        let list = try profiles()
        #expect(list.profiles.map(\.name) == ["Main", "Kids"])
        #expect(list.profiles[0].id == Profile.mainID)
        #expect(kids.name == "Kids")
        #expect(ProfileStore.add(name: "  ", colorIndex: 0, in: context) == nil, "a name is needed")
        for index in 0..<6 { ProfileStore.add(name: "P\(index)", colorIndex: 0, in: context) }
        #expect(try profiles().profiles.count == 8)
        #expect(ProfileStore.add(name: "Ninth", colorIndex: 0, in: context) == nil, "eight is the most")
    }

    @Test("profiles/editing-and-deleting-a-profile rename, delete with favorites, keep the last")
    func editingAndDeleting() throws {
        let kids = try #require(ProfileStore.add(name: "Kids", colorIndex: 5, in: context))
        #expect(ProfileStore.edit(kids.id, name: "Children", colorIndex: 2, in: context))
        #expect(try profiles().profiles.last?.name == "Children")
        #expect(!ProfileStore.edit(kids.id, name: " ", colorIndex: 2, in: context))

        FavoriteRecord.toggle(channels[0], in: try catalogue(for: Profile.mainID), profile: Profile.mainID, context: context)
        FavoriteRecord.toggle(channels[1], in: try catalogue(for: kids.id), profile: kids.id, context: context)
        #expect(ProfileStore.delete(kids.id, in: context))
        #expect(try profiles().profiles.map(\.name) == ["Main"])
        let left = try context.fetch(FetchDescriptor<FavoriteRecord>())
        #expect(left.map(\.channelID) == ["a"], "the deleted profile's favorites go, Main's stay")
        #expect(!ProfileStore.delete(Profile.mainID, in: context), "the last profile cannot be deleted")
    }

    @Test("favorites/favorites-belong-to-a-profile each profile lists and adds its own favorites")
    func favoritesPerProfile() throws {
        FavoriteRecord.toggle(channels[0], in: try catalogue(for: Profile.mainID), context: context)
        let kids = try #require(ProfileStore.add(name: "Kids", colorIndex: 5, in: context))
        #expect(try catalogue(for: Profile.mainID).count(of: .favorites) == 1, "favorites from before profiles stay with Main")
        #expect(try catalogue(for: kids.id).count(of: .favorites) == 0, "the new profile has none")
        FavoriteRecord.toggle(channels[1], in: try catalogue(for: kids.id), profile: kids.id, context: context)
        #expect(try catalogue(for: kids.id).isFavorite(channels[1]))
        #expect(try !catalogue(for: Profile.mainID).isFavorite(channels[1]))
        let stored = try context.fetch(FetchDescriptor<FavoriteRecord>())
        #expect(stored.first { $0.channelID == "a" }?.profileID == nil, "Main's favorites store no profile id")
        #expect(stored.first { $0.channelID == "b" }?.profileID == kids.id)
    }

    @Test("profiles/profiles-sync-between-devices a second Main from another device is deleted on the next write")
    func duplicateMain() throws {
        ProfileStore.add(name: "Kids", colorIndex: 5, in: context)
        context.insert(ProfileRecord(Profile.main(createdAt: .now.addingTimeInterval(60))))
        try context.save()
        #expect(try context.fetch(FetchDescriptor<ProfileRecord>()).count == 3)
        #expect(try profiles().profiles.map(\.name) == ["Main", "Kids"], "reads already show one Main")
        ProfileStore.add(name: "Mum", colorIndex: 4, in: context)
        let records = try context.fetch(FetchDescriptor<ProfileRecord>())
        #expect(records.filter { $0.id == Profile.mainID }.count == 1)
    }

    @Test("profiles/what-each-profile-keeps the last channel and language picks per profile, pruned when a profile goes")
    func perDevice() throws {
        let kids = UUID()
        let key = LastChannelKey(sourceID: source, channelID: "a")
        LastChannelStore(defaults: defaults, profile: kids).write(key)
        #expect(LastChannelStore(defaults: defaults, profile: kids).read() == key)
        #expect(LastChannelStore(defaults: defaults).read() == nil, "Main's last channel is its own")
        #expect(defaults.data(forKey: "shell.lastChannel.\(kids.uuidString)") != nil)

        let channel = channels[0]
        ChannelLanguageStore(defaults: defaults).remember(LanguagePick(audio: "ger", subtitle: nil), for: channel)
        #expect(ChannelLanguageStore(defaults: defaults, profile: kids).pick(for: channel) == nil)
        #expect(ChannelLanguageStore(defaults: defaults).pick(for: channel) == LanguagePick(audio: "ger", subtitle: nil))

        ProfileKeys.prune(defaults, keeping: [Profile.mainID])
        #expect(LastChannelStore(defaults: defaults, profile: kids).read() == nil, "a deleted profile's values go")
        #expect(ChannelLanguageStore(defaults: defaults).pick(for: channel) != nil, "Main's stay")
    }

    @Test("profiles/what-each-profile-keeps the current profile is kept on this device")
    func current() {
        let store = CurrentProfileStore(defaults: defaults)
        #expect(store.read() == nil)
        let kids = UUID()
        store.write(kids)
        #expect(store.read() == kids)
        defaults.set("not a uuid", forKey: CurrentProfileStore.key)
        #expect(store.read() == nil, "a value that fails to decode reads as absent")
    }

    @Test("profiles/sources-and-logins-are-shared every profile sees every source's channels")
    func sourcesShared() throws {
        let kids = try #require(ProfileStore.add(name: "Kids", colorIndex: 5, in: context))
        let other = UUID()
        let all =
            channels + Channel.tagged([Channel(id: "c", name: "Channel c", streamURL: URL(fileURLWithPath: "/c.ts"))], sourceID: other)
        let favorites = try context.fetch(FetchDescriptor<FavoriteRecord>())
        let forKids = Catalogue<PersistentIdentifier>.shell(channels: all, favorites: favorites, profile: kids.id)
        let forMain = Catalogue<PersistentIdentifier>.shell(channels: all, favorites: favorites, profile: Profile.mainID)
        #expect(forKids.count(of: .all) == 3)
        #expect(forKids.groups == forMain.groups, "groups and sources are the same for every profile")
    }

    @Test("profiles/profiles-sync-between-devices a device opens as one profile until profiles arrive")
    func beforeProfilesArrive() throws {
        let empty = try profiles()
        #expect(!empty.showsPicker)
        #expect(empty.current(stored: nil)?.id == Profile.mainID)
        ProfileStore.add(name: "Kids", colorIndex: 5, in: context)
        #expect(try profiles().staying(on: Profile.mainID) == Profile.mainID, "a running device stays on Main when Kids arrives")
    }
}
