import XCTest

/// Runs the system accessibility audit on each screen. The checks are the ones that give the same
/// answer every run: element descriptions, traits, hit regions and element detection.
///
/// Contrast, clipping and Dynamic Type are left out on purpose. The audit reports text drawn with a
/// transparent `primary` as failing contrast although it measures about 8:1, calls text inside a
/// scroll view clipped, and flags the system's own tint and toolbar text. Those three were checked
/// by eye at the largest accessibility text size instead.
@MainActor
final class AccessibilityAuditUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetCache"]
        app.launch()
    }

    func testEpisodeList() throws {
        XCTAssertTrue(app.buttons["episode.row.1"].waitForExistence(timeout: 5))
        try audit()
    }

    func testCast() throws {
        app.buttons["episode.row.1"].tap()
        XCTAssertTrue(castRow.waitForExistence(timeout: 5))
        try audit()
    }

    func testCharacterDetail() throws {
        app.buttons["episode.row.1"].tap()
        XCTAssertTrue(castRow.waitForExistence(timeout: 5))
        castRow.tap()
        XCTAssertTrue(app.images["characterDetail.portrait"].waitForExistence(timeout: 5))
        try audit()
    }

    func testOfflineEpisodeList() throws {
        app.terminate()
        app.launchArguments = ["-uiTesting", "-resetCache", "-networkUnavailable"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["episodeList.loadError"].waitForExistence(timeout: 5))
        try audit()
    }

    private func audit() throws {
        try app.performAccessibilityAudit(for: [.elementDetection, .hitRegion, .sufficientElementDescription, .trait])
    }

    private var castRow: XCUIElement {
        app.buttons.matching(identifier: "character.link.1")
            .matching(NSPredicate(format: "label CONTAINS %@", "Rick Sanchez")).firstMatch
    }
}
