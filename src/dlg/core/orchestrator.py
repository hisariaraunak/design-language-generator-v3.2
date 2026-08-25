#!/usr/bin/env python3
"""Design Language Generator v3.2 reference execution engine.

v3.2 preserves the v3 execution semantics while separating authoritative specs from runtime capabilities. v3.0 turned the playbook into a deterministic, auditable pipeline. Human intervention
is limited to Gate A and Gate B. Protected validations are computed from evidence.
"""
from __future__ import annotations
import argparse, hashlib, json, os, shutil, sys, zipfile
from datetime import datetime, timezone
from pathlib import Path
import yaml, jsonschema

ROOT = Path(__file__).resolve().parents[3]
VERSION = (ROOT/'VERSION').read_text().strip()
WORKFLOW = yaml.safe_load((ROOT/'spec'/'workflow.yaml').read_text())
PROTECTED = set(WORKFLOW.get('protected_validations', []))
SYSTEM_DERIVED = {'visual_baseline.status','interaction_baseline.status','production_verification.completed','production_verification.status','release_packaging.completed','governance_validation','registry_updated'}


def now(): return datetime.now(timezone.utc).isoformat()
def load(p): return json.loads(Path(p).read_text())
ARTIFACT_SPEC = None
def dump(p,d):
    p=Path(p); p.parent.mkdir(parents=True,exist_ok=True); p.write_text(json.dumps(d,indent=2,sort_keys=True)+'\n')
def sha256_file(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''): h.update(b)
    return h.hexdigest()
def project(root): return Path(root).resolve()
def state_path(root): return project(root)/'.dlg/state.json'
def history_path(root): return project(root)/'.dlg/history.jsonl'
def append_history(root,event,detail):
    p=history_path(root); p.parent.mkdir(parents=True,exist_ok=True)
    with p.open('a') as f: f.write(json.dumps({'at':now(),'event':event,'detail':detail},sort_keys=True)+'\n')
def schema_path(name):
    matches=list((ROOT/'schemas').rglob(name))
    if len(matches)!=1: raise RuntimeError(f'Schema resolution for {name}: {len(matches)} matches')
    return matches[0]
def validate_json(data, schema_name): jsonschema.validate(data, load(schema_path(schema_name)))
def artifact_spec(): return load(ROOT/'spec'/'artifacts.json')
def verifier_spec(): return load(ROOT/'spec'/'verifiers.json')
def gates_spec(): return load(ROOT/'spec'/'gates.json')
def get_state(root):
    r=project(root); s=load(state_path(r)); validate_json(s,'project-state.schema.json')
    lp=r/'.dlg/lock.json'
    if lp.exists():
        lock=load(lp); validate_json(lock,'project-lock.schema.json')
        if lock!={'generator_version':s['generator_version'],'design_system_version':s['design_system_version'],'execution_profile':s['execution_profile']}: raise SystemExit('PROJECT LOCK MISMATCH')
    return s

def init(root, ds_version, profile="production"):
    r=project(root); r.mkdir(parents=True,exist_ok=True)
    dirs=['00-scope','01-visual-dna','02-interview','03-directions','04-baselines','05-design-language','06-tokens','07-components','08-implementation/web','08-implementation/swiftui','08-implementation/compose','09-playground/components','09-playground/icons','09-playground/motion','09-playground/responsive','09-playground/accessibility','10-canonical-validation/canonical-screens','10-canonical-validation/reference-snapshots','11-production-verification/evidence','12-governance','release','.dlg']
    for d in dirs:(r/d).mkdir(parents=True,exist_ok=True)
    s={'generator_version':VERSION,'design_system_version':ds_version,'execution_profile':profile,'state':WORKFLOW['initial_state'],'validations':{},'approvals':{},'artifacts':{},'stale_artifacts':[],'scope':{},'revision':0,'created_at':now(),'updated_at':now()}
    dump(state_path(r),s); dump(r/'artifact-graph.json',{'version':VERSION,'nodes':[],'edges':[]}); dump(r/'evidence.json',{'version':VERSION,'generator_version':VERSION,'records':[]})
    dump(r/'.dlg/lock.json',{'generator_version':VERSION,'design_system_version':ds_version,'execution_profile':profile}); dump(r/'.dlg/evidence-index.json',{'generator_version':VERSION,'records':[]})
    (r/'VERSION').write_text(ds_version+'\n'); append_history(r,'init',{'design_system_version':ds_version,'execution_profile':profile}); print(r)

def save_state(r,s,event=None,detail=None):
    s['updated_at']=now(); s['revision']=int(s.get('revision',0))+1; validate_json(s,'project-state.schema.json'); dump(state_path(r),s)
    if event: append_history(r,event,detail or {})

def approve(root,gate,direction=None,approver='human'):
    if gate not in ('gate_a','gate_b'): raise SystemExit('Unknown gate')
    r=project(root); s=get_state(r)
    if s['state']!=gate: raise SystemExit(f'APPROVAL BLOCKED: current state is {s["state"]}, not {gate}')
    a={'status':'approved','gate':gate,'approver':approver,'at':now(),'state_revision':s['revision']+1}
    if gate=='gate_a':
        if not direction: raise SystemExit('Gate A requires --direction')
        dp=r/'03-directions/directions.json'
        if not dp.exists(): raise SystemExit('Gate A requires generated directions.json')
        valid={x['id'] for x in load(dp).get('directions',[])}
        if direction not in valid: raise SystemExit(f'Unknown direction {direction}; choose one of {sorted(valid)}')
        a['direction']=direction
    s['approvals'][gate]=a; save_state(r,s,'approval',a); print(f'{gate} approved')

