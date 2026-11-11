import AntennaCore
import SwiftData
import SwiftUI

/// Watches the stored sources, saved here or arriving through iCloud, and
/// clears each deleted source's channels from the recents, the session and
/// the last channel of every profile on this device
/// (session-restore-and-recently-watched/deleting-a-source-clears-its-channels).
///
/// Only a deletion seen while the app runs counts: a source missing at
/// launch, or one whose record cannot be read, clears nothing.
struct SourceDeletions: ViewModifier {
    /// Told about each deleted source after the store is cleared.
    let removed: (UUID) -> Void
    /// Where the recents live; the app's own defaults outside UI tests.
    let defaults: UserDefaults
    @Query private var records: [SourceRecord]

    func body(content: Content) -> some View {
        content.onChange(of: Set(records.map(\.id))) { old, new in
            for id in old.subtracting(new) {
                RecentsStore.remove(source: id, from: defaults)
                removed(id)
            }
        }
    }
}
