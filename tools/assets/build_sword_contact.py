"""由剑刃姿态与剑光轮廓同时生成绘制、接触数据和可编辑 SVG 图集。"""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / 'data/sword_contact.json'
CFG = json.loads(PATH.read_text(encoding='utf-8'))
MOTION = json.loads((ROOT / CFG['frame_manifest'].removeprefix('res://')).read_text(encoding='utf-8'))
EPS = CFG['geometry_epsilon']


def _cross(o, a, b):
    return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])


def _hull(points):
    points = sorted(set(tuple(p) for p in points))
    if len(points) < 3:
        return []
    lower, upper = [], []
    for p in points:
        while len(lower) >= 2 and _cross(lower[-2], lower[-1], p) <= EPS:
            lower.pop()
        lower.append(p)
    for p in reversed(points):
        while len(upper) >= 2 and _cross(upper[-2], upper[-1], p) <= EPS:
            upper.pop()
        upper.append(p)
    return [list(p) for p in lower[:-1]+upper[:-1]]


def _floor_clip(poly):
    out = []
    floor = CFG['floor_y']
    for a, b in zip(poly, poly[1:]+poly[:1]):
        inside_a, inside_b = a[1] <= floor, b[1] <= floor
        if inside_a:
            out.append(a)
        if inside_a != inside_b:
            t = (floor-a[1])/(b[1]-a[1])
            out.append([a[0]+t*(b[0]-a[0]), floor])
    return _hull(out)


def _grow(poly):
    pad = CFG['contact_padding']
    return _hull([[p[0]+x, p[1]+y] for p in poly for x in [-pad,pad] for y in [-pad,pad]])


def _direction(angle):
    a = math.radians(angle)
    return [math.cos(a),math.sin(a)]


def _local(point):
    return [point[i]-MOTION['native_anchor'][i] for i in range(2)]


def _catmull(a, b, c, d, t):
    return [.5*((2*b[i])+(-a[i]+c[i])*t+(2*a[i]-5*b[i]+4*c[i]-d[i])*t*t+(-a[i]+3*b[i]-3*c[i]+d[i])*t*t*t) for i in range(2)]


def _curve(profile):
    nodes = []
    for entry in profile['nodes']:
        p = list(entry['point']) if 'point' in entry else _local(MOTION['poses'][entry['pose']]['tip'])
        if entry.get('ground'):
            p[1] = CFG['floor_y']
        nodes.append(p)
    curve, widths = [], []
    steps = CFG['curve_subdivisions']
    for index in range(len(nodes)-1):
        for sample in range(steps):
            t = sample/steps
            curve.append(_catmull(nodes[max(0,index-1)],nodes[index],nodes[index+1],nodes[min(len(nodes)-1,index+2)],t))
            widths.append(profile['half_widths'][index]*(1-t)+profile['half_widths'][index+1]*t)
    curve.append(nodes[-1])
    widths.append(profile['half_widths'][-1])
    normals = []
    for index in range(len(curve)):
        a, b = curve[max(0,index-1)], curve[min(len(curve)-1,index+1)]
        dx,dy = b[0]-a[0],b[1]-a[1]
        length = max(EPS, math.hypot(dx,dy))
        normals.append([-dy/length,dx/length])
    return curve,widths,normals


def _ribbon(profile, index):
    curve,widths,normals = _curve(profile)
    count = profile['progress_nodes'][index]*CFG['curve_subdivisions']
    groups = {layer:[] for layer in CFG['layer_ratios']}
    for segment in range(count):
        strength = profile['pose_alpha'][index]*(CFG['tail_min_alpha']+(1-CFG['tail_min_alpha'])*(segment+1)/max(1,count))
        for layer,ratio in CFG['layer_ratios'].items():
            points = []
            for vertex,sign in [(segment,-1),(segment+1,-1),(segment+1,1),(segment,1)]:
                points.append([curve[vertex][axis]+sign*normals[vertex][axis]*widths[vertex]*ratio for axis in range(2)])
            poly = _floor_clip(_hull(points))
            if len(poly) >= 3 and strength > 0:
                groups[layer].append({'polygon':poly,'layer':layer,'strength':strength})
    return [v for group in groups.values() for v in group]


