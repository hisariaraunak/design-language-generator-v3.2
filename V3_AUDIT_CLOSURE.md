# v3.0 Audit Closure

This release addresses the five-pass v2.1 audit backlog.

| Audit gap | v3.0 closure |
|---|---|
| Thin orchestration shell | Deterministic phase execution from scope through governance |
| No production renderer | Built-in deterministic HTML reference renderer + trusted adapter capability model |
| No code generation | Web, Swift and Kotlin reference implementation generation |
| No verification engine | Evidence-derived protected validations with checksum-bound evidence |
| Manual PASS injection | Blocked for protected validations |
| Gate approvals not gate-specific | Gate/state-specific approval records |
| Plain state bypass risk | Schema-validated state, revisions and history log |
| No invalidation | DAG-based downstream stale propagation; release blocks on stale artifacts |
| Multiple output authorities | Canonical `generator-spec/artifacts.json` registry |
| Filename mismatches | Normalized output names in workflow and artifact registry |
| Placeholder self-tests | Executable schema/workflow/template/gate/fixture/generation/regression/invalid/migration/E2E suites |
| Unsafe arbitrary command adapter | Removed; trusted capability-scoped adapter schema |
| Weak release validation | SHA-256, non-empty/substance checks, evidence freshness, DAG integrity and status enforcement |
| Release before governance | Final manifest/archive regenerated after governance; external registry avoids checksum cycles |
| No reference E2E | Phase 0→12 test with Gate A/B human stops |
| Shallow governance templates | Expanded contribution, versioning, deprecation, compatibility and registry contracts |

## Host-dependent boundaries

Figma APIs, proprietary design tools, native simulators, accessibility inspectors and physical-device labs still require host credentials/SDKs. v3.0 treats these as trusted environment adapters with explicit capabilities and sandbox requirements; credentials or arbitrary shell commands are not embedded in the generator package.
