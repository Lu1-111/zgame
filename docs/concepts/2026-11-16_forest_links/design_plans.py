"""森林互联备选：只生成可评审剖面与连接草图，不创建Godot场景或修改运行地图。"""
from pathlib import Path
from html import escape
import json, math
import pymupdf

OUT=Path(__file__).resolve().parent
P=[]
def plan(id,title,kind,paths,ports,stations,route,shortcut,lock,notes,theme=None,rooms=None,mobs=None):
    P.append(dict(id=id,title=title,kind=kind,air=paths,ports=ports,stations=stations,first_route=route,
      shortcut=shortcut,ability_route=lock,notes=notes,theme=theme or [],rooms=rooms or [],mobs=mobs or [],
      status='proposal_only',world_reference=[2560,1808],scale=.375))

# Common physical exits are retained across A/B, so selections can be combined independently.
plan('05A','分水根庭','解谜一 · 双闸分水',
 [[[0,570],[200,570],[200,410],[480,410],[480,210],[790,210],[790,410],[960,410]],
  [[200,570],[790,570],[790,410]],[[200,410],[200,210],[480,210]],[[790,210],[960,210]]],
 [('E1',0,570,'01上层新增侧口'),('E2',960,410,'02上层新增侧口'),('E3',960,210,'08西侧')],
 [('fire',80,608,'S'),('switch',200,450,'A'),('switch',650,250,'B'),('gate',790,410,'G'),('chest',870,248,'R')],
 [[70,570],[200,570],[200,410],[480,410],[480,210],[650,210],[790,210],[790,410],[920,410]],
 [[205,570],[760,570],[790,410]],[[200,410],[200,300],[480,210]],
 ['初访：下闸A放干中渠，沿根井抵达上闸B，再排水接通E2/E3。',
  '捷径G：到达B后打开干渠底门；01与02之间可走低层直廊，跳过控制井。',
  '二段跳：跨160px高根脊直上B背后，回访时绕过闸门操作；奖励R不锁主路。',
  '复位：两闸旁均能复位，落水进可走底渠；水位不封死E1退路。'],
 theme=[('water',270,535,430,60),('water',265,400,180,50)])
plan('05B','双篮树井','解谜一 · 配重升降',
 [[[0,570],[220,570],[220,410],[700,410],[960,410]],
  [[220,410],[220,180],[700,180],[700,410]],[[220,570],[700,570],[700,180]],[[700,180],[960,180]]],
 [('E1',0,570,'01上层新增侧口'),('E2',960,410,'02上层新增侧口'),('E3',960,180,'08西侧')],
 [('fire',75,608,'S'),('switch',220,608,'A'),('switch',560,448,'B'),('gate',700,410,'G'),('chest',875,218,'R')],
 [[60,570],[220,570],[220,410],[550,410],[700,410],[700,180],[915,180]],
 [[220,570],[700,570],[700,410]],[[220,410],[395,310],[700,180]],
 ['初访：下篮A装配重→中层B换载→右篮上升，形成三层位置谜题。',
  '捷径G：在中层背面解除底廊栅栏，跨01/02回访不必重新搬配重。',
  '二段跳：左右篮之间的高根窝成为短接点；普通跳跃仍能沿外井回退。',
  '复位：控制柄可召回篮筐，配重回起点；所有篮位都保留一条步行出口。'],
 theme=[('basket',220,325,70,20),('basket',700,530,70,20)])
plan('06A','折光菌窟','解谜二 · 两层折光',
 [[[0,240],[230,240],[230,520],[720,520],[720,350],[960,350]],
  [[230,240],[720,240],[720,520]],[[400,520],[400,350],[720,350]],[[720,520],[960,520]]],
 [('E1',0,240,'02下层新增侧口'),('E2',960,350,'03中层新增侧口'),('E3',960,520,'09西侧')],
 [('fire',100,278,'S'),('switch',230,278,'A'),('switch',400,558,'B'),('switch',720,388,'C'),('gate',720,520,'G'),('chest',870,558,'R')],
 [[65,240],[230,240],[230,520],[400,520],[400,350],[720,350],[920,350]],
 [[230,240],[720,240],[720,350]],[[400,520],[550,420],[720,350]],
 ['初访：上层光源A→下层镜座B→东侧接收器C；中途能从窗口看到结果。',
  '捷径G：接收器通电后解锁上层直廊，E1至E2省去下井与镜座段。',
  '二段跳：中窟高菌台直达C背面，并接通藏箱；普通路线不要求该能力。',
  '复位：镜座转向有限档，可随时重置；调光只动机关，不伤玩家或锁回程。'],
 theme=[('light',230,240,400,520),('light',400,520,720,350)])
