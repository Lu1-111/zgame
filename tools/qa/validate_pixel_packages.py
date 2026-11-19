"""统一执行所有登记包的像素数据门禁；任何包文件数量或转换记录不符均失败。"""
from pathlib import Path
import json
import validate_pixel_assets

ROOT=Path(__file__).resolve().parents[2]


def main():
    config=json.loads((ROOT/'data/art/pixel_packages.json').read_text(encoding='utf8'))
    failures=0
    summaries=[]
    for package in config['packages']:
        failed=validate_pixel_assets.check(ROOT/package['manifest'])
        result=json.loads((ROOT/'work/qa/pixel_assets.json').read_text(encoding='utf8'))
        count=len(result['images'])
        if count!=package['expected_images']:
            print(f'FAIL: {package["id"]}: {count} images != registered {package["expected_images"]}')
            failed=True
        contract=json.loads((ROOT/package['metrics']).read_text(encoding='utf8'))['assets']
        if len(contract)!=count:
            print(f'FAIL: {package["id"]}: numeric pixel contract does not cover all images')
            failed=True
        for image in result['images']:
            expected=contract.get(image['path'],{})
            if image['pixels']!=expected.get('native_canvas') or image['visible_rect']!=expected.get('visible_rect'):
                print(f'FAIL: numeric canvas/visible bounds changed: {image["path"]}')
                failed=True
            if expected.get('runtime_scale')!=[1,1] or not isinstance(expected.get('anchor'),list) or len(expected['anchor'])!=2 or any(type(v) is not int for v in expected['anchor']):
                print(f'FAIL: native scale or fixed anchor missing: {image["path"]}')
                failed=True
            if image['colors']>expected.get('palette_limit',0):
                print(f'FAIL: per-asset numeric palette limit: {image["path"]}')
                failed=True
        summaries.append({'id':package['id'],'images':count,'passed':not failed})
        failures+=int(failed)
    output={'packages':summaries,'failures':failures}
    (ROOT/'work/qa/pixel_packages.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(f'PIXEL PACKAGES: {len(summaries)} packages / {sum(s["images"] for s in summaries)} images / {failures} failures')
    return int(failures>0)


if __name__=='__main__':
    raise SystemExit(main())
