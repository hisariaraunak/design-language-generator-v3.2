# Architecture

`spec/` is the sole workflow authority. Runtime code consumes it; docs and tests validate against it.

Runtime capabilities are organized by stable concern rather than workflow phase: intake, analysis, generation, rendering, codegen, verification, release and governance.

Generated design-system projects keep machine-owned state under `.dlg/`; human/product artifacts live outside that directory.
