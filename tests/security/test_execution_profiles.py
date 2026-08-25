import json, tempfile, unittest, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; sys.path.insert(0,str(ROOT/'src'))
from dlg.core import orchestrator as dlg
class T(unittest.TestCase):
 def test_reference_cannot_be_production(self):
  sys.path.insert(0,str(ROOT/'tests')); from common import fresh, full
  r=full(fresh()); m=json.loads((r/'manifest.json').read_text()); self.assertEqual(m['release_status'],'ReferenceVerified')
 def test_production_does_not_self_attest_protected_checks(self):
  r=Path(tempfile.mkdtemp()); dlg.init(r,'1.0.0','production')
  # reference evidence is ignored for protected pass in production
  (r/'x.txt').write_text('x')
  dlg.add_evidence(r,'scope_contract_validation','pass','fake','fixture','pass','pass',['x.txt'])
  dlg.evaluate(r,True)
  self.assertEqual(dlg.status_of(dlg.get_state(r),'scope_contract_validation'),'unverified')
 def test_control_plane_lock_and_evidence_index(self):
  r=Path(tempfile.mkdtemp()); dlg.init(r,'1.0.0','production')
  self.assertTrue((r/'.dlg/lock.json').exists()); self.assertTrue((r/'.dlg/evidence-index.json').exists())
if __name__=='__main__': unittest.main()
