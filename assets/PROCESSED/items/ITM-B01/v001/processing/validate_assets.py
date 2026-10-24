from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image

root=Path('/home/lululu/zgame')
p=root/'assets/PROCESSED/items/ITM-B01/v001'
m=json.loads((p/'manifest.json').read_text())
atlas=Image.open(p/m['atlas']['file']);icons=Image.open(p/m['iconAtlas']['file'])
checks=0
def check(value, label):
    global checks
    checks+=1
    if not value: raise AssertionError(label)

check(sum(r['countsInTwelve'] for r in m['items'])==12,'正式12项')
check(len(m['items'])==13,'含独立能力奖励')
for r in m['items']:
    source=root/r['source'];check(hashlib.sha256(source.read_bytes()).hexdigest()==r['sourceSHA256'],'RAW未改变')
    check((root/r['prompt']).exists(),'提示词')
    check(r['anchor']==[16,24] and len(r['frames'])==4,'root与帧数')
    sheet=Image.open(p/r['sheet'])
    icon=Image.open(p/r['icon'])
    check(icon.mode=='RGBA' and icon.size==(24,24),'24像素图标')
    rect=r['iconAtlasRect']; check(np.array_equal(np.array(icon),np.array(icons.crop((rect[0],rect[1],rect[0]+rect[2],rect[1]+rect[3])))),'图标图集')
    check(len(set(f['sha256'] for f in r['frames']))==4,'四帧高光变化')
    check(len(set(tuple(f['scaleActual']) for f in r['frames']))==1,'全动作固定尺度')
    for index,f in enumerate(r['frames']):
        im=Image.open(p/f['path']);a=np.array(im)[:,:,3]
        check(im.mode=='RGBA' and im.size==(32,32),'32像素帧')
        check(a.min()==0 and a.max()>128,'非空真透明')
        check(not(a[0].any() or a[-1].any() or a[:,0].any() or a[:,-1].any()),'完整alpha无触边')
        check(f['outputBodyBBox'][3]==24,'语义底线')
        check(np.array_equal(np.array(im),np.array(sheet.crop((index*32,0,(index+1)*32,32)))),'动画条无重排')
        rect=r['atlasRects'][index]
        check(np.array_equal(np.array(im),np.array(atlas.crop((rect[0],rect[1],rect[0]+rect[2],rect[1]+rect[3])))),'总图集正确')
ability=m['items'][-1]
check(len(set(tuple(f['translation']) for f in ability['frames']))==1,'能力保持统一平移')
check(min(d['alphaSilhouetteIoU'] for d in ability['continuity'])>0.98,'能力循环接缝')
report={'assertions':checks,'failures':0,'items':13,'formalItems':12,'worldFrames':52,'icons':13,'sourceHashesVerified':True,'allAlphaEdgesClear':True}
(p/'asset_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('ITEM ASSETS: assertions=%d failures=0 / 13 items / 52 frames / 13 icons'%checks)
