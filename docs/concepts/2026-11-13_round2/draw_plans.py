"""绘制独立关卡概念图（PNG + 可编辑SVG），不生成或覆盖游戏场景。"""
from pathlib import Path
from math import atan2, cos, sin, hypot
from html import escape
import json
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = Path(__file__).resolve().parent
COL = dict(paper='#f4f2e8', ink='#263b38', muted='#60716a', wall='#80866e',
           air='#fbfcf8', edge='#35443f', blue='#049dce', chest='#e7b82f',
           sealed='#a647ac', mob='#a32847', fire='#2e9b5b', gate='#ed7d35',
           main='#167e82', branch='#ae7c19', shortcut='#7963ac')
FONT = 'C:/Windows/Fonts/msyh.ttc'
BOLD = 'C:/Windows/Fonts/msyhbd.ttc'



class Drawing:
    def __init__(self):
        self.im = Image.new('RGB', (2144, 1560), COL['paper'])
        self.d = ImageDraw.Draw(self.im)
        self.svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="2144" height="1560" viewBox="0 0 2144 1560">',
                    '<rect width="2144" height="1560" fill="'+COL['paper']+'"/>']

    def box(self, xy, fill, outline=None, radius=0):
        """绘制带可选圆角的标注底板。"""
        self.d.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=1)
        x, y, x1, y1 = xy
        self.svg.append(f'<rect x="{x}" y="{y}" width="{x1-x}" height="{y1-y}" rx="{radius}" fill="{fill}" stroke="{outline or "none"}"/>')

    def text(self, xy, txt, size=20, color=None, bold=False):
        """在PNG与SVG中写入同一条中文标注。"""
        color = color or COL['ink']
        font = ImageFont.truetype(BOLD if bold else FONT, size)
        self.d.text(xy, txt, font=font, fill=color, anchor='lt')
        self.svg.append(f'<text x="{xy[0]}" y="{xy[1]+size*.92}" font-family="Microsoft YaHei, sans-serif" font-size="{size}" font-weight="{700 if bold else 400}" fill="{color}">{escape(txt)}</text>')

    def line(self, pts, color, width=3, dashed=False, arrow=False):
        """绘制平台、虚线与带箭头的路线。"""
        for a, b in zip(pts, pts[1:]):
            dx, dy = b[0]-a[0], b[1]-a[1]
            length = hypot(dx, dy)
            if dashed and length:
                for pos in range(0, int(length), 17):
                    end = min(pos+10, length)
                    self.d.line([(a[0]+dx*pos/length, a[1]+dy*pos/length),
                                 (a[0]+dx*end/length, a[1]+dy*end/length)], fill=color, width=width)
            else:
                self.d.line([a, b], fill=color, width=width)
        raw = ' '.join(f'{x},{y}' for x, y in pts)
        dash = ' stroke-dasharray="10 7"' if dashed else ''
        self.svg.append(f'<polyline points="{raw}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round"{dash}/>')
        if arrow and len(pts)>1:
            a, b = pts[-2:]
            angle = atan2(b[1]-a[1], b[0]-a[0])
            self.polygon([b, (b[0]-13*cos(angle-.47), b[1]-13*sin(angle-.47)),
                          (b[0]-13*cos(angle+.47), b[1]-13*sin(angle+.47))], color)

    def polygon(self, pts, color):
        """填充怪物符号或箭头的多边形。"""
        self.d.polygon(pts, fill=color)
        self.svg.append('<polygon points="'+' '.join(f'{x},{y}' for x,y in pts)+f'" fill="{color}"/>')

    def symbol(self, x, y, kind):
        """按共同图例绘制宝箱、篝火、敌人与门。"""
        if kind in ('chest', 'sealed', 'fire'):
            self.box((x-11, y-21, x+11, y-1), COL[kind], COL['edge'], 2)
        elif kind == 'mob':
            self.polygon([(x,y-22),(x-12,y-1),(x+12,y-1)], COL['mob'])
        elif kind == 'elite':
            self.polygon([(x,y-33),(x-14,y-16),(x,y+1),(x+14,y-16)], COL['mob'])
        elif kind == 'gate':
            self.line([(x-12,y-30),(x+12,y+30)],COL['gate'],5)
            self.line([(x+12,y-30),(x-12,y+30)],COL['gate'],5)
        elif kind == 'door':
            self.line([(x,y-32),(x,y+32)],COL['shortcut'],7)

    def label(self, x, y, txt, color=None):
        """绘制自适应宽度的说明框。"""
        font = ImageFont.truetype(FONT, 18)
        width = font.getlength(txt)+20
        self.box((x-8,y-5,x+width,y+26),COL['air'],'#c9d0c7',5)
        self.text((x+2,y),txt,18,color)


