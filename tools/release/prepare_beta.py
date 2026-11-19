"""按生产资源依赖建立独立导出工程；保留源仓库中的储备素材，禁止测试和制作文件进入beta。"""
from pathlib import Path
import argparse
import json
import re
import shutil
import hashlib

ROOT = Path(__file__).resolve().parents[2]
RESOURCE = re.compile(r'''["'](res://[^"'\r\n]+)["']''')
TEXT = {'.gd', '.tscn', '.tres', '.json', '.gdshader', '.godot'}
RUNTIME = TEXT | {'.png', '.svg', '.jpg', '.jpeg', '.wav', '.ogg', '.mp3', '.ttf', '.otf', '.woff2', '.uid'}
FORBIDDEN = ('test/', 'tests/', 'tools/', 'docs/', 'work/', 'backup/', 'assets/RAW/', 'data/enemy_designs/', 'data/art/pixel_contracts/', 'data/art/pixel_packages.json', 'data/art/cave_enemy_imagemagick.json', 'data/art/weapon_conversion_v001.json', 'data/art/arsenal_', 'data/art/status_pixel_')


def production_files():
    """收集正式场景、代码、数据及其递归美术依赖，补齐三个使用格式化文件名的图标目录。"""
    found = {'project.godot'}
    for folder in ['scripts', 'scenes', 'data']:
        found.update(p.relative_to(ROOT).as_posix() for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix in RUNTIME and not p.relative_to(ROOT).as_posix().startswith(FORBIDDEN))
    for folder in ['assets/ui/map/minimaps', 'assets/ui/magic', 'assets/PROCESSED/items/ITM-B01/v001/icons']:
        found.update(p.relative_to(ROOT).as_posix() for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix in RUNTIME)
    scanned = set()
    while pending := found - scanned:
        for relative in pending:
            scanned.add(relative)
            p = ROOT/relative
            if p.suffix not in TEXT and p.name != 'project.godot':
                continue
            for match in RESOURCE.finditer(p.read_text(encoding='utf-8-sig')):
                path = match.group(1).removeprefix('res://')
                if path.startswith(FORBIDDEN) or any(s in path for s in ['%', '{', '*']):
                    continue
                source = ROOT/path
                if source.is_dir():
                    found.update(f.relative_to(ROOT).as_posix() for f in source.rglob('*') if f.is_file() and f.suffix in RUNTIME and not f.relative_to(ROOT).as_posix().startswith(FORBIDDEN))
                elif source.is_file() and (source.suffix in RUNTIME or source.name == 'project.godot'):
                    found.add(path)
                elif not p.read_text(encoding='utf-8-sig')[match.end():].lstrip().startswith('+'):
                    raise ValueError(f'Missing production resource: {relative} -> {path}')
    return sorted(found)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    files = production_files()
    assert not any(p.startswith(FORBIDDEN) for p in files)
    total = sum((ROOT/p).stat().st_size for p in files)
    print(f'BETA CONTENT: {len(files)} production files, {total/1024/1024:.1f} MiB; no tests/docs/tools/RAW')
    if args.check:
        return
    if not args.version or not re.fullmatch(r'[0-9][0-9A-Za-z._-]*', args.version):
        parser.error('--version must be the explicitly requested release number')
    stage = ROOT/'work/releases'/args.version/'project'
    if stage.exists():
        raise SystemExit(f'Staging folder already exists: {stage}; preserve it and choose a fresh build number.')
    stage.mkdir(parents=True)
    for relative in files:
        dst = stage/relative
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT/relative, dst)
    project = stage/'project.godot'
    text = project.read_text(encoding='utf-8')
    text = re.sub(r'^config/version=.*\n?', '', text, flags=re.M)
    text = text.replace('[application]', f'[application]\n\nconfig/version="{args.version}"')
    project.write_text(text, encoding='utf-8')
    # Godot imports this clean staging project before exporting, regenerating machine-local caches.
    (stage/'export_presets.cfg').write_text('''[preset.0]
name="Windows Beta"
platform="Windows Desktop"
runnable=true
advanced_options=false
export_filter="all_resources"
include_filter="data/**/*.json,assets/**/*.json"
exclude_filter="*.md,*.py,*.html,*.prompt.txt,*.layout.json"
export_path="../game/Naibao.exe"
script_export_mode=2

[preset.0.options]
custom_template/debug=""
custom_template/release=""
binary_format/embed_pck=false
binary_format/architecture="x86_64"
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
codesign/enable=false
application/modify_resources=false
''', encoding='utf-8')
    record = {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in files}
    (stage.parent/'source_manifest.json').write_text(json.dumps({'version':args.version,'sha256':record},ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'STAGED: {stage}')


if __name__ == '__main__':
    main()
