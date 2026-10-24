#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""validate_data.py — 《奶龙：银河征途》M0 数据表校验脚本（python3，无第三方依赖）。

用法：python3 tools/validate_data.py
退出码：0 = 全部通过；1 = 存在错误（错误信息逐条打印）。
覆盖范围见 docs/数据契约.md 第 9 节。
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

FILES = {
    "regions": os.path.join(ROOT, "data", "world", "regions.json"),
    "enemies": os.path.join(ROOT, "data", "enemies.json"),
    "items": os.path.join(ROOT, "data", "items.json"),
    "weapons": os.path.join(ROOT, "data", "weapons.json"),
    "skills": os.path.join(ROOT, "data", "skills.json"),
    "talents": os.path.join(ROOT, "data", "talents.json"),
}

TILE_W, TILE_H = 640, 360          # 房间单元像素
PLAYER_HALF_W, PLAYER_HALF_H = 10, 17   # 玩家碰撞体 20x34
CHEST_HALF_H = 10                  # 宝箱 24x20，中心到底部 10

errors = []
passed = 0


def ok(msg):
    global passed
    passed += 1
    print("[OK] %03d %s" % (passed, msg))


def fail(msg):
    errors.append(msg)
    print("[FAIL] %s" % msg)


def check(cond, msg):
    if cond:
        ok(msg)
    else:
        fail(msg)
    return cond


def load_json(name):
    path = FILES[name]
    if not os.path.isfile(path):
        fail("文件缺失: %s" % path)
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)  # 严格 JSON：注释/尾逗号会直接抛异常
    except ValueError as e:
        fail("%s 不是合法严格 JSON: %s" % (path, e))
        return None
    return data


# ---------------------------------------------------------------- 基础工具

def room_wh(room):
    return room["size"][0] * TILE_W, room["size"][1] * TILE_H


def rect_ok(rect, W, H, label):
    """矩形 [x,y,w,h]：四个整数、正宽高、完全在房间边界内。"""
    if not (isinstance(rect, list) and len(rect) == 4
            and all(isinstance(v, int) for v in rect)):
        return False, "%s 形状非法（应为 [x,y,w,h] 四整数）: %r" % (label, rect)
    x, y, w, h = rect
    if w <= 0 or h <= 0:
        return False, "%s 宽高必须为正: %r" % (label, rect)
    if x < 0 or y < 0 or x + w > W or y + h > H:
        return False, "%s 越出房间边界(%dx%d): %r" % (label, W, H, rect)
    return True, ""


def point_in_bounds(p, W, H, label):
    if not (isinstance(p, list) and len(p) == 2
            and all(isinstance(v, int) for v in p)):
        return False, "%s 应为 [x,y] 整数坐标: %r" % (label, p)
    if not (0 <= p[0] <= W and 0 <= p[1] <= H):
        return False, "%s 越出房间边界(%dx%d): %r" % (label, W, H, p)
    return True, ""


def standing(plats, x, y, half_h=PLAYER_HALF_H, half_w=PLAYER_HALF_W, tol=10):
    """点 (x,y) 视为角色/物体中心，脚底 y+half_h 是否落在某平台顶面上。"""
    feet = y + half_h
    for (px, py, pw, _ph) in plats:
        if px - half_w <= x <= px + pw + half_w and -2 <= py - feet <= tol:
            return True
    return False


# ---------------------------------------------------------------- 期望表（与开发计划书 §4/§5 对齐）

EXPECTED_REGIONS = {"camp": ("奶泉营地", "#1a1614", 0),
                    "forest": ("奶源林地", "#16241a", 1),
                    "cave": ("蜜乳洞窟", "#120f1c", 2)}

EXPECTED_SIZES = {"camp_01": [2, 1], "camp_02": [1, 1],
                  "forest_01": [2, 1], "forest_02": [2, 1], "forest_03": [1, 2],
                  "forest_04": [2, 1], "forest_05": [1, 1], "forest_06": [1, 1],
                  "cave_01": [2, 1], "cave_02": [2, 1], "cave_03": [2, 1],
                  "cave_04": [2, 1], "cave_05": [1, 1], "cave_06": [2, 1],
                  "cave_07": [1, 1]}

EXPECTED_ENEMIES = {
    "camp_01": {}, "camp_02": {},
    "forest_01": {"moss_beetle": 2},
    "forest_02": {"milk_moth": 1, "milk_slime": 1},
    "forest_03": {"vine_flower": 1},
    "forest_04": {"moss_guard": 1},
    "forest_05": {}, "forest_06": {},
    "cave_01": {},
    "cave_02": {"lamp_bug": 2, "shadow_wisp": 1},
    "cave_03": {"acid_slug": 2},
    "cave_04": {"hive_guard": 1},
    "cave_05": {"acid_mother": 1},
    "cave_06": {"honey_queen": 1},
    "cave_07": {},
}

