import AntennaCore
import SwiftUI

extension TitlePage {
    /// Holds the page back while its details load and shows it in one go
    /// with a short fade once they arrive or fail
    /// (title-detail-and-episode-picker/the-page-shows-in-one-go). A load
    /// longer than `TitleReveal.delay` shows the mark tuning in the middle
    /// of the ground, and Got it before the page. `back` stays over the
    /// ground meanwhile, at the top leading corner.
    struct Reveal<Back: View, Content: View>: View {
        /// The mark's width.
        let mark: CGFloat
        @ViewBuilder var back: Back
        @ViewBuilder var content: Content
        @Environment(\.titlePage) private var page
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        /// Nil until the first change, when the stage follows from whether
        /// the page opened loading.
        @State private var stage: TitleReveal?

        var body: some View {
            let loading = page?.state.loading ?? false
            let shown = stage ?? .opening(loading: loading)
            ZStack {
                if shown.showsPage {
                    content
                        .transition(.opacity)
                } else {
                    Veil(mark: mark, moment: shown.moment) { back }
                }
            }
            .task(id: loading) { await advance(loading: loading) }
        }

        private func advance(loading: Bool) async {
            let now = stage ?? .opening(loading: loading)
            guard loading else {
                let next = now.loaded()
                guard next == .gotIt else {
                    withAnimation(.easeOut(duration: 0.25)) { stage = next }
                    return
                }
                stage = next
                try? await Task.sleep(for: .seconds(TitleReveal.gotItHold(reduceMotion: reduceMotion)))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.25)) { stage = next.gotItPlayed() }
                return
            }
            stage = now.loadingAgain()
            guard stage == .waiting else { return }
            try? await Task.sleep(for: TitleReveal.delay)
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) { stage = .waiting.delayPassed() }
        }
    }

    /// The ground with the mark in the middle while `moment` is set, and
    /// `back` at the top leading corner.
    struct Veil<Back: View>: View {
        let mark: CGFloat
        let moment: MarkMoment?
        var clock = BrandMark.Clock.live
        @ViewBuilder var back: Back

        var body: some View {
            ZStack {
                Palette.ground
                    .ignoresSafeArea()
                if let moment {
                    BrandMark.Letter(moment: moment, clock: clock)
                        .frame(width: mark)
                        .accessibilityLabel("Loading details")
                        .accessibilityIdentifier("title.loadingMark")
                        .transition(.opacity)
                }
                back
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

#Preview("Loading, the mark tuning", traits: .fixedLayout(width: 402, height: 874)) {
    TitlePage.Veil(mark: 96, moment: .tuning, clock: .frozen(0.8)) { EmptyView() }
}