# 设计图渲染参数，不参与游戏运行或平衡。
COL.update(ability='#b66320', branch='#a57621', muted='#6b756a')
MAP_O=(56,184)
MAP_SIZE=(1280,904)


def _mask(plan):
    mask=Image.new('L',MAP_SIZE,0)
    d=ImageDraw.Draw(mask)
    for points in plan['air']:
        d.polygon([tuple(p) for p in points],fill=255)
    return mask.filter(ImageFilter.GaussianBlur(5)).point(lambda p:255 if p>=128 else 0)


def _terrain(plan, opened=()):
    """生成与SVG相同几何的剖面底图；镜头裁切不含全图说明文字。"""
    mask=_mask(plan)
    im=Image.new('RGB',MAP_SIZE,COL['wall'])
    d=ImageDraw.Draw(im)
    # 墙内细线标出木/岩的连续走向，帮助区分实体与空洞。
    for x in range(-500,1600,46):
        d.line([(x,0),(x+400,904)],fill='#777d68',width=1)
    im.paste(COL['edge'],mask=mask)
    im.paste(COL['air'],mask=mask.filter(ImageFilter.MinFilter(5)))
    d=ImageDraw.Draw(im)
    for x,y,w in plan['platforms']:
        d.line([(x,y),(x+w,y)],fill=COL['blue'],width=4)
    for g in plan['gates']:
        x,y,w,h=g['rect']
        if g['id'] in opened:
            d.rectangle((x,y,x+w,y+h),outline='#bcb5c8',width=2)
        else:
            d.rectangle((x,y,x+w,y+h),fill=COL['shortcut'],outline='#504466',width=2)
    for n in plan['nodes']:
        if n['kind']=='fire':
            x,y=n['pos']; d.rectangle((x-10,y-20,x+10,y-1),fill=COL['fire'],outline=COL['edge'])
    for kind,x,y in plan.get('landmarks',[]):
        if kind=='lamp':
            d.rectangle((x-5,y-5,x+5,y-1),fill='#6a715d')
            d.rectangle((x-2,y-18,x+2,y-5),fill='#69735f')
            d.ellipse((x-4,y-23,x+4,y-15),fill='#a6cbbb',outline='#4d695a')
        else:
            d.polygon([(x-7,y-1),(x-5,y-20),(x+3,y-24),(x+8,y-14),(x+6,y-1)],fill='#9caa91',outline='#586651')
    for kind,x,y in plan['objects']:
        if kind in ('chest','sealed'):
            d.rectangle((x-10,y-18,x+10,y-1),fill=COL[kind],outline=COL['edge'])
        elif kind=='elite':
            d.polygon([(x,y-29),(x+12,y-15),(x,y),(x-12,y-15)],fill=COL['mob'])
        else:
            d.polygon([(x,y-20),(x+10,y),(x-10,y)],fill=COL['mob'])
    return im


def _wrap(text,width,size=21,bold=False):
    font=ImageFont.truetype(BOLD if bold else FONT,size)
    lines=[]; current=''
    for ch in text:
        if current and font.getlength(current+ch)>width:
            lines.append(current); current=''
        current+=ch
    if current: lines.append(current)
    return lines


def _paragraph(page,x,y,text,width=620,size=21,color=None,bold=False):
    for line in _wrap(text,width,size,bold):
        page.text((x,y),line,size,color,bold)
        y+=size+11
    return y


def _flow(page,x,y,ids,color):
    """把状态路线画成与剖面节点一致的小图。"""
    for i,key in enumerate(ids):
        px=x+i*83
        page.box((px,y,px+57,y+38),COL['air'],color,7)
        page.text((px+15,y+7),key,22,color,True)
        if i<len(ids)-1:
            page.line([(px+62,y+19),(px+77,y+19)],color,2,False,True)


def _badge(page,x,y,key,color):
    page.box((x-15,y-18,x+16,y+12),COL['air'],color,10)
    page.text((x-9,y-15),key,19,color,True)


