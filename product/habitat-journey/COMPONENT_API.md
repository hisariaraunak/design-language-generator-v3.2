# Component API

## Contract rules

- State is explicit and externally owned unless a component is purely presentational.
- Events use action-oriented names such as `onAddFood`, `onChangeServing`, and `onDismiss`.
- Required data has no silent fallback; loading, empty, error, disabled, and offline states are modeled.
- Components consume approved tokens and expose no raw color or spacing overrides.
- Accessibility label, value, hint, role, and selected/expanded state are part of the API contract.
- Slots are used for optional leading icon, trailing action, illustration, and supporting content.

## Example contracts

`CalorieRing(consumed, goal, unit, state, accessibilityLabel)`

`FoodRow(food, portion, calories, action, onAction)`

`DailyQuestCard(title, progress, target, xp, state, onOpen)`

`UnlockCelebration(friend, reducedMotion, onContinue, onDismiss)`

Event handlers fire once per confirmed user action. Disabled components expose a reason. Destructive events require confirmation at the owning pattern level.