def add_artifact(r, artifact_id, kind, relpath, deps=None, producer='dlg.reference'):
    p=(r/relpath).resolve()
    if r not in p.parents and p!=r: raise SystemExit('Artifact path escapes project root')
    if not p.exists(): raise SystemExit(f'Artifact missing: {relpath}')
    checksum=sha256_file(p) if p.is_file() else None
    s=get_state(r); s['artifacts'][artifact_id]={'id':artifact_id,'kind':kind,'path':relpath,'sha256':checksum,'status':'current','phase':s['state'],'producer':producer,'generated_at':now()}
    s['stale_artifacts']=[x for x in s['stale_artifacts'] if x!=artifact_id]; save_state(r,s,'artifact',{'id':artifact_id,'path':relpath})
    if artifact_id not in {'manifest','release-archive','registry'}:
        g=load(r/'artifact-graph.json'); g['nodes']=[n for n in g['nodes'] if n['id']!=artifact_id]; g['nodes'].append({'id':artifact_id,'kind':kind,'path':relpath,'sha256':checksum,'phase':s['state'],'producer':producer})
        for dep in deps or []:
            known={n['id'] for n in g['nodes']}
            if dep not in known:
                if dep in s['artifacts']: continue
                raise SystemExit(f'Unknown dependency: {dep}')
            edge={'from':dep,'to':artifact_id,'relation':'derives'}
            if edge not in g['edges']: g['edges'].append(edge)
        dump(r/'artifact-graph.json',g)

def adopt_artifact(root, artifact_id, producer='external', relpath=None):
    import fnmatch
    r=project(root); s=get_state(r); matches=[a for a in artifact_spec()['artifacts'] if a['id']==artifact_id]
    if len(matches)!=1: raise SystemExit(f'Unknown or ambiguous artifact spec id: {artifact_id}')
    a=matches[0]
    if a['phase']!=s['state']: raise SystemExit(f'Artifact {artifact_id} belongs to {a["phase"]}, current state is {s["state"]}')
    target=a['path']
    reg_id=artifact_id
    if '*' in target:
        if not relpath: raise SystemExit('Wildcard artifact adoption requires --path')
        rp=str(Path(relpath).as_posix())
        if not fnmatch.fnmatch(rp,target): raise SystemExit(f'Path {rp} does not match artifact pattern {target}')
        target=rp; reg_id=f'{artifact_id}:{Path(rp).stem}'
        concrete=a.copy(); concrete['path']=target; concrete.pop('min_count',None)
        errs=artifact_contract_errors_unregistered_ok(r,concrete)
    else:
        if relpath and str(Path(relpath).as_posix())!=target: raise SystemExit(f'Artifact {artifact_id} path is fixed at {target}')
        errs=artifact_contract_errors_unregistered_ok(r,a)
    if errs: raise SystemExit('ADOPT BLOCKED: '+'; '.join(errs))
    add_artifact(r,reg_id,'external',target,producer=producer); print(f'ADOPTED {reg_id}')

def artifact_contract_errors_unregistered_ok(r,a):
    rel=a['path']; paths=list(r.glob(rel)) if '*' in rel else ([r/rel] if (r/rel).exists() else [])
    if not paths: return ['missing '+rel]
    errs=[]
    for fp in paths:
        if not fp.is_file(): errs.append('not-file '+str(fp.relative_to(r))); continue
        if fp.stat().st_size<a.get('min_bytes',1): errs.append('insubstantial '+str(fp.relative_to(r)))
        if a.get('schema'):
            try: validate_json(load(fp),a['schema'])
            except Exception as e: errs.append(f'schema {rel}: {e.__class__.__name__}')
    return errs

def state_order():
    order=[]; cur=WORKFLOW['initial_state']; seen=set()
    while cur not in seen:
        seen.add(cur); order.append(cur); cfg=WORKFLOW['states'][cur]
        if cfg.get('terminal'): break
        cur=cfg['next']
    return order

def invalidate(root, artifact_id):
    r=project(root); g=load(r/'artifact-graph.json'); s=get_state(r); adj={}
    for e in g['edges']: adj.setdefault(e['from'],set()).add(e['to'])
    known={n['id'] for n in g['nodes']}
    if artifact_id not in known: raise SystemExit(f'Unknown artifact: {artifact_id}')
    stale={artifact_id}; stack=[artifact_id]
    while stack:
        x=stack.pop()
        for y in adj.get(x,set()):
            if y not in stale: stale.add(y); stack.append(y)
    stale_paths=set()
    phase_by_id={}
    for n in g['nodes']:
        if n['id'] in stale:
            stale_paths.add(n['path']); phase_by_id[n['id']]=n.get('phase')
    for x in stale:
        if x in s['artifacts']: s['artifacts'][x]['status']='stale'
    s['stale_artifacts']=sorted(set(s['stale_artifacts'])|stale)
    ev=load(r/'evidence.json'); invalid_reqs=set()
    for rec in ev.get('records',[]):
        if any(a.get('path') in stale_paths for a in rec.get('artifacts',[])) and not rec.get('invalidated_at'):
            rec['invalidated_at']=now(); rec['invalidated_reason']=f'artifact:{artifact_id}'; invalid_reqs.add(rec['requirement_id'])
    dump(r/'evidence.json',ev)
    for k in invalid_reqs: s['validations'].pop(k,None)
    order=state_order(); idx={x:i for i,x in enumerate(order)}
    phases=[p for p in phase_by_id.values() if p in idx]
    rewind=min(phases,key=lambda x:idx[x]) if phases else s['state']
    if idx.get(rewind,999) <= idx.get('directions',999):
        s['approvals'].pop('gate_a',None); s['approvals'].pop('gate_b',None)
    elif idx.get(rewind,999) <= idx.get('canonical_validation',999):
        s['approvals'].pop('gate_b',None)
    if idx.get(s['state'],0) > idx.get(rewind,0): s['state']=rewind
    save_state(r,s,'invalidate',{'source':artifact_id,'stale':sorted(stale),'rewind_to':s['state'],'invalidated_requirements':sorted(invalid_reqs)})
    print(json.dumps({'stale':sorted(stale),'state':s['state']},indent=2))

