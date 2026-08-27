import XCTest

@MainActor
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

@MainActor
final class MealLoggingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testCompleteMealFlowReturnsToTodayAndUpdatesNutrition() {
        let app = launch("--reset-demo", "--screen", "log")
        let oatmeal = app.descendants(matching: .any)["food.row.Oatmeal"]
        XCTAssertTrue(oatmeal.waitForExistence(timeout: 4))
        oatmeal.tap()

        let increment = app.buttons["serving.plus"]
        XCTAssertTrue(increment.waitForExistence(timeout: 3))
        increment.tap()
        XCTAssertEqual(app.staticTexts["serving.value"].label, "1.5")

        let addButton = app.buttons["food.addButton"]
        XCTAssertTrue(addButton.isEnabled)
        addButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["meal.confirmation"].waitForExistence(timeout: 2))
        let ring = app.descendants(matching: .any)["today.calorieRing"]
        XCTAssertTrue(ring.waitForExistence(timeout: 4))
        XCTAssertTrue(ring.label.contains("745 calories left"), "Unexpected calorie ring label: \(ring.label)")

        let breakfast = app.descendants(matching: .any)["today.meal.breakfast"]
        if !breakfast.waitForExistence(timeout: 1) {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(breakfast.waitForExistence(timeout: 3))
        XCTAssertTrue(breakfast.label.contains("585 kcal"))
    }

    func testSearchEmptyAndLoadingStates() {
        var app = launch("--reset-demo", "--screen", "log")
        let search = app.textFields["log.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("zzzz")
        XCTAssertTrue(app.descendants(matching: .any)["log.empty"].waitForExistence(timeout: 2))

        app.terminate()
        app = launch("--reset-demo", "--screen", "log", "--log-state", "loading")
        XCTAssertTrue(app.descendants(matching: .any)["log.loading"].waitForExistence(timeout: 3))
    }

    func testOfflineAndFutureValidationStates() {
        var app = launch("--reset-demo", "--screen", "log", "--today-state", "offline")
        XCTAssertTrue(app.descendants(matching: .any)["log.offline"].waitForExistence(timeout: 3))

        app.terminate()
        app = launch("--reset-demo", "--screen", "log", "--food-preview", "Oatmeal", "--today-state", "future")
        XCTAssertTrue(app.descendants(matching: .any)["food.validation"].waitForExistence(timeout: 3))
        let addButton = app.buttons["food.addButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        XCTAssertFalse(addButton.isEnabled)
    }

    func testOverGoalStateRemainsSupportive() {
        let app = launch("--reset-demo", "--today-state", "over")
        let ring = app.descendants(matching: .any)["today.calorieRing"]
        XCTAssertTrue(ring.waitForExistence(timeout: 4))
        XCTAssertTrue(ring.label.contains("280 calories over"))
    }

    private func launch(_ arguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }
}
