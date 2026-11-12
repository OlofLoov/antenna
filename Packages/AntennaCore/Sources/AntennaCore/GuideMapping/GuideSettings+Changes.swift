import Foundation

extension GuideSettings {
    /// Most matches a source keeps, tombstones included.
    public static let matchCap = 2_000
    /// Most links a source keeps, removed ones included.
    public static let linkCap = 50

    /// Both copies merged entry by entry: per guide flag, link and match the
    /// later change wins, a removal included, and the later order wins whole
    /// (guide-sources-and-channel-mapping/settings-follow-you-to-every-device).
    /// Ties keep `self`.
    public func merged(with other: GuideSettings) -> GuideSettings {
        var result = self
        if let theirs = other.orderModifiedAt, theirs > (orderModifiedAt ?? .distantPast) {
            result.order = other.order
            result.orderModifiedAt = theirs
        }
        for (key, flag) in other.flags where flag.modifiedAt > (flags[key]?.modifiedAt ?? .distantPast) {
            result.flags[key] = flag
        }
        for (key, link) in other.links where link.modifiedAt > (links[key]?.modifiedAt ?? .distantPast) {
            result.links[key] = link
        }
        for (key, match) in other.matches where match.modifiedAt > (matches[key]?.modifiedAt ?? .distantPast) {
            result.matches[key] = match
        }
        return result
    }

    /// Writes `list` as the order, so every guide keeps its place.
    public mutating func setOrder(_ list: [GuideReference], at date: Date) {
        order = list.map(\.storageKey)
        orderModifiedAt = date
    }

    public mutating func setEnabled(_ enabled: Bool, for reference: GuideReference, at date: Date) {
        flags[reference.storageKey] = Flag(enabled: enabled, modifiedAt: date)
    }

    /// Adds a link the user entered. False when the source already keeps
    /// `linkCap` links and none is a removal that can go.
    public mutating func addLink(_ link: Link, id: String) -> Bool {
        if links.count >= Self.linkCap {
            guard let oldest = links.filter(\.value.removed).min(by: { $0.value.modifiedAt < $1.value.modifiedAt }) else { return false }
            links[oldest.key] = nil
        }
        links[id] = link
        return true
    }

    /// Marks the link removed, so other devices drop it too.
    public mutating func removeLink(_ id: String, at date: Date) {
        guard var link = links[id] else { return }
        link.removed = true
        link.modifiedAt = date
        links[id] = link
        flags["added.\(id)"] = nil
    }

    /// Sets a channel's match: an entry picked by hand, or nil for "no match
    /// by name". Past `matchCap`, removals go first, then matches for
    /// channels not in `present`, oldest first. False when nothing could go
    /// (guide-sources-and-channel-mapping/matches-survive-a-playlist-refresh).
    public mutating func setMatch(_ entryID: String?, for channelID: String, at date: Date, present: Set<String>) -> Bool {
        if matches[channelID] == nil, matches.count >= Self.matchCap {
            let removals = matches.filter(\.value.removed)
            let gone = matches.filter { !$0.value.removed && !present.contains($0.key) }
            guard let drop = (removals.isEmpty ? gone : removals).min(by: { $0.value.modifiedAt < $1.value.modifiedAt }) else {
                return false
            }
            matches[drop.key] = nil
        }
        matches[channelID] = Match(entryID: entryID, modifiedAt: date)
        return true
    }

    /// Removes a channel's match, so it goes back to its own guide id.
    public mutating func removeMatch(for channelID: String, at date: Date) {
        guard matches[channelID] != nil else { return }
        matches[channelID] = Match(entryID: nil, modifiedAt: date, removed: true)
    }
}

/// How a guide link the user adds is checked and kept.
public enum GuideLinkInput {
    public enum Problem: Error, Sendable, Equatable {
        /// "Enter a valid URL."
        case invalid
        /// "This guide is already in the list."
        case duplicate

        public var message: String {
            switch self {
            case .invalid: "Enter a valid URL."
            case .duplicate: "This guide is already in the list."
            }
        }
    }

    /// The link typed into the add form, trimmed: an `http` or `https`
    /// address with a host, not already among `existing`, compared on the
    /// whole link including its login and query
    /// (guide-sources-and-channel-mapping/add-a-guide-link).
    public static func check(_ text: String, existing: [URL]) -> Result<URL, Problem> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
            let host = url.host(), !host.isEmpty
        else { return .failure(.invalid) }
        guard !existing.contains(where: { $0.absoluteString == url.absoluteString }) else { return .failure(.duplicate) }
        return .success(url)
    }

    /// The link as the synced settings keep it, and the whole link when it
    /// has to go to the Keychain: any link with a user, a password, a query,
    /// a fragment or a path deeper than one `.xml`, `.xml.gz` or `.gz` file
    /// (guide-sources-and-channel-mapping/passwords-in-guide-links-stay-private).
    public static func storage(for url: URL, at date: Date) -> (link: GuideSettings.Link, secret: URL?) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let scheme = components?.scheme?.lowercased() ?? "https"
        let host = components?.host ?? ""
        let segments = url.path().split(separator: "/")
        let file = segments.last.map { String($0).lowercased() } ?? ""
        let plainFile = segments.count == 1 && [".xml", ".xml.gz", ".gz"].contains { file.hasSuffix($0) }
        let plain =
            components?.user == nil && components?.password == nil && components?.query == nil && components?.fragment == nil
            && plainFile
        let link = GuideSettings.Link(scheme: scheme, host: host, port: components?.port, plain: plain ? url : nil, addedAt: date)
        return (link, plain ? nil : url)
    }

    /// "epg.example.com/…" for a link whose parts are in the Keychain.
    public static func shortName(_ link: GuideSettings.Link) -> String {
        link.host + (link.port.map { ":\($0)" } ?? "") + "/…"
    }
}