def add_evidence(r, requirement_id, status, test, fixture, expected, actual, artifact_paths, environment=None, evidence_class='reference_fixture', verifier_id='dlg.reference'):
    if status not in ('pass','fail','unverified','not_applicable'): raise ValueError(status)
    refs=[]
    for rel in artifact_paths:
        p=(r/rel).resolve()
        if r not in p.parents and p!=r: raise SystemExit('Evidence path escapes project')
        if not p.exists(): raise SystemExit(f'Evidence artifact missing: {rel}')
        
        if not p.is_file(): raise SystemExit(f'Evidence artifacts must be files: {rel}')
        refs.append({'path':rel,'sha256':sha256_file(p)})
    rec={'id':f'{requirement_id}-{len(load(r/"evidence.json")["records"])+1:04d}','requirement_id':requirement_id,'status':status,'evidence_class':evidence_class,'verifier_id':verifier_id,'test':test,'fixture':fixture,'environment':environment or {'generator_version':VERSION,'python':sys.version.split()[0]},'expected':expected,'actual':actual,'artifacts':refs,'created_at':now()}
    validate_json(rec,'evidence.schema.json'); e=load(r/'evidence.json'); e['records'].append(rec); dump(r/'evidence.json',e)
    idx=load(r/'.dlg/evidence-index.json'); idx['records'].append({'id':rec['id'],'requirement_id':requirement_id,'status':status,'evidence_class':evidence_class,'verifier_id':verifier_id}); dump(r/'.dlg/evidence-index.json',idx); return rec

def evaluate(root, quiet=False):
    r=project(root); s=get_state(r); e=load(r/'evidence.json'); groups={}
    for rec in e.get('records',[]):
        if not rec.get('invalidated_at'): groups.setdefault(rec['requirement_id'],[]).append(rec)
    for req in PROTECTED:
        records=groups.get(req,[])
        if not records: continue
        eligible=records if s['execution_profile']=='reference' else [x for x in records if x.get('evidence_class')=='trusted_verifier']
        if not eligible:
            value='unverified'
            evidence_ids=[]
        else:
            statuses={x['status'] for x in eligible}
            value='pass' if statuses=={'pass'} else ('not_applicable' if statuses=={'not_applicable'} else ('unverified' if statuses=={'unverified'} else 'fail'))
            evidence_ids=[x['id'] for x in eligible]
        s['validations'][req]={'status':value,'derived':True,'evidence_ids':evidence_ids,'evaluated_at':now()}
    save_state(r,s,'evaluate',{'protected_evaluated':len([k for k in s['validations'] if k in PROTECTED])});
    if not quiet: print(json.dumps(s['validations'],indent=2))

def set_internal_validation(root,key,value):
    r=project(root); s=get_state(r); s['validations'][key]={'status':value,'derived':True,'evidence_ids':[],'evaluated_at':now()}; save_state(r,s,'system_validation',{'key':key,'status':value})

def set_manual_validation(root,key,value):
    if key in PROTECTED or key in SYSTEM_DERIVED: raise SystemExit(f'VALIDATION BLOCKED: {key} is system/evidence-derived')
    r=project(root); s=get_state(r); s['validations'][key]={'status':value,'derived':False,'evaluated_at':now()}; save_state(r,s,'manual_validation',{'key':key,'status':value})

def status_of(s,key):
    v=s['validations'].get(key); return v.get('status') if isinstance(v,dict) else v

def resolve(expr,s,current_state):
    if expr=='approval.status=approved':
        a=s['approvals'].get(current_state,{})
        return a.get('status')=='approved' and a.get('state_revision')==s['revision']
    if expr=='approval.direction': return bool(s['approvals'].get(current_state,{}).get('direction'))
    k,v=expr.split('=',1) if '=' in expr else (expr,'true')
    return status_of(s,k)==v

def artifact_contract_errors(r,state_name):
    errs=[]
    for a in artifact_spec()['artifacts']:
        if a.get('phase')!=state_name or not a.get('required',False): continue
        rel=a['path']; paths=list(r.glob(rel)) if '*' in rel else ([r/rel] if (r/rel).exists() else [])
        if not paths:
            errs.append('missing '+rel); continue
        if len(paths)<a.get('min_count',1): errs.append(f'count {rel}: {len(paths)} < {a.get("min_count",1)}')
        state=get_state(r); registered={v.get('path') for v in state['artifacts'].values() if v.get('status')=='current'}
        for fp in paths:
            rp=str(fp.relative_to(r))
            if rp not in registered: errs.append('unregistered '+rp)
            if not fp.is_file(): errs.append('not-file '+str(fp.relative_to(r))); continue
            if fp.stat().st_size<a.get('min_bytes',1): errs.append('insubstantial '+str(fp.relative_to(r)))
            if fp.suffix.lower() in ('.md','.html') and any(x in fp.read_text(errors='ignore').lower() for x in ('todo:','<placeholder>','lorem ipsum')): errs.append('placeholder '+str(fp.relative_to(r)))
            if a.get('schema'):
                try: validate_json(load(fp),a['schema'])
                except Exception as e: errs.append(f'schema {rel}: {e.__class__.__name__}')
    return errs

def check_outputs(r,state_name): return artifact_contract_errors(r,state_name)

def requirements_for_state(name,cfg):
    if name in gates_spec().get('gates',{}):
        reqs=[]
        for x in gates_spec()['gates'][name].get('requires',[]):
            if x.startswith('current_state=') or x=='no_stale_artifacts': continue
            reqs.append(x)
        return reqs
    return cfg.get('requires',[])

def advance(root):
    r=project(root); s=get_state(r); name=s['state']; cfg=WORKFLOW['states'][name]
    missing_req=[x for x in requirements_for_state(name,cfg) if not resolve(x,s,name)]
    missing_out=check_outputs(r,name)
    if name in ('gate_a','gate_b','production_verification','release_packaging','governance'):
        try: validate_graph(r)
        except SystemExit as e: missing_out.append(str(e).splitlines()[0])
    stale=[x for x in s['stale_artifacts'] if s['artifacts'].get(x,{}).get('status')=='stale']
    if missing_req or missing_out or (name in ('gate_b','production_verification','release_packaging','governance') and stale):
        parts=[]
        if missing_req:parts.append('requirements='+', '.join(missing_req))
        if missing_out:parts.append('outputs='+', '.join(missing_out))
        if stale:parts.append('stale='+', '.join(stale))
        raise SystemExit('BLOCKED '+name+': '+'; '.join(parts))
    if cfg.get('terminal'): print('TERMINAL '+name); return
    old=name; s['state']=cfg['next']; save_state(r,s,'advance',{'from':old,'to':s['state']}); print(s['state'])

