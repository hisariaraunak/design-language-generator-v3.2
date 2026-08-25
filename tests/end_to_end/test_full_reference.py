import unittest,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1])); from common import fresh,full,dlg
class T(unittest.TestCase):
 def test_phase_0_to_12(self):
  r=full(fresh());self.assertEqual(dlg.get_state(r)['state'],'governance');self.assertTrue((r/'release/design-system-v1.0.0.zip').exists());self.assertTrue((r/'DESIGN_SYSTEM_REGISTRY.json').exists())
if __name__=='__main__':unittest.main()
