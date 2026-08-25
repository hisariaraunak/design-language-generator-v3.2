import unittest,re
class T(unittest.TestCase):
 def test_semver_examples(self):
  p=re.compile(r'^\d+\.\d+\.\d+$');self.assertRegex('3.0.0',p);self.assertNotRegex('3.0',p)
if __name__=='__main__':unittest.main()
