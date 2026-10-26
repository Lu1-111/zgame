import json
from pathlib import Path
root=Path(".")
def read(p): return json.loads(Path(p).read_text(encoding="utf-8-sig"))
def save(p,obj): Path(p).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
skin={
"font_families":["Noto Serif CJK SC","Source Han Serif SC","SimSun","serif"],
"colors":{"back":"#141411e8","edge":"#9c927080","rule":"#78715c55","text":"#d7d1bd","selected":"#eee5c9"},
"skills_atlas":"res://assets/ui/quiet_v5/skill_oils.png",
"skill_order":["skill_bubble","skill_shield","skill_slam","skill_heal","skill_starfall","skill_cleave","skill_future_01","skill_future_02","skill_future_03","skill_future_04","skill_future_05","skill_future_06","passive_01","passive_02","passive_03","passive_04","passive_05","passive_06","passive_07","passive_08"],
"item_icons":{},"cursor_source":"res://assets/ui/quiet_v5/cursor.svg","cursor_hotspot":[1,1],
"interaction":{"offset_y":-68,"width":124,"height":23,"font_size":10},
"hud":{"rect":[6,6,214,52],"portrait":[15,10,28,32],"bars":[54,14,153,5],"gap":11,"coin":[16,57]}}
# 原生矢量物品：同一套克制的轮廓，不使用大面积辉光或镶宝石。
paths={
"weapon_sword":'<path d="M18 44 40 10 45 7 45 13 23 47z" fill="#bfc3bb"/><path d="m20 43 23-33" stroke="#f0eee1"/><path d="m15 41 11 8" stroke="#9e9172" stroke-width="3"/><path d="m19 46-7 10" stroke="#665344" stroke-width="4"/><circle cx="10" cy="58" r="2.5" fill="#9e9172"/>',
"weapon_hammer":'<path d="m20 51 17-28" stroke="#77634e" stroke-width="5"/><path d="m25 12 12-5 16 15-8 13-15-9z" fill="#c5c1ad"/><path d="m38 9 12 13" stroke="#ede8d2" stroke-width="3"/>',
"weapon_rifle":'<path d="m8 40 8 2 11-12 22-2 8-7-3-3-9 7-18 1-9 7-8 1z" fill="#8b7760"/><path d="m27 28 28-14" stroke="#aeb4af" stroke-width="3"/><path d="m28 31 4 8" stroke="#767b75" stroke-width="3"/><path d="m29 35 7 1 1-5" fill="none" stroke="#c2bba5"/>',
"weapon_staff":'<path d="m17 54 21-34" stroke="#8f7f65" stroke-width="4"/><path d="m34 22-5-9 12-9 8 10-11 12z" fill="#9caeab"/><path d="m35 15 7-7" stroke="#e1e7dc"/>',
"potion_small":'<path d="M25 9h14v9l6 8v22q0 7-13 7T19 48V26l6-8z" fill="#bbbba9" stroke="#ddd7c3"/><path d="M22 35h20v13q-10 7-20 0z" fill="#ede4c9"/><path d="M24 10h16" stroke="#6e6250" stroke-width="5"/>',
"potion_mana":'<path d="M25 9h14v9l6 8v22q0 7-13 7T19 48V26l6-8z" fill="#a3aaa6" stroke="#d4d6c7"/><path d="M22 35h20v13q-10 7-20 0z" fill="#7e91a3"/><path d="M24 10h16" stroke="#6e6250" stroke-width="5"/>',
"potion_sta":'<path d="M25 9h14v9l6 8v22q0 7-13 7T19 48V26l6-8z" fill="#a5aa98" stroke="#d4d6c7"/><path d="M22 35h20v13q-10 7-20 0z" fill="#8d9c68"/><path d="M24 10h16" stroke="#6e6250" stroke-width="5"/>',
"milk_bomb":'<circle cx="31" cy="37" r="17" fill="#a99d81"/><path d="m29 20 6-8 8 1" fill="none" stroke="#978a65" stroke-width="3"/><path d="m20 34 20 7" stroke="#d8cba9"/>',
"mushroom":'<path d="m28 31-2 21h13l-3-21" fill="#b8b39a"/><path d="M10 33Q12 8 32 10q21 1 22 23Q32 40 10 33" fill="#9b8e74" stroke="#d6c9a7"/>',
"honey_wax":'<path d="m18 18 12-7 18 9 5 24-16 10-21-13z" fill="#ba9e64"/><path d="m18 18 17 10 13-8M35 28l2 26" fill="none" stroke="#e0c68b"/>',
"milk_crystal":'<path d="m33 7 15 23-7 22-16 4-10-21z" fill="#a9b5b0"/><path d="m33 7-5 28 13 17M28 35l20-5" fill="none" stroke="#e6e7d5"/>',
"map_fragment":'<path d="m14 11 12 4 13-4 12 4-3 37-12-3-13 5-13-7z" fill="#c0b59a"/><path d="m25 16-3 36m17-39-3 36m-19-13 29-8" stroke="#786e58" fill="none"/>',
"bag_expand":'<path d="M16 24q15-8 32 0l3 29H13z" fill="#8d7d62"/><path d="M22 23V14h20v9M17 32h30" fill="none" stroke="#c8b698" stroke-width="3"/>'
}
for key,color in [("hp_fragment","#a4776f"),("sta_fragment","#8e9a70"),("mana_fragment","#82919e"),("ability_double_jump","#c9c4b0")]:
 paths[key]=f'<path d="m34 7 15 22-8 22-18 5-9-24z" fill="{color}"/><path d="m34 7-6 28 13 16M28 35l21-6" fill="none" stroke="#e3dbc4"/>'
