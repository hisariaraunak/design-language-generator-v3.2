import Foundation

enum MealKind: String, Codable, CaseIterable, Identifiable { case breakfast = "Breakfast", lunch = "Lunch", dinner = "Dinner", snack = "Snack"; var id: String { rawValue } }

struct MacroNutrients: Codable, Equatable {
    var protein: Double; var carbs: Double; var fat: Double; var fiber: Double
    static let zero = MacroNutrients(protein: 0, carbs: 0, fat: 0, fiber: 0)
    static func + (lhs: Self, rhs: Self) -> Self { .init(protein: lhs.protein + rhs.protein, carbs: lhs.carbs + rhs.carbs, fat: lhs.fat + rhs.fat, fiber: lhs.fiber + rhs.fiber) }
}

struct Food: Codable, Identifiable, Hashable {
    let id: UUID; var name: String; var detail: String; var emoji: String; var calories: Int; var macros: MacroNutrients
    init(id: UUID = UUID(), name: String, detail: String, emoji: String, calories: Int, macros: MacroNutrients) { self.id = id; self.name = name; self.detail = detail; self.emoji = emoji; self.calories = calories; self.macros = macros }
}

struct FoodEntry: Codable, Identifiable, Hashable { let id: UUID; let food: Food; var servings: Double; var meal: MealKind; let loggedAt: Date }
struct NutritionGoals: Codable { var calories = 2000; var protein = 120.0; var carbs = 250.0; var fat = 70.0; var fiber = 30.0 }
struct HabitatState: Codable { var xp = 620; var level = 4; var unlockedFriendIDs = ["ollie", "reed", "crabby"]; var didUnlockShelly = false }
struct WeightRecord: Codable, Identifiable { let id: UUID; let date: Date; let kilograms: Double }

struct PersistedState: Codable {
    var entries: [FoodEntry]; var goals: NutritionGoals; var habitat: HabitatState; var weights: [WeightRecord]; var streak: Int
    var waterLiters: Double?
}

extension MacroNutrients: Hashable {}
