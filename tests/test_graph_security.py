import unittest,sys,tempfile
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent));from common import fresh,dlg
class T(unittest.TestCase):
 def test_path_escape_blocked(self):
  r=fresh(); outside=Path(tempfile.mkstemp()[1]); outside.write_text('x')
  with self.assertRaises(SystemExit):dlg.add_artifact(r,'x','x',str(outside))
if __name__=='__main__':unittest.main()
