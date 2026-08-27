# Implementation Mapping

Canonical token IDs and component names are preserved in iOS, Android, and the web prototype.

| Canonical | iOS / SwiftUI | Android / Compose | Web prototype |
|---|---|---|---|
| `semantic.action.primary` | `HJColor.actionPrimary` | `HJColors.ActionPrimary` | `--action-primary` |
| `component.button.height` | `HJSize.buttonHeight` | `HJDimens.ButtonHeight` | `--button-height` |
| `Button` | `HJButton` | `HJButton` | `.hj-button` |
| `Card` | `HJCard` | `HJCard` | `.hj-card` |
| `CalorieRing` | `HJCalorieRing` | `HJCalorieRing` | `.calorie-ring` |
| `DailyQuestCard` | `HJDailyQuestCard` | `HJDailyQuestCard` | `.quest-card` |

Every mapping is traceable to `06-tokens/tokens.json` or `07-components/components.json`. Platform-native navigation and controls may diverge mechanically while preserving state, event, accessibility, and token semantics.
