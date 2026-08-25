#!/usr/bin/env python3
import json,re,sys
from pathlib import Path
import yaml
ROOT=Path(__file__).resolve().parents[1]; errors=[]; version=(ROOT/'VERSION').read_text().strip()
for name in ['README.md','SKILL.md','MODULE.md','CHANGELOG.md']:
    t=(ROOT/name).read_text()
    if version not in t: errors.append(f'{name}: missing version {version}')
for p in list((ROOT/'spec').glob('*.json'))+list((ROOT/'schemas').rglob('*.json')):
    try:d=json.loads(p.read_text())
    except Exception as e: errors.append(f'{p.name}: invalid JSON: {e}'); continue
    if p.parent.name=='spec' and d.get('version') not in (None,version): errors.append(f'{p.name}: version mismatch')
try:
    wf=yaml.safe_load((ROOT/'spec/workflow.yaml').read_text())
    if wf.get('generator_version')!=version: errors.append('workflow generator version mismatch')
    for k,cfg in wf['states'].items():
        if not cfg.get('terminal') and cfg.get('next') not in wf['states']: errors.append(f'workflow {k}: invalid next')
except Exception as e:errors.append(f'workflow invalid: {e}')
art=json.loads((ROOT/'spec/artifacts.json').read_text())
if not art.get('source_of_truth'):errors.append('artifact registry is not authoritative')
if len(art.get('artifacts',[]))<15:errors.append('artifact registry too small')
adapter=json.loads((ROOT/'schemas/governance/renderer-adapter.schema.json').read_text())
if 'command' in adapter.get('properties',{}):errors.append('unsafe command adapter remains')
for p in ROOT.glob('templates/**/*'):
    if p.is_file() and p.stat().st_size==0:errors.append(f'empty template {p.name}')
if errors:
    print('FAIL');print('\n'.join('- '+x for x in errors));sys.exit(1)
print(f'PASS Design Language Generator {version}')