plan('06B','风息风琴','解谜二 · 三阀导风',
 [[[0,240],[300,240],[300,500],[770,500],[770,350],[960,350]],
  [[300,240],[770,240],[770,500]],[[300,500],[120,500],[120,590],[770,590]],[[770,590],[960,590]]],
 [('E1',0,240,'02下层新增侧口'),('E2',960,350,'03中层新增侧口'),('E3',960,590,'09西侧')],
 [('fire',90,278,'S'),('switch',300,278,'A'),('switch',140,538,'B'),('switch',610,538,'C'),('gate',770,350,'G'),('chest',875,628,'R')],
 [[70,240],[300,240],[300,500],[140,500],[610,500],[770,500],[770,350],[920,350]],
 [[300,240],[770,240],[770,350]],[[300,500],[520,380],[770,240]],
 ['初访：A选支管→B开回流→C调排风，依三片风叶的可见转动判断通断。',
  '捷径G：三阀到位抬起中层挡板，E1直通E2；以后不重复解谜。',
  '二段跳：越过回流腔上沿的根台，连接上层管廊，回访可横穿。',
  '复位：失误只停风、不扣血；每阀可回初始档，下检修道始终通往入口。'],
 theme=[('wind',330,500,720,240),('wind',150,590,600,590)])
plan('07A','断冠攀环','跑酷 · 绕柱上升',
 [[[0,570],[220,570],[220,400],[500,400],[500,230],[780,230],[780,110],[960,110]],
  [[220,570],[780,570],[780,400],[500,400]],[[780,230],[960,230]],[[220,400],[220,160],[500,160],[500,230]]],
 [('E1',0,570,'03上层新增竖口'),('E2',960,230,'04待建上层'),('E3',960,110,'08东侧·二段跳')],
 [('fire',80,608,'S'),('switch',500,438,'A'),('gate',780,400,'G'),('chest',870,268,'R'),('ability',780,150,'D')],
 [[65,570],[220,570],[220,400],[500,400],[500,230],[780,230],[900,230]],
 [[220,570],[780,570],[780,400],[500,400]],[[780,230],[780,110],[920,110]],
 ['初访：沿巨根外缘分三段攀升，中段A是安全歇脚点；主奖励R在E2前。',
  '捷径G：到达中段可从背面放下根桥；失误后从下方兜底台快速回中段。',
  '二段跳：主奖励后跨160px高冠口到E3，成为03到08的区域高架路。',
  '容错：上段掉落落入下环而非入口；不靠移动平台、冲刺或技能维持主路。'])
plan('07B','裂谷折返','跑酷 · 下降再攀出',
 [[[0,180],[250,180],[250,360],[490,360],[490,560],[760,560],[760,360],[960,360]],
  [[250,180],[760,180],[760,360]],[[490,560],[180,560],[180,420],[250,360]],[[760,180],[760,90],[960,90]]],
 [('E1',0,180,'03上层新增竖口'),('E2',960,360,'04待建上层'),('E3',960,90,'08东侧·二段跳')],
 [('fire',80,218,'S'),('switch',490,598,'A'),('gate',760,180,'G'),('chest',850,398,'R'),('ability',760,130,'D')],
 [[65,180],[250,180],[250,360],[490,360],[490,560],[760,560],[760,360],[910,360]],
 [[250,180],[760,180],[760,360]],[[760,180],[760,90],[920,90]],
 ['初访：先沿裂壁有控制地下落，再穿根脊攀至东岸；主奖励R不要求二段跳。',
  '捷径G：东岸放下横桥回E1，之后去R/04无需重做谷底跑酷。',
  '二段跳：东岸回廊再抬高160px到E3，让旧入口和08发生新的跨区联系。',
  '容错：三条横向兜底台分层接住坠落；谷底能原路分段攀回，没有无能力死井。'])
