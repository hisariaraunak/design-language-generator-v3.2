import hashlib,json,tempfile,unittest,sys,yaml
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; sys.path.insert(0,str(ROOT/'src')); sys.path.insert(0,str(ROOT/'tests'))
from dlg.core import orchestrator as dlg
from common import fresh,to_gate_b,full
class T(unittest.TestCase):
 def test_spec_derivations_cannot_drift(self):
  wf=yaml.safe_load((ROOT/'spec/workflow.yaml').read_text()); phases=json.loads((ROOT/'spec/phases.json').read_text()); gates=json.loads((ROOT/'spec/gates.json').read_text())
  self.assertEqual(phases['phases'],list(wf['states'].keys())); self.assertEqual(phases['derived_from'],'workflow.yaml')
  self.assertTrue(all('requires' not in wf['states'][g] for g in gates['gates']))
 def test_artifact_registry_is_output_authority(self):
  wf=yaml.safe_load((ROOT/'spec/workflow.yaml').read_text())
  self.assertTrue(all('outputs' not in c and 'enforce_outputs' not in c for c in wf['states'].values()))
  arts=json.loads((ROOT/'spec/artifacts.json').read_text())['artifacts']; self.assertGreaterEqual(len(arts),35)
 def test_all_domain_fixtures_validate(self):
  import jsonschema
  schema=json.loads((ROOT/'schemas/project/reference-fixture.schema.json').read_text())
  for d in ['minimal','fitness','fintech','ecommerce','productivity','media']:
   jsonschema.validate(json.loads((ROOT/'fixtures'/d/'fixture.json').read_text()),schema)
 def test_production_builtin_generation_is_blocked(self):
  r=Path(tempfile.mkdtemp()); dlg.init(r,'1.0.0','production')
  with self.assertRaises(SystemExit): dlg.generate_phase(r)
 def test_untrusted_evidence_bundle_rejected(self):
  r=Path(tempfile.mkdtemp()); dlg.init(r,'1.0.0','production'); (r/'x.txt').write_text('x')
  rec={'id':'x-001','requirement_id':'compile_validation','status':'pass','evidence_class':'trusted_verifier','verifier_id':'evil','test':'compile','fixture':'prod','environment':{'generator_version':dlg.VERSION},'expected':'pass','actual':'pass','artifacts':[{'path':'x.txt','sha256':dlg.sha256_file(r/'x.txt')}],'created_at':dlg.now()}
  b={'generator_version':dlg.VERSION,'adapter_id':'evil','adapter_sha256':'0'*64,'records':[rec]}; bp=r/'bundle.json'; bp.write_text(json.dumps(b))
  with self.assertRaises(SystemExit): dlg.import_evidence_bundle(r,bp)
 def test_invalidation_rewinds_and_revokes_gate_b(self):
  r=fresh(); to_gate_b(r); dlg.approve(r,'gate_b',None,'test'); dlg.advance(r)
  self.assertEqual(dlg.get_state(r)['state'],'production_verification')
  dlg.invalidate(r,'tokens')
  s=dlg.get_state(r); self.assertEqual(s['state'],'tokens'); self.assertNotIn('gate_b',s['approvals']); self.assertIn('gate_a',s['approvals']); self.assertIn('tokens',s['stale_artifacts'])
 def test_release_zip_is_reproducible_for_same_manifest(self):
  r=full(fresh()); z=r/'release/design-system-v1.0.0.zip'; h1=hashlib.sha256(z.read_bytes()).hexdigest(); dlg.package_release(r); h2=hashlib.sha256(z.read_bytes()).hexdigest(); self.assertEqual(h1,h2)
 def test_production_verification_matches_schema(self):
  r=fresh(); to_gate_b(r); dlg.approve(r,'gate_b',None,'test'); dlg.advance(r); dlg.generate_phase(r)
  pv=json.loads((r/'production-verification.json').read_text()); dlg.validate_json(pv,'production-verification.schema.json')
  self.assertEqual(set(pv['required_gate_ids']),set(dlg.WORKFLOW['production_requirements'])); self.assertEqual(set(pv['results']),set(dlg.WORKFLOW['production_requirements']))
if __name__=='__main__': unittest.main()
