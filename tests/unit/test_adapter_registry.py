import hashlib
import json
import unittest
import tempfile
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "src"))
from dlg.core import orchestrator as dlg


ROOT = Path(__file__).resolve().parents[2]


class TestAdapterRegistry(unittest.TestCase):
    def test_registered_adapter_checksums_match(self):
        registry = json.loads((ROOT / "adapters/registry.json").read_text())
        for adapter in registry["adapters"]:
            entrypoint = (ROOT / adapter["entrypoint"]).resolve()
            self.assertTrue(entrypoint.is_file())
            self.assertEqual(hashlib.sha256(entrypoint.read_bytes()).hexdigest(), adapter["sha256"])

    def test_adopted_locked_baselines_derive_system_status(self):
        root = Path(tempfile.mkdtemp()).resolve()
        dlg.init(root, "0.1.0", "production")
        state = dlg.get_state(root)
        state["state"] = "baselines"
        dlg.save_state(root, state)
        (root / "visual_baseline.json").write_text(json.dumps({
            "status": "locked",
            "references": ["direction-E"],
            "locked_signatures": {
                "palette": "semantic", "typography": "humanist", "surfaces": "cards",
                "density": "comfortable", "shape": "rounded", "iconography": "stroke",
                "data_visualization": "labeled"
            },
            "prohibited_drift": []
        }))
        (root / "interaction_baseline.json").write_text(json.dumps({
            "status": "locked", "navigation": {}, "focus_keyboard": {}, "gestures": {},
            "validation": {}, "overlays": {}, "selection": {}, "destructive_actions": {},
            "async_states": {}
        }))
        dlg.adopt_artifact(root, "visual-baseline")
        dlg.adopt_artifact(root, "interaction-baseline")
        state = dlg.get_state(root)
        self.assertEqual(dlg.status_of(state, "visual_baseline.status"), "locked")
        self.assertEqual(dlg.status_of(state, "interaction_baseline.status"), "locked")


if __name__ == "__main__":
    unittest.main()