def render_html(title, body):
    return f'<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{title}</title><style>:root{{--space:16px;--radius:16px;font-family:system-ui}}body{{margin:0;padding:32px;max-width:1100px}}.card{{border:1px solid currentColor;border-radius:var(--radius);padding:var(--space);margin:var(--space) 0}}button,input{{font:inherit;padding:10px 14px}}:focus-visible{{outline:3px solid currentColor;outline-offset:3px}}@media(max-width:600px){{body{{padding:16px}}}}</style><body><main><h1>{title}</h1>{body}</main></body></html>'

def write_text(r,rel,text,artifact_id,kind,deps=None):
    p=r/rel; p.parent.mkdir(parents=True,exist_ok=True); p.write_text(text); add_artifact(r,artifact_id,kind,rel,deps)

def generate_phase(root):
    r=project(root); s=get_state(r); st=s['state']
    # Built-in generation is a deterministic reference fixture only. Production must use trusted adapters/artifacts.
    if s['execution_profile']=='production' and st not in ('production_verification','release_packaging','governance'):
        raise SystemExit(f'PRODUCTION ADAPTER REQUIRED for {st}; built-in reference generator cannot self-attest production work')
    if st=='intake_scope':
        write_text(r,'SCOPE_CONTRACT.md','# Scope Contract\n\nPlatforms: Web, SwiftUI, Compose\nAccessibility: WCAG 2.2 AA / platform equivalent\nLocales: en, ar\nThemes: light, dark, high-contrast\n','#scope','scope')
        dump(r/'scope.json',{'target_platforms':['web','swiftui','compose'],'form_factors':['phone','tablet','desktop'],'themes':['light','dark','high_contrast'],'accessibility_target':'WCAG 2.2 AA','locales':['en','ar'],'support_matrix':{'web':'current-2','ios':'current-2','android':'current-2'},'device_tiers':['baseline','high'],'product_surfaces':['app'],'explicit_exclusions':[]}); add_artifact(r,'scope-json','scope','scope.json',['#scope'])
        set_manual_validation(r,'source_input.available','true'); add_evidence(r,'scope_contract_validation','pass','scope schema','reference','valid scope','valid scope',['scope.json']); evaluate(r, True)
    elif st=='visual_dna':
        write_text(r,'VISUAL_DNA.md','# Visual DNA\n\n## Layout\nResponsive grid.\n## Typography\nSystem-first scale.\n## Color\nSemantic roles.\n## Motion\nPurposeful and reducible.\n','visual-dna','design',['scope-json']); dump(r/'screen_inventory.json',{'screens':['home','detail','settings']}); add_artifact(r,'screen-inventory','inventory','screen_inventory.json',['scope-json'])
    elif st=='interview':
        write_text(r,'DESIGN_DECISIONS.md','# Design Decisions\n\nDensity: comfortable. Personality: precise. Motion: restrained.\n','decisions','decision',['visual-dna']); dump(r/'project_state.json',{'density':'comfortable','personality':'precise','motion':'restrained'}); add_artifact(r,'project-state','decision','project_state.json',['visual-dna'])
    elif st=='directions':
        body=''.join(f'<section class="card"><h2>Direction {x}</h2><p>Materially distinct hierarchy, rhythm and surface treatment.</p><button>Primary action</button></section>' for x in 'ABC')
        write_text(r,'DIRECTIONS.md','# Directions\n\nA — Editorial precision\n\nB — Dense utility\n\nC — Calm spatial\n','directions-doc','direction',['decisions']); dump(r/'03-directions/directions.json',{'directions':[{'id':'A','name':'Editorial precision','summary':'Editorial hierarchy and restrained surfaces.'},{'id':'B','name':'Dense utility','summary':'Compact information-rich utility.'},{'id':'C','name':'Calm spatial','summary':'Generous spacing and calm surfaces.'}]}); add_artifact(r,'directions-json','direction','03-directions/directions.json',['directions-doc']); write_text(r,'03-directions/directions.html',render_html('Three Design Directions',body),'directions-render','render',['directions-doc'])
    elif st=='baselines':
        for rel,title,aid in [('VISUAL_BASELINE.md','Visual Baseline','visual-baseline'),('INTERACTION_BASELINE.md','Interaction Baseline','interaction-baseline')]: write_text(r,rel,f'# {title}\n\nLocked after Gate A.\n',aid,'baseline',['directions-render'])
        dump(r/'visual_baseline.json',{'status':'locked','direction':s['approvals']['gate_a']['direction'],'baseline_id':'visual-v1','references':['03-directions/directions.html'],'locked_signatures':{'palette':'semantic','typography':'system-scale','surfaces':'outlined','density':'comfortable','shape':'rounded','iconography':'stroke','data_visualization':'semantic'},'prohibited_drift':['raw color','unmapped typography','unapproved shape'],'drift_check_dimensions':['palette','typography','spacing','shape']}); add_artifact(r,'visual-baseline-json','baseline','visual_baseline.json',['visual-baseline'])
        dump(r/'interaction_baseline.json',{'status':'locked','baseline_id':'interaction-v1','navigation':{'model':'platform-native'},'focus_keyboard':{'focus_visible':True},'gestures':{'alternatives_required':True},'validation':{'inline_errors':True},'overlays':{'focus_trap':True},'selection':{'explicit':True},'destructive_actions':{'confirmation':'risk-based'},'async_states':{'loading_error_empty':True}}); add_artifact(r,'interaction-baseline-json','baseline','interaction_baseline.json',['interaction-baseline'])
        set_internal_validation(r,'visual_baseline.status','locked'); set_internal_validation(r,'interaction_baseline.status','locked')
    elif st=='language':
        write_text(r,'DESIGN_LANGUAGE.md','# Design Language\n\n## Principles\nClarity, hierarchy, consistency, responsiveness, accessibility.\n## Grammar\nSemantic color, 4pt spatial rhythm, stateful motion and explicit interaction contracts.\n','design-language','language',['visual-baseline-json','interaction-baseline-json']);
        for k in ('visual_drift_check','behavior_drift_check'): add_evidence(r,k,'pass',k,'reference','no drift','no drift',['DESIGN_LANGUAGE.md'])
        evaluate(r, True)
    elif st=='tokens':
        tokens={'version':'1.0.0','primitive':{'space':{'1':4,'2':8,'4':16},'radius':{'m':12,'l':16}},'semantic':{'surface':'canvas','text':'primary','action':'accent'},'component':{'button':{'radius':'{primitive.radius.m}','padding':'{primitive.space.2}'}},'themes':['light','dark','high_contrast']}
        dump(r/'06-tokens/tokens.json',tokens); add_artifact(r,'tokens','tokens','06-tokens/tokens.json',['design-language']); write_text(r,'TOKEN_GOVERNANCE.md','# Token Governance\n\nNaming, aliases, themes, overrides, deprecation, migration and semantic-version rules are mandatory.\n','token-governance','governance',['tokens']); add_evidence(r,'token_governance_validation','pass','token governance','reference','governed tokens','governed tokens',['06-tokens/tokens.json','TOKEN_GOVERNANCE.md']); evaluate(r, True)
    elif st=='components':
        comps={'components':[{'name':'button','category':'control','purpose':'Trigger an action','anatomy':['label','icon'],'variants':['primary','secondary'],'states':['default','hover','focus','pressed','disabled','loading'],'tokens':{'radius':'component.button.radius'},'accessibility':['keyboard operable','visible focus']},{'name':'text-field','category':'control','purpose':'Collect text input','anatomy':['label','input','helper'],'variants':['default'],'states':['default','focus','error','disabled'],'tokens':{'space':'primitive.space.2'},'accessibility':['programmatic label','error association']},{'name':'card','category':'content','purpose':'Group related content','anatomy':['header','body','footer'],'variants':['static','interactive'],'states':['default','interactive'],'tokens':{'radius':'primitive.radius.l'},'accessibility':['semantic grouping']},{'name':'dialog','category':'feedback','purpose':'Present blocking information or decisions','anatomy':['title','body','actions'],'variants':['modal'],'states':['open'],'tokens':{'surface':'semantic.surface'},'accessibility':['focus management','escape dismissal']}] }
        dump(r/'07-components/components.json',comps); add_artifact(r,'components-json','component','07-components/components.json',['tokens']); write_text(r,'COMPONENTS.md','# Components\n\nDomain-neutral primitives, controls, navigation, overlays, feedback, data display and composition patterns.\n','components-doc','component',['components-json']); write_text(r,'COMPONENT_API.md','# Component API\n\nAPIs must be composable, slot-based where appropriate, explicit about state ownership and consistent in event semantics.\n','component-api','component',['components-json']);
        for k in ('domain_neutrality_validation','common_app_coverage_validation','component_api_quality_validation'): add_evidence(r,k,'pass',k,'reference','pass','pass',['07-components/components.json'])
        evaluate(r, True)
    elif st=='implementation':
        write_text(r,'IMPLEMENTATION_MAPPING.md','# Implementation Mapping\n\nToken and component IDs are stable across Web, SwiftUI and Compose. Platform-native divergence must be declared.\n','implementation-map','implementation',['components-json'])
        write_text(r,'08-implementation/web/components.html',render_html('Component Reference','<button>Button</button><label class="card">Label <input aria-label="Example input"></label><section class="card"><h2>Card</h2><p>Content</p></section>'),'web-implementation','implementation',['components-json'])
        write_text(r,'08-implementation/swiftui/Components.swift','import SwiftUI\nstruct DSButton: View { let label:String; var body: some View { Button(label) {} } }\n','swiftui-implementation','implementation',['components-json'])
        write_text(r,'08-implementation/compose/Components.kt','@Composable fun DSButton(label: String, onClick: () -> Unit) { Button(onClick = onClick) { Text(label) } }\n','compose-implementation','implementation',['components-json'])
        write_text(r,'CROSS_PLATFORM_PARITY.md','# Cross-Platform Parity\n\nMust-match: semantic tokens and states. Platform-native: navigation mechanics. Allowed divergence requires rationale and tolerance.\n','parity-doc','implementation',['web-implementation','swiftui-implementation','compose-implementation'])
        for k in ('cross_platform_parity_validation','design_to_code_traceability_validation'): add_evidence(r,k,'pass',k,'reference','pass','pass',['IMPLEMENTATION_MAPPING.md','CROSS_PLATFORM_PARITY.md'])
        evaluate(r, True)
    elif st=='playground':
        body='<section class="card"><button>Default</button> <button disabled>Disabled</button></section><section class="card"><label>Email <input type="email" aria-describedby="help"></label><p id="help">Helper</p></section>'
        write_text(r,'09-playground/components/index.html',render_html('Component Playground',body),'playground','render',['web-implementation']); write_text(r,'PLAYGROUND_SPEC.md','# Playground Specification\n\nCovers states, themes, responsive layouts, accessibility, content stress and app archetypes.\n','playground-spec','spec',['playground']); write_text(r,'MOTION_PLAYGROUND_SPEC.md','# Motion Playground\n\nTransitions support reduced motion, interruption and deterministic fixtures.\n','motion-spec','spec',['playground']); write_text(r,'RESPONSIVE_VALIDATION.md','# Responsive Validation\n\nPhone, tablet, desktop, orientation and container resize.\n','responsive-doc','validation',['playground'])
        for k in ['motion_validation','domain_neutrality_validation','common_app_coverage_validation','accessibility_validation','responsive_validation','icon_system_validation','theme_validation','typography_validation','content_design_validation','data_visualization_validation']:
            add_evidence(r,k,'pass',k,'reference','pass','pass',['09-playground/components/index.html']);
        evaluate(r, True)
    elif st=='canonical_validation':
        for i,name in enumerate(['home','detail','settings','search','empty','error'],1):
            rel=f'10-canonical-validation/canonical-screens/{i:02d}-{name}.html'; write_text(r,rel,render_html(name.title(),f'<section class="card"><h2>{name.title()}</h2><p>Canonical screen built only from approved tokens and components.</p><button>Action</button></section>'),f'canonical-{name}','canonical',['playground'])
        write_text(r,'VALIDATION.md','# Validation\n\nCanonical screens preserve the approved visual and interaction baselines.\n','validation-doc','validation',['canonical-home']); write_text(r,'COMPLETENESS_MATRIX.md','# Completeness Matrix\n\nAll mandatory design-language and design-system categories: PASS.\n','completeness','validation',['validation-doc']); dump(r/'10-canonical-validation/completeness-matrix.json',{'items':[{'area':'tokens','status':'PASS','critical':True},{'area':'components','status':'PASS','critical':True},{'area':'canonical_screens','status':'PASS','critical':True},{'area':'accessibility','status':'PASS','critical':True}],'validation':'pass'}); add_artifact(r,'completeness-json','validation','10-canonical-validation/completeness-matrix.json',['completeness']); dump(r/'gap_log.json',{'critical':[],'major':[],'minor':[]}); add_artifact(r,'gap-log','validation','gap_log.json',['completeness'])
        for k in ['visual_drift_check','behavior_drift_check','motion_validation','domain_neutrality_validation','common_app_coverage_validation','accessibility_validation','responsive_validation','icon_system_validation','theme_validation','typography_validation','content_design_validation','data_visualization_validation','design_quality_validation','completeness_matrix_validation']:
            add_evidence(r,k,'pass',k,'reference','pass','pass',['COMPLETENESS_MATRIX.md']);
        evaluate(r, True)
    elif st=='production_verification':
        tests=WORKFLOW['production_requirements']
        if s['execution_profile']=='reference':
            for k in tests:
                add_evidence(r,k,'pass',k,'reference-fixture','pass','pass',['09-playground/components/index.html','10-canonical-validation/canonical-screens/01-home.html'], evidence_class='reference_fixture', verifier_id='dlg.reference')
        evaluate(r, True); add_artifact(r,'evidence','evidence','evidence.json',['completeness']); s=get_state(r)
        results={k:(status_of(s,k) or 'unverified') for k in tests}
        overall='pass' if all(v in ('pass','not_applicable') for v in results.values()) else ('unverified' if any(v=='unverified' for v in results.values()) else 'fail')
        pv={'generator_version':VERSION,'execution_profile':s['execution_profile'],'status':overall,'required_gate_ids':tests,'results':results,'evidence_file':'evidence.json','generated_at':now()}
        validate_json(pv,'production-verification.schema.json'); dump(r/'production-verification.json',pv); add_artifact(r,'production-verification-json','verification','production-verification.json',['completeness']); write_text(r,'PRODUCTION_VERIFICATION.md','# Production Verification\n\nProfile: **'+s['execution_profile']+'**. All applicable mandatory checks must be evidence-backed. Overall: **'+overall.upper()+'**.\n','production-verification-doc','verification',['production-verification-json'])
        set_internal_validation(r,'production_verification.completed','true'); set_internal_validation(r,'production_verification.status',overall)
    elif st=='release_packaging':
        validate_graph(r); verify_evidence(r)
        write_text(r,'DECISION_LOG.md','# Decision Log\n\nGate A and Gate B approvals are recorded in `.dlg/state.json` and `.dlg/history.jsonl`.\n','decision-log','release',['production-verification-json']); write_text(r,'RELEASE_MANIFEST.md','# Release Manifest\n\nImmutable release content, checksums and provenance are represented in `manifest.json`.\n','release-manifest-doc','release',['decision-log'])
        manifest=build_manifest(r); dump(r/'manifest.json',manifest); add_artifact(r,'manifest','release','manifest.json',['release-manifest-doc']); package_release(r); set_internal_validation(r,'release_packaging.completed','true')
    elif st=='governance':
        scope=load(r/'scope.json'); platforms=scope['target_platforms']; rows=''.join(f'| {x} | Supported |\n' for x in platforms)
        write_text(r,'GOVERNANCE.md','# Governance\n\nSemantic versioning, RFCs, ownership, deprecation, migrations, adoption telemetry, rollback and immutable releases are required.\n','governance-doc','governance',['manifest']); write_text(r,'CONTRIBUTING.md','# Contributing\n\nChanges require owner review, evidence regeneration and affected downstream artifacts to be revalidated.\n','contributing','governance',['governance-doc']); write_text(r,'COMPATIBILITY_MATRIX.md','# Compatibility Matrix\n\n| Platform | Status |\n|---|---|\n'+rows,'compatibility','governance',['governance-doc']); write_text(r,'VERSIONING.md','# Versioning\n\nSemVer. Breaking component/token changes require a major version. Additions require minor; fixes patch.\n','versioning','governance',['governance-doc']); write_text(r,'DEPRECATIONS.md','# Deprecations\n\nDeprecations require replacement, deprecated-in version, removal version and measured usage count.\n','deprecations','governance',['governance-doc']);
        final_manifest=build_manifest(r, governed=True); dump(r/'manifest.json',final_manifest); add_artifact(r,'manifest','release','manifest.json',['governance-doc']); package_release(r); validate_release(r)
        archive=r/'release'/f'design-system-v{s["design_system_version"]}.zip'
        reg={'current_version':s['design_system_version'],'generator_version':VERSION,'releases':[{'version':s['design_system_version'],'manifest_sha256':sha256_file(r/'manifest.json'),'archive_sha256':sha256_file(archive),'released_at':now(),'status':load(r/'manifest.json')['release_status'],'supported_platforms':platforms,'superseded_by':None}]}; dump(r/'DESIGN_SYSTEM_REGISTRY.json',reg); add_artifact(r,'registry','registry','DESIGN_SYSTEM_REGISTRY.json',['manifest']); validate_governance(r); set_internal_validation(r,'governance_validation','pass'); set_internal_validation(r,'registry_updated','true')
    else: raise SystemExit(f'No generator for state {st}; gates require human approval')
    print(f'GENERATED {st}')

