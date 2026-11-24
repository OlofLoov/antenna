#if DEBUG
    import AntennaCore
    import Foundation
    import QuartzCore
    import SwiftUI

    /// The `large` shelf script: a library the size of a big provider's, for
    /// the browsing performance and focus tests
    /// (movies-and-series-browsing/browsing-stays-responsive). Cabin offers
    /// 6 000 movies in 80 categories and 2 500 series in 40; Office 3 000
    /// movies and 1 000 series in categories that share Cabin's names.
    ///
    /// Without `-ui-testing-poster-host <address>` every poster shows its
    /// name tile. With one, posters load from `<address>/poster/<id>.jpg`
    /// and backdrops from `<address>/backdrop/<id>.jpg`, a fixture server
    /// on the Mac, never a provider.
    enum UITestingShelfLarge {
        static let posterHostArgument = "-ui-testing-poster-host"
        /// Office answers this long after Cabin, as a slower provider does,
        /// so its titles join the rows while the viewer is in them.
        static let officeDelay = Duration.seconds(5)

        static let genres = [
            "Action", "Drama", "Comedy", "Thriller", "Horror", "Documentary", "Kids", "Romance", "Crime", "Sci-Fi",
        ]
        static let words = [
            "Harbor", "Engine", "Orchard", "Ferry", "River", "Signal", "Winter", "Station", "Garden", "Mirror", "Lantern",
            "Bridge", "Summit", "Echo", "Copper", "Silver", "Hollow", "Meadow", "Tide", "Ember",
        ]

        /// The fixture server's address, or nil.
        static var posterHost: URL? {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: posterHostArgument), index + 1 < arguments.count else { return nil }
            return URL(string: arguments[index + 1])
        }

        /// The picture at `<host>/<kind>/<id>.jpg`, or nil without a host.
        static func art(_ id: String, _ kind: String) -> URL? {
            posterHost?.appending(path: kind).appending(path: "\(id.replacingOccurrences(of: "#", with: "-")).jpg")
        }

        /// A title's backdrop: from the fixture server in the `large` script,
        /// else the store art.
        static func backdrop(_ id: String, large: Bool) -> URL? {
            large ? art(id, "backdrop") : UITestingStoreShots.art(for: id, .backdrop)
        }

        /// The category names of a source with `count` categories.
        static func categories(_ count: Int) -> [String] {
            (0..<count).map { index in
                let genre = genres[index % genres.count]
                return index < genres.count ? genre : "\(genre) \(index / genres.count + 1)"
            }
        }

        /// The source's catalogue, made away from the main actor as a
        /// provider's answer is parsed. Office answers `officeDelay` late.
        @concurrent
        static func build(_ source: UUID, host: String, kind: ShelfTitle.Kind, launched: Date) async throws -> ShelfCatalogue {
            if host == "office" { try await Task.sleep(for: officeDelay) }
            return catalogue(source, host: host, kind: kind, launched: launched)
        }

        static func catalogue(_ source: UUID, host: String, kind: ShelfTitle.Kind, launched: Date) -> ShelfCatalogue {
            let isCabin = host == "cabin"
            let count = kind == .movie ? (isCabin ? 6_000 : 3_000) : (isCabin ? 2_500 : 1_000)
            let names = categories(kind == .movie ? (isCabin ? 80 : 40) : (isCabin ? 40 : 20))
            let titles = (1...count).map { number in
                let id = "xtream#\(host)#\(kind == .movie ? "vod" : "series")#\(number)"
                // A few large categories and a long tail, as providers have.
                let share = Double(number % 997) / 997
                let category = names[min(names.count - 1, Int(Double(names.count) * share * share))]
                let name = "\(words[number % words.count]) \(words[(number / words.count) % words.count]) \(number)"
                return ShelfTitle(
                    id: id, kind: kind, sourceID: source, name: name, posterURL: art(id, "poster"),
                    added: launched.addingTimeInterval(-Double(number % 400) * 86_400 - Double(number)), category: category,
                    containerExtension: "mp4")
            }
            return ShelfCatalogue(titles: titles, categories: names)
        }
    }

    extension UITestingShelf {
        /// How many times parts of Movies and Series drew their body, for
        /// the UI tests that check a move between posters redraws only what
        /// shows the focused title
        /// (movies-and-series-browsing/browsing-stays-responsive). Not
        /// observed, so counting redraws nothing.
        @MainActor
        enum Redraws {
            enum Part: String, CaseIterable {
                case screen, rows, banner
            }

            private static var counts: [Part: Int] = [:]

            /// Counts one body of `part`, called from inside that body.
            static func mark(_ part: Part) -> EmptyView {
                if testing { counts[part, default: 0] += 1 }
                return EmptyView()
            }

            static func count(_ part: Part) -> Int {
                counts[part] ?? 0
            }
        }

        /// The redraw counts, read through `shelf.debug.redraws.<part>`. It
        /// reads them twice a second, and only its own body redraws for it.
        struct RedrawsProbe: View {
            var body: some View {
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    Counts(date: context.date)
                }
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .onAppear { FrameGaps.shared.start() }
            }
        }

        /// A new `date` each tick, so the counts are read again.
        private struct Counts: View {
            let date: Date

            var body: some View {
                HStack {
                    ForEach(Redraws.Part.allCases, id: \.self) { part in
                        let count = "\(Redraws.count(part))"
                        Text(verbatim: count)
                            .font(.system(size: 8))
                            .foregroundStyle(Palette.textMuted)
                            .accessibilityIdentifier("shelf.debug.redraws.\(part.rawValue)")
                            .accessibilityValue(count)
                    }
                    let gaps = FrameGaps.shared
                    let counts = [("frames", gaps.frames), ("dropped", gaps.dropped), ("hitchMs", gaps.hitchMilliseconds)]
                    ForEach(counts, id: \.0) { name, value in
                        let count = String(value)
                        Text(verbatim: count)
                            .font(.system(size: 8))
                            .foregroundStyle(Palette.textMuted)
                            .accessibilityIdentifier("shelf.debug.\(name)")
                            .accessibilityValue(count)
                    }
                }
                .id(date)
            }
        }
    }

    /// Counts the frames the main thread missed since UI testing started:
    /// a display link tick that comes later than one and a half frames
    /// after the last one missed the frames in between. The simulator's
    /// timing is not a device's, so the counts compare runs on one Mac.
    @MainActor
    final class FrameGaps: NSObject {
        static let shared = FrameGaps()
        private(set) var frames = 0
        private(set) var dropped = 0
        private var hitch: CFTimeInterval = 0
        private var last: CFTimeInterval?
        private var link: CADisplayLink?

        var hitchMilliseconds: Int { Int(hitch * 1000) }

        func start() {
            // The Mac has no target-selector display link; the benchmarks run on Apple TV.
            #if !os(macOS)
                guard link == nil, UITestingShelf.testing else { return }
                let link = CADisplayLink(target: self, selector: #selector(tick))
                // A steady 60 Hz, so a quiet screen does not read as missed frames.
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
                link.add(to: .main, forMode: .common)
                self.link = link
            #endif
        }

        @objc private func tick(_ link: CADisplayLink) {
            let interval = link.targetTimestamp - link.timestamp
            defer { last = link.timestamp }
            frames += 1
            guard let last, interval > 0 else { return }
            let gap = link.timestamp - last
            guard gap > interval * 1.5 else { return }
            dropped += Int((gap / interval).rounded()) - 1
            hitch += gap - interval
        }
    }
#endif
