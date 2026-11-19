"""验证洞穴资源的alpha、原生尺寸、调色板、锁态同源与边缘变体。"""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]


def main():
    cfg=json.loads((ROOT/'data/art/cave_v001.json').read_text(encoding='utf8'))
    allowed={tuple(bytes.fromhex(c[1:])) for c in cfg['palette']}
    checked=0
    for row in cfg['terrain']['variants']+list(cfg['assets'].values()):
        p=ROOT/row['path'][6:]
        im=Image.open(p).convert('RGBA');a=np.array(im)
        assert set(np.unique(a[:,:,3])) <= {0,255},p
        assert set(map(tuple,a[a[:,:,3]>0][:,:3])) <= allowed,p
        if row.get('kind')!='background':
            assert max(im.size)<=64,p
        if row.get('kind') in {'rock','ore','bones','crystal'}:
            assert a[-1,:,3].max()==255,p
        checked+=1
    for side in ['top','bottom','left','right']:
        masks=[]
        for variant in range(8):
            p=ROOT/f'assets/environments/terrain/cave/v001/tiles/edge_{side}_{variant:02d}.png'
            masks.append(Image.open(p).getchannel('A').tobytes())
        assert len(set(masks))==8,side
    closed=np.array(Image.open(ROOT/cfg['assets']['chest_closed']['path'][6:]))
    locked=np.array(Image.open(ROOT/cfg['assets']['chest_locked']['path'][6:]))
    assert np.array_equal(closed[:,:,3],locked[:,:,3]),'闭箱与锁箱轮廓必须相同'
    difference=np.any(closed!=locked,axis=2)
    yy,xx=np.where(difference)
    assert 0<len(xx)<120 and min(xx)>=20 and max(xx)<=28 and min(yy)>=24,'只允许锁区域变化'
    assert cfg['hazard']['damage'] is None,'未批准的陷阱伤害不得擅填'
    print(f'CAVE ASSET QA: {checked} images, binary alpha / {len(allowed)}-color palette / native scale / 32 unique edge masks / identical chest body PASS')


if __name__=='__main__': main()
