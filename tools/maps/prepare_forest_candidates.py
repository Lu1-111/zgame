"""将十张备选草图转为独立试玩数据；布局适配不写入正式地图或世界登记。"""
from pathlib import Path
from collections import defaultdict
import json, math
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT/'docs/concepts/2026-11-16_forest_links/plans.json'
OUT = ROOT/'test/data/forest_candidates'
ART = ROOT/'test/assets/forest_candidates'
RULES = json.loads((ROOT/'test/data/forest_candidates_rules.json').read_text(encoding='utf-8'))


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')


def contours(mask, cell):
    """有向像素边界：外环面积为正，内孔为负；仅消去共线点，保持碰撞轮廓一致。"""
    edges = defaultdict(list)
    height, width = mask.shape
    for y, x in np.argwhere(mask):
        x, y = int(x), int(y)
        if y == 0 or not mask[y-1,x]: edges[(x,y)].append((x+1,y))
        if x == width-1 or not mask[y,x+1]: edges[(x+1,y)].append((x+1,y+1))
        if y == height-1 or not mask[y+1,x]: edges[(x+1,y+1)].append((x,y+1))
        if x == 0 or not mask[y,x-1]: edges[(x,y+1)].append((x,y))
    polys = []
    while edges:
        start = next(iter(edges)); current = start; ring = []
        while True:
            ring.append(current)
            nxt = edges[current].pop()
            if not edges[current]: del edges[current]
            current = nxt
            if current == start: break
        ring = [p for i,p in enumerate(ring) if (p[0]-ring[i-1][0])*(ring[(i+1)%len(ring)][1]-p[1]) != (p[1]-ring[i-1][1])*(ring[(i+1)%len(ring)][0]-p[0])]
        if len(ring) < 3: continue
        area = sum(a[0]*b[1]-a[1]*b[0] for a,b in zip(ring,ring[1:]+ring[:1]))
        polys.append((area,[[x*cell,y*cell] for x,y in ring]))
    return [p for a,p in polys if a>0], [p for a,p in polys if a<0]


