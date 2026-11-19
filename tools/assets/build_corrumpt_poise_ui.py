"""以现有Boss血条为参考的裂纹/恢复覆盖层，ImageMagick转换，Pillow只读测量。"""
from pathlib import Path
from PIL import Image
import subprocess
import json
from sprite_frames_writer import write_frames

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT/'assets/ui/corrumpt_poise_v1'
MAGICK = ROOT/'work/tools/imagemagick-7.1.2-35/magick.exe'


def main():
    source = DEST/'sources/cracks_repair.png'
    image = Image.open(source).convert('RGBA')
    paths = []
    audit = []
    for i, cy in enumerate([124, 274, 436, 590, 744, 866]):
        frame = DEST/'frames'/f'{i:02d}.png'
        subprocess.run([str(MAGICK), str(source), '-crop', f'{image.width}x120+0+{cy-60}', '+repage',
                        '-channel', 'A', '-morphology', 'Dilate', 'Disk:2', '+channel',
                        '-filter', 'box', '-resize', '350x16!', '-channel', 'A', '-threshold', '15%', '+channel',
                        '+dither', '-colors', '24', '-strip', str(frame)], check=True, capture_output=True)
        native = Image.open(frame).convert('RGBA')
        assert native.size == (350, 16)
        assert native.getpixel((0, 0))[3] == 0
        paths.append('res://assets/ui/corrumpt_poise_v1/frames/'+frame.name)
        audit.append({'frame': i, 'size': native.size, 'bounds': native.getbbox()})
    write_frames(DEST/'CorrumptPoise_frames.tres', {
        'break': {'frames': paths[:3], 'fps': 12.5, 'loop': False},
        'broken': {'frames': [paths[2]], 'fps': 1, 'loop': True},
        'recover': {'frames': paths[3:], 'fps': 12.5, 'loop': False}})
    (DEST/'VALIDATION.json').write_text(json.dumps(audit, indent=2)+'\n', encoding='utf-8')
    subprocess.run([str(MAGICK), *[str(DEST/'frames'/f'{i:02d}.png') for i in range(6)], '-append',
                    '-sample', '200%', str(ROOT/'docs/previews/corrumpt_poise_overlays.png')], check=True, capture_output=True)
    print('CORRUMPT POISE UI: 6 transparent overlays, 350x16, shared bounds')


if __name__ == '__main__':
    main()