def import_evidence_bundle(root, bundle_path):
    r=project(root); bundle=load(bundle_path); validate_json(bundle,'evidence-bundle.schema.json')
    registry=load(ROOT/'adapters'/'registry.json'); validate_json(registry,'adapter-registry.schema.json'); adapters={a['id']:a for a in registry.get('adapters',[])}
    aid=bundle['adapter_id']; adapter=adapters.get(aid)
    if not adapter: raise SystemExit(f'UNTRUSTED ADAPTER: {aid}')
    ep=(ROOT/adapter['entrypoint']).resolve()
    if ROOT not in ep.parents or not ep.is_file(): raise SystemExit('Trusted adapter entrypoint missing/outside generator root')
    actual_hash=sha256_file(ep)
    if actual_hash!=bundle['adapter_sha256'] or actual_hash!=adapter.get('sha256'): raise SystemExit('ADAPTER CHECKSUM MISMATCH')
    cap=adapter['capability']; reqcaps=verifier_spec()['requirements']; e=load(r/'evidence.json'); idx=load(r/'.dlg/evidence-index.json')
    for rec in bundle['records']:
        if rec.get('evidence_class')!='trusted_verifier' or rec.get('verifier_id')!=aid: raise SystemExit('Bundle records must be trusted_verifier evidence from adapter_id')
        required_cap=reqcaps.get(rec['requirement_id'])
        if required_cap and required_cap!=cap: raise SystemExit(f'CAPABILITY MISMATCH {rec["requirement_id"]}: requires {required_cap}, adapter is {cap}')
        validate_json(rec,'evidence.schema.json')
        for a in rec['artifacts']:
            fp=(r/a['path']).resolve()
            if r not in fp.parents or not fp.is_file() or sha256_file(fp)!=a['sha256']: raise SystemExit(f'BUNDLE ARTIFACT INVALID: {a["path"]}')
        e['records'].append(rec); idx['records'].append({'id':rec['id'],'requirement_id':rec['requirement_id'],'status':rec['status'],'evidence_class':rec['evidence_class'],'verifier_id':aid})
    dump(r/'evidence.json',e); dump(r/'.dlg/evidence-index.json',idx); evaluate(r,True); print(f'IMPORTED {len(bundle["records"])} evidence records from {aid}')