def _map_svg(page,plan):
    """保留可编辑的房间轮廓、平台与对象，不嵌入PNG。"""
    ox,oy=MAP_O
    shapes=''.join('<polygon points="'+' '.join(f'{x},{y}' for x,y in pts)+'" fill="white"/>' for pts in plan['air'])
    page.svg.append('<defs><filter id="erode"><feMorphology operator="erode" radius="2"/></filter><mask id="space" maskUnits="userSpaceOnUse" x="0" y="0" width="1280" height="904"><rect width="1280" height="904" fill="black"/>'+shapes+'</mask></defs>')
    page.svg.append(f'<g transform="translate({ox} {oy})"><rect width="1280" height="904" fill="{COL["wall"]}"/><rect width="1280" height="904" fill="{COL["edge"]}" mask="url(#space)"/><g filter="url(#erode)"><rect width="1280" height="904" fill="{COL["air"]}" mask="url(#space)"/></g></g>')
    # 用同源矢量对象建立SVG；PNG已有对象，不在此重复绘制。
    original=page.im.copy()
    for x,y,w in plan['platforms']:
        page.line([(x+ox,y+oy),(x+w+ox,y+oy)],COL['blue'],4)
    for g in plan['gates']:
        x,y,w,h=g['rect']; page.box((x+ox,y+oy,x+w+ox,y+h+oy),COL['shortcut'])
    for n in plan['nodes']:
        if n['kind']=='fire': page.symbol(n['pos'][0]+ox,n['pos'][1]+oy,'fire')
    for kind,x,y in plan.get('landmarks',[]):
        if kind=='lamp':
            page.box((x+ox-2,y+oy-18,x+ox+2,y+oy-1),'#69735f')
            page.box((x+ox-4,y+oy-23,x+ox+4,y+oy-15),'#a6cbbb','#4d695a',4)
        else:
            page.polygon([(x+ox-7,y+oy-1),(x+ox-5,y+oy-20),(x+ox+3,y+oy-24),(x+ox+8,y+oy-14),(x+ox+6,y+oy-1)],'#9caa91')
    for kind,x,y in plan['objects']:
        page.symbol(x+ox,y+oy,kind)
    page.im=original; page.d=ImageDraw.Draw(page.im)


def _camera(page,plan,camera,x,y):
    """以320×180草图单位表示640×360世界单位的设计镜头。"""
    from base64 import b64encode
    from io import BytesIO
    terrain=_terrain(plan,camera['open'])
    fx,fy=camera['foot']
    cx=max(160,min(1120,fx)); cy=max(90,min(814,fy-8))
    crop=terrain.crop((cx-160,cy-90,cx+160,cy+90))
    d=ImageDraw.Draw(crop)
    px,py=fx-cx+160,fy-cy+90
    d.rectangle((px-4,py-17,px+4,py-1),fill='#edca56',outline='#6f531f',width=1)
    crop=crop.resize((384,216),Image.Resampling.NEAREST)
    page.im.paste(crop,(x,y))
    # 关键镜头是剖面裁切的预览图；主剖面仍为可编辑矢量。
    b=BytesIO(); crop.save(b,format='PNG')
    page.svg.append(f'<image x="{x}" y="{y}" width="384" height="216" href="data:image/png;base64,{b64encode(b.getvalue()).decode()}"/>')
    page.d.rectangle((x,y,x+384,y+216),outline=COL['edge'],width=1)
    page.svg.append(f'<rect x="{x}" y="{y}" width="384" height="216" fill="none" stroke="{COL["edge"]}"/>')


