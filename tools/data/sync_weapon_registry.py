"""从正式武器表生成ID映射、参数及效果状态；新增/修改武器后必须同步。"""
from pathlib import Path
import argparse
import json

ROOT=Path(__file__).resolve().parents[2]


def build():
    data=json.loads((ROOT/'data/weapons.json').read_text(encoding='utf8'))['weapons']
    base=json.loads((ROOT/'data/weapon_attributes.json').read_text(encoding='utf8'))['types']
    lines=['# 武器登记表','','权威数据：`data/weapons.json`；四类普攻基础值：`data/weapon_attributes.json`。',
           '新增或修改武器必须运行 `python tools/data/sync_weapon_registry.py`，验收使用 `--check`。其他表引用稳定ID，不使用显示名称定位。',
           '','','普通攻击削韧为类别基础削韧乘武器削韧倍率；实际攻击动作时间为基础时间除以攻速倍率，起手、判定、收招均按此规则计算。攻速倍率越大，攻击用时越短。技能时间与削韧独立配置。',
           '','| 类别 | 各段基础削韧 | 起手/判定/收招（秒） | 每段总时间（秒） |', '|---|---|---|---|']
    for kind,row in base.items():
        lines.append(f'| {kind} | '+ ' / '.join(map(str,row['base_poise']))+' | '+ ' / '.join(str(row['base_attack_time'][p]) for p in ['startup','active','recovery'])+f' | {row["base_total_seconds"]} |')
    lines+=['','步枪使用已有兼容武器 milk_gun 的已填削韧25；旧 poise.json 中 bow_01 的历史空值仍保留。',
            '','| ID | 名称 | 类别 | 攻击力 | 削韧倍率 | 攻速倍率 | 每次耗弹 | 外观 |', '|---|---|---|---:|---:|---:|---:|---|']
    for row in data:
        legacy='（旧档兼容）' if row.get('legacy') else ''
        ammo = f'{row["ammo_cost_pct"]}%' if "ammo_cost_pct" in row else "—"
        lines.append(f'| `{row["id"]}` | {row["name"]}{legacy} | {row["weapon_type"]} | {row["attack"]} | {row["poise_multiplier"]} | {row["attack_speed_multiplier"]} | {ammo} | `{row["appearance_id"]}` |')
    for row in data:
        lines+=['',f'## {row["id"]} · {row["name"]}','',row.get('appearance_description','沿用已确认原武器外形。'),'',row['desc'],'',
                '能力：'+row.get('special_description','无')]
        for effect in row.get('special_effects',[]):
            lines.append('- '+effect['kind']+'：'+('已实装' if effect.get('implemented') else '占位，尚未生效'))
        if row['appearance_id'] == row['id']:
            lines += ['', f'原生模型见 `assets/PROCESSED/weapons/{row["id"]}/v001/model.json`。']
    lines+=['','## 运行约定','',
            '切割者每段首次造成有效生命伤害后增加一层动能，该段后续目标沿用段开始时的伤害倍率；空挥结束清层，换装与死亡清层。',
            '血刃按敌人实际生命损失的5%治疗，小数累计至完整生命值；过量击杀部分不计，满血不储存治疗。',
            '流星锤只对命中前已经破韧的目标增加20%伤害，造成破韧的那一击不追溯加成。',
            '巨剑持握格挡时生命伤害为0，仍消耗体力；体力耗尽仍破防，退出防御后的攻击正常受伤。',
            '枪类基础射击间隔为1秒，实际间隔除以攻速倍率。弹药储量由枪类共用，每次射击扣除表内百分比，新开局、坐火及重生时补满。长按左键连续普攻，剑锤按原连段循环，枪杖持续按光标方向发射。',
            '十字弩发射弩箭，撕裂者发射蓝色电磁弹，电磁弹命中时扩散浅蓝色电弧。狙击弹可穿过多个敌人，每个敌人只命中一次。电磁弹范围判定半径暂定48像素，对直接目标之外、范围内无遮挡的敌人造成40%伤害，附加削韧为0。',
            '本原型批次通过rpg_systems修订3一次性加入装备库，方便验证。饰品效果见[饰品登记表](饰品登记表.md)。',
            '残刃命中施加2秒流血，落英命中施加5秒中毒。各异常数值见data/status_effects.json。武器技能仍为占位。',
            '旧武器拆分层保存在assets/PROCESSED/weapons/appearances/v001，按动作归类；原人物确认母版继续保留作为无损来源。',
            '','测试入口：`test/launchers/run_weapon_combat.cmd`；可选择武器、逐段攻击、完整连招、重播及左右朝向。','']
    return '\n'.join(lines)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    path=ROOT/'docs/gameplay/武器登记表.md';content=build()
    if args.check:
        if not path.exists() or path.read_text(encoding='utf8')!=content:
            print('WEAPON REGISTRY: FAIL; run tools/data/sync_weapon_registry.py');return 1
        print('WEAPON REGISTRY: synchronized');return 0
    path.parent.mkdir(parents=True,exist_ok=True);path.write_text(content,encoding='utf8');print('WEAPON REGISTRY: updated');return 0


if __name__=='__main__':raise SystemExit(main())
