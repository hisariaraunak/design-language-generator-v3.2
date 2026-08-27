# Habitat Journey Scope Contract

## Product

Habitat Journey is a mobile calorie and nutrition tracker that rewards consistent logging with cosmetic habitat restoration and animal-friend stories. Nutrition data and controls remain usable when gamification is disabled.

## Initial release

- Platforms: iOS and Android.
- Form factor: portrait phone.
- Theme: light, with system accessibility adaptations.
- Locale: English (United States) with localization-ready layout and content.
- Accessibility: WCAG 2.2 AA and equivalent native-platform guidance.
- Surfaces: onboarding, Today, food logging, food details, Progress, Habitat, Profile, and required system states.

## Critical journey

`Today → Log Meal → Food Details → Add to Meal → XP Receipt → Habitat → Friend Unlock → Progress`

## Explicit exclusions for 0.1

- Clinical diagnosis, medical advice, and eating-disorder treatment.
- Wearable, health-record, restaurant-database, and social integrations.
- Tablet, desktop, web, watch, and landscape-specific layouts.
- Dark theme, multiplayer features, competitive leaderboards, and paid virtual currency.
- Production identity, analytics, payments, notification delivery, and cloud synchronization.

## Safety boundary

The reward layer cannot alter nutrition totals or recommendations. It cannot reward skipped meals, rapid weight loss, or eating below a target. Users can disable mascot, celebration, and habitat features without losing tracking functionality.
