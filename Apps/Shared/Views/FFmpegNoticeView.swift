import SwiftUI

/// The FFmpeg notice under Settings, About. FFmpeg's LGPL 2.1 asks that
/// users are told the app uses it, under which license, and where its
/// source is.
struct FFmpegNoticeView: View {
    static let release = "https://github.com/OlofLoov/antenna/releases/tag/ffmpeg-7.1.3-1"
    static let license = "https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html"

    var body: some View {
        Form {
            Section {
                Text(
                    """
                    Antenna plays broadcast streams, Matroska and AVI with FFmpeg 7.1, which is licensed \
                    under the GNU Lesser General Public License, version 2.1 or later. Antenna links its own build \
                    of FFmpeg as a separate library and changes none of FFmpeg's code.
                    """
                )
                .accessibilityIdentifier("ffmpegNotice.text")
            }
            Section("Source") {
                Text("The build script, the build and FFmpeg's source are published with the release.")
                if let url = URL(string: Self.release) {
                    Link(Self.release, destination: url)
                        .accessibilityIdentifier("ffmpegNotice.source")
                }
            }
            Section("License") {
                if let url = URL(string: Self.license) {
                    Link("GNU LGPL 2.1", destination: url)
                }
            }
        }
        .navigationTitle("FFmpeg")
    }
}

#Preview {
    NavigationStack { FFmpegNoticeView() }
}
