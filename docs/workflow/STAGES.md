# User-facing stages

Discover → Define → Build → Demonstrate → Verify → Govern.

Gate A separates Define and Build. Gate B separates Demonstrate and Verify. Internal states remain defined in `spec/workflow.yaml`.

In production, adopting schema-valid `visual_baseline.json` and `interaction_baseline.json` artifacts with `status: locked` derives their system-owned lock validations. Manual validation mutation remains prohibited.