plan('08A','苔甲三庭','战斗一 · 平地串庭',
 [[[0,480],[200,480],[470,480],[770,480],[960,480]],
  [[200,480],[200,210],[770,210],[770,480]],[[470,480],[470,330],[770,330]],[[770,210],[960,210]]],
 [('E1',0,480,'02中层新增侧口'),('E2',960,480,'05东侧'),('E3',960,210,'07上层·二段跳')],
 [('fire',75,518,'S'),('gate',470,480,'G1'),('gate',770,480,'G2'),('chest',870,518,'R'),('ability',770,250,'D')],
 [[60,480],[200,480],[470,480],[770,480],[920,480]],
 [[200,480],[200,210],[770,210],[770,480]],[[470,330],[770,210],[920,210]],
 ['初访：三块宽平地分别安排近战、近远配合、苔甲卫；连接廊留补给空隙。',
  '捷径：清场后开启上层巡护廊，02↔05回访避开已打过的三庭。',
  '二段跳：第二庭上方高看台接E3；初次封印未解除时不能从看台跳过守门战。',
  '战斗：每庭有可后退的平地与一段低台；飞蛾不放在出口或窄井贴脸。'],
 rooms=[(110,375,205,155),(360,375,230,155),(660,375,240,155)],
 mobs=[(180,510,'mob'),(250,510,'mob'),(420,510,'mob'),(530,435,'fly'),(750,510,'elite'),(830,510,'mob')])
plan('08B','树心双层堂','战斗一 · 双厅错层',
 [[[0,480],[240,480],[240,230],[700,230],[700,480],[960,480]],
  [[240,480],[700,480]],[[450,230],[450,360],[700,360]],[[700,230],[960,230]]],
 [('E1',0,480,'02中层新增侧口'),('E2',960,480,'05东侧'),('E3',960,230,'07上层·二段跳')],
 [('fire',70,518,'S'),('gate',240,480,'G1'),('gate',700,480,'G2'),('chest',875,518,'R'),('ability',700,270,'D')],
 [[60,480],[240,480],[240,230],[700,230],[700,480],[915,480]],
 [[240,480],[700,480]],[[450,360],[700,230],[920,230]],
 ['初访：西下厅清近战群→宽阶上东厅打远近组合→东侧落回出口层。',
  '捷径：第二厅前先从背面开下廊门，复战可从S直达东厅准备区。',
  '二段跳：东厅观战台连接E3，与07共同形成树冠跨区环；不能越未清封印。',
  '战斗：只有两层宽厅与中间短阶；柱子切远程射线，近战平地不布跳跃坑。'],
 rooms=[(115,370,300,160),(490,120,350,160)],mobs=[(210,510,'mob'),(330,510,'mob'),(570,260,'mob'),(660,260,'elite'),(770,200,'fly')])
plan('09A','断根哨营','战斗二 · 哨所与围场',
 [[[0,250],[230,250],[230,480],[740,480],[960,480]],
  [[230,250],[740,250],[740,480]],[[480,480],[480,590],[740,590]],[[740,250],[960,250]]],
 [('E1',0,250,'03下层新增侧口'),('E2',960,480,'06东侧'),('E3',960,250,'04待建下层')],
 [('fire',80,288,'S'),('gate',230,480,'G1'),('gate',740,480,'G2'),('chest',875,288,'R'),('ability',480,340,'D')],
 [[65,250],[230,250],[230,480],[480,480],[740,480],[740,250],[910,250]],
 [[230,250],[740,250]],[[480,480],[480,340],[740,250]],
 ['初访：哨所斜坡下到围场；两处宽场分开清理藤鞭花掩护与苔甲卫。',
  '捷径：抵东哨先拉栅门连上层走廊，03↔04未来通行不用穿围场。',
  '二段跳：围场高瞭望台接上廊，既是回访捷径也能看到下层藏箱。',
  '战斗：各场至少保留一个无坑后撤方向；E2为06解谜区的替代入口。'],
 rooms=[(100,145,220,155),(300,365,290,165),(630,365,240,165)],mobs=[(200,280,'mob'),(380,510,'mob'),(480,510,'flower'),(720,510,'elite'),(810,510,'mob')])
