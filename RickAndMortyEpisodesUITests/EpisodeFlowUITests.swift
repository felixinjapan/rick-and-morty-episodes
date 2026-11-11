import XCTest

/// End-to-end user journeys. The app runs with `-uiTesting`, which swaps in local
/// fixture data (25 episodes over 2 pages) so the tests never touch the network.
final class EpisodeFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    func testEpisodeRowShowsNameCodeAndFormattedDate() {
        XCTAssertTrue(app.staticTexts["Pilot"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["S01E01"].exists)
        XCTAssertTrue(app.staticTexts["02/12/2013"].firstMatch.exists)
    }

    func testScrollingLoadsAllPagesAndShowsEndOfList() {
        XCTAssertTrue(app.staticTexts["Pilot"].waitForExistence(timeout: 5))

        let endOfList = app.staticTexts["episodeList.endOfList"]
        for _ in 0..<10 where !endOfList.exists {
            app.swipeUp()
        }

        XCTAssertTrue(endOfList.waitForExistence(timeout: 5))
        XCTAssertEqual(endOfList.label, "You've reached the end · 25 episodes")
        XCTAssertTrue(app.staticTexts["episodeList.lastUpdated"].exists)
    }

    func testEpisodeToCharacterDetailToExport() {
        let pilot = app.staticTexts["Pilot"]
        XCTAssertTrue(pilot.waitForExistence(timeout: 5))
        pilot.tap()

        let character = app.buttons["Character #1"]
        XCTAssertTrue(character.waitForExistence(timeout: 5))
        character.tap()

        XCTAssertTrue(element(containing: "Rick Sanchez").waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "Earth (C-137)").exists)

        // The episode count row can be below the image on small screens, and List only
        // creates cells that are on screen.
        let episodeCount = element(containing: "51")
        if !episodeCount.exists { app.swipeUp() }
        XCTAssertTrue(episodeCount.waitForExistence(timeout: 5))

        app.buttons["characterDetail.export"].tap()
        XCTAssertTrue(app.staticTexts["export.confirmation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open in…"].exists)
    }

    /// `LabeledContent` may expose its label and value as one accessibility element
    /// ("Origin, Earth (C-137)"), so match on containment rather than the exact text.
    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }
}
