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
        if arguments.contains("--reset-demo") { state = SeedData.state }
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
    func macros(for meal: MealKind) -> MacroNutrients { entries(for: meal).reduce(.zero) { $0 + $1.food.macros.scaled(by: $1.servings) } }
    func entries(on date: Date) -> [FoodEntry] { state.entries.filter { Calendar.current.isDate($0.loggedAt, inSameDayAs: date) } }
    var isSelectedDateToday: Bool { Calendar.current.isDateInToday(selectedDate) }
    var isSelectedDateFuture: Bool { selectedDate > Calendar.current.startOfDay(for: Date()) }
    var waterLiters: Double { state.waterLiters ?? 1.2 }
    var weightUnit: WeightUnit { state.weightUnit ?? .kilograms }
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

    @discardableResult
    func log(food: Food, servings: Double, meal: MealKind) -> Bool {
        guard servings >= 0.5, servings <= 20 else { lastError = "Choose a serving between 0.5 and 20."; return false }
        guard !isSelectedDateFuture else { lastError = "Meals cannot be logged in the future."; return false }
        let loggedAt = Calendar.current.date(
            bySettingHour: Calendar.current.component(.hour, from: Date()),
            minute: Calendar.current.component(.minute, from: Date()),
            second: 0,
            of: selectedDate
        ) ?? selectedDate
        state.entries.append(FoodEntry(id: UUID(), food: food, servings: servings, meal: meal, loggedAt: loggedAt))
        state.habitat.xp += 10
        xpReceiptTitle = "\(food.name) added"
        xpReceiptAmount = 10
        showXPReceipt = true
        persist()
        return true
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

    @discardableResult
    func updateEntry(id: UUID, servings: Double, meal: MealKind) -> Bool {
        guard servings >= 0.5, servings <= 20 else { lastError = "Choose a serving between 0.5 and 20."; return false }
        guard !isSelectedDateFuture else { lastError = "Meals cannot be edited in the future."; return false }
        guard let index = state.entries.firstIndex(where: { $0.id == id }) else { lastError = "That food entry is no longer available."; return false }
        state.entries[index].servings = servings
        state.entries[index].meal = meal
        persist()
        return true
    }

    @discardableResult
    func deleteEntry(id: UUID) -> DeletedFoodEntry? {
        guard let index = state.entries.firstIndex(where: { $0.id == id }) else { return nil }
        let deleted = DeletedFoodEntry(entry: state.entries.remove(at: index), originalIndex: index)
        persist()
        return deleted
    }

    func restore(_ deleted: DeletedFoodEntry) {
        guard !state.entries.contains(where: { $0.id == deleted.entry.id }) else { return }
        state.entries.insert(deleted.entry, at: min(deleted.originalIndex, state.entries.endIndex))
        persist()
    }

    func weightRecord(on date: Date) -> WeightRecord? {
        state.weights.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func setWeightUnit(_ unit: WeightUnit) {
        state.weightUnit = unit
        persist()
    }

    @discardableResult
    func saveWeight(kilograms: Double, on date: Date, editingID: UUID? = nil) -> Bool {
        guard kilograms.isFinite, (20...500).contains(kilograms) else {
            lastError = "Enter a weight between 20 and 500 kg."
            return false
        }
        guard Calendar.current.startOfDay(for: date) <= Calendar.current.startOfDay(for: Date()) else {
            lastError = "Weight cannot be logged in the future."
            return false
        }

        let normalizedDate = Calendar.current.startOfDay(for: date)
        let matchingDateIndex = state.weights.firstIndex { Calendar.current.isDate($0.date, inSameDayAs: normalizedDate) }
        let editingIndex = editingID.flatMap { id in state.weights.firstIndex { $0.id == id } }
        let recordID = editingID ?? matchingDateIndex.map { state.weights[$0].id } ?? UUID()
        let replacement = WeightRecord(id: recordID, date: normalizedDate, kilograms: kilograms)

        if let editingIndex {
            state.weights[editingIndex] = replacement
            state.weights.removeAll { $0.id != recordID && Calendar.current.isDate($0.date, inSameDayAs: normalizedDate) }
        } else if let matchingDateIndex {
            state.weights[matchingDateIndex] = replacement
        } else {
            state.weights.append(replacement)
        }
        state.weights.sort { $0.date > $1.date }
        persist()
        return true
    }

    @discardableResult
    func deleteWeight(id: UUID) -> DeletedWeightRecord? {
        guard let index = state.weights.firstIndex(where: { $0.id == id }) else { return nil }
        let deleted = DeletedWeightRecord(record: state.weights.remove(at: index), originalIndex: index)
        persist()
        return deleted
    }

    func restoreWeight(_ deleted: DeletedWeightRecord) {
        guard !state.weights.contains(where: { $0.id == deleted.record.id }) else { return }
        state.weights.removeAll { Calendar.current.isDate($0.date, inSameDayAs: deleted.record.date) }
        state.weights.insert(deleted.record, at: min(deleted.originalIndex, state.weights.endIndex))
        persist()
    }

    func resetDemo() { state = SeedData.state; persist() }
    private func persist() { do { try persistence.save(state) } catch { lastError = "Your changes could not be saved." } }
}

struct DeletedFoodEntry: Equatable {
    let entry: FoodEntry
    let originalIndex: Int
}

struct DeletedWeightRecord: Equatable {
    let record: WeightRecord
    let originalIndex: Int
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
        var entries = [
            FoodEntry(id: UUID(), food: breakfastFood, servings: 1, meal: .breakfast, loggedAt: now),
            FoodEntry(id: UUID(), food: lunchFood, servings: 1, meal: .lunch, loggedAt: now),
            FoodEntry(id: UUID(), food: snackFood, servings: 1, meal: .snack, loggedAt: now)
        ]
        let historicalCalories = [1_710, 1_820, 1_560, 1_680, 1_740, 1_620]
        for (offset, calories) in historicalCalories.enumerated() {
            let food = Food(
                name: "Daily nutrition",
                detail: "Logged meals",
                emoji: "🍽️",
                calories: calories,
                macros: .init(protein: Double(calories) * 0.075, carbs: Double(calories) * 0.115, fat: Double(calories) * 0.033, fiber: Double(calories) * 0.016)
            )
            entries.append(FoodEntry(id: UUID(), food: food, servings: 1, meal: .dinner, loggedAt: calendar.date(byAdding: .day, value: -(offset + 1), to: now) ?? now))
        }
        let weightDays = Array(0...6) + Array(stride(from: 7, through: 84, by: 7))
        let weights = weightDays.enumerated().map { index, daysAgo in
            let kilograms = 70.4 + Double(daysAgo) * 0.025 + sin(Double(index) * 0.7) * 0.12
            return WeightRecord(id: UUID(), date: calendar.date(byAdding: .day, value: -daysAgo, to: now)!, kilograms: kilograms)
        }
        return PersistedState(entries: entries, goals: NutritionGoals(), habitat: HabitatState(), weights: weights, streak: 7, waterLiters: 1.2, weightUnit: .kilograms)
    }
}