plan('09B','盘根防线','战斗二 · 中庭三支路',
 [[[0,250],[250,250],[490,250],[740,250],[960,250]],
  [[250,250],[250,500],[740,500],[960,500]],[[490,250],[490,100],[740,100],[740,250]]],
 [('E1',0,250,'03下层新增侧口'),('E2',960,500,'06东侧'),('E3',960,250,'04待建下层')],
 [('fire',70,288,'S'),('gate',490,250,'G1'),('gate',740,250,'G2'),('chest',875,288,'R'),('ability',490,140,'D')],
 [[60,250],[250,250],[250,500],[740,500],[740,250],[915,250]],
 [[250,250],[740,250]],[[490,250],[490,100],[740,100],[740,250]],
 ['初访：外防线后可选中庭强攻或下沟侧击；两路最终会合到东门准备区。',
  '捷径：东门背面解锁中庭直廊；以后03去06/04均可从这里分流。',
  '二段跳：上层残壁跳入哨楼，构成第三条回访路线；主线两路均不锁能力。',
  '战斗：中庭平地对精英，下沟低台分散小怪；层级只三处，敌人不追进窄返井。'],
 rooms=[(105,140,245,155),(370,140,240,155),(600,390,280,160)],mobs=[(220,280,'mob'),(470,280,'elite'),(690,530,'mob'),(805,530,'flower')])

COL={'wall':'#7e8879','edge':'#394b45','air':'#fafbf5','platform':'#009dc6','route':'#167f78','shortcut':'#b77a2a','lock':'#8554ae','mob':'#a02d45'}
# Give every ability bypass an actual gallery rather than drawing its route through rock.
revisit={
 '05A':[[200,410],[200,350],[480,350],[480,210]],
 '05B':[[220,410],[220,350],[700,350],[700,180]],
 '06A':[[560,520],[560,460],[720,460],[720,350]],
 '06B':[[500,500],[500,440],[770,440],[770,240]],
 '09A':[[480,480],[480,420],[740,420],[740,250]],
 '09B':[[490,250],[490,190],[620,190],[620,100],[740,100],[740,250]],
 '07A':[[780,230],[780,170],[960,170]],
 '07B':[[760,180],[760,120],[960,120]],
 '08A':[[770,210],[800,210],[800,150],[960,150]],
 '08B':[[700,230],[800,230],[800,170],[960,170]],
}
for p in P:
    # Remove ordinary stairways that would otherwise defeat the proposed ability choke.
    if p['id']=='05A':
        p['air']=[a for a in p['air'] if a!=[[200,410],[200,210],[480,210]]]
    elif p['id']=='07A':
        p['air'][0]=p['air'][0][:6]
    elif p['id']=='07B':
        p['air']=[a for a in p['air'] if a!=[[760,180],[760,90],[960,90]]]
    elif p['id']=='09B':
        p['air']=[a for a in p['air'] if a!=[[490,250],[490,100],[740,100],[740,250]]]
    p['ability_route']=revisit[p['id']]
    p['ability_gate']={'requires':'double_jump','rise_world':160,'status':'planned_geometry_must_be_playtested'}
    p['air'].append(p['ability_route'])
    p['platform_rule']={'regular_rise_world_max':96,'single_jump_height_world':112.36,'gate_rise_world':160}
    p['coordinates_note']='Sketch geometry, not an executable collision mesh; native dimensions verified after choice.'
    if p['id'] in ['07A','07B','08A','08B']:
        end=p['ability_route'][-1]
        p['ports'][-1]=('E3',end[0],end[1],p['ports'][-1][3])
        # Replace the old free upper exit: its final access now uses the raised ledge.
        p['air']=[a for a in p['air'] if a is p['ability_route'] or not (len(a)==2 and a[-1][0]==960 and a[-1][1] not in [p['ports'][1][2],end[1]])]
    p['jump_sections']=[]
    if p['id']=='07A':
        p['jump_sections']=[{'pit':[245,395,225,220],'ledges':[[270,444,44],[334,420,44],[398,444,44]]},
          {'pit':[550,225,195,220],'ledges':[[560,274,44],[625,250,44],[690,274,44]]}]
    elif p['id']=='07B':
        p['jump_sections']=[{'pit':[280,355,190,250],'ledges':[[290,404,44],[355,380,44],[420,404,44]]}]

