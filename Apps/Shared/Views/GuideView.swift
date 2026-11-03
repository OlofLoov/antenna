import SwiftUI

struct GuideView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Guide",
                systemImage: "list.bullet.rectangle",
                description: Text("XMLTV guide grid goes here. Parser is in AntennaCore; the grid is the next piece of UI work.")
            )
            .navigationTitle("Guide")
        }
    }
}
