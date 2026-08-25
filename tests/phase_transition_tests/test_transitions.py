import unittest,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1])); from common import fresh,dlg
class T(unittest.TestCase):
 def test_cannot_advance_without_outputs(self):
  r=fresh()
  with self.assertRaises(SystemExit): dlg.advance(r)
if __name__=='__main__':unittest.main()
