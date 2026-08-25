# Motion Playground Specification

## Motion character
Describe how motion expresses the Canonical Visual Baseline.

## Token inventory
| Token | Value | Purpose | Reduced-motion behavior |
|---|---|---|---|

## Pattern inventory
| Pattern | Trigger | From → To | Duration | Easing/spring | Choreography | Interruption | Reduced motion | Platform notes |
|---|---|---|---|---|---|---|---|---|

Required patterns:
- Screen/page transitions
- Editorial/hero entrance
- Atmospheric/background evolution
- Metric interpolation
- Chart drawing/updating
- Component enter/exit
- Press/hover/focus/selection/toggle feedback
- Navigation transitions
- Overlays/sheets/dialogs
- Loading/skeleton/progress/success/error
- State transformations

## Accessibility
Document vestibular-risk avoidance, flashing constraints, focus continuity, motion-triggering interaction safeguards, and reduced-motion equivalents.

## Exit criteria
`motion_validation=pass` only when all applicable patterns are demonstrated using production tokens/contracts and match the Canonical Visual Baseline.
