extends RefCounted
## test_world_data.gd —— 世界数据完整性用例（QA，T-004）
## 经 DataDB.load_all() 载入 data/*.json，断言规模锚点（参考书 §4.1 连接表）与
## 门图完整性：目标房间存在、目标门存在、两门互指、one_way 组合合法、requires 合法，
## 以及刷怪 id / 宝箱 item 均可查询。

const VALID_REQUIRES := ["", "double_jump"]

func run(ctx) -> bool:
	var db: Node = ctx.fetch_singleton("DataDB", "res://scripts/autoload/data_db.gd")
	var err: int = db.load_all()
	ctx.expect_eq(err, OK, "DataDB.load_all() 返回 OK")
	ctx.expect_true(bool(db.loaded), "DataDB.loaded == true")

	# ---- 规模锚点：3 区域 / 15 房 / 12 敌（8 small + 3 elite + 1 boss）/ 物品≥12 / 武器4 / 技能5 / 天赋12 ----
	ctx.expect_eq(db.regions.size(), 3, "区域数 regions == 3")
	ctx.expect_eq(db.rooms.size(), 15, "房间数 rooms == 15")
	ctx.expect_eq(db.enemies.size(), 12, "敌人数 enemies == 12")
	var rank_count := {"small": 0, "elite": 0, "boss": 0}
	for e_any in db.enemies.values():
		var rank := String((e_any as Dictionary).get("rank", ""))
		if rank_count.has(rank):
			rank_count[rank] = int(rank_count[rank]) + 1
	ctx.expect_eq(rank_count["small"], 8, "敌人类别 small == 8")
	ctx.expect_eq(rank_count["elite"], 3, "敌人类别 elite == 3")
	ctx.expect_eq(rank_count["boss"], 1, "敌人类别 boss == 1")
	ctx.expect_true(db.items.size() >= 12, "道具数 items >= 12（实际 %d）" % db.items.size())
	ctx.expect_eq(db.weapons.size(), 4, "武器数 weapons == 4")
	ctx.expect_eq(db.skills.size(), 5, "技能数 skills == 5")
	ctx.expect_eq(db.talents.size(), 12, "天赋数 talents == 12")

	# ---- 门图完整性：每个房间的每扇门 ----
	for room_any in db.rooms.values():
		var room: Dictionary = room_any
		var rid := String(room.get("id", ""))
		for door_any in room.get("doors", []):
			var door: Dictionary = door_any
			var did := String(door.get("id", ""))
			var label := "房间 %s 门 %s" % [rid, did]
			var target := String(door.get("target", ""))
			var target_door := String(door.get("target_door", ""))

			var other_room: Dictionary = db.get_room(StringName(target))
			ctx.expect_true(not other_room.is_empty(), "%s：target 房间 '%s' 存在" % [label, target])
			if other_room.is_empty():
				continue

			var other: Dictionary = {}
			for od_any in other_room.get("doors", []):
				var od: Dictionary = od_any
				if String(od.get("id", "")) == target_door:
					other = od
					break
			ctx.expect_true(not other.is_empty(), "%s：目标房间 '%s' 存在 id=='%s' 的门" % [label, target, target_door])
			if other.is_empty():
				continue

			var mutual: bool = String(other.get("target", "")) == rid and String(other.get("target_door", "")) == did
			ctx.expect_true(mutual, "%s：与 %s/%s 两门互指（对方 target=='%s'、target_door=='%s'）" % [label, target, target_door, rid, did])

			# one_way 组合：双向门两侧均 false；单向对恰有一侧 true（true 侧 = 仅落点，AGENTS.md §6）
			var one_way_ok: bool = not (bool(door.get("one_way", false)) and bool(other.get("one_way", false)))
			ctx.expect_true(one_way_ok, "%s：与 %s/%s 的 one_way 组合合法（双向门两侧均 false / 单向对恰一侧 true）" % [label, target, target_door])

			var req := String(door.get("requires", ""))
			ctx.expect_true(req in VALID_REQUIRES, "%s：requires '%s' ∈ {\"\", \"double_jump\"}" % [label, req])

	# ---- 刷怪与宝箱引用完整性 ----
	for room_any2 in db.rooms.values():
		var room2: Dictionary = room_any2
		var rid2 := String(room2.get("id", ""))
		for e_any2 in room2.get("enemies", []):
			var spawn: Dictionary = e_any2
			var eid := String(spawn.get("id", ""))
			ctx.expect_true(not db.get_enemy(StringName(eid)).is_empty(),
				"房间 %s 刷怪 id '%s' 能经 get_enemy 查到" % [rid2, eid])
		for c_any in room2.get("chests", []):
			var chest: Dictionary = c_any
			var cid := String(chest.get("id", ""))
			var item := String(chest.get("item", ""))
			if item == "":
				ctx.expect_true(int(chest.get("coins", 0)) > 0,
					"宝箱 %s：item 为空串时必须 coins>0（实际 coins=%s）" % [cid, str(chest.get("coins", 0))])
			else:
				ctx.expect_true(not db.get_item(StringName(item)).is_empty(),
					"宝箱 %s：item '%s' 能经 get_item 查到" % [cid, item])
	return true
