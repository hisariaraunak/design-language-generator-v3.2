import unittest,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1])); from common import fresh,to_gate_b,dlg
class T(unittest.TestCase):
 def test_downstream_invalidation(self):
  r=fresh();to_gate_b(r);dlg.invalidate(r,'tokens');s=dlg.get_state(r);self.assertIn('components-json',s['stale_artifacts']);self.assertIn('canonical-home',s['stale_artifacts'])
if __name__=='__main__':unittest.main()
