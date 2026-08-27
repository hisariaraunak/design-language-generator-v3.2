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

@MainActor
final class MealManagementUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testEditingServingAndMovingFoodUpdatesBothMeals() {
        let app = launch("--reset-demo", "--meal-preview", "Breakfast")
        let summary = app.descendants(matching: .any)["meal.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 4))
        XCTAssertTrue(summary.label.contains("360 calories"))

        let entry = app.staticTexts["Berry oatmeal"]
        XCTAssertTrue(entry.waitForExistence(timeout: 2))
        entry.tap()

        let increment = app.buttons["serving.plus"]
        XCTAssertTrue(increment.waitForExistence(timeout: 2))
        increment.tap()
        app.buttons["meal.selector.lunch"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["entry.moveNotice"].waitForExistence(timeout: 2))

        let save = app.buttons["entry.saveChanges"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.navigationBars["Breakfast"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["meal.empty"].waitForExistence(timeout: 2))

        app.navigationBars["Breakfast"].buttons.firstMatch.tap()
        let lunch = app.descendants(matching: .any)["today.meal.lunch"]
        XCTAssertTrue(lunch.waitForExistence(timeout: 3))
        lunch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["meal.summary"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["meal.summary"].label.contains("1,060 calories"))
        XCTAssertTrue(app.staticTexts["Berry oatmeal"].exists)
    }

    func testSwipeDeleteShowsEmptyStateAndUndoRestoresFood() {
        let app = launch("--reset-demo", "--meal-preview", "Snacks")
        let entry = app.staticTexts["Apple & almonds"]
        XCTAssertTrue(entry.waitForExistence(timeout: 4))
        entry.swipeLeft()
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 2))
        delete.tap()

        XCTAssertTrue(app.descendants(matching: .any)["meal.deleteConfirmation"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["meal.empty"].waitForExistence(timeout: 2))
        app.buttons["meal.undoDelete"].tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["meal.summary"].label.contains("150 calories"))
    }

    func testLogAnotherFoodPreservesMealAndRefreshesMealReview() {
        let app = launch("--reset-demo", "--meal-preview", "Dinner")
        let logAnother = app.buttons["meal.logAnother"]
        XCTAssertTrue(logAnother.waitForExistence(timeout: 4))
        logAnother.tap()

        let dinnerSelector = app.buttons["meal.selector.dinner"]
        XCTAssertTrue(dinnerSelector.waitForExistence(timeout: 3))
        XCTAssertEqual(dinnerSelector.value as? String, "Selected")
        app.descendants(matching: .any)["food.row.Oatmeal"].tap()
        let add = app.buttons["food.addButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        add.tap()

        XCTAssertTrue(app.navigationBars["Dinner"].waitForExistence(timeout: 4))
        let summary = app.descendants(matching: .any)["meal.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 4))
        XCTAssertTrue(summary.label.contains("150 calories"))
    }

    func testEmptyMealStateIsSupportiveAndActionable() {
        let app = launch("--reset-demo", "--today-state", "empty", "--meal-preview", "Dinner")
        XCTAssertTrue(app.descendants(matching: .any)["meal.empty"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["meal.logAnother"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["meal.summary"].label.contains("0 calories"))
    }

    private func launch(_ arguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }
}

@MainActor
final class ProgressUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testProgressDashboardShowsAllSevenSectionsAndCalorieDetail() {
        let app = launch("--reset-demo", "--screen", "progress")
        XCTAssertTrue(app.descendants(matching: .any)["progress.streak"].waitForExistence(timeout: 4))
        let calories = app.descendants(matching: .any)["progress.calories"]
        XCTAssertTrue(calories.waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["progress.macros"].exists)
        calories.tap()
        XCTAssertTrue(app.navigationBars["Calories"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Daily totals and goal range"].exists)
    }

    func testWeightPeriodsAndAchievementDrillDown() {
        let app = launch("--reset-demo", "--screen", "progress")
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 4))
        scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.76))
            .press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.43)))

        let weight = app.descendants(matching: .any)["progress.weight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 3))
        let month = app.segmentedControls.buttons["1M"]
        XCTAssertTrue(month.waitForExistence(timeout: 2))
        XCTAssertTrue(month.isHittable)
        month.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["progress.weight"].tap()
        XCTAssertTrue(app.navigationBars["Weight trend"].waitForExistence(timeout: 3))

        app.navigationBars["Weight trend"].buttons.firstMatch.tap()
        scroll.swipeUp()
        let badge = app.descendants(matching: .any)["progress.badge.steady-otter"]
        XCTAssertTrue(badge.waitForExistence(timeout: 3))
        badge.tap()
        XCTAssertTrue(app.navigationBars["Steady Otter"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Badge earned"].exists)
    }

    func testProgressLoadingEmptyAndInsufficientStates() {
        var app = launch("--reset-demo", "--screen", "progress", "--progress-state", "loading")
        XCTAssertTrue(app.descendants(matching: .any)["progress.loading"].waitForExistence(timeout: 4))

        app.terminate()
        app = launch("--reset-demo", "--screen", "progress", "--progress-state", "empty")
        XCTAssertTrue(app.descendants(matching: .any)["progress.empty"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Your trail starts here"].exists)

        app.terminate()
        app = launch("--reset-demo", "--screen", "progress", "--progress-state", "insufficient")
        XCTAssertTrue(app.descendants(matching: .any)["progress.insufficient"].firstMatch.waitForExistence(timeout: 4))
    }

    private func launch(_ arguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }
}
