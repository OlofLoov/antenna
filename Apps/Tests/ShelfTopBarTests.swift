#if os(iOS) || os(macOS)
    import SwiftUI
    import Testing

    @testable import Antenna

    /// The top bar of Movies and Series on iPhone, read from the type of the
    /// views it builds: which modifiers wrap what. A fill, outline or shadow
    /// added later shows up in that type and fails these tests.
    @MainActor @Suite struct ShelfTopBarTests {
        /// The modifiers that draw a fill, an outline or a shadow of their own:
        /// `background`, `overlay` and `border`, a stroked shape, `shadow`.
        private static let surfaces = ["_Background", "_Overlay", "_StrokedShape", "StrokeBorder", "_ShadowEffect"]

        private static func typeName(_ view: some View) -> String {
            String(reflecting: type(of: view))
        }

        /// Owner-found: the genre button over light art needed a ground of its
        /// own. It is a glass capsule, the system glass button style, and
        /// nothing in it draws a fill, an outline or a shadow.
        @Test("design-system/liquid-glass-stays-on-the-navigation-layer: the genre button is glass alone")
        func genreButtonIsGlassAlone() {
            let name = Self.typeName(ShelfCategoryButton(name: "All movies", count: 214) {}.body)
            #expect(name.contains("GlassButtonStyle"), "\(name)")
            for surface in Self.surfaces {
                #expect(!name.contains(surface), "\(surface) in \(name)")
            }
        }

        /// The markers catch each kind of surface, so the two tests above and
        /// below fail when one is added.
        @Test func markersCatchSurfaces() {
            let views: [String] = [
                Self.typeName(Text(verbatim: "A").background(Color.black)),
                Self.typeName(Text(verbatim: "A").background { Capsule() }),
                Self.typeName(Text(verbatim: "A").overlay { Capsule().stroke() }),
                Self.typeName(Text(verbatim: "A").border(Color.white)),
                Self.typeName(Text(verbatim: "A").shadow(radius: 4)),
            ]
            for name in views {
                #expect(Self.surfaces.contains { name.contains($0) }, "\(name)")
            }
        }

        /// The bar holds the glass button, so the bar itself draws nothing:
        /// no glass, which would put glass on glass, and no fill.
        @Test("movies-and-series-browsing/a-pinned-top-bar-on-iphone: the bar draws nothing behind its controls")
        func barIsClear() {
            let bar = ShelfTopBar(title: "Movies") {
                ShelfCategoryButton(name: "All movies", count: 214) {}
            } profile: {
                EmptyView()
            }
            let name = Self.typeName(bar.body)
            #expect(!name.contains("GlassEffect"), "\(name)")
            for surface in Self.surfaces {
                #expect(!name.contains(surface), "\(surface) in \(name)")
            }
        }
    }
#endif
