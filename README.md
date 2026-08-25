# Design Language Generator v3.2.0

A spec-first, auditable design-language and design-system generation framework with strict separation between reference-fixture proof and production verification.

## Repository map

- `spec/` — authoritative generator, workflow, gate, artifact, verifier and requirement contracts.
- `schemas/` — project, design, evidence, release and governance data contracts.
- `src/dlg/` — installable runtime and stable capability namespaces.
- `adapters/` — trusted external-system boundary and adapter registry.
- `templates/` — categorized design-system output templates.
- `fixtures/` — executable cross-domain reference fixtures.
- `tests/` — contract, security, regression and Phase 0→12 reference validation.
- `docs/` — human-readable architecture/workflow guidance.

## Execution profiles

`reference` runs deterministic built-in fixtures and may create a **ReferenceVerified** release. It exists to test generator behavior and must never be represented as production verification.

`production` disables built-in reference design generation. Production artifacts must come from external tools/adapters and be registered with the project. Protected production validations require evidence from a trusted verifier adapter whose capability and implementation checksum match `adapters/registry.json`.

## Generated-project control plane

Machine-owned state lives under `.dlg/`:

- `state.json`
- `history.jsonl`
- `lock.json`
- `evidence-index.json`

Product/design-system artifacts remain outside `.dlg/`. Required outputs are defined only by `spec/artifacts.json`.

## Workflow

**Discover → Define → Build → Demonstrate → Verify → Govern**

Gate A approves one generated direction. Gate B approves the demonstrated design system. Approvals are gate-specific and revision-bound. Upstream invalidation rewinds the project, invalidates affected evidence and revokes downstream approvals.

## CLI

Install with `pip install -e . --no-build-isolation`, then use `dlg --help`.

Key commands include `init`, `approve`, `advance`, `generate-phase`, `adopt-artifact`, `import-evidence`, `verify-evidence`, `validate-graph`, `invalidate`, and `validate-release`.

## Production boundary

The package now contains the contracts and secure ingestion path required for real Figma/browser/Xcode/Android/device integrations, but those host-specific adapters still require their respective SDKs, credentials and execution environments. The generator does not fabricate those results.
