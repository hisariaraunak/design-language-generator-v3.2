import XCTest

final class WaterQuestUITests: XCTestCase {
    func testSingleTapAddsAndDoubleTapSubtractsTwoHundredMilliliters() {
        let app = XCUIApplication()
        app.launchArguments = ["--today-state", "water"]
        app.launch()

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 4))
        scrollView.swipeUp()
        let quest = app.descendants(matching: .any)["today.waterQuest"]
        XCTAssertTrue(quest.waitForExistence(timeout: 3))
        XCTAssertTrue(wait(for: quest, toContain: "1.2 of 2 liters"))

        quest.tap()
        XCTAssertTrue(wait(for: quest, toContain: "1.4 of 2 liters"))

        quest.doubleTap()
        XCTAssertTrue(wait(for: quest, toContain: "1.2 of 2 liters"))
    }

    private func wait(for element: XCUIElement, toContain text: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 3) == .completed
    }
}
