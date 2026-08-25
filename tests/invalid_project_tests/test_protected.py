import unittest,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1])); from common import fresh,dlg
class T(unittest.TestCase):
 def test_protected_validation_cannot_be_set(self):
  r=fresh()
  with self.assertRaises(SystemExit):dlg.set_manual_validation(r,'compile_validation','pass')
if __name__=='__main__':unittest.main()
