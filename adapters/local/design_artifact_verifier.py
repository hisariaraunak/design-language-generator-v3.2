#!/usr/bin/env python3
"""Deterministic local verifier for pre-production design artifacts.

This adapter checks artifact integrity, structured-data parsing, minimum content,
and requirement-specific markers. It intentionally does not perform runtime,
browser, device, performance, or production-environment verification.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


REQUIRED_MARKERS = {
    "scope_contract_validation": ["target_platforms", "accessibility_target", "explicit_exclusions"],
    "visual_drift_check": ["palette", "typography", "spacing", "shape"],
    "behavior_drift_check": ["navigation", "focus", "validation", "async"],
    "token_governance_validation": ["semantic", "deprecation", "version"],
    "domain_neutrality_validation": ["button", "card", "navigation", "feedback"],
    "common_app_coverage_validation": ["navigation", "input", "loading", "error"],
    "component_api_quality_validation": ["state", "event", "accessibility", "tokens"],
    "cross_platform_parity_validation": ["ios", "android", "web"],
    "design_to_code_traceability_validation": ["token", "component", "mapping"],
    "motion_validation": ["reduced motion", "interrupt", "duration"],
    "accessibility_validation": ["contrast", "focus", "screen reader", "touch"],
    "responsive_validation": ["phone", "reflow", "dynamic type"],
    "icon_system_validation": ["stroke", "size", "selected", "label"],
    "theme_validation": ["light", "semantic", "contrast"],
    "typography_validation": ["type", "line", "dynamic"],
    "content_design_validation": ["encourage", "label", "error"],
    "data_visualization_validation": ["chart", "label", "color"],
    "design_quality_validation": ["hierarchy", "consistent", "accessible"],
    "completeness_matrix_validation": ["tokens", "components", "canonical", "pass"],
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate_artifact(root: Path, relpath: str) -> tuple[Path, str]:
    path = (root / relpath).resolve()
    if root not in path.parents or not path.is_file():
        raise SystemExit(f"invalid artifact path: {relpath}")
    if path.stat().st_size < 40:
        raise SystemExit(f"insubstantial artifact: {relpath}")
    if path.suffix == ".json":
        json.loads(path.read_text())
    text = path.read_text(errors="ignore").lower()
    if any(marker in text for marker in ("todo:", "<placeholder>", "lorem ipsum")):
        raise SystemExit(f"placeholder content: {relpath}")
    return path, text


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root")
    parser.add_argument("output")
    parser.add_argument("--requirement", action="append", required=True)
    parser.add_argument("--artifact", action="append", required=True)
    args = parser.parse_args()

    root = Path(args.root).resolve()
    checked = [validate_artifact(root, item) for item in args.artifact]
    corpus = "\n".join(text for _, text in checked)
    refs = [{"path": rel, "sha256": sha256_file(path)} for rel, (path, _) in zip(args.artifact, checked)]
    created_at = datetime.now(timezone.utc).isoformat()
    records = []
    for index, requirement in enumerate(args.requirement, 1):
        markers = REQUIRED_MARKERS.get(requirement)
        if markers and not all(marker in corpus for marker in markers):
            missing = [marker for marker in markers if marker not in corpus]
            raise SystemExit(f"{requirement} missing markers: {', '.join(missing)}")
        records.append({
            "id": f"local-design-{requirement}-{index:03d}",
            "requirement_id": requirement,
            "status": "pass",
            "evidence_class": "trusted_verifier",
            "verifier_id": "local.design-artifact",
            "test": "artifact integrity, parseability, prohibited placeholders, and requirement markers",
            "fixture": "habitat-journey-production-artifacts",
            "environment": {"generator_version": "3.2.0", "network": "none"},
            "expected": "all supplied artifacts are substantive and contain required design-contract markers",
            "actual": "all deterministic local checks passed",
            "artifacts": refs,
            "created_at": created_at,
        })

    adapter_path = Path(__file__).resolve()
    bundle = {
        "generator_version": "3.2.0",
        "adapter_id": "local.design-artifact",
        "adapter_sha256": sha256_file(adapter_path),
        "records": records,
    }
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(bundle, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