for key,content in paths.items():
 p=Path("assets/ui/quiet_v5")/(key+".svg")
 p.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'+content+'</svg>',encoding="utf-8")
 skin["item_icons"][key]="res://"+p.as_posix()
skin["item_icons"]["weapon_bow"]=skin["item_icons"]["weapon_rifle"]
Path("assets/ui/quiet_v5/cursor.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28"><path d="m2 2 7 22 4-9 9-4z" fill="#e4dfce" stroke="#39392f" stroke-width="1.5"/></svg>',encoding="utf-8")
save("data/ui_skin.json",skin)
ui=read("data/gameplay_ui.json")
ui["colors"].update({"ink":"#12130f","panel":"#191b15","slot":"#1b1d17","gold":"#8c8469","bright_gold":"#d9d1b5","text":"#d7d1bd","muted":"#96988a","hp":"#8e443f","sta":"#70804f","mana":"#596f86","accent":"#c0b795","disabled":"#565a50"})
save("data/gameplay_ui.json",ui)
w=read("data/weapons.json")
for e in w["weapons"]:
 if e["id"] in ["bow_01","milk_gun"]:
  e.update(name="制式步枪",weapon_type="rifle",icon="res://assets/ui/quiet_v5/weapon_rifle.svg",desc="小队制式单发步枪。双手持枪，枪口随光标俯仰。左键射击，无需蓄力。")
  e["projectile"]={"speed":760,"charge":False}
 if e["id"]=="sword_01":
  e.update(name="制式直剑",desc="朴素的双手直剑。三段连击：纵斩、挑斩、横斩。",hitbox={"w":58,"h":52})
save("data/weapons.json",w)
skills=read("data/skills.json")
for e in skills["skills"]:
 if e["id"]=="skill_cleave":
  e.update(name="剑气",shape="projectile",desc="挥出一道大型剑气，沿光标方向贯穿路径上的敌人，造成 1.35 倍物理伤害。消耗 18 体力。")
  e["presentation"]={"speed":460,"range":540,"hitbox":[36,76],"world_size":[86,100],"spawn_offset":[26,-12],"effect":"sword_wave","fps":14}
save("data/skills.json",skills)
motion=read("data/hero_motion.json")
motion["sword"].update(length=27,hilt=9,guard=5,steel="#b8c0bd",edge="#e7ebe0",shadow="#414f56",grip="#5c4637",gold="#9d9579",phase_indices=[3,5,7])
motion["sword"]["grips"]=[
 [[35,39],[36,31],[37,26],[41,28],[46,36],[43,37],[40,40],[34,40]],
 [[43,37],[44,40],[47,39],[46,32],[41,25],[36,24],[37,31],[34,40]],
 [[30,40],[28,37],[30,34],[37,35],[46,37],[49,39],[41,40],[34,40]]]
motion["sword"]["angles"]=[[-35,-95,-125,-65,50,140,80,-35],[140,130,75,15,-65,-120,-70,-35],[-170,-160,-130,-65,-5,12,-10,-35]]
motion["sword"]["body_degrees"]=[[-3,-9,-13,-5,9,15,8,0],[10,14,10,0,-11,-14,-6,0],[-5,-12,-15,-5,8,14,7,0]]
motion["sword"]["depth"]=[[1]*8,[1]*8,[0.5,0.6,0.7,0.85,1,0.9,0.8,1]]
motion["rifle"]={"pivot":[34,39],"pitch_offset":[8,8],"barrel_length":28,"support":15,"recoil":3,"recoil_seconds":0.12,"body_aim_factor":0.08,"wood":"#765d42","wood_light":"#a28b67","steel":"#555f60","highlight":"#a2aeaa","dark":"#2d3434"}
motion["arms"]={"front_shoulder":[26,35],"back_shoulder":[38,35],"skin_sample":[25,32],"edge_sample":[23,43],"highlight_sample":[29,26],"mask":[[20,35,16,13],[43,34,6,12]],"fill_row":49,"far_limit":44,"width":4,"hand_width":3}
motion["guard"]={"raise_frame_seconds":0.10,"hold_frame":2,"release_seconds":0.18}
motion.pop("bow",None)
motion={k:v for k,v in motion.items() if k in ["source","canvas","anchor","sword","rifle","arms","guard"]}
save("data/hero_motion.json",motion)
combat=read("data/combat_presentation.json")
combat["weapon_modules"]["sword"].update(effects=["sword_down","sword_up","sword_cross"],sockets=[[17,-10],[17,-12],[19,-9]],startup=0.17,active=0.18,recovery=0.18,effect_rate=1.0)
combat["weapon_modules"]["rifle"]={"animations":["rifle_shot"],"startup":0.14,"active":0.04,"recovery":0.26,"socket":[29,-10]}
combat["weapon_modules"].pop("bow",None)
combat["motion_rig"]="res://data/hero_motion.json"
combat["animations"]={}
for name,prefix in [("sword_1","sword_1"),("sword_2","sword_2"),("sword_3","sword_3"),("rifle_shot","rifle_2")]:
 combat["animations"][name]={"frame_paths":[f"res://assets/PROCESSED/characters/CHR-01/rpg_v5/{prefix}_{f:02d}.png" for f in range(8)],"anchors":[[48,84]]*8,"scale":1.0,"fps":20,"loop":False}
combat["independent_fx"]={}
for k,size in [("sword_down",[76,88]),("sword_up",[76,88]),("sword_cross",[94,40]),("sword_wave",[86,100])]:
 combat["independent_fx"][k]={"texture":"res://assets/effects/sword_v5/"+{"sword_down":"down","sword_up":"up","sword_cross":"cross","sword_wave":"wave"}[k]+".png","grid":[2,2],"frames":4,"fps":22 if k!="sword_wave" else 14,"world_size":size}
save("data/combat_presentation.json",combat)
print("v5 data and vector assets written")
