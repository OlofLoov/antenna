import XCTest

extension ShellUITests {
    // local-m3u-file-import/no-import-on-apple-tv
    func testSettingsOffersNoFileImport() {
        launch("loading")
        XCTAssertTrue(element("shell.loading").waitForExistence(timeout: 10))
        press(.menu)
        expectFocus("shell.tab.live")
        press(.right, times: 5)
        expectFocus("shell.settings")
        press(.select)
        XCTAssertTrue(element("settings.addSource").waitForExistence(timeout: 10))
        XCTAssertFalse(element("import.pickFile").exists)
        XCTAssertFalse(element("import.reimport").exists)
        XCTAssertFalse(element("import.dropTarget").exists)
    }
}
