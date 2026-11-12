import Foundation

extension ChannelsDVRClient {
    /// The channels of a lineup download. Throws `.malformed` unless the
    /// first text after an optional byte-order mark and whitespace is
    /// `#EXTM3U`. Invalid UTF-8 is read with replacement characters.
    public static func channels(fromPlaylist data: Data) throws -> [Channel] {
        let text = String(decoding: data, as: UTF8.self)
        let start = text.unicodeScalars.drop { $0 == "\u{FEFF}" || CharacterSet.whitespacesAndNewlines.contains($0) }
        guard String(start.prefix(7)) == "#EXTM3U" else { throw ChannelsDVRError.malformed }
        return channels(mapping: M3UParser(nameSource: .title).parse(text))
    }

    /// The parsed lineup with each channel's id taken from the lineup alone,
    /// never from the server's address, so favorites survive an address
    /// change (channels-dvr-source/favorites-survive-an-address-change).
    ///
    /// The id is `channelsdvr#id#<tvg-id>`, else `channelsdvr#no#<tvg-chno>`,
    /// else `channelsdvr#pos#<n>` with `n` the 1-based place in the lineup.
    /// Entries sharing a `tvg-id` share an id and are all kept. No channel
    /// has catch-up.
    public static func channels(mapping playlist: Playlist) -> [Channel] {
        playlist.channels.indices.map { offset in
            let parsed = playlist.channels[offset]
            var channel = parsed
            if let epgID = parsed.epgID {
                channel.id = "channelsdvr#id#\(epgID)"
            } else if let number = parsed.number {
                channel.id = "channelsdvr#no#\(number)" + (parsed.minorNumber.map { ".\($0)" } ?? "")
            } else {
                channel.id = "channelsdvr#pos#\(offset + 1)"
            }
            channel.hasCatchup = false
            channel.catchupDays = nil
            channel.catchupMode = nil
            channel.catchupSource = nil
            channel.catchupCorrectionHours = nil
            return channel
        }
    }
}
