import unittest
from pathlib import Path
class T(unittest.TestCase):
 def test_no_empty_templates(self):
  root=Path(__file__).resolve().parents[2]
  for p in root.glob('templates/**/*'):
   if not p.is_file(): continue
   if p.is_file(): self.assertGreater(len(p.read_bytes()),80,p.name)
if __name__=='__main__':unittest.main()
