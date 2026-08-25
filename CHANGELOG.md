# Changelog

## 3.2.0

Integrity-hardening release following the v3.1 structural refactor.

- Added separate `reference` and `production` execution profiles.
- Prevented reference fixture evidence from producing a Production release label.
- Aligned `production-verification.json` with its schema and enforce exact production requirement coverage.
- Added trusted evidence-bundle ingestion with adapter registry, capability and adapter-checksum enforcement.
- Added production artifact adoption, including wildcard outputs such as canonical screens.
- Made `spec/artifacts.json` the sole required-output authority; removed output duplication from workflow states.
- Made `spec/gates.json` the sole gate-requirement authority and added drift conformance tests.
- Added artifact schema/substance/provenance validation before phase advancement.
- Added machine-readable directions and completeness outputs.
- Brought scope, visual baseline, interaction baseline, token and component reference artifacts into schema compliance.
- Bound Gate approvals to the current state revision and actual generated direction IDs.
- Added upstream invalidation rewind, Gate B revocation and evidence invalidation.
- Added immutable project lock checks and evidence index metadata.
- Separated manual, evidence-derived and system-derived validations to prevent status forgery.
- Added deterministic ZIP packaging.
- Computed release completion/status instead of hard-coding completion.
- Added final release revalidation and computed governance/registry validation.
- Derived registry platform support from project scope.
- Replaced placeholder cross-domain fixtures with executable fixture contracts for minimal, fitness, fintech, ecommerce, productivity and media archetypes.
- Expanded conformance/security/E2E coverage to 29 passing tests.

## 3.1.0

Structural refactor: `spec/` authority, installable `src/dlg/`, adapter boundary, `.dlg/` control plane, and six user-facing workflow stages.

## 3.0.0

See `V3_AUDIT_CLOSURE.md`.
