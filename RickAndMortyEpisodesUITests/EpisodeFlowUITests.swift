import XCTest

/// End-to-end user journeys. The app runs with `-uiTesting`, which serves real API
/// responses recorded in the app (51 episodes over 3 pages) so the tests never touch the network,
/// and `-resetCache`, so every test starts without cached episodes.
@MainActor
final class EpisodeFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetCache"]
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
        for _ in 0..<20 where !endOfList.exists {
            app.swipeUp()
        }

        XCTAssertTrue(endOfList.waitForExistence(timeout: 5))
        XCTAssertEqual(endOfList.label, "You've reached the end. 51 episodes")
        XCTAssertTrue(app.staticTexts["episodeList.lastUpdated"].exists)
    }

    func testRelaunchShowsCachedListImmediately() {
        XCTAssertTrue(app.staticTexts["Pilot"].waitForExistence(timeout: 5))
        let endOfList = app.staticTexts["episodeList.endOfList"]
        for _ in 0..<20 where !endOfList.exists {
            app.swipeUp()
        }
        XCTAssertTrue(endOfList.waitForExistence(timeout: 5))

        // Relaunch without resetting the cache and with every request failing. Without a
        // cache this would show the full-screen error, so the list must have come from disk.
        app.terminate()
        app.launchArguments = ["-uiTesting", "-networkUnavailable"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Pilot"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["episodeList.lastUpdated"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.descendants(matching: .any)["episodeList.loadError"].exists)
    }

    func testEpisodeToCharacterDetailToExport() {
        // Navigation uses identifiers, so copy or language changes don't break the test.
        let pilot = app.buttons["episode.row.1"]
        XCTAssertTrue(pilot.waitForExistence(timeout: 5))
        pilot.tap()

        let character = app.buttons["character.link.1"]
        XCTAssertTrue(character.waitForExistence(timeout: 5))
        character.tap()

        // The name is also the navigation title, so match the Name row by its identifier.
        let name = element(containing: "Rick Sanchez", identifier: "characterDetail.name")
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "Earth (C-137)").exists)
        XCTAssertTrue(app.images["characterDetail.portraitUnavailable"].exists)
        XCTAssertFalse(app.progressIndicators["characterDetail.portraitLoading"].exists)

        // The episode count row can be below the image on small screens, and List only
        // creates cells that are on screen.
        let episodeCount = element(containing: "51")
        if !episodeCount.exists { app.swipeUp() }
        XCTAssertTrue(episodeCount.waitForExistence(timeout: 5))

        app.buttons["characterDetail.export"].tap()
        XCTAssertTrue(app.staticTexts["export.confirmation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["export.share"].exists)
    }

    /// `LabeledContent` may expose its label and value as one accessibility element
    /// ("Origin, Earth (C-137)"), so match on containment rather than the exact text.
    private func element(containing text: String, identifier: String? = nil) -> XCUIElement {
        var query = app.descendants(matching: .any)
        if let identifier {
            query = query.matching(identifier: identifier)
        }
        return query.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func testExportRemainsReachableAtLargestAccessibilityTextSize() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Pilot"].waitForExistence(timeout: 5))

        // The "Last updated" status item stays fully on screen; the bottom bar caps its text size.
        let lastUpdated = app.staticTexts["episodeList.lastUpdated"]
        XCTAssertTrue(lastUpdated.waitForExistence(timeout: 5))
        XCTAssertTrue(app.frame.contains(lastUpdated.frame))

        app.buttons["episode.row.1"].tap()
        let character = app.buttons["character.link.1"]
        XCTAssertTrue(character.waitForExistence(timeout: 5))
        character.tap()
        let export = app.buttons["characterDetail.export"]
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        // The button is there from the start but disabled until the character has loaded.
        XCTAssertTrue(export.wait(for: \.isEnabled, toEqual: true, timeout: 5))
        export.tap()
        XCTAssertTrue(app.staticTexts["export.confirmation"].waitForExistence(timeout: 5))

        let share = app.buttons["export.share"]
        let content = app.scrollViews["export.content"]
        for _ in 0..<8 {
            if share.isHittable && content.frame.contains(share.frame) { break }
            content.swipeUp()
        }
        XCTAssertTrue(share.isHittable)
        XCTAssertTrue(content.frame.contains(share.frame))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Export at largest accessibility text size"
        attachment.lifetime = .keepAlways
        add(attachment)
        share.tap()
        XCTAssertTrue(app.collectionViews["activityCollectionView"].waitForExistence(timeout: 5))
    }
}
