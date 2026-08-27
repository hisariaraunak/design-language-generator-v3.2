import Foundation
import Observation

@MainActor @Observable
final class AppStore {
    private(set) var state: PersistedState
    var selectedMeal: MealKind = .breakfast
    var pendingFood: Food?
    var showXPReceipt = false
    var xpReceiptTitle = "Meal updated"
    var xpReceiptAmount = 10
    var showUnlock = false
    var lastError: String?
    var selectedDate = Calendar.current.startOfDay(for: Date())
    var isOffline = false
    var isRefreshing = false
    private let persistence: PersistenceService

    init(persistence: PersistenceService = .live) {
        self.persistence = persistence
        self.state = persistence.load() ?? SeedData.state
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--today-state"), arguments.indices.contains(index + 1) {
            switch arguments[index + 1] {
            case "empty": state.entries.removeAll { Calendar.current.isDateInToday($0.loggedAt) }
            case "over":
                let food = Food(name: "Celebration feast", detail: "1 serving", emoji: "🍲", calories: 1_250, macros: .init(protein: 34, carbs: 130, fat: 55, fiber: 8))
                state.entries.append(FoodEntry(id: UUID(), food: food, servings: 1, meal: .dinner, loggedAt: Date()))
            case "complete": state.waterLiters = 2
            case "water": state.waterLiters = 1.2
            case "offline": isOffline = true
            case "past": selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            case "future": selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            default: break
            }
        }
        #endif
    }

    var todayEntries: [FoodEntry] { entries(on: selectedDate) }
    var consumedCalories: Int { todayEntries.reduce(0) { $0 + Int(Double($1.food.calories) * $1.servings) } }
    var calorieBalance: Int { state.goals.calories - consumedCalories }
    var caloriesRemaining: Int { max(0, state.goals.calories - consumedCalories) }
    var consumedMacros: MacroNutrients { todayEntries.reduce(.zero) { total, entry in total + entry.food.macros.scaled(by: entry.servings) } }

    func entries(for meal: MealKind) -> [FoodEntry] { todayEntries.filter { $0.meal == meal } }
    func calories(for meal: MealKind) -> Int { entries(for: meal).reduce(0) { $0 + Int(Double($1.food.calories) * $1.servings) } }
    func entries(on date: Date) -> [FoodEntry] { state.entries.filter { Calendar.current.isDate($0.loggedAt, inSameDayAs: date) } }
    var isSelectedDateToday: Bool { Calendar.current.isDateInToday(selectedDate) }
    var isSelectedDateFuture: Bool { selectedDate > Calendar.current.startOfDay(for: Date()) }
    var waterLiters: Double { state.waterLiters ?? 1.2 }
    var questProgress: Double { min(1, waterLiters / 2) }
    var isQuestComplete: Bool { waterLiters >= 2 }

    func moveSelectedDate(by days: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectedDate = date
    }

    func addWater() {
        guard isSelectedDateToday, !isQuestComplete else { return }
        state.waterLiters = min(2, waterLiters + 0.2)
        if isQuestComplete {
            state.habitat.xp += 25
            xpReceiptTitle = "Hydration quest complete"
            xpReceiptAmount = 25
            showXPReceipt = true
        }
        persist()
    }

    func removeWater() {
        guard isSelectedDateToday, waterLiters > 0 else { return }
        let wasComplete = isQuestComplete
        state.waterLiters = max(0, waterLiters - 0.2)
        if wasComplete {
            state.habitat.xp = max(0, state.habitat.xp - 25)
            showXPReceipt = false
        }
        persist()
    }

    func refreshToday() async {
        isRefreshing = true
        try? await Task.sleep(for: .milliseconds(550))
        isRefreshing = false
    }

    func log(food: Food, servings: Double, meal: MealKind) {
        guard servings > 0, servings <= 20 else { lastError = "Choose a serving between 0 and 20."; return }
        guard !isSelectedDateFuture else { lastError = "Meals cannot be logged in the future."; return }
        let loggedAt = Calendar.current.date(
            bySettingHour: Calendar.current.component(.hour, from: Date()),
            minute: Calendar.current.component(.minute, from: Date()),
            second: 0,
            of: selectedDate
        ) ?? selectedDate
        state.entries.append(FoodEntry(id: UUID(), food: food, servings: servings, meal: meal, loggedAt: loggedAt))
        state.habitat.xp += 10
        xpReceiptTitle = "\(meal.rawValue) updated"
        xpReceiptAmount = 10
        showXPReceipt = true
        persist()
    }

    func dismissXPReceipt() { showXPReceipt = false }

    func unlockShelly() {
        guard !state.habitat.didUnlockShelly else { return }
        state.habitat.didUnlockShelly = true
        state.habitat.unlockedFriendIDs.append("shelly")
        showUnlock = true
        persist()
    }

    func deleteEntries(at offsets: IndexSet, meal: MealKind) {
        let targets = offsets.map { entries(for: meal)[$0].id }
        state.entries.removeAll { targets.contains($0.id) }
        persist()
    }

    func resetDemo() { state = SeedData.state; persist() }
    private func persist() { do { try persistence.save(state) } catch { lastError = "Your changes could not be saved." } }
}

