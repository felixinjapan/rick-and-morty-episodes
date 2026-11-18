import XCTest

@MainActor
final class DelayedEpisodeFeedUITests: XCTestCase {
    func testEmptyCastShowsNoLoadingRows() {
        let app = launchEdgeCases(episodeID: 2)
        XCTAssertTrue(app.staticTexts["No Characters"].exists)
        XCTAssertFalse(app.progressIndicators.firstMatch.exists)
    }

    func testMixedCastKeepsOrderAndHandlesMissingDetailsAndCorruptPortrait() {
        let app = launchEdgeCases(episodeID: 3)
        let missing = app.buttons["character.link.9002"]
        let corrupt = app.buttons["character.link.9001"]
        let unicode = app.buttons["character.link.9003"]

        XCTAssertTrue(corrupt.waitForExistence(timeout: 5))
        XCTAssertTrue(missing.waitForExistence(timeout: 5))
        XCTAssertTrue(missing.label.contains("Tap for details"))
        XCTAssertTrue(corrupt.label.contains("Endless Character 9001"))
        XCTAssertLessThan(missing.frame.minY, corrupt.frame.minY)
        XCTAssertTrue(unicode.waitForExistence(timeout: 5))
        XCTAssertTrue(unicode.label.contains("偏遠太空站 🛸"))
        XCTAssertEqual(app.buttons.matching(identifier: "character.link.9003").count, 1)
        XCTAssertTrue(app.staticTexts["3 characters"].exists)

        corrupt.tap()
        XCTAssertTrue(app.images["characterDetail.portraitUnavailable"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.progressIndicators["characterDetail.portraitLoading"].exists)
    }

    func testMissingCharacterShowsDetailError() {
        let app = launchEdgeCases(episodeID: 3)
        let missing = app.buttons["character.link.9002"]
        XCTAssertTrue(missing.waitForExistence(timeout: 5))
        missing.tap()
        XCTAssertTrue(app.descendants(matching: .any)["characterDetail.loadError"].waitForExistence(timeout: 5))
    }

    func testReopeningCastRecoversFromFailedBatch() {
        let app = launchEdgeCases(episodeID: 4)
        let row = app.buttons["character.link.9004"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Tap for details"))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["episode.row.4"].tap()
        XCTAssertTrue(app.staticTexts["Endless Character 9004"].waitForExistence(timeout: 5))
    }

    private func launchEdgeCases(episodeID: Int) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetCache", "-delayedEpisodeFeed", "-characterEdgeCases"]
        app.launch()
        let episode = app.buttons["episode.row.\(episodeID)"]
        XCTAssertTrue(episode.waitForExistence(timeout: 8))
        episode.tap()
        XCTAssertTrue(app.navigationBars["Characters"].waitForExistence(timeout: 5))
        return app
    }

    func testFastScrollingLoadsAnEndlessCharacterList() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetCache", "-delayedEpisodeFeed", "-endlessCharacters"]
        app.launch()
        XCTAssertTrue(app.buttons["episode.row.1"].waitForExistence(timeout: 8))
        app.buttons["episode.row.1"].tap()
        XCTAssertTrue(app.navigationBars["Characters"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Episode 1"].exists)

        for _ in 0..<4 {
            app.swipeUp(velocity: XCUIGestureVelocity(rawValue: 8_000))
        }

        let loadedRow = app.buttons.matching(NSPredicate(
            format: "identifier MATCHES %@ AND label BEGINSWITH %@",
            "character\\.link\\.[1-9][0-9]{2,}", "Endless Character "
        )).firstMatch
        XCTAssertTrue(loadedRow.waitForExistence(timeout: 5))
        XCTAssertTrue(loadedRow.isHittable)
    }

    func testShowsCastProgressUntilCharactersLoad() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetCache", "-delayedEpisodeFeed"]
        app.launch()
        XCTAssertTrue(app.buttons["episode.row.1"].waitForExistence(timeout: 8))
        app.buttons["episode.row.1"].tap()

        let progress = app.descendants(matching: .any)["episodeCharacters.loading.1"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Character #1"].exists)
        XCTAssertTrue(app.staticTexts["Rick Sanchez"].waitForExistence(timeout: 5))
        XCTAssertFalse(progress.exists)
    }

    func testFastScrollingAndRetryInLongDelayedFeed() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetCache", "-delayedEpisodeFeed"]
        app.launch()
        XCTAssertTrue(app.buttons["episode.row.1"].waitForExistence(timeout: 8))

        let retry = app.buttons["Retry"]
        for _ in 0..<12 {
            if retry.exists && retry.isHittable { break }
            app.swipeUp(velocity: XCUIGestureVelocity(rawValue: 8_000))
        }
        XCTAssertTrue(retry.isHittable)
        XCTAssertTrue(app.buttons["episode.row.36"].isHittable)
        XCTAssertFalse(app.buttons["episode.row.37"].exists)
        retry.tap()
        XCTAssertTrue(app.buttons["episode.row.37"].waitForExistence(timeout: 5))
        // Stay at the page boundary long enough for a second delayed request to complete.
        RunLoop.current.run(until: Date.now.addingTimeInterval(3))
        XCTAssertTrue(app.buttons["episode.row.36"].isHittable, "Appending a page should keep the previous rows in view")

        let laterEpisodes = app.buttons.matching(
            NSPredicate(format: "identifier MATCHES %@", "episode\\.row\\.(9[0-9]|[1-9][0-9]{2,})")
        )
        var target: XCUIElement?
        for _ in 0..<24 {
            target = laterEpisodes.allElementsBoundByIndex.first { $0.isHittable }
            if target != nil { break }
            app.swipeUp(velocity: XCUIGestureVelocity(rawValue: 8_000))
        }
        guard let target else {
            XCTFail("Fast scrolling did not reach episode 90 or later")
            return
        }
        XCTAssertFalse(retry.exists)
        XCTAssertFalse(app.staticTexts["episodeList.endOfList"].exists)
        XCTAssertTrue(app.staticTexts["episodeList.lastUpdated"].exists)

        let episodeID = target.identifier.dropFirst("episode.row.".count)
        target.tap()
        XCTAssertTrue(app.navigationBars["Characters"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Episode \(episodeID)"].exists)
    }
}
