import XCTest

final class SignInTests: XCTestCase {
    @MainActor func testSignedOutLaunchShowsSignIn() {
        let app = XCUIApplication()
        app.launch()
        let settings = app.tabBars.buttons["Settings"]
        if settings.waitForExistence(timeout: 5) {
            settings.tap()
            app.buttons["Sign Out"].tap()
        }
        let signIn = app.buttons["Continue with Vesper"]
        XCTAssert(signIn.waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.exists)

        signIn.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let cancel = springboard.buttons["Cancel"]
        XCTAssert(cancel.waitForExistence(timeout: 20))
        cancel.tap()
        XCTAssert(signIn.waitForExistence(timeout: 5))
        XCTAssert(app.staticTexts["Memos, photos and the places they happened, sealed by your passkey."].exists)
    }
}
