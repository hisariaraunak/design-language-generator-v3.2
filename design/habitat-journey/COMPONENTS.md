# Component Foundation

## Navigation

- `AppTabBar`: Today, Log, Progress, Habitat, Profile; icon plus label; exactly one selected item.
- `TopBar`: title, optional back action, one optional trailing action.
- `MealTabs`: Breakfast, Lunch, Dinner, Snack; horizontally scrollable under large text.

## Nutrition

- `CalorieRing`: consumed, remaining, goal, over-goal state, loading state.
- `MacroCard`: nutrient icon, consumed/goal values, progress bar, accessible text.
- `MealRow`: meal name, summary, calories, disclosure action.
- `FoodRow`: food illustration, name, portion, calories, add/remove action.
- `ServingStepper`: decrement, value, increment, unit selector.
- `NutritionSummary`: calories plus protein, carbohydrates, fat, and fiber.

## Habitat

- `CompanionCoachCard`: small character vignette, one-line message, optional action.
- `DailyQuestCard`: action, progress, XP value; never replaces nutrition feedback.
- `HabitatStage`: decorative environment with level and progress exposed separately as text.
- `FriendAvatar`: locked, available, selected, and newly unlocked states.
- `XPReceipt`: transient confirmation after an eligible action.
- `UnlockCelebration`: character art, name, description, continue action, skip/reduced-motion state.

## Feedback and states

- `PrimaryButton`, `SecondaryButton`, `IconButton`, `FilterChip`, `Toast`, `InlineError`, `Skeleton`, `EmptyState`.
- All destructive actions require explicit labels and confirmation when data loss is possible.
- Disabled controls must explain the missing requirement when tapped or focused.