# Return corridors are physically closed until their far-side controls or combat groups clear.
# The combat barrier also covers an ability exit; possessing double jump cannot skip its fight.
extra_gates={
 '06A':[('gate',550,240,'G2')],
 '08A':[('gate',400,210,'G3'),('gate',870,150,'G4')],
 '08B':[('gate',870,170,'G3')],
 '09A':[('gate',520,250,'G3'),('chest',660,628,'R2')],
 '09B':[('gate',740,100,'G3')],
}
for p in P:
    p['stations'].extend(extra_gates.get(p['id'],[]))
    # Put the ability marker at the raised gallery entrance instead of in solid rock.
    gx,gy=p['ability_route'][0]
    if not any(s[0]=='ability' for s in p['stations']):p['stations'].append(('ability',gx,gy-10,'D'))
    p['stations']=[(k,gx,gy-10,n) if k=='ability' else (k,x,y,n) for k,x,y,n in p['stations']]
    p['barrier_rule']='Combat seals span all parallel outlets of their arena, including the ability branch; clear state persists.' if p['id'].startswith(('08','09')) else 'Shortcut barrier stays closed until the puzzle solution or far-side control persists.'
def svg_text(x,y,s,size=19,color='#253c36',anchor='start'):
    return f'<text x="{x}" y="{y}" font-family="Microsoft YaHei, sans-serif" font-size="{size}" fill="{color}" text-anchor="{anchor}">{escape(s)}</text>'
def path(pts,color,width=3,dash=False):
    points=' '.join(f'{x},{y}' for x,y in pts)
    return f'<polyline points="{points}" stroke="{color}" stroke-width="{width}" fill="none" stroke-linejoin="round" stroke-linecap="round"'+(' stroke-dasharray="8 6"' if dash else '')+'/>'

