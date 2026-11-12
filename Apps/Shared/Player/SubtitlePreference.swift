import AntennaCore
import SwiftData
import SwiftUI

extension View {
    /// Calls `apply` with the synced Subtitles preference now and on each
    /// change, so the next stream starts by it
    /// (playback-engine/subtitles-start-by-the-subtitle-setting).
    func followsSubtitlePreference(_ apply: @escaping (SubtitleMode) -> Void) -> some View {
        modifier(SubtitlePreference(apply: apply))
    }
}

private struct SubtitlePreference: ViewModifier {
    @Query private var records: [PreferencesRecord]
    let apply: (SubtitleMode) -> Void

    func body(content: Content) -> some View {
        content.onChange(of: PreferencesStore.current(records).subtitles, initial: true) { _, mode in apply(mode) }
    }
}
