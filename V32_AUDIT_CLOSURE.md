# v3.2 Audit Closure

## Closed internal gaps

| Area | Closure |
|---|---|
| Reference evidence mislabeled Production | Separate execution profiles; reference releases are `ReferenceVerified` |
| Production verification/schema mismatch | Generated verification validates against the canonical schema and exact requirement set |
| Manual/self-attested production PASS | Protected validations accept only trusted-verifier evidence in production |
| No real verifier ingestion path | Trusted evidence bundles with capability + implementation checksum checks |
| Production generation impossible to register | `adopt-artifact`, including wildcard canonical outputs |
| Output contract drift | `spec/artifacts.json` is the sole output authority |
| Gate contract drift | `spec/gates.json` is the sole gate-requirement authority |
| File-existence-only phase checks | Substance, schema and registration/provenance checks |
| Arbitrary Gate A direction | Direction must exist in machine-readable generated direction set |
| Approval staleness | Revision-bound approvals plus graph-drift checks |
| Invalidation incomplete | Source + descendants stale, evidence invalidated, state rewound, downstream approval revoked |
| System statuses forgeable | Manual/evidence/system-derived validations separated |
| Non-reproducible ZIP metadata | Sorted deterministic ZIP entries with fixed timestamps/permissions |
| Hard-coded completion/governance | Completion, release status, platforms and governance checks computed from state/scope/artifacts |
| Placeholder domain fixtures | Six executable cross-domain fixture contracts |

## Remaining external proof gaps

These cannot be closed by more local generator rules alone: production Figma API integration; real browser/Playwright visual capture; Xcode/SwiftUI compilation and simulator accessibility; Android/Compose compilation and emulator accessibility; physical-device motion/haptics/refresh-rate/thermal/power tests; enterprise identity/signing for multi-user approvals; and remote immutable registry infrastructure.

v3.2 intentionally blocks Production verification when those applicable trusted verifier results are absent.
