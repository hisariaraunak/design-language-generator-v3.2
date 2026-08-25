import json, pathlib, subprocess, sys, unittest, yaml
ROOT=pathlib.Path(__file__).resolve().parents[2]
class T(unittest.TestCase):
 def test_spec_is_single_authority(self):
  self.assertTrue((ROOT/'spec/workflow.yaml').exists())
  self.assertFalse((ROOT/'workflow.yaml').exists())
  self.assertFalse((ROOT/'generator-spec').exists())
  self.assertTrue(json.loads((ROOT/'spec/artifacts.json').read_text())['source_of_truth'])
 def test_runtime_is_src_layout(self):
  self.assertTrue((ROOT/'src/dlg/core/orchestrator.py').exists())
  self.assertIn('dlg.cli.main:main',(ROOT/'pyproject.toml').read_text())
 def test_contract_categories_exist(self):
  for d in ['schemas/project','schemas/design','schemas/evidence','schemas/release','schemas/governance']:
   self.assertTrue((ROOT/d).is_dir())
 def test_external_adapters_are_isolated(self):
  for d in ['figma','browsers','xcode','android','devices']:
   self.assertTrue((ROOT/'adapters'/d/'README.md').exists())
 def test_generated_project_control_plane(self):
  sys.path.insert(0,str(ROOT/'src')); from dlg.core import orchestrator as dlg
  import tempfile
  r=pathlib.Path(tempfile.mkdtemp()); dlg.init(r,'1.0.0','reference')
  self.assertTrue((r/'.dlg/state.json').exists()); self.assertTrue((r/'.dlg/history.jsonl').exists())
