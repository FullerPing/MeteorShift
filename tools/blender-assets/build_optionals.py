"""Run optional asset builders in Blender, keeping complete error logs."""
import contextlib
import importlib
import io
import json
import traceback
from pathlib import Path

ROOT=Path('Z:/final-final-actual-final/MeteorShift/blender')
MODULES=['optional_minerals','optional_heroes','optional_props']

def build(modules=None, asset_ids=None):
    results=[]
    for module_name in modules or MODULES:
        module=importlib.reload(importlib.import_module(module_name))
        for ident,builder in module.BUILDERS.items():
            if asset_ids is not None and ident not in asset_ids:continue
            capture=io.StringIO()
            try:
                with contextlib.redirect_stdout(capture):report=builder()
                results.append({'id':ident,'triangles':report['triangles'],'budget':report['budget'],'status':'exported'})
            except Exception:
                results.append({'id':ident,'status':'failed','traceback':traceback.format_exc(),'output':capture.getvalue()})
    log=ROOT/'optional-build-log.json'
    log.write_text(json.dumps(results,indent=2))
    print(json.dumps(results))
    return results
