"""从合作者清单生成运行时动画索引，不修改原始图片。"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/PROCESSED/skills'


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def main():
    animations = {}
    for batch in ['SKL-B01', 'SKL-NB01']:
        folder = BASE / batch / 'v001'
        manifest = read(folder / 'manifest.json')
        frames = {f['id']: f for f in manifest.get('frames', [])}
        for source in manifest['animations']:
            b01 = batch == 'SKL-B01'
            paths = [frames[x]['file'] for x in source['frames']] if b01 else source['frames']
            files = [folder / x for x in paths]
            assert all(p.is_file() for p in files), source['id']
            animations[source['id']] = {
                'batch': batch,
                'manifest': 'res://' + (folder / 'manifest.json').relative_to(ROOT).as_posix(),
                'kind': source['layer'] if b01 else ('actor' if source['kind'] == 'hero' else 'fx'),
                'frames': ['res://' + p.relative_to(ROOT).as_posix() for p in files],
                'sha256': [hashlib.sha256(p.read_bytes()).hexdigest() for p in files],
                'root': source['root'] if b01 else source['anchor'],
                'attachment': frames[source['frames'][0]].get('attachment', [0, 0]) if b01 else [0, 0],
                'fps': source['fps'], 'loop': source['loop'],
            }
    components = read(BASE / 'SKL-B01/v001/manifest.json')['beamComponents']
    result = {
        'revision': 1, 'skill_count': 12,
        'actor_foot_offset': [0, 17], 'body_center_offset': [0, -20],
        'query_max_results': 96, 'contact_margin': 2,
        'ground_probe_up': 12, 'ground_probe_down': 48,
        'same_ground_tolerance': 12, 'target_clearance': 30,
        'field_intro_frames': 4, 'field_outro_frames': 2, 'beam_fps': 8,
        'beam_probe_fractions': [-0.5, 0, 0.5],
        'unguardable_sources': ['hazard', 'spike', 'lava', 'fall'],
        'animations': animations,
        'beam_components': {p['variant'] + '_' + p['part']: {
            'texture': 'res://assets/PROCESSED/skills/SKL-B01/v001/' + p['file'],
            'root': p['root'], 'sha256': p['sha256']
        } for p in components},
    }
    (ROOT / 'data/skill_presentations.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'SKILL LIBRARY: {len(animations)} animation groups, 192 unique frames, 6 beam components')


if __name__ == '__main__':
    main()