def prepare(p):
    scale = 1/float(p['scale']); cell = RULES['mask_cell']; w,h=RULES['bounds']
    half = RULES['corridor_half_sketch']; radius=half*scale/cell
    image = Image.new('L',(w//cell,h//cell)); draw=ImageDraw.Draw(image)
    def pt(point): return tuple(v*scale/cell for v in point)
    for points in p['air']:
        draw.line([pt(q) for q in points], fill=255, width=round(radius*2))
        for q in points:
            x,y=pt(q);draw.ellipse((x-radius,y-radius,x+radius,y+radius),fill=255)
    for x,y,rw,rh in p['rooms']+[s['pit'] for s in p['jump_sections']]:
        draw.rectangle((x*scale/cell,y*scale/cell,(x+rw)*scale/cell,(y+rh)*scale/cell),fill=255)
    mask=np.asarray(image)>0
    outer,holes=contours(mask,cell)
    platforms=[]
    def is_air(x,y):
        ix,iy=int(x/cell),int(y/cell)
        return 0<=ix<mask.shape[1] and 0<=iy<mask.shape[0] and bool(mask[iy,ix])
    def ledge(x,y,length):
        rect=[round(x*scale),round(y*scale),round(length*scale),RULES['ledge_thickness']]
        if not is_air(rect[0]+rect[2]/2,rect[1]-cell):return
        if any(abs(q['rect'][0]-rect[0])<cell and abs(q['rect'][1]-rect[1])<cell for q in platforms):return
        platforms.append({'id':f'ledge_{len(platforms):03d}','rect':rect,'type':'oneway'})
    gx,gy=p['ability_route'][0]
    choke=next((a,b) for a,b in zip(p['ability_route'],p['ability_route'][1:]) if a[0]==b[0] and a[1]!=b[1])
    for points in p['air']:
        for (x0,y0),(x1,y1) in zip(points,points[1:]):
            if x0 != x1:continue
            low,high=sorted([y0,y1]); step=RULES['step_sketch']; lw=RULES['ledge_width_sketch']
            if p['id']=='05B' and points != p['ability_route'] and x0 in [220,700]:continue
            if points == p['ability_route'] and ([x0,y0],[x1,y1]) == choke:
                ledge(x0-lw/2,low+half,lw)
                continue
            for i,yy in enumerate(range(round(high+half-step),round(low+half),-step)):
                if x0==gx and gy+8<yy<gy+half:continue
                ledge(x0-half+6 if i%2==0 else x0+2,yy,lw)
            ledge(x0-lw/2,low+half,lw)
    for section in p['jump_sections']:
        for x,y,length in section['ledges']:ledge(x,y,length)

    def support(x,approx):
        """先找草图锚点附近的实地；井内机关另加停靠薄台。"""
        xx=x*scale; yy=approx*scale
        candidates=[]
        for row in range(max(1,int(yy/cell)-8),min(mask.shape[0]-1,int(yy/cell)+12)):
            if is_air(xx,row*cell-cell) and not is_air(xx,row*cell):candidates.append(row*cell)
        if candidates:return min(candidates,key=lambda y:abs(y-yy))
        ledge(x-RULES['ledge_width_sketch']/2,approx,RULES['ledge_width_sketch'])
        return round(yy)

    markers=[]; gates=[]; controls=[]; chests=[]
    replacements=RULES['gate_overrides'].get(p['id'],{})
    for kind,x,y,name in p['stations']:
        if kind=='gate':
            x,y=replacements.get(name,[x,y]);gates.append({'id':name,'center':[x,y]});continue
        if kind=='ability':continue
        foot=round((y+(4 if kind=='switch' else 6)))
        fy=support(x,foot)
        row={'id':name,'kind':kind,'pos':[round(x*scale),fy], 'action':name}
        if kind=='switch':
            row['action']='checkpoint' if p['id'].startswith('07') else name
            if p['id']=='05B':row['action']='lift_left' if name=='A' else 'prepare_right'
            controls.append(row)
        elif kind=='chest':chests.append(row)
        else:markers.append(row)
    existing={g['id'] for g in gates}
    for name,center in replacements.items():
        if name not in existing:gates.append({'id':name,'center':center})
    if p['id']=='05A':gates.append({'id':'WaterSeal','center':[330,410]})
    for name,x,y,action in RULES['additional_controls'].get(p['id'],[]):
        controls.append({'id':name,'kind':'switch','pos':[round(x*scale),support(x,y)],'action':action})
    for gate in gates:
        x,y=gate.pop('center');wx,wy=round(x*scale),round(y*scale)
        top,bottom=int(wy/cell),int(wy/cell)
        while top>0 and is_air(wx,top*cell):top-=1
        while bottom<h//cell-1 and is_air(wx,bottom*cell):bottom+=1
        margin=RULES['gate_margin'];width=RULES['gate_width']
        gate['rect']=[wx-width/2,top*cell-margin,width,(bottom-top)*cell+margin*2]
        gate['condition']=RULES['gate_conditions'][p['id']][gate['id']]

    enemies=[]
    for index,(x,y,kind) in enumerate(p['mobs']):
        group=next((i for i,(rx,ry,rw,rh) in enumerate(p['rooms']) if rx<=x<=rx+rw and ry<=y<=ry+rh),0)
        fy=round(y*scale) if kind=='fly' else support(x,y+20)
        bounds=p['rooms'][group] if p['rooms'] else [x-80,y,160,80]
        enemies.append({'spawn_id':f'{p["id"]}_{index}','enemy_id':RULES['enemy_map'][kind], 'pos':[round(x*scale),fy], 'group':group,
          'patrol_bounds':[round((bounds[0]+12)*scale),round((bounds[0]+bounds[2]-12)*scale)]})
    # Every candidate has its original room three-way interface, with independent review-state links.
    ports=[]
    for name,x,y,desc in p['ports']:
        px=RULES['arrival_offset'] if x==0 else w-RULES['arrival_offset']
        floor=support(px/scale,y+half)
        ports.append({'id':name,'pos':[px,floor], 'destination':desc[:2],'description':desc,'ability':name=='E3' and p['id'].startswith(('07','08'))})
    origin=ports[0]['pos']; spawn=[origin[0]+RULES['arrival_offset'],origin[1]-RULES['body_half']]
    takeoff=[round(gx*scale),round((gy+half)*scale)]
    ledge(gx-RULES['ledge_width_sketch']/2,gy+half,RULES['ledge_width_sketch'])
    landing=[round(gx*scale)-RULES['landing_width']/2,round((p['ability_route'][1][1]+half)*scale),RULES['landing_width'],RULES['ledge_thickness']]
    if p['ability_route'][1][1]==gy:
        lx,ly=p['ability_route'][1];target=p['ability_route'][2];takeoff=[round(lx*scale),round((ly+half)*scale)]
        landing=[round(target[0]*scale)-RULES['landing_width']/2,round((target[1]+half)*scale),RULES['landing_width'],RULES['ledge_thickness']]
    # Explicit takeoff and landing shelves make the 160px ability gap physically reviewable.
    for x,y,length in [(takeoff[0]-RULES['landing_width']/2,takeoff[1],RULES['landing_width']),(landing[0],landing[1],landing[2])]:ledge(x/scale,y/scale,length/scale)
    water_regions=[]
    for index,theme in enumerate(p['theme']):
        if theme[0]!='water':continue
        _,x,y,rw,rh=theme
        wx=(x+rw/2)*scale; top=round(y*scale); bottom=top
        while bottom<h and is_air(wx,bottom):bottom+=cell
        water_regions.append({'rect':[round(x*scale),top,round(rw*scale),bottom-top], 'condition':'solved' if index==0 else 'water_a'})
    data={'id':'forest_02','candidate_id':p['id'],'name':p['title'],'kind':p['kind'],'bounds':RULES['bounds'],'tile_size':16,
      'region':'forest','background':'res://assets/environments/backgrounds/forest/v002/deep_woodland.png','background_tint':'#bacdc0',
      'smoothing':{'distance_cell':8,'distance_max':32},'outer_polygons':outer,'hole_polygons':holes,'platforms':platforms,
      'spawn':spawn,'markers':markers,'controls':controls,'chests':chests,'gates':gates,'enemies':enemies,'ports':ports,
      'ability_test':{'takeoff':[takeoff[0],takeoff[1]-RULES['body_half']],'landing':landing},'notes':p['notes'],'lifts':[],
      'water_regions':water_regions}
    if p['id']=='05B':
        for name,x,stops in [('LeftLift',220,[614,454]),('RightLift',700,[614,454,224])]:
            data['lifts'].append({'id':name,'x':round(x*scale),'stops':[round(y*scale) for y in stops]})
    write(OUT/f'{p["id"]}.json',data)
    ART.mkdir(parents=True,exist_ok=True)
    rgba=Image.new('RGBA',image.size,(0,0,0,0));rgba.putalpha(image);rgba.save(ART/f'{p["id"]}_open.png')
    preview=Image.new('RGB',image.size,'#4b6753');preview.paste('#152a26',mask=image)
    d=ImageDraw.Draw(preview)
    for plat in platforms:
        x,y,pw,ph=plat['rect'];d.line((x/cell,y/cell,(x+pw)/cell,y/cell),fill='#74c7c6',width=1)
    preview.save(ART/f'{p["id"]}_map.png')
    return {'id':p['id'],'title':p['title'],'kind':p['kind'],'scene':f'res://test/scenes/forest_candidates/forest_{p["id"]}.tscn','config':f'res://test/data/forest_candidates/{p["id"]}.json','map':f'res://test/assets/forest_candidates/{p["id"]}_map.png'}


def main():
    rows=[prepare(p) for p in json.loads(SOURCE.read_text(encoding='utf-8'))]
    write(OUT/'manifest.json',{'candidates':rows,'rules':'res://test/data/forest_candidates_rules.json'})
    print('CANDIDATE DATA: 10 playable layouts; formal maps untouched')


if __name__=='__main__':main()
