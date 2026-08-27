# Habitat Journey Design Language

Status: selected direction, ready for product prototyping. This is not production verification.

## Product idea

Habitat Journey is a calorie tracker where consistent nutrition habits restore a river habitat and introduce new animal friends. Nutrition is always the primary interface; the habitat is the emotional reward layer.

## Experience principles

1. **Health before game.** Calories, portions, macros, and trends must remain clear without interpreting game mechanics.
2. **Encourage, never shame.** Characters celebrate consistency and recovery. They never react negatively to food choices, weight, or missed days.
3. **Progress is visible.** Every eligible action explains the XP earned and the habitat change it supports.
4. **Characters have jobs.** Ollie the otter guides; unlocked friends add habitat stories and optional tips, not competing navigation.
5. **Illustration has boundaries.** Habitat artwork occupies at most one third of a tracking screen and may expand on dedicated habitat screens.

## Visual character

- Mood: optimistic, restorative, adventurous, calm.
- Shape language: rounded rectangles, circular progress, pill filters, soft organic scenery.
- Illustration: polished 2.5D cartoons with soft volume, simplified texture, expressive eyes, and consistent three-quarter lighting.
- Photography: not used in the core experience; food uses isolated illustrated icons.
- Typography: **Nunito Sans** for UI and numbers; **Fraunces** only for large habitat or celebration headings. System fallbacks must preserve metrics.
- Iconography: 2 px rounded stroke at 24 px, filled only for selected navigation and reward moments.

## Color roles

- Lagoon teal is the primary action and tracking color.
- Coral signals calories and active energy, never errors.
- Leaf green signals completed healthy actions and fiber.
- Sunny yellow signals XP, rewards, and carbohydrates.
- Deep navy carries text, navigation, and high-contrast surfaces.
- Red is reserved for destructive actions and validation errors.

## Mascot rules

- Ollie appears once per screen at most.
- Use full-body art in habitats and celebrations; use bust or small vignette art in tracking flows.
- Mascots never cover data, controls, charts, or safe-area content.
- Characters speak in one short sentence, with a concrete and non-judgmental message.
- Do not assign moral labels such as “good,” “bad,” “clean,” or “cheat” to foods.

## Motion

- Standard transition: 220 ms ease-out.
- Progress fill: 450 ms ease-out after confirmed data changes.
- Reward reveal: 700–900 ms, skippable, with reduced-motion fallback to a static card.
- No infinite mascot animation on tracking screens.

## Accessibility

- Target WCAG AA contrast for text and essential controls.
- Minimum touch target: 44 × 44 px.
- Never encode macro or progress state by color alone; pair color with labels and values.
- Provide descriptive text for mascot, habitat, food, and badge illustrations.
- Dynamic type must preserve logging and navigation before decorative artwork.
