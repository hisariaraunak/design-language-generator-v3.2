# Design Language Generator — Mandatory Project Guide

These instructions apply to every agent and every change in this repository.

## Required guidance

1. Read and follow [`SKILL.md`](SKILL.md) before planning or making changes.
2. Treat `spec/` as the sole authoritative definition of phases, gates, artifacts, verifiers, workflow, and requirements.
3. Do not duplicate specification rules in prose or implementation. Runtime behavior must consume the machine-readable specification.
4. Preserve the separation between `reference` and `production` profiles. Never present reference-fixture output as production verification.
5. Keep human intervention limited to Gate A and Gate B in the reference workflow unless the authoritative specification is intentionally changed.
6. Treat `.dlg/` as machine-owned generated-project state. Keep product and design-system artifacts outside it.
7. For production validations, require evidence from trusted adapters whose capabilities and implementation checksums match `adapters/registry.json`.

## Change discipline

- When behavior and documentation disagree, update or follow the authoritative files in `spec/`; do not work around them in prose.
- Any intentional contract change must update the relevant specification, schema, runtime behavior, tests, and documentation together.
- Preserve upstream invalidation semantics: affected evidence and downstream approvals must be invalidated when their dependencies change.
- Do not fabricate external-tool, browser, Figma, Xcode, Android, or device verification results.

## Required verification

Before considering a repository change complete, run the relevant focused tests and, when practical, the full validation suite:

```bash
python tests/run_all.py
```

Report any validation that could not be run and why.
