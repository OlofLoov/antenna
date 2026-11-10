import Foundation

/// How a track reads in the audio and subtitle lists.
public enum TrackName {
    /// Codes that name no language.
    static let noLanguage: Set<String> = ["und", "mis", "mul", "zxx", "qaa"]

    /// The language in `locale`, followed by the provider's own name in
    /// brackets when it says more, as in "English (Commentary)". A track with
    /// no language reads as its provider name, or "Track n" counted from 1
    /// in stream order. A forced subtitle with nothing else to go by reads
    /// "Forced".
    public static func display(
        _ track: MediaTrack, position: Int, isForced: Bool = false, locale: Locale = Locale(identifier: "en_US")
    ) -> String {
        let language = languageName(track.languageCode, locale: locale)
        let name = track.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        switch (language, name) {
        case (let language?, let name?) where name.caseInsensitiveCompare(language) != .orderedSame:
            return "\(language) (\(name))"
        case (let language?, _):
            return language
        case (nil, let name?):
            return name
        case (nil, nil):
            return isForced && track.kind == .subtitle ? "Forced" : "Track \(position + 1)"
        }
    }

    /// The language a code names, nil for no code, an unknown code or one
    /// that names no language.
    public static func languageName(_ code: String?, locale: Locale = Locale(identifier: "en_US")) -> String? {
        guard let code = code?.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            !noLanguage.contains(code.lowercased())
        else { return nil }
        let identifier = code.replacingOccurrences(of: "_", with: "-")
        if let name = locale.localizedString(forIdentifier: identifier), name.lowercased() != identifier.lowercased() {
            return name
        }
        let language = Locale.Language(identifier: identifier).languageCode?.identifier ?? identifier
        guard let name = locale.localizedString(forLanguageCode: language), name.lowercased() != language.lowercased()
        else { return nil }
        return name
    }
}

extension String {
    fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}
