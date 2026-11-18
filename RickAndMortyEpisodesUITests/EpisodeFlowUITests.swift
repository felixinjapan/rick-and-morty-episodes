import XCTest

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
        // The code is shown as S01E01 but read as words.
        XCTAssertTrue(app.staticTexts["Season 1, episode 1"].exists)
        XCTAssertTrue(app.staticTexts["Aired 02/12/2013"].firstMatch.exists)
    }

    func testScrollingLoadsAllPagesAndShowsEndOfList() {
        XCTAssertTrue(app.staticTexts["Pilot"].waitForExistence(timeout: 5))

        XCTAssertEqual(scrollToEndOfList().label, "You've reached the end. 51 episodes")
        XCTAssertTrue(app.staticTexts["episodeList.lastUpdated"].exists)
    }

    func testRelaunchShowsCachedListImmediately() {
        XCTAssertTrue(app.staticTexts["Pilot"].waitForExistence(timeout: 5))
        scrollToEndOfList()
        relaunchOffline()

        XCTAssertTrue(app.staticTexts["Pilot"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["episodeList.lastUpdated"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.descendants(matching: .any)["episodeList.loadError"].exists)

        XCTAssertEqual(scrollToEndOfList().label, "You've reached the end. 51 episodes")
    }

    func testEpisodeToCharacterDetailToExport() {
        let pilot = app.buttons["episode.row.1"]
        XCTAssertTrue(pilot.waitForExistence(timeout: 5))
        pilot.tap()

        let character = app.buttons["character.link.1"]
        XCTAssertTrue(character.waitForExistence(timeout: 5))
        XCTAssertTrue(characterRow(1, named: "Rick Sanchez").waitForExistence(timeout: 5))
        XCTAssertTrue(character.label.contains("Character #1"))
        XCTAssertTrue(characterRow(2, named: "Morty Smith").waitForExistence(timeout: 5))
        capture("Character list with names, IDs and portraits")
        character.tap()
        XCTAssertTrue(app.navigationBars["Rick Sanchez"].waitForExistence(timeout: 5))

        // The name is also the navigation title, so match the heading by its identifier.
        let name = element(containing: "Rick Sanchez", identifier: "characterDetail.name")
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "Earth (C-137)").exists)
        XCTAssertTrue(app.images["characterDetail.portrait"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.progressIndicators["characterDetail.portraitLoading"].exists)
        XCTAssertFalse(app.images["characterDetail.portraitUnavailable"].exists)

        // The episode count row can be below the image on small screens, and List only
        // creates cells that are on screen.
        let episodeCount = element(containing: "51", identifier: "characterDetail.episodeCount")
        if !episodeCount.exists { app.swipeUp() }
        XCTAssertTrue(episodeCount.waitForExistence(timeout: 5))

        app.buttons["characterDetail.export"].tap()
        XCTAssertTrue(app.staticTexts["export.confirmation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["export.share"].exists)
    }

    func testOpenedCharacterStaysAvailableOffline() {
        openCharacter(1)
        XCTAssertTrue(element(containing: "Rick Sanchez", identifier: "characterDetail.name").waitForExistence(timeout: 5))

        XCTAssertTrue(app.images["characterDetail.portrait"].waitForExistence(timeout: 5))

        relaunchOffline()

        openCharacter(1)
        XCTAssertTrue(element(containing: "Rick Sanchez", identifier: "characterDetail.name").waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["characterDetail.portrait"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.images["characterDetail.portraitUnavailable"].exists)

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(characterRow(1, named: "Rick Sanchez").waitForExistence(timeout: 5))
        capture("Saved character list available offline")
        app.navigationBars.buttons.firstMatch.tap()
        openCharacter(46, episodeID: 2)
        XCTAssertTrue(app.descendants(matching: .any)["characterDetail.loadError"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Character"].exists)
        XCTAssertTrue(app.buttons["characterDetail.retry"].exists)
        XCTAssertFalse(app.progressIndicators.firstMatch.exists)
        XCTAssertFalse(app.buttons["characterDetail.export"].isEnabled)
        XCTAssertFalse(app.descendants(matching: .any)["characterDetail.name"].exists)
    }

    func testCharacterNamesLoadAfterFastScrolling() {
        let episode = app.buttons["episode.row.10"]
        for _ in 0..<3 where !episode.exists || !episode.isHittable {
            app.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(episode.isHittable)
        episode.tap()
        XCTAssertTrue(app.navigationBars["Characters"].waitForExistence(timeout: 5))
        XCTAssertTrue(characterRow(1, named: "Rick Sanchez").waitForExistence(timeout: 5))

        let lastRow = app.buttons["character.link.663"]
        for _ in 0..<12 where !lastRow.exists || !lastRow.isHittable {
            app.swipeUp(velocity: XCUIGestureVelocity(rawValue: 8_000))
        }
        XCTAssertTrue(lastRow.isHittable)
        XCTAssertTrue(characterRow(663, named: "Reggie").waitForExistence(timeout: 5))
        XCTAssertTrue(characterRow(434, named: "Super Weird Rick").waitForExistence(timeout: 5))
        XCTAssertTrue(characterRow(433, named: "Doopidoo").waitForExistence(timeout: 5))
    }

    private func relaunchOffline() {
        app.terminate()
        app.launchArguments = ["-uiTesting", "-networkUnavailable"]
        app.launch()
    }

    @discardableResult
    private func scrollToEndOfList() -> XCUIElement {
        let endOfList = app.staticTexts["episodeList.endOfList"]
        for _ in 0..<20 {
            if endOfList.exists && endOfList.isHittable && app.frame.contains(endOfList.frame) { break }
            app.swipeUp()
        }
        XCTAssertTrue(endOfList.waitForExistence(timeout: 5))
        XCTAssertTrue(endOfList.isHittable && app.frame.contains(endOfList.frame))
        return endOfList
    }

    private func openCharacter(_ id: Int, episodeID: Int = 1) {
        let episode = app.buttons["episode.row.\(episodeID)"]
        if episode.waitForExistence(timeout: 5) { episode.tap() }
        let character = app.buttons["character.link.\(id)"]
        XCTAssertTrue(character.waitForExistence(timeout: 5))
        character.tap()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func characterRow(_ id: Int, named name: String) -> XCUIElement {
        app.buttons.matching(identifier: "character.link.\(id)")
            .matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
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

    /// The system share sheet. `activityCollectionView` is UIKit's own identifier, not the
    /// app's, so if an iOS update renames it, this is the one place to change.
    private var shareSheet: XCUIElement {
        app.collectionViews["activityCollectionView"]
    }

    func testExportRemainsReachableAtLargestAccessibilityTextSize() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Pilot"].waitForExistence(timeout: 5))

        let lastUpdated = app.staticTexts["episodeList.lastUpdated"]
        XCTAssertTrue(lastUpdated.waitForExistence(timeout: 5))
        XCTAssertTrue(app.frame.contains(lastUpdated.frame))

        app.buttons["episode.row.1"].tap()
        let character = app.buttons["character.link.1"]
        XCTAssertTrue(character.waitForExistence(timeout: 5))
        XCTAssertTrue(characterRow(1, named: "Rick Sanchez").waitForExistence(timeout: 5))
        capture("Character list at largest accessibility text size")
        character.tap()
        let export = app.buttons["characterDetail.export"]
        XCTAssertTrue(export.waitForExistence(timeout: 5))
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
        capture("Export at largest accessibility text size")
        share.tap()
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 5), "The share sheet should open for the exported file")
    }
}