def verify_evidence(root):
    r=project(root); data=load(r/'evidence.json'); errs=[]
    for i,rec in enumerate(data.get('records',[])):
        try: validate_json(rec,'evidence.schema.json')
        except Exception as e: errs.append(f'record {i}: {e}')
        if rec.get('invalidated_at'): continue
        for a in rec.get('artifacts',[]):
            p=r/a['path']
            if not p.exists(): errs.append(f'missing evidence artifact {a["path"]}')
            elif a.get('sha256') and sha256_file(p)!=a['sha256']: errs.append(f'stale evidence artifact {a["path"]}')
    if errs: raise SystemExit('EVIDENCE FAIL\n'+'\n'.join(errs))
    print(f'EVIDENCE PASS {len(data.get("records",[]))} records')

def validate_graph(root):
    r=project(root); g=load(r/'artifact-graph.json'); validate_json(g,'artifact-graph.schema.json'); ids=[n['id'] for n in g['nodes']]
    if len(ids)!=len(set(ids)): raise SystemExit('GRAPH FAIL duplicate node IDs')
    known=set(ids)
    for n in g['nodes']:
        p=r/n['path']
        if not p.exists(): raise SystemExit(f'GRAPH FAIL missing node path {n["path"]}')
        if n.get('sha256') and p.is_file() and sha256_file(p)!=n['sha256']: raise SystemExit(f'GRAPH FAIL checksum drift {n["id"]}')
    for e in g['edges']:
        if e['from'] not in known or e['to'] not in known: raise SystemExit('GRAPH FAIL dangling edge')
    adj={x:set() for x in known}
    for e in g['edges']: adj[e['from']].add(e['to'])
    visiting=set(); visited=set()
    def dfs(x):
        if x in visiting: raise SystemExit('GRAPH FAIL cycle')
        if x in visited:return
        visiting.add(x)
        for y in adj[x]:dfs(y)
        visiting.remove(x);visited.add(x)
    for x in known:dfs(x)
    print(f'GRAPH PASS {len(known)} nodes')

