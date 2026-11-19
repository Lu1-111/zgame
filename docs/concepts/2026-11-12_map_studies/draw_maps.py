"""绘制独立关卡概念图（PNG + 可编辑SVG），不生成或覆盖游戏场景。"""
from pathlib import Path
from math import atan2, cos, sin, hypot
from html import escape
import json
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = Path(__file__).resolve().parent
COL = dict(paper='#f3f2eb', ink='#263b38', muted='#60716a', wall='#858b82',
           air='#fbfcf8', edge='#35443f', blue='#049dce', chest='#e7b82f',
           sealed='#a647ac', mob='#a32847', fire='#2e9b5b', gate='#ed7d35',
           main='#167e82', branch='#ae7c19', shortcut='#7963ac')
FONT = 'C:/Windows/Fonts/msyh.ttc'
BOLD = 'C:/Windows/Fonts/msyhbd.ttc'



class Drawing:
    def __init__(self):
        self.im = Image.new('RGB', (1440, 1264), COL['paper'])
        self.d = ImageDraw.Draw(self.im)
        self.svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="1264" viewBox="0 0 1440 1264">',
                    '<rect width="1440" height="1264" fill="'+COL['paper']+'"/>']

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


def map_draw(config):
    """从独立JSON设计源导出一张完整概念图。"""
    page = Drawing()
    width, height = config['size']
    ox, oy = (1440-width)//2, 164
    page.text((64,30), config['title'], 37, bold=True)
    page.text((66,84), config['subtitle'],22)
    page.text((66,123),config['scale']+'  |  灰盒概念，尚未实装与跳跃验证',17,COL['muted'])
    mask = Image.new('L',(width,height),0)
    md = ImageDraw.Draw(mask)
    for points in config['air']:
        md.polygon(points,fill=255)
    for points in config.get('solid',[]):
        md.polygon(points,fill=0)
    for points in config.get('cut',[]):
        md.polygon(points,fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(2)).point(lambda n:255 if n>=128 else 0)
    cropped = Image.new('RGB',(width,height),COL['wall'])
    cropped.paste(COL['edge'],mask=mask)
    cropped.paste(COL['air'],mask=mask.filter(ImageFilter.MinFilter(5)))
    page.im.paste(cropped,(ox,oy))
    # SVG使用相同开洞/填实顺序；mask整体腐蚀后得到无交叉线的墙体边界。
    shapes=[]
    for role,fill in [('air','white'),('solid','black'),('cut','white')]:
        for pts in config.get(role,[]):
            shapes.append('<polygon points="'+' '.join(f'{x},{y}' for x,y in pts)+f'" fill="{fill}"/>')
    page.svg.append(f'<defs><filter id="erode"><feMorphology operator="erode" radius="2"/></filter><mask id="space" maskUnits="userSpaceOnUse" x="0" y="0" width="{width}" height="{height}"><rect width="{width}" height="{height}" fill="black"/>'+''.join(shapes)+'</mask></defs>')
    page.svg.append(f'<g transform="translate({ox} {oy})"><rect width="{width}" height="{height}" fill="{COL["wall"]}"/><rect width="{width}" height="{height}" fill="{COL["edge"]}" mask="url(#space)"/><g filter="url(#erode)"><rect width="{width}" height="{height}" fill="{COL["air"]}" mask="url(#space)"/></g></g>')
    def p(x,y): return (x+ox,y+oy)
    for x,y,w in config['platforms']:
        page.line([p(x,y),p(x+w,y)],COL['blue'],4)
    for role, points in config['routes']:
        page.line([p(*point) for point in points], COL[role],3,role!='main',True)
    for kind,x,y in config['objects']:
        page.symbol(x+ox,y+oy,kind)
    for x,y,txt,role in config['labels']:
        page.label(x+ox,y+oy,txt,COL.get(role,COL['ink']))
    page.text((64,1090),config['takeaway'],21,bold=True)
    y=1145
    legends=[('wall','实心墙'),('blue','空心平台'),('chest','普通箱'),('sealed','清怪箱'),('mob','小怪'),('elite','精英'),('fire','篝火'),('gate','封印门')]
    for idx,(kind,label) in enumerate(legends):
        x=78+idx*164
        if kind=='wall': page.box((x-10,y-20,x+12,y),COL['wall'])
        elif kind=='blue': page.line([(x-12,y-9),(x+14,y-9)],COL['blue'],4)
        else: page.symbol(x,y,kind)
        page.text((x+22,y-21),label,18)
    for x,role,label in [(64,'main','主路'),(275,'branch','可选探索 / 分岔'),(680,'shortcut','从异侧解锁的返程捷径')]:
        page.line([(x,1192),(x+60,1192)],COL[role],3,role!='main',True)
        page.text((x+74,1180),label,18)
    page.line([(1130,1180),(1130,1206)],COL['shortcut'],6)
    page.text((1147,1180),'异侧开启门',18)
    page.text((64,1230),'地形与物件为设计示意；正式制作时主路台阶按 ≤0.9 单跳高度重排，奖励与敌人数值另定。',16,COL['muted'])
    name=config['id']
    page.im.save(OUT/(name+'.png'))
    (OUT/(name+'.svg')).write_text('\n'.join(page.svg+['</svg>']),encoding='utf-8')
    print(name, 'PNG + SVG', page.im.size)


if __name__ == '__main__':
    configs = json.loads((OUT/'concepts.json').read_text(encoding='utf-8'))
    for config in configs:
        map_draw(config)
