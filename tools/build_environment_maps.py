#!/usr/bin/env python3
"""ENV-B01 图块美术→分层地图。只读关卡表，不改可玩关卡。"""
from __future__ import annotations

import argparse
import base64
import hashlib
import html
import io
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
BATCH = ROOT / "assets/PROCESSED/environments/ENV-B01/v001"
SOURCE = ROOT / "data/world/regions.json"


def save_json(path, value):
    """保存可追溯的严格 JSON。"""
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def sha(path):
    """计算来源文件的校验和。"""
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read_image(path):
    """读取并保持透明图层。"""
    return Image.open(path).convert("RGBA")


def font(size=14):
    """为设计标记选择本机中文字体。"""
    for path in ("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def data_url(path):
    """将预览图嵌入离线页面。"""
    return "data:image/png;base64," + base64.b64encode(Path(path).read_bytes()).decode()


def kit_id(room):
    """按既有房间选择环境套件。"""
    if room["id"] in ("cave_06", "cave_07"):
        return "ENV-04"
    return {"camp": "ENV-01", "forest": "ENV-02", "cave": "ENV-03"}[room["region"]]


def pano(image, size, vertical=None):
    """镜像延展等比例背景，不把单屏拉成长房。"""
    width, height = size
    out = Image.new("RGBA", size)
    if vertical is not None and height > image.height:
        out.alpha_composite(vertical, (0, 0))
        return out
    for x in range(0, width, image.width):
        segment = image if (x // image.width) % 2 == 0 else image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        out.alpha_composite(segment, (x, 0))
    if height > image.height:
        # 无专用竖房背景时延伸最下方一像素，不倒置树冠。
        edge = out.crop((0, image.height - 1, width, image.height))
        out.alpha_composite(edge.resize((width, height - image.height), Image.Resampling.NEAREST), (0, image.height))
    return out


def tile(atlas, index, size):
    """按固定索引截取原生图块。"""
    x, y = index % 4 * size, index // 4 * size
    return atlas.crop((x, y, x + size, y + size))


def platform_image(atlas, width, height, size):
    """按角色脚下的原矩形机械拼接，边角覆盖最后不足整格的部分。"""
    out = Image.new("RGBA", (width, height))
    records = []
    rows, columns = math.ceil(height / size), math.ceil(width / size)
    for row in range(rows):
        for col in range(columns):
            if height <= size:
                index = 9 if columns == 1 else (10 if col == 0 else 12 if col == columns - 1 else 11)
            else:
                index = (0 if col == 0 else 2 if col == columns - 1 else 1) if row == 0 else (3 if col == 0 else 5 if col == columns - 1 else 4)
            x, y = col * size, row * size
            # 右端向左对齐完整端头，避免把角部裁没；碰撞仍为精确原矩形。
            if col == columns - 1:
                x = max(0, width - size)
            fragment = tile(atlas, index, size)
            frag_w, frag_h = min(size, width - x), min(size, height - y)
            out.alpha_composite(fragment.crop((0, 0, frag_w, frag_h)), (x, y))
            records.append({"position": [x, y], "atlas_index": index, "visible_size": [frag_w, frag_h]})
    return out, records


def find_prop(kit, words):
    """按原画模块语义查找装饰。"""
    props = kit.get("props", [])
    for word in words:
        for p in props:
            if word.lower() in (p["id"] + " " + p["path"]).lower():
                return p
    return None


def place_prop(layer, placements, kit_name, kit, words, anchor, opacity=1, flip=False, z=1):
    """在语义锚点放置保留原比例的装饰模块。"""
    prop = find_prop(kit, words)
    if prop is None:
        return
    path = BATCH / kit_name / prop["path"]
    img = read_image(path)
    if flip:
        img = img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    if opacity != 1:
        img.putalpha(img.getchannel("A").point(lambda v: int(v * opacity)))
    root = prop.get("surface_anchor", prop.get("anchor", [img.width // 2, img.height])) if "bridge" in prop["id"] else prop.get("anchor", [img.width // 2, img.height])
    if flip:
        root = [img.width - root[0], root[1]]
    pos = [round(anchor[0] - root[0]), round(anchor[1] - root[1])]
    # 装饰不得越出房间画布，不能覆盖原有实体或门的逻辑。
    if prop["id"] != "cave_entrance":
        pos[0] = min(max(0, pos[0]), max(0, layer.width - img.width))
    pos[1] = min(max(0, pos[1]), max(0, layer.height - img.height))
    layer.alpha_composite(img, tuple(pos))
    placements.append({"kit": kit_name, "prop_id": prop["id"], "path": str(path.relative_to(ROOT)),
                       "position": pos, "anchor": list(anchor), "opacity": opacity, "flip_h": flip, "z_index": z})


def decoration(room, kits):
    """逐房编排地标与空场，使用生成的原画模块。"""
    w, h = room["size"][0] * 640, room["size"][1] * 360
    back, front = Image.new("RGBA", (w, h)), Image.new("RGBA", (w, h))
    placements = []
    name = kit_id(room)
    kit = kits[name]
    rid = room["id"]
    def put(words, x, y, alpha=1, flip=False, behind=False, use=None):
        use = use or name
        place_prop(back if behind else front, placements, use, kits[use], words, [x, y], alpha, flip, -12 if behind else 1)
    if rid == "camp_01":
        put(["house", "tent", "cottage"], 460, 338, .65, behind=True)
        put(["fountain", "spring"], 730, 340)
        put(["storage", "crate"], 350, 340, flip=True)
        put(["return_glyph"], 980, 40, .8)
        put(["lamp", "lantern", "sign"], 1150, 340)
    elif rid == "camp_02":
        put(["shelf", "merchant"], 155, 340, .85)
        put(["storage", "crate"], 510, 296)
        put(["lamp", "lantern"], 580, 340)
    elif rid.startswith("forest"):
        if rid == "forest_03":
            put(["tree", "trunk"], 510, 710, .35, behind=True)
            put(["bridge_left", "bridge_l", "bridge"], 124, 340, .8, behind=True)
            put(["bridge_right", "bridge_r", "bridge"], 468, 340, .8, behind=True)
            put(["canopy", "crown"], 320, 120, .32, behind=True)
            put(["root"], 85, 700, .7)
            put(["moss", "rock"], 540, 700, .65, behind=True)
        elif rid == "forest_06":
            put(["canopy", "crown"], 150, 300, .35, behind=True)
            put(["root"], 520, 340, .65)
            put(["fern", "mush"], 65, 340, .65, behind=True)
        elif rid == "forest_05":
            put(["cave", "entrance"], 630, 340, .8, behind=True)
            put(["root"], 180, 340, .55, behind=True)
            put(["rock", "moss"], 430, 340, .4, behind=True)
            put(["crystal", "mineral"], 535, 340, .5, behind=True, use="ENV-03")
        else:
            put(["tree", "trunk"], 225 if rid == "forest_04" else 730, 340, .35, behind=True)
            put(["root"], 1080, 340, .58, behind=True)
            put(["canopy", "crown"], 150, 160, .3, behind=True)
            put(["fern", "mush"], 150 if rid == "forest_04" else 310, 340, .65, behind=True)
            put(["moss", "rock"], 1180, 340, .6, behind=True)
            if rid == "forest_01":
                put(["sign"], 85, 340, .35, behind=True, use="ENV-01")
            if rid == "forest_02":
                put(["vine"], 715, 0, .55, behind=True)
    elif rid.startswith("cave"):
        if rid == "cave_06":
            put(["pillar", "wall", "column", "hive"], 130, 340, .55, behind=True)
            put(["pillar", "wall", "column", "hive"], 1150, 340, .55, flip=True, behind=True)
            put(["extractor", "collector", "machine", "pipe", "device"], 220, 210, .38, behind=True)
            put(["wax", "honey"], 85, 340, .8)
            put(["wax", "honey"], 1195, 340, .8, flip=True)
        elif rid == "cave_07":
            put(["pipe", "extractor", "collector", "device"], 560, 340, .25, behind=True)
            put(["honey", "wax"], 580, 340, .65)
            put(["return", "arch", "gate"], 200, 340, .6, behind=True, use="ENV-01")
        else:
            put(["hidden_crevice", "arch", "entrance", "rock"], 120, 340, .42, behind=True)
            put(["glow_roots", "stalactite", "ceiling"], w - 120, 0, .55, behind=True)
            put(["crystal", "mineral", "glow"], w - 90, 340, .75)
            if rid == "cave_01":
                put(["root"], 80, 340, .25, behind=True, use="ENV-02")
            if rid == "cave_04":
                put(["extractor", "pipe", "collector", "device"], 1050, 340, .4, behind=True, use="ENV-04")
                put(["wax", "honey"], 1170, 340, .7, use="ENV-04")
            elif rid == "cave_05":
                put(["rock", "stalagmite"], 75, 340, .75)
            elif rid == "cave_02":
                put(["crystal", "glow"], 280, 292, .75)
    for checkpoint in room["checkpoints"]:
        put(["campfire", "fire"], checkpoint["pos"][0], checkpoint["pos"][1] + 17, use="ENV-01")
    for chest in room["chests"]:
        # 复用原画箱体，隐藏款只在设计标记中呈现，避免背景泄露秘密。
        if not chest["hidden"]:
            put(["chest"], chest["pos"][0], chest["pos"][1] + 10, use="ENV-01")
    return back, front, placements


def markers(room, size, config):
    """生成可隐藏的设计图层，危险图层另行交付。"""
    guide = Image.new("RGBA", size)
    d = ImageDraw.Draw(guide)
    for door in room["doors"]:
        x, y = door["pos"]
        color = config["colors"]["gate"] if door["requires"] else config["colors"]["exit"]
        if door["one_way"]:
            color = config["colors"]["shortcut"]
        d.rectangle((max(0, x-6), max(0, y-25), min(size[0]-1, x+6), min(size[1]-1, y+12)), outline=color, width=2)
        label = ("IN " if door["one_way"] else "> ") + door["target"] + (" / 2J" if door["requires"] else "")
        tx = max(4, min(x - 8, size[0] - 190))
        d.text((tx, max(4, y - 45)), label, font=font(10), fill=color)
    for point in room["checkpoints"]:
        x, y = point["pos"]
        d.polygon([(x,y-14),(x-7,y),(x+7,y)], fill=config["colors"]["save"])
    for chest in room["chests"]:
        x, y = chest["pos"]
        d.rectangle((x-7, y-9, x+7, y), outline=config["colors"]["treasure"], width=2)
    for enemy in room["enemies"]:
        x, y = enemy["pos"]
        d.ellipse((x-5,y-8,x+5,y+2), outline=config["colors"]["enemy"], width=1)
    x, y = room["spawn"]
    d.ellipse((x-5,y-5,x+5,y+5), fill=config["colors"]["exit"])
    for path in config["rooms"][room["id"]].get("routes", []):
        d.line([tuple(p) for p in path], fill=config["colors"]["route"], width=2)
    return guide


def hazard_layer(room, size, config):
    out = Image.new("RGBA", size)
    d = ImageDraw.Draw(out)
    for x,y,w,h in room["hazards"]:
        # 独立的危险设计覆层，未假装已制作酸池动画。
        d.rectangle((x,y,x+w-1,y+h-1), fill=config["colors"]["hazard_fill"])
        for px in range(x, x+w, 8):
            d.line((px,y,min(px+4,x+w-1),y+min(h-1,4)), fill=config["colors"]["hazard_edge"], width=2)
    return out


def room_build(room, kits, config):
    rid = room["id"]
    outdir = BATCH / "maps" / rid
    outdir.mkdir(parents=True, exist_ok=True)
    size = (room["size"][0]*config["screen"][0], room["size"][1]*config["screen"][1])
    name = kit_id(room)
    kit = kits[name]
    bg_path = BATCH/name/kit["background"]
    if rid == "camp_02" and (BATCH/name/"interior_background.png").exists():
        bg_path = BATCH/name/"interior_background.png"
    bg = read_image(bg_path)
    offset_y = int(config["rooms"][rid].get("background_offset_y", 0))
    if offset_y:
        aligned = bg.crop((0, 0, bg.width, 1)).resize(bg.size, Image.Resampling.NEAREST)
        aligned.alpha_composite(bg, (0, offset_y))
        bg = aligned
    vp = BATCH/name/kit.get("background_vertical", "background_vertical.png")
    background = pano(bg, size, read_image(vp) if vp.exists() else None)
    wide_path = BATCH/name/kit.get("background_wide", "background_wide.png")
    if size[0] > bg.width and wide_path.exists():
        wide = read_image(wide_path)
        if wide.size == size:
            background = wide
    # 按房间安排整体明度；不改变原画几何。
    tone = config["rooms"][rid].get("background_brightness", 1)
    background = ImageEnhance.Brightness(background).enhance(tone)
    mid, props, placements = decoration(room, kits)
    ground = Image.new("RGBA", size)
    platforms = []
    for index, rect in enumerate(room["platforms"]):
        x,y,w,h = rect
        platform_kit = "ENV-04" if rid == "cave_04" and x >= 640 else name
        atlas = read_image(BATCH/platform_kit/kits[platform_kit]["terrain"])
        fragment, cells = platform_image(atlas,w,h,config["tile_size"])
        ground.alpha_composite(fragment,(x,y))
        # 每个平台自己的整数原点与本地16px网格，尾部用裁片。
        platforms.append({"index": index, "rect": rect, "kit":platform_kit,"cells":cells,
                          "global_grid_aligned": all(v%config["tile_size"]==0 for v in rect)})
    hazard = hazard_layer(room,size,config)
    guides = markers(room,size,config)
    layers = [("background",background,-30),("midground",mid,-12),("terrain",ground,0),("props",props,1),("hazards",hazard,2)]
    composite = Image.new("RGBA",size)
    for key,img,z in layers:
        img.save(outdir/(key+".png"))
        composite.alpha_composite(img)
    composite.save(outdir/"map.png")
    guides.save(outdir/"guides.png")
    overlay = composite.copy()
    overlay.alpha_composite(guides)
    overlay.save(outdir/"design.png")
    desc = config["rooms"][rid]
    manifest = {"id":rid,"name":room["name"],"size_px":size,"kit":name,"source":str(SOURCE.relative_to(ROOT)),
                "source_sha256":sha(SOURCE),"design":desc,"source_room":room,"platforms":platforms,
                "placements":placements,"layers":[{"path":key+".png","z_index":z} for key,_,z in layers],
                "limitations":["独立美术场景，不含敌人AI、开门、拾取、存档逻辑。","平台碰撞忠实保留源表，非整格矩形不吸附。","危险图层为静态设计覆盖，不是酸池动画。"]}
    save_json(outdir/"layout.json",manifest)
    # Tiled 也可按图层打开；精确地形与门等对象保存在对象层。
    tiled_layers=[]
    for i,(key,img,z) in enumerate(layers):
        tiled_layers.append({"id":i+1,"name":key,"type":"imagelayer","image":key+".png","opacity":1,"visible":True,"x":0,"y":0})
    objects=[]
    for i,rect in enumerate(room["platforms"]):
        x,y,w,h=rect
        objects.append({"id":i+1,"name":f"platform_{i}","type":"collision","x":x,"y":y,"width":w,"height":h,"rotation":0,"visible":True})
    tiled_layers.append({"id":6,"name":"Collision (source rectangles)","type":"objectgroup","objects":objects,"visible":False,"opacity":1,"x":0,"y":0,"draworder":"topdown"})
    save_json(outdir/"map.tmj",{"type":"map","version":"1.10","tiledversion":"1.11.2","orientation":"orthogonal","renderorder":"right-down","infinite":False,"tilewidth":16,"tileheight":16,"width":math.ceil(size[0]/16),"height":math.ceil(size[1]/16),"layers":tiled_layers,"tilesets":[],"nextlayerid":7,"nextobjectid":len(objects)+1})
    return {"id":rid,"name":room["name"],"kit":name,"size_px":size,"map":f"maps/{rid}/map.png","design":f"maps/{rid}/design.png","layout":f"maps/{rid}/layout.json","scene":f"maps/{rid}/{rid}.tscn","description":desc}


def overview(rooms, records, config):
    """按小地图坐标排总览，连接是拓扑关系。"""
    sx,sy,pad=config["overview"]["cell"]+[config["overview"]["padding"]]
    width=(max(r["map_rect"][0]+r["map_rect"][2] for r in rooms)+1)*sx+pad*2
    height=(max(r["map_rect"][1]+r["map_rect"][3] for r in rooms)+1)*sy+pad*2
    out=Image.new("RGB",(width,height),"#0c1518")
    d=ImageDraw.Draw(out)
    d.text((pad,16),"ENV-B01 / 15 ROOM WORLD ATLAS",font=font(22),fill="#f4e2b4")
    centers={}
    for room,rec in zip(rooms,records):
        x,y,w,h=room["map_rect"]
        px,py=pad+x*sx,pad+y*sy
        iw,ih=w*sx-12,h*sy-12
        img=Image.open(BATCH/rec["map"]).convert("RGB")
        img.thumbnail((iw,ih-34),Image.Resampling.NEAREST)
        d.rounded_rectangle((px,py,px+iw,py+ih),radius=6,fill="#172326",outline="#55615c")
        out.paste(img,(px+(iw-img.width)//2,py+25))
        d.text((px+6,py+4),rec["id"]+"  "+rec["name"],font=font(11),fill="#f4e2b4")
        centers[room["id"]]=(px+iw//2,py+ih//2)
    edges=set()
    for room in rooms:
        for door in room["doors"]:
            if door["one_way"]:
                continue
            edge=tuple(sorted([room["id"],door["target"]]))
            if edge in edges:
                continue
            edges.add(edge)
            a,b=centers[room["id"]],centers[door["target"]]
            col=config["colors"]["gate"] if door["requires"] else config["colors"]["shortcut"] if edge==("camp_01","cave_07") else config["colors"]["exit"]
            # 细线不掩盖地图内容，完整路由见HTML交互图。
            d.line([a,b],fill=col,width=2)
    d.text((pad,height-28),"Topology only / cyan: connection / gold: double jump / violet: return shortcut",font=font(12),fill="#aebfb9")
    out.save(BATCH/"world_atlas.png")


def write_preview(records, config):
    """写入自包含离线预览，图片嵌入便于直接双击打开。"""
    payload=[]
    for r in records:
        q=dict(r)
        for key,fn in [("image","map.png"),("guide","guides.png"),("terrain","terrain.png"),("bg","background.png"),("props","props.png")]:
            q[key]=data_url(BATCH/"maps"/r["id"]/fn)
        q["room"]=json.loads((BATCH/r["layout"]).read_text())["source_room"]
        payload.append(q)
    kits=[]
    for name in ("ENV-01","ENV-02","ENV-03","ENV-04"):
        kits.append({"id":name,"image":data_url(BATCH/name/"atlas_preview.png"),"terrain":data_url(BATCH/name/"terrain.png")})
    serialized=json.dumps({"rooms":payload,"kits":kits,"config":config},ensure_ascii=False).replace("</","<\\/")
    template=r'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>银河征途 · ENV-B01 地图工坊</title>
<style>*{box-sizing:border-box}body{margin:0;background:#0a1518;color:#d3e1d5;font:15px system-ui,sans-serif}header{padding:24px 32px;border-bottom:1px solid #344746;background:#102126;display:flex;justify-content:space-between;align-items:center}h1{font-size:24px;color:#f5e3b3;margin:4px 0}header small{letter-spacing:3px;color:#80b8a5}.badge{padding:8px 12px;border:1px solid #697156;border-radius:18px;color:#e6cd8e}.shell{display:grid;grid-template-columns:245px 1fr;min-height:90vh}aside{padding:20px;background:#0d1b1f;border-right:1px solid #344746}button,select{background:#183035;color:#d3e1d5;border:1px solid #3c5957;border-radius:6px;padding:9px;cursor:pointer}aside button{display:block;text-align:left;width:100%;margin-bottom:6px}button:hover,button.active{background:#32514a;border-color:#a1b99b}aside small{display:block;color:#81a49b}main{padding:24px;min-width:0}.tools{display:flex;gap:14px;align-items:center;flex-wrap:wrap;margin:18px 0}.viewport{overflow:auto;background:#071013;border:1px solid #3c5957;max-height:70vh;padding:16px}canvas,img.pixel{image-rendering:pixelated;display:block}h2{color:#f5e3b3;margin-top:0}.notes{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:18px}.card{background:#12252a;border:1px solid #2f4545;padding:16px;border-radius:8px}.card p{line-height:1.7;margin:8px 0}a{color:#92cbbb}.sub{color:#83a59c;font-size:13px}.route{padding:8px 14px;color:#ddc582;border-left:2px solid #b69b56}svg{max-width:100%;height:auto}label{cursor:pointer}.kitgrid{display:grid;grid-template-columns:1fr 1fr;gap:14px}.kitgrid img{max-width:100%;width:100%;image-rendering:pixelated}.legend{font-size:12px;color:#97b7ab}.warn{color:#d6bb84}.mono{font-family:monospace}@media(max-width:800px){.shell{grid-template-columns:1fr}aside{display:flex;flex-wrap:wrap;gap:4px}aside button{width:auto}.notes,.kitgrid{grid-template-columns:1fr}header{padding:16px}}</style>
<header><div><small>NAIBAO / GALACTIC ODYSSEY</small><h1>箱庭地图 · ENV-B01</h1><span class="sub">原创环境原画 → 16px 图块 → 15 房分层地图</span></div><div class="badge">3 区域 · 4 套件 · v001</div></header><div class="shell"><aside id="nav"></aside><main id="main"></main></div>
<script>const DATA=__DATA__;let selected=DATA.rooms[0],mode='map';let assets={};const $=s=>document.querySelector(s);const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function nav(){let s='<button onclick="world()">◎ 世界连接与回环</button><button onclick="kits()">▦ 四套图块套件</button><p class="sub">房间 / 点选查看完整地图</p>';for(let r of DATA.rooms)s+=`<button class="${mode==='map'&&r.id===selected.id?'active':''}" onclick="show('${r.id}')">${esc(r.name)}<small>${r.id} · ${r.size_px.join(' × ')}</small></button>`;$('#nav').innerHTML=s}
function img(src){return new Promise(resolve=>{let i=new Image;i.onload=()=>resolve(i);i.src=src})}
async function show(id){mode='map';selected=DATA.rooms.find(r=>r.id===id);nav();let r=selected;$('#main').innerHTML=`<h2>${esc(r.name)} <span class="sub mono">${r.id}</span></h2><div class="route">${esc(r.description.role)} · ${esc(r.description.landmark)}</div><div class="tools"><label>显示 <select id="layer"><option value="image">完整美术</option><option value="bg">背景</option><option value="terrain">地形</option><option value="props">装饰</option></select></label><label><input type="checkbox" id="guides">设计标记</label><label><input type="checkbox" id="grid">16px 网格</label><label><input type="checkbox" id="actor">角色比例</label><label>缩放 <select id="zoom"><option value="1">100%</option><option value="2">200%</option><option value=".5">50%</option></select></label></div><div class="viewport"><canvas id="map"></canvas></div><div class="notes"><div class="card"><b>构图安排</b><p>${esc(r.description.composition)}</p><span class="sub">${esc(r.description.pacing)}</span></div><div class="card"><b>路径与回访</b><p>${esc(r.description.exploration)}</p><span class="sub">${r.room.doors.map(d=>esc(d.id+' → '+d.target+(d.requires?' · 二段跳':'')+(d.one_way?' · 仅落点':''))).join('<br>')}</span></div><div class="card"><b>可编辑资源</b><p><a href="maps/${r.id}/${r.id}.tscn">Godot 美术场景</a> · <a href="maps/${r.id}/layout.json">分层布局</a> · <a href="maps/${r.id}/map.tmj">Tiled 图层</a> · <a href="maps/${r.id}/map.png" download>导出 PNG</a></p></div><div class="card warn"><b>验收范围</b><p>本页是美术与空间设计预览。门、怪物、奖励是设计标记；危险为静态覆盖。游戏通关和关卡合并需后续联调。</p></div></div>`;assets={};for(let key of ['image','guide','terrain','bg','props'])assets[key]=await img(r[key]);if(DATA.actor)assets.actor=await img(DATA.actor);for(let key of ['layer','guides','grid','actor','zoom'])$('#'+key).onchange=draw;draw()}
function draw(){let c=$('#map');if(!c)return;let ctx=c.getContext('2d'),r=selected;c.width=r.size_px[0];c.height=r.size_px[1];ctx.imageSmoothingEnabled=false;ctx.fillStyle='#101e22';ctx.fillRect(0,0,c.width,c.height);ctx.drawImage(assets[$('#layer').value],0,0);if($('#guides').checked)ctx.drawImage(assets.guide,0,0);if($('#actor').checked&&assets.actor){let p=r.room.spawn;ctx.drawImage(assets.actor,p[0]-32,p[1]+17-58)}if($('#grid').checked){ctx.strokeStyle='#99b6a72f';ctx.lineWidth=1;for(let x=.5;x<c.width;x+=16){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,c.height);ctx.stroke()}for(let y=.5;y<c.height;y+=16){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(c.width,y);ctx.stroke()}}let z=Number($('#zoom').value);c.style.width=c.width*z+'px';c.style.height=c.height*z+'px'}
function kits(){mode='kits';nav();$('#main').innerHTML='<h2>四套环境图块</h2><p class="sub">每套 64×64 图集 / 16 张 16×16 图块。当前提供明确索引绘制，不宣称完整 47 格自动地形。</p><div class="kitgrid">'+DATA.kits.map(k=>`<div class="card"><h3>${k.id}</h3><img class="pixel" src="${k.image}"><p><a href="${k.id}/kit.json">来源与规格</a> · <a href="godot/${k.id}.tres">Godot TileSet</a> · <a href="${k.id}/README.md">制作说明</a></p></div>`).join('')+'</div>'}
function world(){mode='world';nav();let nodes=DATA.rooms.map(r=>{let q=r.room.map_rect;return {r,x:60+q[0]*92,y:90+q[1]*96,w:q[2]*92-12,h:q[3]*96-12}}),lookup=Object.fromEntries(nodes.map(n=>[n.r.id,n])),seen=new Set(),lines='';for(let n of nodes)for(let d of n.r.room.doors){if(d.one_way)continue;let key=[n.r.id,d.target].sort().join('|');if(seen.has(key))continue;seen.add(key);let b=lookup[d.target],col=d.requires?'#f1c66e':key==='camp_01|cave_07'?'#c6a8ec':'#7abfb0';lines+=`<path d="M${n.x+n.w/2} ${n.y+n.h/2} L${b.x+b.w/2} ${b.y+b.h/2}" stroke="${col}" fill="none" stroke-width="3" ${d.requires?'stroke-dasharray="5 4"':''}/>`}let blocks=nodes.map(n=>`<g tabindex="0" role="button" aria-label="${esc(n.r.name)}" onclick="show('${n.r.id}')" onkeydown="if(event.key==='Enter')show('${n.r.id}')" style="cursor:pointer"><rect x="${n.x}" y="${n.y}" width="${n.w}" height="${n.h}" rx="6" fill="${n.r.kit==='ENV-01'?'#4d4030':n.r.kit==='ENV-02'?'#244a3c':n.r.kit==='ENV-03'?'#36364d':'#5c4730'}" stroke="#b5b99b"/><text x="${n.x+7}" y="${n.y+22}" fill="#f4e7be" font-size="12">${esc(n.r.name)}</text><text x="${n.x+7}" y="${n.y+42}" fill="#a6c2b6" font-size="10">${n.r.id}</text></g>`).join('');$('#main').innerHTML=`<h2>空间连接 / 主线与回环</h2><p class="legend">青绿：连接　金色虚线：二段跳　紫色：女王后单向回营（cave_07 → camp_01）</p><div class="viewport"><svg viewBox="0 0 1600 780" style="min-width:1000px" aria-label="15房世界拓扑连接图">${lines}${blocks}<text x="60" y="55" fill="#f4e7be" font-size="23">15 ROOMS / THREE REGIONS / ONE RETURN LOOP</text></svg></div><div class="notes"><div class="card"><b>主线</b><p>营地 → 林地入口 → 深林 → 洞窟入口 → 前厅 → 回廊 → 酸池 → 蜂巢外围 → 女王大厅 → 奖励房。</p></div><div class="card"><b>回环与回访</b><p>forest_01—forest_02—forest_04 形成林地环；cave_07 返回营地。取得二段跳后重访断桥与树冠。</p></div></div><p class="warn">位置来自 map_rect，为拓扑示意；门线不等同连续世界坐标。能力门标签不证明跳跃物理上不可绕过。</p>`}
nav();world();</script></html>'''
    actor=ROOT/"assets/PROCESSED/characters/CHR-01/v001/frames/CHR-01_player_idle_right_v001_f01.png"
    data={"rooms":payload,"kits":kits,"config":config}
    if actor.exists():data["actor"]=data_url(actor)
    serialized=json.dumps(data,ensure_ascii=False).replace("</","<\\/")
    template = template.replace('stroke="${col}" fill="none" stroke-width="3"', 'stroke="${col}" fill="none" stroke-width="3" ${key===\'camp_01|cave_07\'?\'marker-end="url(#returnArrow)"\':\'\'}')
    template = template.replace('${lines}${blocks}', '<defs><marker id="returnArrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 Z" fill="#c6a8ec"/></marker></defs>${lines}${blocks}')
    (BATCH/"preview.html").write_text(template.replace("__DATA__",serialized))


def main():
    """生成完整地图、世界总览与交付索引。"""
    parser=argparse.ArgumentParser()
    parser.add_argument("--config",default=str(ROOT/"tools/environment_map_design.json"))
    args=parser.parse_args()
    config=json.loads(Path(args.config).read_text())
    rooms=json.loads(SOURCE.read_text())["rooms"]
    kits={name:json.loads((BATCH/name/"kit.json").read_text()) for name in ("ENV-01","ENV-02","ENV-03","ENV-04")}
    records=[room_build(room,kits,config) for room in rooms]
    overview(rooms,records,config)
    write_preview(records,config)
    save_json(BATCH/"manifest.json",{"batch":"ENV-B01","version":"v001","source":str(SOURCE.relative_to(ROOT)),"source_sha256":sha(SOURCE),"screen":config["screen"],"tile_size":config["tile_size"],"kits":list(kits),"rooms":records,"design_research":"docs/地图设计研究-ENV-B01.md"})
    print(f"ENV-B01: {len(kits)} kits / {len(records)} rooms / layered maps + offline preview")


if __name__=="__main__":
    main()
