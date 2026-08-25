# Design System Playground

Tabs/sections:
1. Foundations
2. Color
3. Typography
4. Spacing
5. Shape & Elevation
6. Icons
7. Controls
8. Navigation
9. Content
10. Feedback
11. Data Visualization
12. States
13. Accessibility
14. Responsive / platform variations
15. Motion Playground
16. Reduced Motion

Every component should render all supported variants and states from the same production token/component source.

## Motion Playground — mandatory

A static component inventory does not complete Phase 8. Demonstrate all applicable motion categories from the production token/component source:

| Pattern | Trigger | Properties | Duration token | Easing/spring | Choreography | Interruptible | Reduced-motion equivalent | Status |
|---|---|---|---|---|---|---|---|---|
| Screen/page transition | | | | | | | | |
| Editorial/hero entrance | | | | | | | | |
| Atmospheric evolution | | | | | | | | |
| Metric interpolation | | | | | | | | |
| Chart draw/update | | | | | | | | |
| Component enter/exit | | | | | | | | |
| Interaction feedback | | | | | | | | |
| Navigation transition | | | | | | | | |
| Overlay/sheet/dialog | | | | | | | | |
| Loading/progress/feedback | | | | | | | | |
| State transformation | | | | | | | | |

Phase 8 exit criteria:
- all applicable rows demonstrated
- all motion values map to tokens
- interruption behavior defined
- reduced-motion equivalents present
- accessibility constraints checked
- Canonical Visual Baseline motion drift check passes
- `motion_validation=pass`


## Mandatory domain-neutrality proof
Use at least three unrelated demo domains (for example business analytics, commerce/content, and settings/workflow). The same production core components must work unchanged across them. Source-domain-specific composites may appear only in an extension/demo section.

Phase 8 fails if source-domain content dominates the playground or if core APIs require source-domain semantics. Record `domain_neutrality_validation=pass`.

## Icon Playground
Render all core icons and validate size/state/token/RTL/accessibility/motion coverage. Block unless `icon_system_validation=pass`.



## Icon Color Contract (mandatory)
Render semantic icon roles: default, muted, active/selected, secondary contextual, success, warning, error, info, disabled, and on-accent. Validate predominantly neutral routine usage, selective semantic color, contrast, and non-color state cues. Include a prohibited rainbow/arbitrary-color example.
