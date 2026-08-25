import json, unittest
from pathlib import Path
class T(unittest.TestCase):
 def test_json_schemas_parse(self):
  root=Path(__file__).resolve().parents[2]
  for p in root.glob('schemas/**/*.json'): json.loads(p.read_text())
if __name__=='__main__':unittest.main()
