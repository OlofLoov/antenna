import Testing

@testable import Antenna

#if os(iOS) || os(macOS)
    @Suite struct LiveColumnsTests {
        @Test(
            "live-tv-on-iphone-ipad-mac/sidebar-list-and-picture-side-by-side: the sidebar folds below 904 pt, then the list below 672 pt")
        func breakpoints() {
            #expect(LiveColumns(width: 1194) == .all)
            #expect(LiveColumns(width: 904) == .all)
            #expect(LiveColumns(width: 903.5) == .listAndPicture)
            #expect(LiveColumns(width: 800) == .listAndPicture)
            #expect(LiveColumns(width: 672) == .listAndPicture)
            #expect(LiveColumns(width: 671) == .picture)
            #expect(LiveColumns(width: 320) == .picture)
        }
    }
#endif
