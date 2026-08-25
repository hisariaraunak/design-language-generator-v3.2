import unittest, pathlib, sys
root=pathlib.Path(__file__).resolve().parent;sys.path.insert(0,str(root))
suite=unittest.defaultTestLoader.discover(str(root),pattern='test*.py')
r=unittest.TextTestRunner(verbosity=2).run(suite);raise SystemExit(0 if r.wasSuccessful() else 1)
