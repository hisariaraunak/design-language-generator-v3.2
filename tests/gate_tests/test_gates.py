import unittest,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1])); from common import fresh,to_gate_a,dlg
class T(unittest.TestCase):
 def test_gate_is_specific(self):
  r=fresh();to_gate_a(r);dlg.approve(r,'gate_a','A','test');dlg.advance(r)
  with self.assertRaises(SystemExit): dlg.approve(r,'gate_b',None,'test')
 def test_gate_a_direction_required(self):
  r=fresh();to_gate_a(r)
  with self.assertRaises(SystemExit):dlg.approve(r,'gate_a',None,'test')
if __name__=='__main__':unittest.main()
