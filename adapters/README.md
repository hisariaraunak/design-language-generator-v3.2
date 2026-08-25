# Trusted Adapter Model

v3.0 removes the v2.1 arbitrary-command adapter. Production integrations are registered by adapter ID and capability. An adapter may read only declared project inputs and write only declared project outputs. Path traversal is rejected. Production adapters should run in a sandboxed CI worker with CPU, memory, network, timeout and secret scopes defined by the host.

Required integration capabilities include source ingestion (Figma/repository/app/reference images), rendering, platform compilation, snapshots, accessibility, localization/RTL, motion instrumentation, performance/device verification, asset processing, migration/codemods and registry publication.

The included reference generator is deterministic and self-contained. Host-specific integrations remain environment adapters because they require credentials, SDKs, simulators or physical devices.
