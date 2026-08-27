# Token Governance

Version: 0.1.0.

- Product code consumes semantic or component aliases, never raw primitive values.
- Token names describe roles rather than current appearance.
- Every new token needs a documented consumer and light-theme value.
- A token change includes visual-drift review for palette, typography, spacing, shape, and data visualization.
- Deprecation requires a replacement token, deprecated-in version, removal version, and migration note.
- Breaking removals require a major design-system version; additive tokens require a minor version; compatible corrections require a patch.
- Platform mappings may use native names but must preserve the canonical token ID in implementation mapping.
- Contrast is rechecked whenever text, action, chart, or state colors change.
