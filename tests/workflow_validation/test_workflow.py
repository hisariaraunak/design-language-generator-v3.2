import unittest, yaml
from pathlib import Path
class T(unittest.TestCase):
 def test_states_are_connected(self):
  w=yaml.safe_load((Path(__file__).resolve().parents[2]/'spec/workflow.yaml').read_text()); states=w['states']; cur=w['initial_state']; seen=[]
  while True:
   self.assertNotIn(cur,seen); seen.append(cur); cfg=states[cur]
   if cfg.get('terminal'): break
   self.assertIn(cfg['next'],states); cur=cfg['next']
  self.assertEqual(cur,'governance')
if __name__=='__main__':unittest.main()
