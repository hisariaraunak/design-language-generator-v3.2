# Canonical Screen Validation

## Screen coverage
| Screen | Archetype | Components exercised | Exceptions |
|---|---|---|---|

## Gap log
Classify each gap:
- SYSTEM_GAP
- VARIANT_GAP
- SCREEN_VIOLATION
- UX_ARCHITECTURE

## Rule
Any repeated exception across 2+ screens must be evaluated for promotion into the design system.


## Motion validation
| Screen | Transition exercised | Component motion | Loading/state motion | Reduced-motion equivalent | Baseline motion match | Result |
|---|---|---|---|---|---|---|

Canonical Screen Validation fails if representative motion cannot be built from Phase 8 motion tokens/contracts, if reduced-motion behavior is missing, or if motion character drifts from the Canonical Visual Baseline.


## Domain-neutrality validation
| Scenario/domain | Screens/archetypes | Core components exercised | API changes required? | Result |
|---|---|---|---|---|

Require at least three unrelated scenarios unless the user explicitly requested a domain-specific system. Remove all source-domain examples as a regression test: the core system must remain complete.

## Icon-system validation
`icon_system_validation={{pass|fail}}`
Core icon count: {{count}} (minimum 100)

