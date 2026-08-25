# Production Verification

## Toolchain
- Platform:
- SDK/Xcode/IDE:
- OS:
- Devices/simulators:

## Verification matrix
| Gate | Evidence | Result | Blocker |
|---|---|---|---|
| Platform compile | | PASS/FAIL/UNVERIFIED | |
| Component coverage | | PASS/FAIL/UNVERIFIED | |
| Component snapshots | | PASS/FAIL/UNVERIFIED | |
| Canonical snapshots | | PASS/FAIL/UNVERIFIED | |
| Icon implementation | | PASS/FAIL/UNVERIFIED | |
| Motion runtime | | PASS/FAIL/UNVERIFIED | |
| Accessibility runtime | | PASS/FAIL/UNVERIFIED | |
| Localization / RTL | | PASS/FAIL/UNVERIFIED | |
| Performance | | PASS/FAIL/UNVERIFIED | |
| Physical devices | | PASS/FAIL/UNVERIFIED | |
| Regression suite | | PASS/FAIL/UNVERIFIED | |
| Package audit | | PASS/FAIL/UNVERIFIED | |

## Snapshot policy
Declare deterministic device, scale, appearance, seed/input/timestamp, and pixel-diff tolerance.

## Overall
`production_verification.status={{pass|fail}}`

**Phase 10 PASS means production-ready.** Production status is prohibited unless every mandatory row is PASS with evidence. Any FAIL or UNVERIFIED mandatory row makes the overall Phase 10 status FAIL.
