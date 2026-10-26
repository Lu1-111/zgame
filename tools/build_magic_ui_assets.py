"""生成 Godot 可直接导入的原创矢量 UI，形状与文字控件分离。"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "assets/ui/magic"
ROOT.mkdir(parents=True, exist_ok=True)

def save(name, width, height, body):
    defs = '''<defs><linearGradient id="bg" x2="0" y2="1"><stop stop-color="#173b46"/><stop offset="1" stop-color="#071720"/></linearGradient><linearGradient id="gold" x2="0" y2="1"><stop stop-color="#f1dfad"/><stop offset="0.45" stop-color="#b4965a"/><stop offset="1" stop-color="#6f603e"/></linearGradient><radialGradient id="glow"><stop stop-color="#75cdb4" stop-opacity=".2"/><stop offset="1" stop-color="#75cdb4" stop-opacity="0"/></radialGradient></defs>'''
    (ROOT / name).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">{defs}{body}</svg>', encoding="utf-8")

def panel(w, h):
    body = f'<path d="M18 1 H{w-18} L{w-1} 18 V{h-18} L{w-18} {h-1} H18 L1 {h-18} V18 Z" fill="url(#bg)" stroke="url(#gold)" stroke-width="2"/>'
    body += f'<rect x="9" y="9" width="{w-18}" height="{h-18}" rx="8" fill="none" stroke="#ae9360" stroke-opacity=".4"/>'
    for x, y, sx, sy in [(14,14,1,1),(w-14,14,-1,1),(14,h-14,1,-1),(w-14,h-14,-1,-1)]:
        body += f'<g transform="translate({x} {y}) scale({sx} {sy})" fill="none" stroke="#c6ac78"><path d="M0 34 Q2 9 34 0 M0 20 Q10 16 13 6 M20 0 Q16 10 6 13"/><path d="M0 3 L3 0 L6 3 L3 6 Z" fill="#e7d9ac"/></g>'
    body += f'<path d="M{w/2-42} 12 H{w/2-10} L{w/2} 4 L{w/2+10} 12 H{w/2+42}" fill="none" stroke="#d7bd86"/>'
    body += f'<path d="M{w/2-32} {h-12} H{w/2-6} L{w/2} {h-6} L{w/2+6} {h-12} H{w/2+32}" fill="none" stroke="#977f51"/>'
    return body

save("inventory_panel.svg",584,312,panel(584,312))
save("rest_panel.svg",240,282,panel(240,282)+'<circle cx="120" cy="96" r="70" fill="url(#glow)"/><g fill="none" stroke="#98895b" stroke-opacity=".25"><circle cx="120" cy="102" r="52"/><circle cx="120" cy="102" r="43"/><path d="M120 44 V160 M62 102 H178 M79 61 L161 143 M79 143 L161 61"/></g>')
save("slot.svg",40,40,'<path d="M6 1 H34 L39 6 V34 L34 39 H6 L1 34 V6 Z" fill="url(#bg)" stroke="url(#gold)"/><path d="M8 5 H32 L35 8 V32 L32 35 H8 L5 32 V8 Z" fill="#071923" stroke="#4f665f" stroke-width=".6"/><path d="M1 10 H5 M1 30 H5 M35 10 H39 M35 30 H39 M10 1 V5 M30 1 V5 M10 35 V39 M30 35 V39" stroke="#b99e64"/>')
hud = '<circle cx="32" cy="30" r="27" fill="#081b24" stroke="url(#gold)" stroke-width="2"/><circle cx="32" cy="30" r="22" fill="#173e47" stroke="#617b69"/><path d="M9 13 Q1 0 17 3 L32 0 L47 3 Q63 0 55 13 M9 47 Q5 59 23 57 L32 63 L41 57 Q59 59 55 47" fill="none" stroke="#c8ac70"/><path d="M54 13 H191 L201 19 L192 25 H55 M55 26 H180 L190 32 L180 38 H55 M55 39 H170 L180 45 L170 51 H54" fill="#081b24" stroke="url(#gold)" stroke-width="1.4"/><circle cx="201" cy="19" r="2" fill="#e56d70"/><circle cx="190" cy="32" r="2" fill="#e9c75e"/><circle cx="180" cy="45" r="2" fill="#a78be8"/>'
save("hud_frame.svg",210,64,hud)
icons = {
    "bubble": '<circle cx="20" cy="20" r="12" fill="#1b7e9d" stroke="#b2f2e3" stroke-width="2"/><path d="M10 20 A10 10 0 0 1 21 10" fill="none" stroke="#fff5d1" stroke-width="2"/><ellipse cx="20" cy="20" rx="18" ry="6" transform="rotate(-35 20 20)" fill="none" stroke="#7bd8bf"/>',
    "shield": '<path d="M20 3 L34 9 V22 Q32 32 20 38 Q8 32 6 22 V9 Z" fill="#1d5768" stroke="#c6e6d6" stroke-width="2"/><path d="M20 9 L29 13 V22 Q26 29 20 32 Q14 29 11 22 V13 Z" fill="#5986af"/><path d="M20 12 V29 M14 20 H26" stroke="#e9f4dc" stroke-width="2"/>',
    "heal": '<path d="M16 5 H24 V16 H35 V24 H24 V35 H16 V24 H5 V16 H16 Z" fill="#e8dfad" stroke="#faf3d7"/><path d="M4 29 Q1 39 14 37 M26 37 Q39 39 36 29" fill="none" stroke="#7bd8bf" stroke-width="3"/>',
    "slam": '<path d="M20 2 L24 13 L34 7 L29 17 L39 21 L28 25 L34 35 L24 29 L20 39 L16 28 L5 35 L11 25 L1 21 L12 17 L7 7 L16 13 Z" fill="#c49553"/><path d="M20 8 L24 18 L33 21 L24 25 L20 34 L16 25 L7 21 L16 18 Z" fill="#f1e3a2"/>',
    "starfall": '<path d="M21 3 L25 14 L37 16 L28 24 L30 37 L20 30 L9 37 L12 24 L3 16 L15 14 Z" fill="#e9ca85" stroke="#fcf2ca"/><path d="M2 29 L11 20 M7 38 L16 29" stroke="#b2a1f1" stroke-width="2"/>'
}
for key, body in icons.items():
    save(f"skill_{key}.svg",40,40,body)
save("hit_vignette.svg",640,360,'<defs><radialGradient id="hit"><stop offset=".55" stop-color="#c3213e" stop-opacity="0"/><stop offset="1" stop-color="#a80d30" stop-opacity=".65"/></radialGradient></defs><rect width="640" height="360" fill="url(#hit)"/>')
print("Magic UI: 10 original SVG assets")