def draw(p):
    a=['<svg xmlns="http://www.w3.org/2000/svg" width="1180" height="1130" viewBox="0 0 1180 1130">','<rect width="1180" height="1130" fill="#f3f1e7"/>']
    a += [svg_text(70,52,f'forest_{p["id"]} · {p["title"]}',29),svg_text(70,88,p['kind']+'｜备选草图，待评审后建造',20)]
    a.append('<g transform="translate(105,140)">')
    a.append(f'<rect width="960" height="678" fill="{COL["wall"]}" stroke="{COL["edge"]}" stroke-width="2"/>')
    # Air corridors are cut from a solid mass; the broad outlines remain physical terrain.
    for points in p['air']:a.append(path(points,COL['edge'],94));a.append(path(points,COL['air'],88))
    for x,y,w,h in p['rooms']:a.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="13" fill="{COL["air"]}" stroke="{COL["edge"]}" stroke-width="2"/>')
    for section in p['jump_sections']:
        x,y,w,h=section['pit']
        a.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{COL["air"]}"/>')
        for x,y,w in section['ledges']:a.append(path([(x,y),(x+w,y)],COL['platform'],4))
    # Vertical links have native-scale ledges (32 sketch px = 85.3 world px, below 0.9 single jump).
    for points in p['air']:
        for (x0,y0),(x1,y1) in zip(points,points[1:]):
            if x0==x1 and abs(y1-y0)>65:
                # Basket shafts are traversed by the puzzle machinery, not a free staircase.
                if p['id']=='05B' and points is not p['ability_route'] and x0 in [220,700]:continue
                low,high=sorted([y0,y1])
                for i,yy in enumerate(range(int(high)+44-32,int(low)+44,-32)):
                    # The first missing step on the bypass is its ability choke.
                    gx,gy=p['ability_route'][0]
                    if x0==gx and gy+8<yy<gy+44:continue
                    xx=x0-38 if i%2==0 else x0+2
                    a.append(path([(xx,yy),(xx+36,yy)],COL['platform'],3))
    for theme,x,y,w,h in p['theme']:
        if theme=='water':a.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#69bac8" opacity=".5"/>')
        elif theme=='basket':a.append(f'<rect x="{x-w/2}" y="{y}" width="{w}" height="{h}" fill="#b99b64" stroke="#68553c" stroke-width="2"/>')
        else:a.append(path([(x,y),(w,h)],'#ccac49' if theme=='light' else '#87aeb1',3,True))
    a.append(path(p['first_route'],COL['route'],3,True))
    a.append(path(p['shortcut'],COL['shortcut'],5,True))
    a.append(path(p['ability_route'],COL['lock'],4,True))
    for x,y,kind in p['mobs']:
        if kind=='elite':shape=f'<polygon points="{x},{y-27} {x+12},{y-13} {x},{y+1} {x-12},{y-13}" fill="{COL["mob"]}"/>'
        elif kind=='fly':shape=f'<path d="M {x-15} {y-10} L {x} {y} L {x+15} {y-10}" fill="none" stroke="{COL["mob"]}" stroke-width="4"/>'
        elif kind=='flower':shape=f'<circle cx="{x}" cy="{y-12}" r="10" fill="{COL["mob"]}"/>'
        else:shape=f'<polygon points="{x},{y-20} {x+10},{y} {x-10},{y}" fill="{COL["mob"]}"/>'
        a.append(shape)
    for kind,x,y,name in p['stations']:
        if kind=='fire':a.append(f'<rect x="{x-10}" y="{y-20}" width="20" height="20" fill="#31855c"/>')
        elif kind=='switch':a.append(f'<circle cx="{x}" cy="{y-15}" r="11" fill="#70c6c2" stroke="#26716e" stroke-width="2"/>')
        elif kind=='chest':a.append(f'<rect x="{x-11}" y="{y-18}" width="22" height="18" fill="#e2b249" stroke="#715f32"/>')
        elif kind=='gate':a.append(path([(x,y-42),(x,y+42)],'#cc7749',7))
        elif kind=='ability':a.append(f'<path d="M {x-13} {y-30} L {x} {y-42} L {x+13} {y-30} M {x-13} {y-13} L {x} {y-25} L {x+13} {y-13}" fill="none" stroke="{COL["lock"]}" stroke-width="4"/>')
        a.append(svg_text(x-34 if kind=='ability' else x+16,y-24,name,18))
    for id,x,y,detail in p['ports']:
        a.append(f'<rect x="{x-9}" y="{y-28}" width="18" height="56" fill="#62b4c0" stroke="#21515a" stroke-width="2"/>')
        a.append(svg_text(x+(18 if x==0 else -18),y-39,id,19,anchor='start' if x==0 else 'end'))
    a.append('</g>')
    a.append(svg_text(105,854,'出口：'+'　'.join(f'{id}→{desc}' for id,x,y,desc in p['ports']),18))
    for i,s in enumerate(p['notes']):a.append(svg_text(70,903+i*40,s,18))
    a.append(svg_text(70,1094,'灰＝实心　白＝通道　蓝＝薄台　绿线＝初访　赭线＝永久捷径　紫线＝二段跳回访（比例示意）',17))
    a.append('</svg>')
    target=OUT/f'forest_{p["id"]}.svg';target.write_text('\n'.join(a),encoding='utf-8')
    doc=pymupdf.open(target);doc[0].get_pixmap(alpha=False).save(target.with_suffix('.png'))