EXPECTED_FEATURES = {
    "camp_01": ["campfire", "storage"],
    "camp_02": ["merchant"],
    "forest_01": ["tutorial"],
    "forest_05": ["campfire"],
    "cave_01": ["tutorial"],
    "cave_04": ["campfire"],
    "cave_07": ["campfire"],
}

EXPECTED_CHESTS = {  # room -> [(item, count, coins, hidden), ...]
    "forest_01": [("potion_small", 2, 0, False)],
    "forest_04": [("hp_fragment", 1, 0, False)],
    "forest_06": [("hp_fragment", 1, 0, True)],
    "cave_02": [("sta_fragment", 1, 0, False)],
    "cave_03": [("", 0, 30, False)],
    "cave_05": [("bag_expand", 1, 0, False), ("mana_fragment", 1, 0, True)],
    "cave_07": [("ability_double_jump", 1, 0, False)],
}

EXPECTED_CHECKPOINTS = {"cp_camp_01", "cp_forest_05", "cp_cave_04", "cp_cave_07"}

EXPECTED_ENEMY_STATS = {  # id -> (rank, tier, hp, damage, defense, exp, coin_drop)
    "moss_beetle": ("small", 1, 30, 6, 8, 8, [3, 6]),
    "milk_moth": ("small", 1, 30, 6, 8, 8, [3, 6]),
    "milk_slime": ("small", 1, 30, 6, 8, 8, [3, 6]),
    "vine_flower": ("small", 1, 30, 6, 8, 8, [3, 6]),
    "lamp_bug": ("small", 2, 40, 8, 11, 14, [3, 6]),
    "shadow_wisp": ("small", 2, 40, 8, 11, 14, [3, 6]),
    "acid_slug": ("small", 2, 40, 8, 11, 14, [3, 6]),
    "wax_bee": ("small", 2, 40, 8, 11, 14, [3, 6]),
    "moss_guard": ("elite", 1, 240, 10, 8, 60, [30, 50]),
    "hive_guard": ("elite", 2, 320, 13, 11, 90, [30, 50]),
    "acid_mother": ("elite", 2, 320, 13, 11, 90, [30, 50]),
    "honey_queen": ("boss", 2, 1800, 18, 11, 400, [250, 250]),
}

EXPECTED_RESIST = {  # id -> (physical, magic)；缺省 (1.0, 1.0)
    "moss_beetle": (0.8, 1.0),
    "shadow_wisp": (1.0, 0.0),
    "acid_slug": (1.2, 0.6),
    "honey_queen": (1.0, 0.5),
}

EXPECTED_AI_FEATURES = {
    "milk_slime": ["split"],
    "moss_guard": ["shield"],
    "hive_guard": ["summon", "dive"],
    "acid_mother": ["split", "spray"],
}

EXPECTED_ITEMS = {  # id -> (type, stack, buy, sell)
    "potion_small": ("consumable", 5, 30, 15),
    "potion_mana": ("consumable", 5, 35, 17),
    "potion_sta": ("consumable", 5, 25, 12),
    "milk_bomb": ("consumable", 5, 20, 10),
    "mushroom": ("material", 99, None, 5),
    "honey_wax": ("material", 99, None, 8),
    "milk_crystal": ("material", 99, None, 40),
    "hp_fragment": ("fragment", 1, None, None),
    "sta_fragment": ("fragment", 1, None, None),
    "mana_fragment": ("fragment", 1, None, None),
    "bag_expand": ("special", 1, 120, 60),
    "map_fragment": ("special", 1, 60, 30),
    "ability_double_jump": ("ability", 1, None, None),
}

EXPECTED_WEAPONS = {  # id -> (damage_type, range_type, attack, interval, combo)
    "hammer_01": ("physical", "melee", 12, 0.55, 3),
    "milk_gun": ("physical", "ranged", 8, 0.35, 1),
    "milk_staff": ("magic", "melee", 10, 0.45, 1),
    "star_orb": ("magic", "ranged", 14, 0.9, 1),
}

EXPECTED_SKILLS = {  # id -> (mana_cost, cooldown, damage_mult, unlock)
    "skill_bubble": (8, 0.6, 1.0, "initial"),
    "skill_shield": (15, 8.0, None, "talent_milk_2"),
    "skill_slam": (12, 1.2, 1.5, "chest_cave"),
    "skill_heal": (25, 12.0, None, "merchant"),
    "skill_starfall": (30, 15.0, 0.8, "talent_milk_4"),
}

