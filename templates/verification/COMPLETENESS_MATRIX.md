# Design Language Completeness Matrix

Every applicable row must be assessed as PASS, PARTIAL, N/A, or FAIL. Critical FAIL blocks Gate B. PARTIAL must carry an owner/resolution note before finalization.

## Foundations
- Visual philosophy and principles [critical]
- Domain neutrality [critical]
- Color primitives and semantic colors [critical]
- Typography hierarchy and mechanics [critical]
- Spacing, radius, borders, elevation, opacity [critical]
- Grid: columns, gutters, margins, max-widths [critical]
- Density modes
- Layout primitives and responsive breakpoints [critical]
- Z-index/layering [critical]
- Theming strategy; light theme if applicable

## Components and interaction
- Actions, forms, selection, navigation, menus [critical]
- Cards/content, lists/collections, tables [critical]
- Search/filtering, disclosure, overlays [critical]
- Feedback/loading/empty/error [critical]
- Messaging, notifications, files, calendar, commerce, account, onboarding as applicable
- Universal state matrix [critical]
- Keyboard interaction [critical]
- Pointer/hover/touch strategy
- Drag/drop and reorder if applicable
- Scroll/sticky/overflow behavior [critical]
- Mobile safe areas, keyboard avoidance, gestures
- Desktop split/resizable patterns if applicable

## Iconography and media
- 100+ semantic icon library [critical]
- Icon size/stroke/color/accessibility/RTL/motion contracts [critical]
- Photography language
- Image treatment: ratios, crop, focal point, loading/fallback
- Illustration language if applicable
- Brand/logo treatment if applicable

## Data visualization
- Core chart primitives [critical if data product]
- Scales, axes, legends, thresholds, multi-series grammar
- Annotation and interaction
- Accessible non-color differentiation [critical if data product]

## Content, accessibility, localization
- Content/writing language: voice, labels, capitalization, CTA, error copy
- Focus, contrast, touch targets [critical]
- Screen-reader semantics [critical]
- High contrast / forced colors [critical]
- Reduced motion [critical]
- Localization: expansion, RTL layout, dates, numbers, currency [critical]

## Responsive/adaptive
- Component transformations by breakpoint [critical]
- Adaptive navigation [critical]
- Cross-platform mapping

## Motion
- Motion tokens, component/state/editorial motion [critical]
- Motion Playground and reduced-motion equivalents [critical]

## Governance and QA
- Token naming and component API governance [critical]
- Anti-drift rules [critical]
- Versioning/changelog
- Deprecation lifecycle
- Contribution/change process
- Design QA and visual-regression acceptance [critical]
- Design/code parity and synchronization rules [critical]

## Required output
- Overall PASS only when no applicable critical FAIL remains.
- Record totals for PASS / PARTIAL / N/A / FAIL.
- `completeness_matrix_validation=pass` is mandatory before Gate B.
