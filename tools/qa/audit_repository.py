"""检查正式资源静态引用、导入描述及保留素材批次，不依据未引用自动删除素材。"""
from pathlib import Path
import ast
import re
import os

ROOT = Path(__file__).resolve().parents[2]
RESOURCE = re.compile(r'''["'](res://[^"'\r\n]+)["']''')


def main():
    failures = []
    checked = 0
    sources = [ROOT/'project.godot']
    for folder, suffix in [('scripts', '.gd'), ('scenes', '.tscn'), ('data', '.json'), ('assets', '.tres'), ('test', '.gd'), ('test', '.tscn'), ('tools', '.gd')]:
        sources.extend((ROOT/folder).rglob('*'+suffix))
    for source in sources:
        text = source.read_text(encoding='utf-8-sig')
        for match in RESOURCE.finditer(text):
            resource = match.group(1)
            # 预览脚本的输出路径不要求预先存在；输入资源仍正常检查。
            line = text[text.rfind('\n', 0, match.start())+1:text.find('\n', match.end()) if '\n' in text[match.end():] else len(text)]
            if any(token in line for token in ['save_png(', 'make_dir_recursive_absolute(', 'FileAccess.WRITE']):
                continue
            if source.is_relative_to(ROOT/'test/previews') and resource.startswith('res://work/'):
                continue
            if any(token in resource for token in ['%', '{', '*']) or text[match.end():].lstrip().startswith('+'):
                continue
            path = ROOT/resource.removeprefix('res://')
            checked += 1
            if not path.exists():
                failures.append(f'{source.relative_to(ROOT)} -> {resource}')
    for description in (ROOT/'assets').rglob('*.import'):
        if not description.with_suffix('').is_file():
            failures.append(f'孤立导入描述: {description.relative_to(ROOT)}')
    for source in (ROOT/'tools').rglob('*.py'):
        ast.parse(source.read_text(encoding='utf-8-sig'), filename=str(source))
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in {'.git', '.godot', 'work', 'backup', '__pycache__'}]
        for name in files:
            path = Path(base)/name
            relative = path.relative_to(ROOT).as_posix()
            if any(token in name.lower() for token in ['waveform8', 'measured_rf', '实验八', '波形发生', 'draw_triangle_svg']):
                failures.append(f'非游戏内容: {relative}')
            if path.suffix == '.tscn' and ('arena' in name or 'preview' in name or name == 'Showcase.tscn' or name.startswith(('sim_', 'shot_'))) and not relative.startswith('test/'):
                failures.append(f'测试场景未集中: {relative}')
    reserved = ['assets/RAW/skills/SKL-B01', 'assets/RAW/skills/SKL-NB01',
                'assets/PROCESSED/skills/SKL-B01', 'assets/PROCESSED/skills/SKL-NB01',
                'assets/RAW/enemies/ENM-B03', 'assets/RAW/enemies/ENM-B04',
                'assets/PROCESSED/enemies/ENM-B03', 'assets/PROCESSED/enemies/ENM-B04']
    reserved += [f'assets/PROCESSED/enemies/ENM-{i:02d}' for i in range(1, 9)]
    for directory in reserved:
        if not (ROOT/directory).is_dir() or not any((ROOT/directory).rglob('*.png')):
            failures.append(f'保留素材批次缺失: {directory}')
    for error in failures:
        print('FAIL:', error)
    print(f'REPOSITORY AUDIT: {checked} static resource references, {len(reserved)} reserved batches, {len(failures)} errors')
    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