def validate_governance(root):
    r=project(root); s=get_state(r); errs=[]
    import re
    if not re.fullmatch(r'\d+\.\d+\.\d+',s['design_system_version']): errs.append('invalid semver')
    man=load(r/'manifest.json'); validate_json(man,'release-manifest.schema.json')
    reg=load(r/'DESIGN_SYSTEM_REGISTRY.json'); validate_json(reg,'design-system-registry.schema.json')
    if reg['current_version']!=s['design_system_version']: errs.append('registry current_version mismatch')
    if reg['releases'][-1]['manifest_sha256']!=sha256_file(r/'manifest.json'): errs.append('registry manifest checksum mismatch')
    archive=r/'release'/f'design-system-v{s["design_system_version"]}.zip'
    if reg['releases'][-1]['archive_sha256']!=sha256_file(archive): errs.append('registry archive checksum mismatch')
    scope=load(r/'scope.json')
    if sorted(reg['releases'][-1]['supported_platforms'])!=sorted(scope['target_platforms']): errs.append('registry platforms mismatch scope')
    if errs: raise SystemExit('GOVERNANCE FAIL\n'+'\n'.join(errs))
    print('GOVERNANCE PASS')

def build_manifest(r, governed=False):
    s=get_state(r); files=[]
    for p in sorted(x for x in r.rglob('*') if x.is_file() and '.dlg' not in x.parts and x.name not in ('manifest.json','DESIGN_SYSTEM_REGISTRY.json') and not x.name.endswith('.zip')):
        files.append({'path':str(p.relative_to(r)),'sha256':sha256_file(p),'bytes':p.stat().st_size})
    design_language='pass' if s['approvals'].get('gate_a',{}).get('status')=='approved' and s['artifacts'].get('design-language',{}).get('status')=='current' else 'fail'
    design_system='pass' if s['approvals'].get('gate_b',{}).get('status')=='approved' and status_of(s,'completeness_matrix_validation')=='pass' else 'fail'
    pv=status_of(s,'production_verification.status')
    prod_completion='pass' if s['execution_profile']=='production' and pv=='pass' else ('reference_pass' if s['execution_profile']=='reference' and pv=='pass' else 'fail')
    release_status=('Production' if prod_completion=='pass' else ('ReferenceVerified' if prod_completion=='reference_pass' else 'ReleaseCandidate'))
    return {'schema_version':VERSION,'generator_version':VERSION,'design_system_version':s['design_system_version'],'execution_profile':s['execution_profile'],'release_status':release_status,'completion':{'design_language':design_language,'design_system':design_system,'production_verified':prod_completion,'governed_release':'pass' if governed else 'pending'},'files':files,'approvals':s['approvals'],'created_at':now()}

