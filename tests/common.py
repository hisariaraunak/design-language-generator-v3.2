import sys
import importlib.util, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'src'))
from dlg.core import orchestrator as dlg
def fresh():
    r=Path(tempfile.mkdtemp()); dlg.init(r,'1.0.0','reference'); return r

def to_gate_a(r):
    for _ in range(4): dlg.generate_phase(r); dlg.advance(r)
def to_gate_b(r):
    to_gate_a(r); dlg.approve(r,'gate_a','A','test'); dlg.advance(r)
    for _ in range(7): dlg.generate_phase(r); dlg.advance(r)
def full(r):
    to_gate_b(r); dlg.approve(r,'gate_b',None,'test'); dlg.advance(r); dlg.generate_phase(r); dlg.advance(r); dlg.generate_phase(r); dlg.validate_release(r); dlg.advance(r); dlg.generate_phase(r); dlg.advance(r); return r