extension MacroNutrients { func scaled(by factor: Double) -> Self { .init(protein: protein * factor, carbs: carbs * factor, fat: fat * factor, fiber: fiber * factor) } }

struct PersistenceService {
    var load: () -> PersistedState?
    var save: (PersistedState) throws -> Void
    @MainActor static let live = Self(load: {
        guard let data = UserDefaults.standard.data(forKey: "habitatJourney.state.v1") else { return nil }
        return try? JSONDecoder().decode(PersistedState.self, from: data)
    }, save: { state in
        let data = try JSONEncoder().encode(state)
        UserDefaults.standard.set(data, forKey: "habitatJourney.state.v1")
    })
}

enum SeedData {
    static let foods = [
        Food(name: "Greek yogurt", detail: "170 g", emoji: "🥛", calories: 100, macros: .init(protein: 17, carbs: 6, fat: 0, fiber: 0)),
        Food(name: "Blueberries", detail: "½ cup", emoji: "🫐", calories: 42, macros: .init(protein: 0.5, carbs: 11, fat: 0.2, fiber: 1.8)),
        Food(name: "Oatmeal", detail: "½ cup dry (40 g)", emoji: "🥣", calories: 150, macros: .init(protein: 5, carbs: 27, fat: 3, fiber: 4)),
        Food(name: "Banana", detail: "1 medium", emoji: "🍌", calories: 105, macros: .init(protein: 1.3, carbs: 27, fat: 0.4, fiber: 3.1)),
        Food(name: "Almonds", detail: "1 oz (23 g)", emoji: "🥜", calories: 160, macros: .init(protein: 6, carbs: 6, fat: 14, fiber: 3.5))
    ]
    static var state: PersistedState {
        let calendar = Calendar.current; let now = Date()
        let breakfastFood = Food(name: "Berry oatmeal", detail: "1 bowl", emoji: "🥣", calories: 360, macros: .init(protein: 18, carbs: 56, fat: 9, fiber: 8))
        let lunchFood = Food(name: "Power bowl", detail: "1 bowl", emoji: "🥗", calories: 520, macros: .init(protein: 32, carbs: 60, fat: 17, fiber: 9))
        let snackFood = Food(name: "Apple & almonds", detail: "1 serving", emoji: "🍎", calories: 150, macros: .init(protein: 4, carbs: 18, fat: 8, fiber: 4))
        return PersistedState(entries: [
            FoodEntry(id: UUID(), food: breakfastFood, servings: 1, meal: .breakfast, loggedAt: now),
            FoodEntry(id: UUID(), food: lunchFood, servings: 1, meal: .lunch, loggedAt: now),
            FoodEntry(id: UUID(), food: snackFood, servings: 1, meal: .snack, loggedAt: now)
        ], goals: NutritionGoals(), habitat: HabitatState(), weights: (0..<7).map { i in WeightRecord(id: UUID(), date: calendar.date(byAdding: .day, value: -i, to: now)!, kilograms: 70.4 + Double(i) * 0.18) }, streak: 7, waterLiters: 1.2)
    }
}