TALENT_COST_BY_TIER = {1: 100, 2: 130, 3: 160, 4: 170}
EXPECTED_TALENTS = ["brute_1", "brute_2", "brute_3", "brute_4",
                    "milk_1", "milk_2", "milk_3", "milk_4",
                    "agile_1", "agile_2", "agile_3", "agile_4"]

DOOR_ID_RE = re.compile(r"^([wesn])(\d*)$")
OPPOSITE = {"w": "e", "e": "w", "n": "s", "s": "n"}

ROOM_REQUIRED_FIELDS = ["id", "name", "region", "size", "bg", "platforms", "spawn",
                        "doors", "enemies", "chests", "hazards", "checkpoints",
                        "features", "map_rect"]


# ---------------------------------------------------------------- 主流程

def main():
    print("=== 《奶龙：银河征途》数据表校验（validate_data.py）===")

    # 1. 六文件严格 JSON 可解析
    data = {}
    for name in FILES:
        data[name] = load_json(name)
    check(all(v is not None for v in data.values()),
          "六个数据文件全部存在且为严格 JSON（无注释/无尾逗号）")
    if any(v is None for v in data.values()):
        summary()
        return 1

    regions_doc, enemies_doc = data["regions"], data["enemies"]
    items_doc, weapons_doc = data["items"], data["weapons"]
    skills_doc, talents_doc = data["skills"], data["talents"]

    enemies_by_id = {e["id"]: e for e in enemies_doc["enemies"]}
    items_by_id = {i["id"]: i for i in items_doc["items"]}

    # 2. regions 三条、rooms 15 条、id 唯一
    regions = regions_doc.get("regions", [])
    rooms = regions_doc.get("rooms", [])
    check(len(regions) == 3, "regions 数量 = 3（实际 %d）" % len(regions))
    region_ids = [r.get("id") for r in regions]
    check(len(set(region_ids)) == len(region_ids), "region id 唯一")
    for rid, (name, bg, tier) in EXPECTED_REGIONS.items():
        r = next((x for x in regions if x.get("id") == rid), None)
        check(r is not None and r.get("name") == name and r.get("bg") == bg
              and r.get("tier") == tier,
              "region %s = %s/%s/tier%d（附录 B 原文）" % (rid, name, bg, tier))
    check(len(rooms) == 15, "rooms 数量 = 15（实际 %d）" % len(rooms))
    room_ids = [r.get("id") for r in rooms]
    check(len(set(room_ids)) == len(room_ids), "room id 唯一")
    check(set(room_ids) == set(EXPECTED_SIZES), "15 房 id 集合与 §4.1 连接表一致")
    rooms_by_id = {r["id"]: r for r in rooms}

    # 3. 每房必填字段 / 尺寸 / bg / map_rect
    bad_fields = [r.get("id") for r in rooms
                  if any(f not in r for f in ROOM_REQUIRED_FIELDS)]
    check(not bad_fields, "15 房均含全部必填字段（缺失: %s）" % (bad_fields or "无"))
    bad_size = [rid for rid, sz in EXPECTED_SIZES.items()
                if rooms_by_id.get(rid, {}).get("size") != sz]
    check(not bad_size, "各房尺寸与 §4.1 一致且 ∈ {1x1,2x1,1x2,2x2}（异常: %s）"
          % (bad_size or "无"))
    bad_bg = []
    for r in rooms:
        reg = next((x for x in regions if x["id"] == r["region"]), None)
        if reg is None or r.get("bg") != reg.get("bg"):
            bad_bg.append(r["id"])
    check(not bad_bg, "每房 region 可解析且 bg 与所属区域一致（异常: %s）" % (bad_bg or "无"))

    # map_rect 互不重叠
    rects = [(r["id"], r["map_rect"]) for r in rooms]
    overlaps = []
    for i in range(len(rects)):
        for j in range(i + 1, len(rects)):
            (a_id, a), (b_id, b) = rects[i], rects[j]
            if (a[0] < b[0] + b[2] and b[0] < a[0] + a[2]
                    and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]):
                overlaps.append("%s×%s" % (a_id, b_id))
    check(not overlaps, "map_rect 两两互不重叠（重叠: %s）" % (overlaps or "无"))
    bad_maprect = [r["id"] for r in rooms
                   if not (isinstance(r["map_rect"], list) and len(r["map_rect"]) == 4
                           and all(isinstance(v, int) and v >= 0 for v in r["map_rect"])
                           and r["map_rect"][2] == r["size"][0]
                           and r["map_rect"][3] == r["size"][1])]
    check(not bad_maprect, "map_rect 为 [x,y,w,h] 非负整数且 w/h 与 size 一致（异常: %s）"
          % (bad_maprect or "无"))

    # 4. 几何：平台/危险区/各点坐标在边界内；spawn/门/宝箱/地面怪站在平台上
    for r in rooms:
        rid = r["id"]
        W, H = room_wh(r)
        plats = r["platforms"]
        geo_errs = []
        for p in plats:
            good, msg = rect_ok(p, W, H, "%s.platforms %s" % (rid, p))
            if not good:
                geo_errs.append(msg)
        for hz in r["hazards"]:
            good, msg = rect_ok(hz, W, H, "%s.hazards %s" % (rid, hz))
            if not good:
                geo_errs.append(msg)
        for label, p in [("spawn", r["spawn"])]:
            good, msg = point_in_bounds(p, W, H, "%s.%s" % (rid, label))
            if not good:
                geo_errs.append(msg)
        if not standing(plats, r["spawn"][0], r["spawn"][1]):
            geo_errs.append("%s.spawn %r 未站在任何平台上" % (rid, r["spawn"]))
        for d in r["doors"]:
            good, msg = point_in_bounds(d["pos"], W, H, "%s.door %s" % (rid, d["id"]))
            if not good:
                geo_errs.append(msg)
            if not standing(plats, d["pos"][0], d["pos"][1]):
                geo_errs.append("%s.door %s %r 未站在平台上" % (rid, d["id"], d["pos"]))
        for c in r["chests"]:
            good, msg = point_in_bounds(c["pos"], W, H, "%s.chest %s" % (rid, c["id"]))
            if not good:
                geo_errs.append(msg)
            if not standing(plats, c["pos"][0], c["pos"][1],
                            half_h=CHEST_HALF_H, half_w=12, tol=10):
                geo_errs.append("%s.chest %s %r 未放置在平台上" % (rid, c["id"], c["pos"]))
        for cp in r["checkpoints"]:
            good, msg = point_in_bounds(cp["pos"], W, H, "%s.checkpoint %s" % (rid, cp["id"]))
            if not good:
                geo_errs.append(msg)
            if not standing(plats, cp["pos"][0], cp["pos"][1]):
                geo_errs.append("%s.checkpoint %s 未站在平台上" % (rid, cp["id"]))
        for en in r["enemies"]:
            eid = en["id"]
            spec = enemies_by_id.get(eid)
            good, msg = point_in_bounds(en["pos"], W, H, "%s.enemy %s" % (rid, eid))
            if not good:
                geo_errs.append(msg)
                continue
            if spec and spec["ai"]["type"] in ("ground", "turret"):
                if not standing(plats, en["pos"][0], en["pos"][1]):
                    geo_errs.append("%s.enemy %s %r（地面/炮台）未站在平台上"
                                    % (rid, eid, en["pos"]))
        if geo_errs:
            for m in geo_errs:
                fail(m)
        else:
            ok("%s 几何合法：平台/危险区在边界内，spawn/门/宝箱/检查点/地面怪均立于平台" % rid)

    # 5. 门配对规则
    door_errs = []
    prefix_ok = True
    pair_seen = set()
    oneway_true = []
    requires_doors = []
    for r in rooms:
        rid = r["id"]
        W, H = room_wh(r)
        ids = [d["id"] for d in r["doors"]]
        if len(set(ids)) != len(ids):
            door_errs.append("%s 门 id 重复: %s" % (rid, ids))
        for d in r["doors"]:
            m = DOOR_ID_RE.match(d["id"])
            if not m:
                door_errs.append("%s 门 id %s 不符合方位惯例 w/e/n/s(+数字后缀)" % (rid, d["id"]))
                prefix_ok = False
                continue
            side = m.group(1)
            x, y = d["pos"]
            if side == "w" and x != 0:
                door_errs.append("%s.%s 西门应在 x=0（实际 %d）" % (rid, d["id"], x))
            if side == "e" and x != W - 10:
                door_errs.append("%s.%s 东门应在 x=%d（实际 %d）" % (rid, d["id"], W - 10, x))
            if side == "n" and y > 48:
                door_errs.append("%s.%s 北门应贴上边 y<=48（实际 %d）" % (rid, d["id"], y))
            if side == "s" and y < H - 48:
                door_errs.append("%s.%s 南门应贴下边 y>=%d（实际 %d）" % (rid, d["id"], H - 48, y))
            # 配对互指
            tgt_room = rooms_by_id.get(d["target"])
            if tgt_room is None:
                door_errs.append("%s.%s 目标房间 %s 不存在" % (rid, d["id"], d["target"]))
                continue
            tgt_door = next((t for t in tgt_room["doors"] if t["id"] == d["target_door"]), None)
            if tgt_door is None:
                door_errs.append("%s.%s 目标门 %s.%s 不存在" % (rid, d["id"], d["target"], d["target_door"]))
                continue
            if not (tgt_door["target"] == rid and tgt_door["target_door"] == d["id"]):
                door_errs.append("%s.%s 与 %s.%s 未互指" % (rid, d["id"], d["target"], d["target_door"]))
            tm = DOOR_ID_RE.match(tgt_door["id"])
            if not tm or tm.group(1) != OPPOSITE[side]:
                door_errs.append("%s.%s 与目标门 %s.%s 方位不互补（w<->e / n<->s）"
                                 % (rid, d["id"], d["target"], tgt_door["id"]))
            if d["one_way"] and tgt_door["one_way"]:
                door_errs.append("%s.%s 与 %s.%s 双侧 one_way=true" % (rid, d["id"], d["target"], tgt_door["id"]))
            if d["requires"] not in ("", "double_jump"):
                door_errs.append("%s.%s requires 枚举非法: %r" % (rid, d["id"], d["requires"]))
            if d["requires"] != tgt_door["requires"]:
                door_errs.append("%s.%s 与 %s.%s requires 不一致" % (rid, d["id"], d["target"], tgt_door["id"]))
            if d["one_way"]:
                oneway_true.append("%s.%s" % (rid, d["id"]))
            if d["requires"] == "double_jump":
                requires_doors.append("%s.%s" % (rid, d["id"]))
            pair_seen.add(tuple(sorted(("%s.%s" % (rid, d["id"]),
                                        "%s.%s" % (d["target"], d["target_door"])))))
    if door_errs:
        for m in door_errs:
            fail(m)
    else:
        ok("32 个门全部：id 方位惯例、贴边位置、互指一致、方位互补、requires 枚举合法")
    check(oneway_true == ["camp_01.n"],
          "单向捷径恰一处：camp_01.n 为 one_way=true 落点门（实际 %s）" % oneway_true)
    if oneway_true == ["camp_01.n"]:
        landing = rooms_by_id["camp_01"]["doors"]
        landing_door = next(d for d in landing if d["id"] == "n")
        cave_side = next(d for d in rooms_by_id["cave_07"]["doors"] if d["id"] == "s")
        check(landing_door["target"] == "cave_07" and not cave_side["one_way"],
              "cave_07.s 可通行(one_way=false) -> camp_01.n 锁定落点(one_way=true, 指回 cave_07)")
    check(sorted(requires_doors) == ["forest_03.n", "forest_06.s"],
          "能力门 requires=double_jump 恰为 forest_03.n / forest_06.s 两侧（实际 %s）"
          % sorted(requires_doors))

    # 6. 宝箱：共 8、hidden 恰 2、碎片分布、引用可解析
    all_chests = [(r["id"], c) for r in rooms for c in r["chests"]]
    check(len(all_chests) == 8, "宝箱总数 = 8（实际 %d）" % len(all_chests))
    hidden_rooms = sorted({rid for rid, c in all_chests if c.get("hidden")})
    check(hidden_rooms == ["cave_05", "forest_06"],
          "隐藏宝箱恰 2 个且位于 forest_06 / cave_05（实际 %s）" % hidden_rooms)
    got = {}
    for rid, c in all_chests:
        got.setdefault(rid, []).append((c["item"], c.get("count", 0),
                                        c.get("coins", 0), bool(c.get("hidden"))))
    mismatch = []
    for rid, exp_list in EXPECTED_CHESTS.items():
        if sorted(got.get(rid, [])) != sorted(exp_list):
            mismatch.append("%s: 期望 %s 实际 %s" % (rid, exp_list, got.get(rid, [])))
    for rid in got:
        if rid not in EXPECTED_CHESTS:
            mismatch.append("%s: 计划外宝箱 %s" % (rid, got[rid]))
    check(not mismatch, "8 个宝箱的物品/数量/奶币/隐藏分布与 §4.4 一致（%s）"
          % ("; ".join(mismatch) if mismatch else "全部匹配"))
    frag_rooms = {"hp_fragment": set(), "sta_fragment": set(), "mana_fragment": set()}
    for rid, c in all_chests:
        if c["item"] in frag_rooms:
            frag_rooms[c["item"]].add(rid)
    check(frag_rooms["hp_fragment"] == {"forest_04", "forest_06"}
          and frag_rooms["sta_fragment"] == {"cave_02"}
          and frag_rooms["mana_fragment"] == {"cave_05"},
          "碎片分布：生命x2(forest_04/forest_06) 体力x1(cave_02) 奶力x1(cave_05)（实际 %s）" % frag_rooms)
    bad_ref = []
    for rid, c in all_chests:
        if c["item"] == "":
            if not (isinstance(c.get("coins"), int) and c["coins"] > 0):
                bad_ref.append("%s.%s item 为空但 coins<=0" % (rid, c["id"]))
        elif c["item"] not in items_by_id:
            bad_ref.append("%s.%s 引用未知物品 %s" % (rid, c["id"], c["item"]))
    check(not bad_ref, "宝箱 item 引用可解析（item 空串则 coins>0）（%s）" % (bad_ref or "全部通过"))

    # 7. 房间敌人分布与引用
    got_enemies = {}
    bad_enemy_ref = []
    for r in rooms:
        cnt = {}
        for en in r["enemies"]:
            if en["id"] not in enemies_by_id:
                bad_enemy_ref.append("%s 引用未知敌人 %s" % (r["id"], en["id"]))
            cnt[en["id"]] = cnt.get(en["id"], 0) + 1
        got_enemies[r["id"]] = cnt
    check(not bad_enemy_ref, "房间 enemies[].id 引用全部可解析（%s）" % (bad_enemy_ref or "全部通过"))
    mism = [rid for rid in EXPECTED_ENEMIES
            if got_enemies.get(rid, {}) != EXPECTED_ENEMIES[rid]]
    check(not mism, "15 房刷怪分布与 §4.1/§4.3 一致（异常: %s）" % (mism or "无"))

    # 8. 检查点与功能设施
    cps = [(r["id"], cp["id"]) for r in rooms for cp in r["checkpoints"]]
    cp_ids = [cp for _, cp in cps]
    check(len(set(cp_ids)) == len(cp_ids), "检查点 id 全局唯一")
    check(set(cp_ids) == EXPECTED_CHECKPOINTS,
          "检查点恰为 cp_camp_01/cp_forest_05/cp_cave_04/cp_cave_07（实际 %s）" % sorted(cp_ids))
    feat_errs = []
    for rid, feats in EXPECTED_FEATURES.items():
        have = rooms_by_id[rid].get("features", [])
        for f in feats:
            if f not in have:
                feat_errs.append("%s 缺少 feature %s" % (rid, f))
    check(not feat_errs, "篝火/仓库/商人/教学等功能设施分布正确（%s）" % (feat_errs or "全部匹配"))
    check(len(rooms_by_id["cave_03"]["hazards"]) >= 1, "cave_03 酸池 hazard >= 1")

    # 9. 连通性：主路可达（无能力门），加二段跳后全图可达
    def reachable(abilities):
        seen = {"camp_01"}
        frontier = ["camp_01"]
        while frontier:
            cur = frontier.pop()
            for d in rooms_by_id[cur]["doors"]:
                if d["one_way"]:
                    continue
                if d["requires"] and d["requires"] not in abilities:
                    continue
                nxt = d["target"]
                if nxt not in seen:
                    seen.add(nxt)
                    frontier.append(nxt)
        return seen

    base = reachable(set())
    check(base == set(room_ids) - {"forest_06"},
          "主线连通：从 camp_01 不用二段跳可达除 forest_06 外全部 14 房（缺: %s）"
          % (sorted(set(room_ids) - {"forest_06"} - base) or "无"))
    full = reachable({"double_jump"})
    check(full == set(room_ids), "解锁二段跳后 15 房全部可达（缺: %s）"
          % (sorted(set(room_ids) - full) or "无"))

    # 10. enemies.json：数量、档位、§5.2 公式、抗性、预警、词条、经验/掉落
    elist = enemies_doc["enemies"]
    check(len(elist) == 12, "敌人总数 = 12（实际 %d）" % len(elist))
    check(len({e["id"] for e in elist}) == 12, "敌人 id 唯一")
    check(set(e["id"] for e in elist) == set(EXPECTED_ENEMY_STATS),
          "12 个敌人 id 集合与 §4.3 一致（8 小怪/3 精英/1 BOSS）")
    rank_cnt = {"small": 0, "elite": 0, "boss": 0}
    for e in elist:
        rank_cnt[e["rank"]] = rank_cnt.get(e["rank"], 0) + 1
    check(rank_cnt == {"small": 8, "elite": 3, "boss": 1},
          "档位构成 8 小怪 / 3 精英 / 1 BOSS（实际 %s）" % rank_cnt)
    stat_errs = []
    for e in elist:
        exp = EXPECTED_ENEMY_STATS[e["id"]]
        got_tuple = (e["rank"], e["tier"], e["hp"], e["damage"], e["defense"],
                     e["exp"], e["coin_drop"])
        if got_tuple != exp:
            stat_errs.append("%s 数值 %s != §5.2 期望 %s" % (e["id"], got_tuple, exp))
        p, m = EXPECTED_RESIST.get(e["id"], (1.0, 1.0))
        if e["resist"]["physical"] != p or e["resist"]["magic"] != m:
            stat_errs.append("%s 抗性 (%s,%s) != 期望 (%s,%s)"
                             % (e["id"], e["resist"]["physical"], e["resist"]["magic"], p, m))
        if e["ai"]["telegraph_time"] < 0.25:
            stat_errs.append("%s telegraph_time %.2f < 0.25" % (e["id"], e["ai"]["telegraph_time"]))
        if e["ai"]["type"] not in ("ground", "fly", "float", "turret"):
            stat_errs.append("%s ai.type 枚举非法: %s" % (e["id"], e["ai"]["type"]))
        for f in EXPECTED_AI_FEATURES.get(e["id"], []):
            if f not in e["ai"]["features"]:
                stat_errs.append("%s ai.features 缺少 %s" % (e["id"], f))
    check(not stat_errs, "敌人 hp/damage/defense 符合 §5.2 公式、抗性符合 §3.3、预警>=0.25s、"
          "机制词条齐全（%s）" % ("; ".join(stat_errs) if stat_errs else "12 条全部通过"))
    q = enemies_by_id["honey_queen"]
    check("P1" in q["desc"] and "P2" in q["desc"] and "酸池喷涌" in q["desc"]
          and "俯冲三连" in q["desc"],
          "蜂蜜女王两阶段招式已写入 desc（P1 酸池喷涌/蜂群冲击，P2 俯冲三连/黏网/召唤）")

    # 11. items.json：数量、价格、堆叠、卖价<买价
    ilist = items_doc["items"]
    check(len(ilist) >= 12, "道具数 >= 12（实际 %d）" % len(ilist))
    check(len({i["id"] for i in ilist}) == len(ilist), "道具 id 唯一")
    item_errs = []
    for i in ilist:
        if i["type"] not in ("consumable", "material", "fragment", "special", "ability"):
            item_errs.append("%s type 枚举非法: %s" % (i["id"], i["type"]))
        if i["price_buy"] is not None and i["price_sell"] is not None \
                and not (0 <= i["price_sell"] < i["price_buy"]):
            item_errs.append("%s 卖价 %s 未严格小于买价 %s" % (i["id"], i["price_sell"], i["price_buy"]))
        if i["id"] in EXPECTED_ITEMS:
            exp = EXPECTED_ITEMS[i["id"]]
            got_ = (i["type"], i["stack"], i["price_buy"], i["price_sell"])
            if got_ != exp:
                item_errs.append("%s %s != 计划 %s" % (i["id"], got_, exp))
    eff = items_by_id["potion_small"]["effect"]
    check(eff.get("restore_hp") == 30, "potion_small 效果 restore_hp=30")
    check(items_by_id["ability_double_jump"]["effect"].get("unlock_ability") == "double_jump",
          "ability_double_jump 效果 unlock_ability=double_jump")
    check(not item_errs, "道具类型/堆叠/价格全部符合计划且可卖道具卖价<买价（%s）"
          % ("; ".join(item_errs) if item_errs else "13 条全部通过"))

    # 12. weapons.json：四象限、数值、专属字段
    wlist = weapons_doc["weapons"]
    check(len(wlist) == 4 and len({w["id"] for w in wlist}) == 4, "武器 4 条且 id 唯一")
    w_errs = []
    for w in wlist:
        if w["id"] not in EXPECTED_WEAPONS:
            w_errs.append("计划外武器 %s" % w["id"])
            continue
        exp = EXPECTED_WEAPONS[w["id"]]
        got_ = (w["damage_type"], w["range_type"], w["attack"],
                w["attack_interval"], w["combo"])
        if got_ != exp:
            w_errs.append("%s %s != §3.3 表 %s" % (w["id"], got_, exp))
    wby = {w["id"]: w for w in wlist}
    if not (wby["hammer_01"]["hitbox"] == {"w": 44, "h": 36}
            and wby["hammer_01"].get("shield_break") is True):
        w_errs.append("hammer_01 hitbox/shield_break 字段不符")
    if not (wby["milk_gun"]["projectile"] == {"speed": 420, "charge": True,
                                              "pierce_when_full": True}):
        w_errs.append("milk_gun projectile 字段不符")
    if not (wby["milk_staff"]["hitbox"] == {"w": 52, "h": 30}
            and wby["milk_staff"].get("mana_regen") == 3):
        w_errs.append("milk_staff hitbox/mana_regen 字段不符")
    if not (wby["star_orb"]["projectile"] == {"speed": 260, "split": 6}):
        w_errs.append("star_orb projectile 字段不符")
    check(not w_errs, "四武器四象限类型/攻速/连击/专属字段与 §3.3 一致（%s）"
          % ("; ".join(w_errs) if w_errs else "全部通过"))

    # 13. skills.json：数值与 §3.6 一致
    slist = skills_doc["skills"]
    check(len(slist) == 5 and len({s["id"] for s in slist}) == 5, "技能 5 条且 id 唯一")
    s_errs = []
    sby = {s["id"]: s for s in slist}
    for sid, exp in EXPECTED_SKILLS.items():
        if sid not in sby:
            s_errs.append("缺少技能 %s" % sid)
            continue
        s = sby[sid]
        got_ = (s["mana_cost"], s["cooldown"], s["damage_mult"], s["unlock"])
        if got_ != exp:
            s_errs.append("%s %s != §3.6 表 %s" % (sid, got_, exp))
    if sby["skill_shield"].get("absorb") != 40 or sby["skill_shield"].get("duration") != 5:
        s_errs.append("skill_shield absorb/duration 应为 40/5")
    if sby["skill_heal"].get("heal_pct") != 30:
        s_errs.append("skill_heal heal_pct 应为 30")
    if sby["skill_starfall"].get("hits") != 3:
        s_errs.append("skill_starfall hits 应为 3（每段 0.8 倍）")
    if sby["skill_bubble"].get("slow") != 30:
        s_errs.append("skill_bubble slow 应为 30")
    if sby["skill_slam"].get("shape") != "sector" or sby["skill_slam"].get("knockback") is None:
        s_errs.append("skill_slam 应为扇形+击退")
    check(not s_errs, "5 技能奶力/冷却/倍率/解锁与 §3.6 一致，专属字段齐全（%s）"
          % ("; ".join(s_errs) if s_errs else "全部通过"))

    # 14. talents.json：12 节点、链条、费用
    tlist = talents_doc["talents"]
    check(len(tlist) == 12 and len({t["id"] for t in tlist}) == 12, "天赋 12 条且 id 唯一")
    check(sorted(t["id"] for t in tlist) == sorted(EXPECTED_TALENTS),
          "天赋 id 集合 = brute/milk/agile 1..4")
    tby = {t["id"]: t for t in tlist}
    t_errs = []
    for t in tlist:
        prefix, tier_s = t["id"].rsplit("_", 1)
        tier = int(tier_s)
        if t["tier"] != tier or t["branch"] not in ("蛮力", "奶术", "灵巧"):
            t_errs.append("%s tier/branch 非法" % t["id"])
        if t["cost_coin"] != TALENT_COST_BY_TIER[tier]:
            t_errs.append("%s cost_coin %s != %d" % (t["id"], t["cost_coin"], TALENT_COST_BY_TIER[tier]))
        if t["cost_point"] != 1:
            t_errs.append("%s cost_point 应为 1" % t["id"])
        want_req = "" if tier == 1 else "%s_%d" % (prefix, tier - 1)
        if t["requires"] != want_req:
            t_errs.append("%s requires %r != %r" % (t["id"], t["requires"], want_req))
        if want_req and want_req not in tby:
            t_errs.append("%s 前置 %s 不存在" % (t["id"], want_req))
        if not isinstance(t["effect"], dict) or not t["effect"]:
            t_errs.append("%s effect 不能为空" % t["id"])
    total_cost = sum(t["cost_coin"] for t in tlist)
    if total_cost != 1680:
        t_errs.append("三支合计 cost_coin = %d != 1680（§3.8 预算）" % total_cost)
    if tby["agile_4"]["effect"].get("enabled") is not False:
        t_errs.append("agile_4 三重奶泡应为本期预留（enabled=false）")
    branches = {"brute": "蛮力", "milk": "奶术", "agile": "灵巧"}
    for pre, br in branches.items():
        got_branches = {tby["%s_%d" % (pre, i)]["branch"] for i in range(1, 5)}
        if got_branches != {br}:
            t_errs.append("%s 分支名不一致: %s" % (pre, got_branches))
    check(not t_errs, "天赋 12 节点链条/层级/分支正确，层价 100/130/160/170，合计 1680（%s）"
          % ("; ".join(t_errs) if t_errs else "全部通过"))

    summary()
    return 0 if not errors else 1


def summary():
    print("-" * 64)
    if errors:
        print("结果：失败，%d 项错误 / %d 项通过" % (len(errors), passed))
    else:
        print("结果：全部通过（%d 项检查，0 错误）" % passed)
    print("-" * 64)


if __name__ == "__main__":
    sys.exit(main())