def package_release(r):
    s=get_state(r); out=r/'release'/f'design-system-v{s["design_system_version"]}.zip'; out.parent.mkdir(parents=True,exist_ok=True)
    files=sorted(x for x in r.rglob('*') if x.is_file() and '.dlg' not in x.parts and x.name!='DESIGN_SYSTEM_REGISTRY.json' and x!=out and not (x.parent==out.parent and x.suffix=='.zip'))
    with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for fp in files:
            zi=zipfile.ZipInfo(str(fp.relative_to(r)).replace('\\','/'),date_time=(1980,1,1,0,0,0)); zi.compress_type=zipfile.ZIP_DEFLATED; zi.external_attr=(0o644 & 0xFFFF)<<16
            z.writestr(zi,fp.read_bytes())
    add_artifact(r,'release-archive','release',str(out.relative_to(r)),['manifest']); print(out)

def validate_release(root):
    r=project(root); verify_evidence(r); validate_graph(r); man=load(r/'manifest.json'); validate_json(man,'release-manifest.schema.json')
    pv=load(r/'production-verification.json'); validate_json(pv,'production-verification.schema.json')
    errs=[]
    expected=set(WORKFLOW['production_requirements'])
    if set(pv['required_gate_ids'])!=expected: errs.append('production verification required_gate_ids mismatch workflow')
    if set(pv['results'])!=expected: errs.append('production verification result keys mismatch workflow')
    for f in man['files']:
        p=r/f['path']
        if not p.exists(): errs.append('missing '+f['path'])
        elif p.stat().st_size==0: errs.append('empty '+f['path'])
        elif p.suffix.lower() in ('.md','.html','.json') and p.stat().st_size < 40: errs.append('insubstantial '+f['path'])
        elif p.suffix.lower() in ('.md','.html') and any(x in p.read_text(errors='ignore').lower() for x in ('todo:','<placeholder>','lorem ipsum')): errs.append('placeholder '+f['path'])
        elif sha256_file(p)!=f['sha256']: errs.append('checksum '+f['path'])
    s=get_state(r)
    if man['release_status']=='Production' and (s['execution_profile']!='production' or status_of(s,'production_verification.status')!='pass'): errs.append('Production requires production profile + trusted verified pass')
    if man['release_status']=='ReferenceVerified' and s['execution_profile']!='reference': errs.append('ReferenceVerified requires reference profile')
    if s['stale_artifacts']: errs.append('stale artifacts present')
    if errs: raise SystemExit('RELEASE BLOCKED\n'+'\n'.join(errs))
    print('RELEASE PASS')

def main():
    ap=argparse.ArgumentParser(); sp=ap.add_subparsers(dest='cmd',required=True)
    x=sp.add_parser('init');x.add_argument('root');x.add_argument('--design-system-version',default='1.0.0');x.add_argument('--profile',choices=['reference','production'],default='production')
    x=sp.add_parser('status');x.add_argument('root')
    x=sp.add_parser('approve');x.add_argument('root');x.add_argument('gate',choices=['gate_a','gate_b']);x.add_argument('--direction');x.add_argument('--approver',default='human')
    x=sp.add_parser('advance');x.add_argument('root')
    x=sp.add_parser('generate-phase');x.add_argument('root')
    x=sp.add_parser('evaluate');x.add_argument('root')
    x=sp.add_parser('set-validation');x.add_argument('root');x.add_argument('key');x.add_argument('value')
    x=sp.add_parser('verify-evidence');x.add_argument('root')
    x=sp.add_parser('import-evidence');x.add_argument('root');x.add_argument('bundle')
    x=sp.add_parser('validate-graph');x.add_argument('root')
    x=sp.add_parser('invalidate');x.add_argument('root');x.add_argument('artifact_id')
    x=sp.add_parser('adopt-artifact');x.add_argument('root');x.add_argument('artifact_id');x.add_argument('--producer',default='external');x.add_argument('--path')
    x=sp.add_parser('validate-release');x.add_argument('root')
    a=ap.parse_args()
    if a.cmd=='init':init(a.root,a.design_system_version,a.profile)
    elif a.cmd=='status':print(json.dumps(get_state(a.root),indent=2))
    elif a.cmd=='approve':approve(a.root,a.gate,a.direction,a.approver)
    elif a.cmd=='advance':advance(a.root)
    elif a.cmd=='generate-phase':generate_phase(a.root)
    elif a.cmd=='evaluate':evaluate(a.root)
    elif a.cmd=='set-validation':set_manual_validation(a.root,a.key,a.value)
    elif a.cmd=='verify-evidence':verify_evidence(a.root)
    elif a.cmd=='import-evidence':import_evidence_bundle(a.root,a.bundle)
    elif a.cmd=='validate-graph':validate_graph(a.root)
    elif a.cmd=='invalidate':invalidate(a.root,a.artifact_id)
    elif a.cmd=='adopt-artifact':adopt_artifact(a.root,a.artifact_id,a.producer,a.path)
    elif a.cmd=='validate-release':validate_release(a.root)
if __name__=='__main__':main()
