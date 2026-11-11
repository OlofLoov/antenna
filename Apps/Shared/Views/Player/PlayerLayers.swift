import SwiftUI

/// The spinner, the slow-source line or the reconnect count over the
/// picture, as `PlayerModel` says. Nothing while the picture plays.
struct PlayerWaitingLayer: View {
    let player: PlayerModel

    var body: some View {
        switch player.waiting {
        case .spinner, .slow:
            PlayerStatus.Waiting(caption: player.waiting?.caption)
        case .reconnecting(let caption):
            PlayerStatus.Reconnecting(caption: caption)
        case nil:
            EmptyView()
        }
    }
}
