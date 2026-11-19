"""检查草图的条件路线、开门顺序与图上通道；不替代Godot物理走查。"""
from collections import deque
from pathlib import Path
from math import ceil, dist
from xml.etree import ElementTree
import json
from draw_plans import _mask

ROOT=Path(__file__).resolve().parent


def _path(plan,start,goal,flags):
    graph={n['id']:[] for n in plan['nodes']}
    for a,b,condition,*direction in plan['edges']:
        if condition!='base' and condition not in flags: continue
        graph[a].append(b)
        if direction!=['oneway']: graph[b].append(a)
    pending=deque([[start]]); visited={start}
    while pending:
        path=pending.popleft()
        if path[-1]==goal: return path
        for node in graph[path[-1]]:
            if node not in visited:
                visited.add(node); pending.append(path+[node])
    return []


def _points(a,b):
    n=max(1,ceil(dist(a,b)))
    for i in range(n+1):
        yield tuple(round(a[k]+(b[k]-a[k])*i/n) for k in range(2))


def _review(plan):
    errors=[]; notes=[]
    ids={n['id'] for n in plan['nodes']}
    for gate in plan['gates']:
        path=_path(plan,'S',gate['opens_at'],set())
        if not path or 'T' in path:
            errors.append(gate['id']+'的开启点不能在目标挑战之前抵达')
        notes.append(gate['id']+'开启点：'+'→'.join(path))
    for s in plan['shortcuts']:
        flags=set(s.get('also',[]))
        before=_path(plan,s['start'],s['goal'],flags)
        after=_path(plan,s['start'],s['goal'],flags|{s['flag']})
        if not before or not after: errors.append(s['flag']+'状态路线不连通')
        if any(n in after for n in s['skip']): errors.append(s['flag']+'没有跳过声明的区域')
        if len(after)>=len(before): errors.append(s['flag']+'图论路线没有变短')
        notes.append(s['flag']+'：'+'→'.join(before)+' => '+'→'.join(after))
    mask=_mask(plan)
    for key in plan.get('low_ceiling_nodes',[]):
        node=next(n for n in plan['nodes'] if n['id']==key)
        x,floor=node['pos']; top=floor-8
        while top>0 and mask.getpixel((x,top-1)): top-=1
        height=(floor-top)*plan['world_per_map_unit']
        headroom=height-plan['reference_body_height']
        if not 0<headroom<plan['reference_single_jump_height']:
            errors.append(key+'没有形成声明的低顶空间')
        notes.append(f'{key}低顶：草图净高约{height}px，扣除参考碰撞身体后上升余量约{headroom}px（非物理实测）')
    for role,route in plan['routes']:
        for a,b in zip(route,route[1:]):
            for x,y in _points(a,b):
                if not (0<=x<1280 and 0<=y<904 and mask.getpixel((x,y))):
                    errors.append(f'{role}路线穿过实体：({x},{y})'); break
                if role in ('main','branch'):
                    for g in plan['gates']:
                        gx,gy,w,h=g['rect']
                        if gx<=x<=gx+w and gy<=y<=gy+h:
                            errors.append(f'首次路线提前穿过{g["id"]}'); break
    for c in plan['cameras']:
        x,y=c['foot']
        if not mask.getpixel((x,y-8)): errors.append(c['id']+'站位位于实体')
        supported=not mask.getpixel((x,y+3)) or any(abs(py-y)<=1 and px<=x<=px+w for px,py,w in plan['platforms'])
        if not supported: errors.append(c['id']+'示意站位没有落脚面')
    for edge in plan['edges']:
        if edge[0] not in ids or edge[1] not in ids: errors.append('未知节点')
    ElementTree.parse(ROOT/(plan['id']+'.svg'))
    return errors,notes


if __name__=='__main__':
    plans=json.loads((ROOT/'plans.json').read_text(encoding='utf-8'))
    lines=['# 草图结构检查','','只检查所声明的状态图、开门顺序、图上通道和镜头站位；不判断角色能否完成每次跳跃。','']
    failures=0
    for plan in plans:
        errors,notes=_review(plan)
        failures+=len(errors)
        lines+=['## '+plan['title'],'']+['- '+n for n in notes]+['- 图上检查：'+('通过' if not errors else '需要修整'),'']+['- 问题：'+e for e in errors]
        print(plan['id'],len(errors),'issues')
        for e in errors: print(' ',e)
    (ROOT/'结构检查.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    raise SystemExit(1 if failures else 0)
