extends RefCounted
## test_game_state.gd —— GameState 状态与序列化用例（QA，T-004）
## 断言默认值锚点（AGENTS.md §5）、to_save_dict/load_from_dict 往返一致、reset 恢复默认。

func run(ctx) -> bool:
	var gs: Node = ctx.fetch_singleton("GameState", "res://scripts/autoload/game_state.gd")
	# 先 reset 一次，保证无论从哪条路径取得单例，起点都是默认态
	gs.reset()
	_check_defaults(ctx, gs, "初始默认值")

	# ---- to_save_dict / load_from_dict 往返 ----
	gs.level = 5
	gs.exp = 120
	gs.coin = 77
	gs.hp = 33
	gs.hp_max = 96
	gs.sta = 40
	gs.sta_max = 110
	gs.mana = 12
	gs.mana_max = 74
	gs.weapon_id = StringName("milk_gun")
	# 类型化数组属性不能跨脚本动态赋无类型数组字面量，需先构造同型数组再赋值
	var abilities_val: Array[StringName] = [StringName("double_jump")]
	gs.abilities = abilities_val
	var talents_val: Array[StringName] = [StringName("brute_1"), StringName("milk_2")]
	gs.talents = talents_val
	gs.inventory = [{"id": "potion_small", "count": 2}, {"id": "mushroom", "count": 7}]
	gs.hotbar = ["potion_small", "", "", "", ""]
	var chests_val: Array[StringName] = [StringName("chest_f01"), StringName("chest_c03")]
	gs.opened_chests = chests_val
	var rooms_val: Array[StringName] = [StringName("camp_01"), StringName("cave_03")]
	gs.visited_rooms = rooms_val
	var bosses_val: Array[StringName] = [StringName("honey_queen")]
	gs.defeated_bosses = bosses_val
	gs.current_room = StringName("cave_03")
	gs.checkpoint_id = StringName("cp_cave_04")
	gs.play_time = 123.45

	var snap: Dictionary = gs.to_save_dict()
	gs.reset()  # 先抹掉，再靠读档恢复，验证 load_from_dict 真正写入
	gs.load_from_dict(snap)

	var restored: Dictionary = gs.to_save_dict()
	for key in snap.keys():
		# 用 JSON 文本比对（字典/数组经两次独立序列化，逐键比对内容而非引用）
		ctx.expect_eq(JSON.stringify(restored.get(key)), JSON.stringify(snap[key]),
			"存档往返恢复字段 '%s'" % String(key))
	# 关键锚点直接对实例复查（防 to_save_dict 二次序列化掩盖问题）
	ctx.expect_eq(int(gs.level), 5, "读档后 level == 5")
	ctx.expect_eq(int(gs.coin), 77, "读档后 coin == 77")
	ctx.expect_eq(String(gs.weapon_id), "milk_gun", "读档后 weapon_id == milk_gun")
	ctx.expect_eq(String(gs.current_room), "cave_03", "读档后 current_room == cave_03")
	ctx.expect_eq(String(gs.checkpoint_id), "cp_cave_04", "读档后 checkpoint_id == cp_cave_04")

	# ---- reset 恢复默认 ----
	gs.reset()
	_check_defaults(ctx, gs, "reset 后默认值")
	return true

func _check_defaults(ctx, gs: Node, tag: String) -> void:
	## 断言 GameState 全部默认值锚点（AGENTS.md §5：HP 80/80、体力 100/100、奶力 60/60、
	## Lv1、EXP 0、奶币 0、初始武器 hammer_01、初始房间 camp_01、初始检查点 cp_camp_01）
	ctx.expect_eq(int(gs.hp), 80, "%s：hp == 80" % tag)
	ctx.expect_eq(int(gs.hp_max), 80, "%s：hp_max == 80" % tag)
	ctx.expect_eq(int(gs.sta), 100, "%s：sta == 100" % tag)
	ctx.expect_eq(int(gs.sta_max), 100, "%s：sta_max == 100" % tag)
	ctx.expect_eq(int(gs.mana), 60, "%s：mana == 60" % tag)
	ctx.expect_eq(int(gs.mana_max), 60, "%s：mana_max == 60" % tag)
	ctx.expect_eq(int(gs.level), 1, "%s：level == 1" % tag)
	ctx.expect_eq(int(gs.exp), 0, "%s：exp == 0" % tag)
	ctx.expect_eq(int(gs.coin), 0, "%s：coin == 0" % tag)
	ctx.expect_eq(String(gs.weapon_id), "hammer_01", "%s：weapon_id == hammer_01" % tag)
	ctx.expect_eq(String(gs.current_room), "camp_01", "%s：current_room == camp_01" % tag)
	ctx.expect_eq(String(gs.checkpoint_id), "cp_camp_01", "%s：checkpoint_id == cp_camp_01" % tag)
	ctx.expect_true((gs.abilities as Array).is_empty(), "%s：abilities 为空" % tag)
	ctx.expect_true((gs.talents as Array).is_empty(), "%s：talents 为空" % tag)
	ctx.expect_true((gs.inventory as Array).is_empty(), "%s：inventory 为空" % tag)
	ctx.expect_true((gs.hotbar as Array).is_empty(), "%s：hotbar 为空" % tag)
	ctx.expect_true((gs.opened_chests as Array).is_empty(), "%s：opened_chests 为空" % tag)
	ctx.expect_true((gs.visited_rooms as Array).is_empty(), "%s：visited_rooms 为空" % tag)
	ctx.expect_true((gs.defeated_bosses as Array).is_empty(), "%s：defeated_bosses 为空" % tag)
	ctx.expect_eq(float(gs.play_time), 0.0, "%s：play_time == 0.0" % tag)
