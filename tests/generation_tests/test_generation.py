import unittest,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1])); from common import fresh,to_gate_b
class T(unittest.TestCase):
 def test_canonical_screens_exist(self):
  r=fresh();to_gate_b(r);self.assertGreaterEqual(len(list((r/'10-canonical-validation/canonical-screens').glob('*.html'))),5)
if __name__=='__main__':unittest.main()
