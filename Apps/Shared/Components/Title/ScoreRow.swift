import AntennaCore
import SwiftUI

/// A title's scores from other sites, each the site's name in muted text
/// and the value in semibold, on a quiet chip (`iPhone-Title-Scores`,
/// `iPad-Title-Scores`, `TV-Title-Scores`;
/// title-detail-and-episode-picker/scores-from-other-sites). Takes no focus.
/// Wraps to a column at large text sizes. `note` adds a bordered label after
/// the chips, "Sample" while the scores are made up.
struct ScoreRow: View {
    /// In the order they show.
    let scores: [Score]
    let note: LocalizedStringResource?
    /// The value's point size: 13 on iPhone, 14 on iPad and Mac, 24 on Apple TV.
    let size: CGFloat
    @Environment(\.locale) private var locale

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: size / 2) { chips }
            VStack(alignment: .leading, spacing: size / 3) { chips }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("title.scores")
    }

    @ViewBuilder private var chips: some View {
        ForEach(scores, id: \.site) { score in
            HStack(alignment: .firstTextBaseline, spacing: size * 0.4) {
                Text(score.site.name)
                    .font(.system(size: (size * 0.84).rounded()))
                    .foregroundStyle(Palette.textMuted)
                Text(score.text ?? "")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(Palette.text)
            }
            .lineLimit(1)
            .padding(.horizontal, size * 0.7)
            .padding(.vertical, size / 3)
            .background(Palette.surface(0.08), in: RoundedRectangle(cornerRadius: size * 0.55, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(score.spoken(locale) ?? score.site.name)
            .accessibilityIdentifier("title.score.\(score.site.rawValue)")
        }
        if let note {
            Text(note)
                .font(.system(size: (size * 0.84).rounded(), weight: .semibold))
                .foregroundStyle(Palette.textMuted)
                .lineLimit(1)
                .padding(.horizontal, size * 0.6)
                .padding(.vertical, size / 4)
                .overlay(RoundedRectangle(cornerRadius: size * 0.55, style: .continuous).strokeBorder(Palette.textMuted, lineWidth: 1))
                .accessibilityLabel("\(note) scores, not from the movie database")
                .accessibilityIdentifier("title.scores.sample")
        }
    }
}

extension TitlePage {
    /// The scores from other sites below the buttons and progress, so
    /// their arrival moves nothing the user can tap or focus. Takes no
    /// space until a score arrives (title-detail-and-episode-picker/scores-from-other-sites).
    struct Scores: View {
        let type: Sizes
        @Environment(\.titlePage) private var page

        var body: some View {
            if let meta = page?.state.metadata, !meta.scores.isEmpty {
                ScoreRow(scores: meta.scores, note: meta.scoresAreSample ? "Sample" : nil, size: type.meta)
            }
        }
    }
}

extension ScoreRow {
    /// Every site, for previews.
    nonisolated static let previewScores = [
        Score(site: .imdb, value: 7.8, scale: 10), Score(site: .rottenTomatoes, value: 92, scale: 100),
        Score(site: .metacritic, value: 81, scale: 100), Score(site: .tmdb, value: 7.4, scale: 10),
    ]
}

#Preview("Scores, iPhone", traits: .fixedLayout(width: 390, height: 120)) {
    VStack(alignment: .leading, spacing: 16) {
        ScoreRow(scores: [Score(site: .tmdb, value: 7.4, scale: 10)], note: nil, size: 13)
        ScoreRow(scores: ScoreRow.previewScores, note: nil, size: 13)
        ScoreRow(scores: [Score(site: .tmdb, value: 6.8, scale: 10)], note: "Sample", size: 13)
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Palette.ground)
}

#Preview("Scores, Apple TV", traits: .fixedLayout(width: 1920, height: 240)) {
    VStack(alignment: .leading, spacing: 24) {
        ScoreRow(scores: ScoreRow.previewScores, note: nil, size: 24)
        ScoreRow(scores: [Score(site: .tmdb, value: 6.8, scale: 10)], note: "Sample", size: 24)
    }
    .padding(96)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Palette.ground)
}