def _thrust(profile, pose, index):
    alpha = profile['pose_alpha'][index]
    if alpha <= 0:
        return []
    d = _direction(pose['angle_degrees'])
    n = [-d[1],d[0]]
    start = [v+d[i]*CFG['thrust_start_offset'] for i,v in enumerate(_local(pose['grip']))]
    tip = [v+d[i]*CFG['thrust_extra'] for i,v in enumerate(_local(pose['tip']))]
    middle = [start[i]+(tip[i]-start[i])*CFG['thrust_mid_fraction'] for i in range(2)]
    visuals = []
    for layer,ratio in CFG['layer_ratios'].items():
        width = CFG['thrust_half_width']*ratio
        poly = _floor_clip(_hull([start,[middle[i]+n[i]*width for i in range(2)],tip,[middle[i]-n[i]*width for i in range(2)]]))
        if len(poly) >= 3:
            visuals.append({'polygon':poly,'layer':layer,'strength':alpha})
    # 剑尖两侧的收束破风线，所有可见部分同样参与接触轮廓生成。
    wind = CFG['thrust_wind']
    for side in [-1, 1]:
        origin = [start[i]+(tip[i]-start[i])*wind['front_fraction']+n[i]*wind['side_offset']*side for i in range(2)]
        tail = [origin[i]-d[i]*wind['length']+n[i]*wind['sweep']*side for i in range(2)]
        for layer, ratio in CFG['layer_ratios'].items():
            width = wind['thickness']*ratio
            polygon = _floor_clip(_hull([tail,[origin[i]+n[i]*width for i in range(2)],tip,[origin[i]-n[i]*width for i in range(2)]]))
            if len(polygon) >= 3:
                visuals.append({'polygon':polygon,'layer':layer,'strength':alpha})
    return visuals


def _blade(pose):
    d = _direction(pose['angle_degrees'])
    n = [-d[1],d[0]]
    grip,tip = _local(pose['grip']),_local(pose['tip'])
    root = [grip[i]+d[i]*CFG['blade_root_offset'] for i in range(2)]
    base = [grip[i]+d[i]*CFG['blade_base_offset'] for i in range(2)]
    w = CFG['blade_half_width']
    return _hull([[root[i]-n[i]*w for i in range(2)],[base[i]-n[i]*w for i in range(2)],tip,[base[i]+n[i]*w for i in range(2)],[root[i]+n[i]*w for i in range(2)]])


def _svg(profile, frames):
    cell,anchor = CFG['atlas']['cell'],CFG['atlas']['anchor']
    samples = CFG['atlas']['pose_indices']
    lines = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{cell[0]*len(samples)}" height="{cell[1]}" viewBox="0 0 {cell[0]*len(samples)} {cell[1]}">']
    for column,index in enumerate(samples):
        frame = frames[MOTION['clips'][profile['clip']]['frames'][index]['pose']]
        for item in frame['visuals']:
            color = CFG['colors'][item['layer']]
            alpha = int(color[7:9],16)/255*item['strength']
            points = ' '.join(f'{p[0]+anchor[0]+column*cell[0]:.4f},{p[1]+anchor[1]:.4f}' for p in item['polygon'])
            lines.append(f'<polygon points="{points}" fill="{color[:7]}" opacity="{alpha:.4f}"/>')
    lines.append('</svg>')
    out = ROOT/'assets/effects/sword_contact_v1'
    out.mkdir(parents=True,exist_ok=True)
    (out/(profile['kind']+'.svg')).write_text('\n'.join(lines)+'\n',encoding='utf-8')


def main():
    """重建同源的特效、逐帧接触轮廓和 SVG 资源。"""
    frames = {}
    for profile in CFG['profiles']:
        for index,entry in enumerate(MOTION['clips'][profile['clip']]['frames']):
            pose = MOTION['poses'][entry['pose']]
            visuals = _ribbon(profile,index) if profile['shape']=='ribbon' else _thrust(profile,pose,index)
            blade = _blade(pose)
            contacts = [{'polygon':_grow(blade),'source':'blade'}]
            for visual_index,item in enumerate(visuals):
                if item['layer']=='glow':
                    contacts.append({'polygon':_grow(item['polygon']),'source':'visual','visual_index':visual_index})
            frames[entry['pose']] = {'visuals':visuals,'blade':blade,'contacts':contacts}
        _svg(profile,frames)
    CFG['frames'] = frames
    PATH.write_text(json.dumps(CFG,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'SWORD CONTACT: {len(frames)} frames, shared visual/contact contours, padding={CFG["contact_padding"]}px')


if __name__ == '__main__':
    main()