def _draw(plan):
    page=Drawing()
    page.text((56,28),plan['title'],44,bold=True)
    page.text((56,94),plan['theme'],25)
    page.text((58,140),'第二轮概念 · 世界尺度参考2560×1808 · 主路 / 状态变化 / 640×360设计镜头',18,COL['muted'])
    page.box((1716,35,2088,78),'#e7e9dc',None,12)
    page.text((1738,45),'设计提案，尚未实装或物理走查',20)
    page.im.paste(_terrain(plan),MAP_O)
    _map_svg(page,plan)
    ox,oy=MAP_O
    for role,pts in plan['routes']:
        page.line([(x+ox,y+oy) for x,y in pts],COL[role],3,role!='main',True)
    for x,y,txt in plan['labels']:
        page.label(x+ox,y+oy,txt)
    for n in plan['nodes']:
        x,y=n['pos']; color=COL['fire'] if n['kind']=='fire' else (COL['mob'] if n['kind']=='target' else COL['main'])
        _badge(page,x+ox-22,y+oy-42,n['id'],color)
    for g in plan['gates']:
        x,y,w,h=g['rect']
        page.label(x+ox+w+9,y+oy-31 if h>w else y+oy,g['id'],COL['shortcut'])
    for i,c in enumerate(plan['cameras']):
        x,y=c['foot']; page.text((x+ox+8,y+oy-24),c['id'],17,'#7b6525',True)
        page.box((x+ox-3,y+oy-4,x+ox+3,y+oy+2),'#edca56','#6f531f',2)
    # 只显示V1的视口范围，避免三个大框遮住地形。
    fx,fy=plan['cameras'][0]['foot']; cx=max(160,min(1120,fx)); cy=max(90,min(814,fy-8))
    corners=[(cx-160,cy-90),(cx+160,cy-90),(cx+160,cy+90),(cx-160,cy+90),(cx-160,cy-90)]
    page.line([(x+ox,y+oy) for x,y in corners],'#9d947a',1,True)
    # 右侧：先交代空间来源，再展示不同状态下的可用路线。
    page.box((1384,184,2088,1504),'#ebece1',None,15)
    page.text((1410,207),'空间与路线',27,bold=True)
    y=_paragraph(page,1410,250,plan['premise'],646,21)+20
    for card in plan['cards']:
        role=card['kind']; color=COL.get(role,COL['ink'])
        height=54+sum(len(_wrap(t,614,20))*29 for t in card['lines'])+(58 if card.get('flow') else 0)
        page.box((1404,y,2068,y+height),COL['air'],None,12)
        page.text((1424,y+15),card['title'],24,color,True)
        yy=y+54
        if card.get('flow'):
            _flow(page,1424,yy,card['flow'],color); yy+=56
        for line in card['lines']:
            for text in _wrap(line,614,20):
                page.text((1424,yy),text,20); yy+=29
        y+=height+14
    if y+40+((len(plan['nodes'])+1)//2)*32<1490:
        page.text((1424,y+10),'节点对照',21,bold=True)
        for i,node in enumerate(plan['nodes']):
            xx=1424+(i%2)*317; yy=y+49+(i//2)*32
            page.text((xx,yy),node['id']+'  '+node['name'],18)
    # 与制作人沿用相同对象图例；路线颜色另外说明。
    legends=[('wall','实心地形'),('blue','空心平台'),('chest','普通箱'),('sealed','清怪箱'),('mob','小怪'),('elite','精英'),('fire','篝火')]
    for i,(kind,label) in enumerate(legends):
        x=72+i*178; yy=1132
        if kind=='wall': page.box((x-10,yy-18,x+12,yy+2),COL['wall'])
        elif kind=='blue': page.line([(x-12,yy-8),(x+14,yy-8)],COL['blue'],4)
        else: page.symbol(x,yy+2,kind)
        page.text((x+22,yy-18),label,18)
    for x,key,label in [(58,'main','首次主路线'),(340,'branch','分岔 / 探索'),(610,'shortcut','开通后的路线'),(960,'ability','能力回访')]:
        page.line([(x,1164),(x+54,1164)],COL[key],3,key!='main',True)
        page.text((x+65,1153),label,18)
    page.text((56,1193),'关键镜头示意：按640×360世界单位裁切，黄色小块为角色站位；不代表已完成运行时镜头验证。',18,COL['muted'])
    for i,camera in enumerate(plan['cameras']):
        x=56+i*432
        _camera(page,plan,camera,x,1230)
        page.text((x,1457),camera['id']+' · '+camera['title'],18,bold=True)
        _paragraph(page,x,1488,camera['note'],398,16,COL['muted'])
    page.text((56,1535),'S / A…为对应空间节点；G为永久通路。箭头表示行进意图，平台间距、封闭性和战斗需进入灰盒验证。',17,COL['muted'])
    name=plan['id']
    page.im.save(OUT/(name+'.png'))
    (OUT/(name+'.svg')).write_text('\n'.join(page.svg+['</svg>']),encoding='utf-8')
    print(name,'PNG/SVG',page.im.size,'cards_end_y=',y)


if __name__=='__main__':
    plans=json.loads((OUT/'plans.json').read_text(encoding='utf-8'))
    for plan in plans: _draw(plan)