def overview():
    nodes={'01':(220,450),'02':(730,450),'03':(1240,450),'04':(1750,450),'05':(360,160),'06':(920,760),'07':(1610,120),'08':(1000,150),'09':(1530,750)}
    edges=[('01','02',False),('02','03',False),('03','04',True),('01','05',False),('02','05',False),('05','08',False),('02','08',False),('08','07',True),('03','07',False),('04','07',True),('02','06',False),('03','06',False),('06','09',False),('03','09',False),('04','09',True)]
    a=['<svg xmlns="http://www.w3.org/2000/svg" width="2020" height="1020" viewBox="0 0 2020 1020">','<rect width="2020" height="1020" fill="#f3f1e7"/>',svg_text(75,55,'森林互联方案 · A/B共用出口，选择可以自由组合',31)]
    for s,t,d in edges:
        x,y=nodes[s];xx,yy=nodes[t];a.append(path([(x,y),(xx,yy)],COL['lock'] if (s,t)==('08','07') else '#8a9b91',4,d))
    for id,(x,y) in nodes.items():
        label={'01':'已实装','02':'已实装','03':'已实装','04':'横生巨木·待建','05':'解谜一 A/B','06':'解谜二 A/B','07':'跑酷 A/B','08':'战斗一 A/B','09':'战斗二 A/B'}[id]
        a.append(f'<rect x="{x-110}" y="{y-45}" width="220" height="90" rx="14" fill="'+('#dae4da' if id in ['01','02','03'] else '#e5ddca' if id=='04' else '#fbfcf6')+'" stroke="#536c61" stroke-width="2"/>')
        a.append(svg_text(x,y-8,'forest_'+id,24,anchor='middle'));a.append(svg_text(x,y+24,label,20,anchor='middle'))
    for i,s in enumerate(['灰线＝拟双向互联；连接04的路线须等04建造后才启用。','紫线08↔07＝二段跳高架线；未获得能力时，两图仍能从02/03分别进入。','既有01↔02、02↔03的上下双通道保留；图中仅用一条线概括，不减少已有出口。','编号05～09只是备选提案占位；不覆盖旧灰盒，不写入运行时房间登记或存档。']):a.append(svg_text(80,885+i*31,s,21))
    a.append('</svg>');p=OUT/'connections.svg';p.write_text('\n'.join(a),encoding='utf-8');d=pymupdf.open(p);d[0].get_pixmap(alpha=False).save(p.with_suffix('.png'))

def main():
    for p in P:draw(p)
    overview()
    # Compose pairs from the source vectors, keeping the detailed single-plan files available.
    for group in ['05','06','07','08','09']:
        a=['<svg xmlns="http://www.w3.org/2000/svg" width="2360" height="1130" viewBox="0 0 2360 1130">']
        for i,suffix in enumerate(['A','B']):
            src=(OUT/f'forest_{group}{suffix}.svg').read_text(encoding='utf-8')
            a.append(f'<g transform="translate({i*1180},0)">'+src[src.index('>')+1:src.rindex('</svg>')]+'</g>')
        a.append('</svg>');p=OUT/f'compare_{group}.svg';p.write_text('\n'.join(a),encoding='utf-8');d=pymupdf.open(p);d[0].get_pixmap(alpha=False).save(p.with_suffix('.png'))
    (OUT/'plans.json').write_text(json.dumps(P,ensure_ascii=False,indent=2),encoding='utf-8')
    cards=''.join(f'<section><h2>{p["id"]} {p["title"]}</h2><p><a href="forest_{p["id"]}.svg">SVG源图</a> · <a href="forest_{p["id"]}.png">PNG大图</a></p><img src="forest_{p["id"]}.png"><p>{"<br>".join(p["notes"])}</p></section>' for p in P)
    html='<!doctype html><html lang="zh"><meta charset="utf-8"><title>森林互联备选</title><style>body{background:#f3f1e7;color:#253c36;font:18px system-ui;max-width:1500px;margin:40px auto}img{max-width:100%}section{border-top:1px solid #acb5a8;padding:25px 0}p{line-height:1.8}</style><h1>五类场景，各两个方案</h1><p>十案已有独立实际试玩场景，双击 test/launchers/run_forest_candidates.cmd 进入。此页保留原始草图；正式世界接入仍待选案。A/B共用外部出口。</p><img src="connections.png">'+cards+'</html>'
    (OUT/'index.html').write_text(html,encoding='utf-8')
    print('DESIGN OUTPUT: 10 plans, 5 A/B comparison sheets, 1 connection sketch; no runtime changes.')

if __name__=='__main__':main()
