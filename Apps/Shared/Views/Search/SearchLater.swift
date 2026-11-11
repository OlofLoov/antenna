#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// The programme picked in Search as a "Later" row under Up next on iPad
    /// and Mac, until the channel changes or the programme ends
    /// (search/pick-a-programme).
    struct LiveLaterRow: View {
        @Environment(LiveModel.self) private var live

        var body: some View {
            if let later = live.later {
                TimelineView(.periodic(from: .now, by: LiveClock.tick)) { context in
                    if later.stop > context.date {
                        SearchParts.LaterRow(text: SearchText().later(later, now: context.date))
                            .accessibilityIdentifier("browse.later")
                    }
                }
            }
        }
    }

    /// The same as a "Later:" line under the now-playing line on iPhone.
    struct LiveLaterLine: View {
        @Environment(LiveModel.self) private var live

        var body: some View {
            if let later = live.later {
                TimelineView(.periodic(from: .now, by: LiveClock.tick)) { context in
                    if later.stop > context.date {
                        SearchParts.LaterLine(text: SearchText().later(later, now: context.date))
                            .accessibilityIdentifier("browse.later")
                    }
                }
            }
        }
    }
#endif
