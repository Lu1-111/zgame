"""用ImageMagick把生成的通用红光转为96px原生逐帧；Pillow只测量中心与校验。"""
from pathlib import Path
from PIL import Image
import subprocess
import json
from sprite_frames_writer import write_frames

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'assets/effects/danger_warning_v1'
MAGICK = ROOT / 'work/tools/imagemagick-7.1.2-35/magick.exe'


def main():
    source = DEST / 'sources/danger_glint.png'
    atlas = Image.open(source).convert('RGBA')
    paths = []
    audit = []
    for index in range(6):
        # 只用高亮像素测量对齐点，淡光晕不参与中心计算。
        points = [(x, y) for y in range(380, 640) for x in range(index*256, (index+1)*256)
                  if (lambda c: c[0] > 200 and c[1] > 60 and c[3] > 128)(atlas.getpixel((x, y)))]
        cx = round(sum(x for x, y in points)/len(points))
        cy = round(sum(y for x, y in points)/len(points))
        frame = DEST / 'frames' / f'{index:02d}.png'
        subprocess.run([str(MAGICK), str(source), '-crop', f'256x96+{cx-128}+{cy-48}', '+repage',
                        '-sample', '96x36!', '-background', 'none', '-gravity', 'center', '-extent', '96x96',
                        '-channel', 'A', '-threshold', '60%', '+channel', '+dither', '-colors', '12',
                        '-strip', str(frame)], check=True, capture_output=True)
        image = Image.open(frame).convert('RGBA')
        assert image.size == (96, 96)
        assert {v[3] for v in image.get_flattened_data()} == {0, 255}
        paths.append('res://assets/effects/danger_warning_v1/frames/' + frame.name)
        audit.append({'frame': index, 'bounds': image.getbbox(), 'center': [48, 48]})
    write_frames(DEST / 'DangerWarning_frames.tres', {'warning': {'frames': paths, 'fps': 30, 'loop': False}})
    (DEST / 'VALIDATION.json').write_text(json.dumps(audit, indent=2)+'\n', encoding='utf-8')
    subprocess.run([str(MAGICK), *[str(DEST/'frames'/f'{i:02d}.png') for i in range(6)], '+append',
                    '-sample', '200%', str(ROOT/'docs/previews/danger_warning_strip.png')], check=True, capture_output=True)
    print('DANGER WARNING: 6 frames, 96x96, native pixels, 0.2 seconds')


if __name__ == '__main__':
    main()
