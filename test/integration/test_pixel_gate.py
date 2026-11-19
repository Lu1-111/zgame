"""真实负例：修改临时规格/透明边时像素门禁必须失败，不改动正式素材或数值。"""
from pathlib import Path
import contextlib
import io
import json
import sys
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/qa'))
import validate_pixel_assets


def main():
    work=ROOT/'work/qa/pixel_gate_negative'
    work.mkdir(parents=True,exist_ok=True)
    original=json.loads((ROOT/'data/art/forest_v002.json').read_text(encoding='utf8'))
    original['assets']={'rock_field':original['assets']['rock_field']}
    spec=json.loads((ROOT/original['pixel_spec'][6:]).read_text(encoding='utf8'))
    original['pixel_spec']='res://work/qa/pixel_gate_negative/spec.json'
    results=[]
    for case in ['valid','wrong_canvas','upscaled_runtime','33_color_limit','soft_alpha','unregistered_converter']:
        cfg=json.loads(json.dumps(original));settings=json.loads(json.dumps(spec))
        if case=='wrong_canvas':cfg['assets']['rock_field']['native_canvas'][0]-=1
        if case=='upscaled_runtime':cfg['assets']['rock_field']['runtime_scale']=[2,2]
        if case=='33_color_limit':settings['max_colors']=33
        if case=='soft_alpha':
            image=Image.open(ROOT/cfg['assets']['rock_field']['path'][6:]).convert('RGBA')
            rgba=list(image.getpixel((0,0)));rgba[3]=128;image.putpixel((0,0),tuple(rgba))
            image.save(work/'soft.png');cfg['assets']['rock_field']['path']='res://work/qa/pixel_gate_negative/soft.png'
        if case=='unregistered_converter':
            report=json.loads((ROOT/spec['conversion_report'][6:]).read_text(encoding='utf8'))
            report['tool']='imagegen_pixel_appearance_only'
            (work/'bad_report.json').write_text(json.dumps(report),encoding='utf8')
            settings['conversion_report']='res://work/qa/pixel_gate_negative/bad_report.json'
        (work/'spec.json').write_text(json.dumps(settings),encoding='utf8')
        (work/'manifest.json').write_text(json.dumps(cfg),encoding='utf8')
        with contextlib.redirect_stdout(io.StringIO()):failed=validate_pixel_assets.check(work/'manifest.json')
        results.append({'case':case,'passed':failed==(case!='valid')})
    (work/'results.json').write_text(json.dumps(results,indent=2),encoding='utf8')
    failures=sum(not row['passed'] for row in results)
    print(f'PIXEL GATE NEGATIVE CASES: {len(results)} checks / {failures} failures')
    return int(failures>0)


if __name__=='__main__':raise SystemExit(main())
