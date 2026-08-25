import unittest,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1])); from common import fresh,dlg
class T(unittest.TestCase):
 def test_intake_fixture(self):
  r=fresh();dlg.generate_phase(r);self.assertTrue((r/'scope.json').exists());self.assertTrue((r/'SCOPE_CONTRACT.md').exists())
if __name__=='__main__':unittest.main()
