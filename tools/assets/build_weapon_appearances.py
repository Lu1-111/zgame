"""从已确认逐帧中拆出武器像素层，生成独立外观与完整合成缓存，不重采样人物。"""
from pathlib import Path
import hashlib
import json
import re
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/PROCESSED/weapons/appearances/v001'


def load(path):return json.loads((ROOT/path).read_text(encoding='utf8'))
def res(path):return 'res://'+path.relative_to(ROOT).as_posix()


def main():
    config=load('data/weapon_appearances.json');motion=load('data/hero_motion.json')
    previous=load('assets/PROCESSED/weapons/appearances/v001/manifest.json') if (OUT/'manifest.json').exists() else {'animations':{}}
    combat=load('data/combat_presentation.json');guard=load('data/guard_frames.json')
    sword=load(motion['sword']['frame_manifest'][6:]);rows={}
    text=(ROOT/'assets/PROCESSED/characters/CHR-01/v001/godot/CHR-01_sprite_frames.tres').read_text(encoding='utf8')
    regions={name:tuple(map(int,re.findall(r'-?\d+',rect))) for name,rect in re.findall(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\s*atlas = [^\n]+\s*region = Rect2\(([^)]+)\)',text)}
    atlas_path='res://assets/PROCESSED/characters/CHR-01/v001/CHR-01_atlas_right_v001.png'
    atlas=Image.open(ROOT/atlas_path[6:]).convert('RGBA')
    for name in ['hammer_1','hammer_2','hammer_3','staff_sweep']:
        block=next(block for block in text.split('{\n"frames":')[1:] if f'"name": &"{name}"' in block.split('},\n{')[0])
        ids=re.findall(r'SubResource\("([^"]+)"\)',block.split('"loop"')[0])
        frames=[];kind='staff' if name.startswith('staff') else 'hammer'
        for index,id in enumerate(ids):
            rect=regions[id];im=atlas.crop((rect[0],rect[1],rect[0]+rect[2],rect[1]+rect[3]))
            native=motion['native_motion']['frames'][f'{name}_{index+1}']
            a=np.array(im);mask=np.zeros(a.shape[:2],bool)
            ox,oy=native['origin']
            for x,y,w,h in native['masks']:mask[int(y+oy):int(y+oy+h),int(x+ox):int(x+ox+w)]=True
            mask &= a[:,:,3]>0
            # 沿原武器冷色/白色像素簇补全矩形边外的尖端；暖色人物像素阻断扩展。
            rgb=a[:,:,:3].astype(float)
            cool=(rgb[:,:,2]>rgb[:,:,0]*config['extraction']['blue_ratio_r'])&(rgb[:,:,2]>rgb[:,:,1]*config['extraction']['blue_ratio_g'])
            pale=(rgb[:,:,0]>170)&(rgb[:,:,1]>160)&(rgb[:,:,2]>150)&(abs(rgb[:,:,0]-rgb[:,:,1])<28)&(abs(rgb[:,:,1]-rgb[:,:,2])<44)
            allowed=(cool|pale)&(a[:,:,3]>0)
            stack=[(int(x),int(y)) for y,x in np.argwhere(mask)]
            while stack:
                x,y=stack.pop()
                for nx,ny in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                    if 0<=nx<im.width and 0<=ny<im.height and allowed[ny,nx] and not mask[ny,nx]:mask[ny,nx]=True;stack.append((nx,ny))
            mask |= cool&(a[:,:,3]>0)
            hand=np.array(native['hand'])+np.array(native['origin'])
            if kind=='staff':
                seeds=np.argwhere(mask&pale)
                if len(seeds):
                    head=seeds[:,::-1].mean(axis=0);direction=head-hand;length=np.linalg.norm(direction);direction/=max(length,1)
                    yy,xx=np.indices(mask.shape);points=np.stack([xx-hand[0],yy-hand[1]],axis=2)
                    along=points@direction;cross=points@np.array([-direction[1],direction[0]])
                    yellow=(rgb[:,:,0]>160)&(rgb[:,:,0]>rgb[:,:,1]*1.08)&(rgb[:,:,1]>rgb[:,:,2]*1.8)
                    shaft=(along>=-6)&(along<=length)&(abs(cross)<=2)&~yellow&(a[:,:,3]>0)
                    shaft &= np.linalg.norm(points,axis=2)>3
                    mask |= shaft
            # 矩形外残留的独立亮点属于武器端点；原手掌附近的独立像素仍保留。
            visible=(a[:,:,3]>0)&~mask;visited=np.zeros(mask.shape,bool);components=[]
            for yy,xx in np.argwhere(visible):
                if visited[yy,xx]:continue
                group=[];todo=[(int(xx),int(yy))];visited[yy,xx]=True
                while todo:
                    x,y=todo.pop();group.append((x,y))
                    for nx,ny in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                        if 0<=nx<im.width and 0<=ny<im.height and visible[ny,nx] and not visited[ny,nx]:visited[ny,nx]=True;todo.append((nx,ny))
                components.append(group)
            largest=max((len(c) for c in components),default=0)
            for component in components:
                if len(component)<largest and min(np.linalg.norm(np.array(p)-hand) for p in component)>5:
                    for x,y in component:mask[y,x]=True
            frames.append({'image':im,'mask':mask,'source':{'path':atlas_path,'region':list(rect)},'anchor':[motion['anchor'][0]+ox,motion['anchor'][1]+oy]})
        rows[name]={'module':kind,'frames':frames}
    skills=load('data/skill_presentations.json')
    for name,definition in load('data/weapon_skill_sockets.json')['animations'].items():
        frames=[]
        for index,pose in enumerate(definition['frames']):
            path=skills['animations'][name]['frames'][index];im=Image.open(ROOT/path[6:]).convert('RGBA');a=np.array(im)
            drawing=Image.new('L',im.size);pen=ImageDraw.Draw(drawing)
            for x,y,w,h in pose['regions']:pen.rectangle((x,y,x+w-1,y+h-1),fill=255)
            for start,end,width in pose['strokes']:pen.line([tuple(start),tuple(end)],fill=255,width=width)
            mask=(np.array(drawing)>0)&(a[:,:,3]>0)
            yy,xx=np.indices(mask.shape);palm=(xx-pose['socket'][0])**2+(yy-pose['socket'][1])**2<=4
            mask &= ~palm
            frames.append({'image':im,'mask':mask,'source':{'path':path},'anchor':skills['animations'][name]['root'],'socket_override':pose})
        rows[name]={'module':definition['module'],'frames':frames}
    for name,definition in combat['animations'].items():
        kind='sword' if name.startswith('sword_') else 'rifle' if name=='rifle_shot' else name.removeprefix('guard_') if name.startswith('guard_') else ''
        if not kind:continue
        frames=[]
        for index,path in enumerate(definition['frame_paths']):
            im=Image.open(ROOT/path[6:]).convert('RGBA');a=np.array(im)
            socket_override=None
            if name.startswith('guard_'):
                weapon=Image.open(ROOT/guard['weapon_sources'][kind]['frames'][index]['weapon_path'][6:]).convert('RGBA')
                w=np.array(weapon);mask=(w[:,:,3]>0)&(a[:,:,3]>0)&np.all(a[:,:,:3]==w[:,:,:3],axis=2)
            elif name.startswith('sword_'):
                pose=sword['poses'][sword['clips'][name]['frames'][index]['pose']]
                offset=np.array(sword['anchor'])-np.array(sword['native_anchor'])
                grip=np.array(pose['grip'])+offset;direction=np.array([np.cos(np.deg2rad(pose['angle_degrees'])),np.sin(np.deg2rad(pose['angle_degrees']))])
                yy,xx=np.indices(a.shape[:2]);p=np.stack([xx-grip[0],yy-grip[1]],axis=2)
                along=p@direction;cross=p@np.array([-direction[1],direction[0]])
                colors=[motion['sword'][k] for k in ['steel','edge','shadow','grip','gold']]+['#86999c','#9e8b68']
                rgb=np.array([tuple(bytes.fromhex(c[1:])) for c in colors]);matches=np.any(np.all(a[:,:,:3,None]==rgb.T[None,None,:,:],axis=2),axis=2)
                mask=matches&(a[:,:,3]>0)&(abs(cross)<=config['extraction']['sword_half_width'])&(along>=-config['extraction']['sword_handle_length'])
            else:
                # 备用射击帧的原枪由三种铁色与两种木色组成。
                extraction=config['rifle_frame_extraction']
                colors=np.array([tuple(bytes.fromhex(color[1:])) for color in extraction['palette']],np.uint8)
                matched=np.any(np.all(a[:,:,:3,None]==colors.T[None,None,:,:],axis=2),axis=2)
                mask=np.zeros(a.shape[:2],bool)
                x0,y0,x1,y1=extraction['region']
                mask[y0:y1,x0:x1]=matched[y0:y1,x0:x1]&(a[y0:y1,x0:x1,3]>0)
                socket_override={'socket':extraction['grips'][index],'angle_degrees':0}
            frame={'image':im,'mask':mask,'source':{'path':path},'anchor':definition['anchors'][index]}
            if socket_override is not None:
                frame['socket_override']=socket_override
            frames.append(frame)
        rows[name]={'module':kind,'frames':frames}
    OUT.mkdir(parents=True,exist_ok=True);manifest={'animations':{},'source_policy':'Approved character masters unchanged. Layers are native pixel copies, not generated images.','frames':0}
    metrics=[];board=Image.new('RGBA',(900,4*160),'#111521');draw=ImageDraw.Draw(board)
    for name,row in rows.items():
        destination={'module':row['module'],'frames':[]}
        for index,frame in enumerate(row['frames']):
            a=np.array(frame['image']);mask=frame['mask'];base=frame['image'];prefix=f'{name}_{index:02d}'
            folder=OUT/name;folder.mkdir(exist_ok=True)
            mask_im=Image.fromarray(np.uint8(mask)*255);mask_path=folder/f'{prefix}_mask.png';mask_im.save(mask_path)
            body=a.copy();body[mask]=0
            if frame.get('socket_override',{}).get('repair_belly'):
                for y,x in np.argwhere(mask):
                    if 46<=x<57 and 64<=y<77:body[y,x]=a[y,48]
            body_path=folder/f'{prefix}_body.png';Image.fromarray(body).save(body_path)
            # 原武器不再烘焙进动作。占位只记握点；正式武器用同画布逐帧层重新装配。
            if 'socket_override' in frame:
                point=np.array(frame['socket_override']['socket']);angle=frame['socket_override']['angle_degrees']
            elif name.startswith('sword_'):
                pose=sword['poses'][sword['clips'][name]['frames'][index]['pose']]
                point=np.array(pose['hand'])+np.array(sword['anchor'])-np.array(sword['native_anchor'])
                angle=pose['angle_degrees']
            elif name.startswith('guard_'):
                pose=guard['poses'][index];point=np.array(pose['hand'])+np.array(guard['anchor'])-np.array(guard['native_anchor']);angle=pose['angle_degrees']
            else:
                native=motion['native_motion']['frames'].get(f'{name}_{index+1}',{})
                point=np.array(native.get('hand',[48,48]))+np.array(native.get('origin',[0,0]));angle=native.get('weapon_angle',0)
            if row['module']=='hammer':
                bright=mask&(a[:,:,0]>175)&(a[:,:,1]>160)&(a[:,:,2]>145)
                samples=np.argwhere(bright)
                if len(samples):
                    direction=samples[:,::-1].mean(axis=0)-point
                    angle=float(np.degrees(np.arctan2(direction[1],direction[0])))
            original=np.zeros_like(a);original[mask]=a[mask];original_path=folder/f'{prefix}_original_weapon.png';Image.fromarray(original).save(original_path)
            yy,xx=np.indices(mask.shape);palm=(xx-point[0])**2+(yy-point[1])**2<=16
            foreground=np.zeros_like(a);foreground[palm&~mask]=a[palm&~mask]
            foreground_path=folder/f'{prefix}_fingers.png';Image.fromarray(foreground).save(foreground_path)
            record={'source':frame['source'],'canvas':list(base.size),'anchor':frame['anchor'],'socket':{'position':[float(v) for v in point],'angle_degrees':angle},'mask':res(mask_path),'body':res(body_path),'foreground':res(foreground_path),'skins':{'original':{'weapon':res(original_path)}},'changed_pixels':int(mask.sum())}
            for skin,definition in config['skins'].items():
                if skin==config['default'] or 'palette' not in definition:continue
                colors=np.array([tuple(bytes.fromhex(c[1:])) for c in definition['palette']],np.uint8)
                layer=np.zeros_like(a);luminance=(a[:,:,:3].astype(np.float32)@np.array([0.2126,0.7152,0.0722]))
                levels=np.clip(np.rint(luminance/255*(len(colors)-1)).astype(int),0,len(colors)-1)
                layer[mask,:3]=colors[levels[mask]];layer[mask,3]=255
                layer_path=folder/f'{prefix}_{skin}_weapon.png';Image.fromarray(layer).save(layer_path)
                record['skins'][skin]={'weapon':res(layer_path)}
                metrics.append({'path':res(layer_path),'native_canvas':list(base.size),'runtime_scale':[1,1],'authored_native':True,'anchor':[int(v) for v in frame['anchor']]})
            old_frames=previous['animations'].get(name,{}).get('frames',[])
            if index<len(old_frames):
                old=old_frames[index]
                if old.get('canvas')==record['canvas'] and old.get('socket')==record['socket']:
                    for model,layer in old.get('skins',{}).items():
                        if model not in record['skins'] and model in config['skins'] and (ROOT/layer['weapon'][6:]).is_file():record['skins'][model]=layer
            destination['frames'].append(record);manifest['frames']+=1
        manifest['animations'][name]=destination
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    palette=sorted({c for d in config['skins'].values() for c in d.get('palette',[])})
    spec={'palette':palette,'max_colors':32,'sprite_canvases':{}}
    (OUT/'pixel_spec.json').write_text(json.dumps(spec,indent=2)+'\n',encoding='utf8')
    (OUT/'pixel_manifest.json').write_text(json.dumps({'id':'weapon_appearances_v001','pixel_standard':'res://data/art/pixel_standards.json','pixel_spec':res(OUT/'pixel_spec.json'),'assets':metrics},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(f'WEAPON APPEARANCES: {len(rows)} animations / {manifest["frames"]} source frames / {len(metrics)} native replacement layers / body unchanged')


if __name__=='__main__':main()
