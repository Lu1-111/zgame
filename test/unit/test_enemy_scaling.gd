extends RefCounted
## 基础属性解析只生成副本，区域倍率绝不改变未标基础的数值。
func run(ctx) -> bool:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/regions.json"))
	for region: Dictionary in world.regions:
		ctx.expect_eq(float(region.enemy_multiplier),1.0,"%s 当前区域倍率为1.0" % region.id)
	for base: Dictionary in data.enemies:
		var same := EnemyStats.resolve(base,{"enemy_multiplier":1.0})
		ctx.expect_eq(same.hp,base.base_hp,"%s 区域1.0保留基础生命" % base.id)
		ctx.expect_eq(same.damage,base.base_damage,"%s 区域1.0保留基础攻击" % base.id)
		var doubled := EnemyStats.resolve(base,{"enemy_multiplier":2.0})
		ctx.expect_eq(doubled.hp,int(base.base_hp)*2,"%s 实际生命按区域倍率计算" % base.id)
		ctx.expect_eq(doubled.damage,int(base.base_damage)*2,"%s 实际攻击按区域倍率计算" % base.id)
		ctx.expect_true(doubled.defense == base.defense and doubled.poise == base.poise and doubled.exp == base.exp and doubled.coin_drop == base.coin_drop and doubled.ai == base.ai,"%s 非基础属性不缩放" % base.id)
		ctx.expect_true(not base.has("hp") and not base.has("damage"),"%s 不回写基础表" % base.id)
	var boss: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses/claffert.json"))
	ctx.expect_true(boss.phases[0].base_hp == 600 and boss.phases[1].base_hp == 1000 and boss.base_damage == 10 and boss.phases[0].poise == 300 and boss.phases[1].poise == 450,"克拉弗特两阶段已确认值准确登记")
	ctx.expect_true(boss.combat_enabled and boss.id == "corrumpt" and boss.combat.implemented_phase == 2 and boss.phase2_combat.enabled,"首领双阶段按新设计开放")
	var frames := load(str(boss.art.root)+"godot/Claffert_idle_frames.tres") as SpriteFrames
	for phase in [1,2]:
		if phase == 2:
			frames = load(str(boss.art.phase2.root)+"godot/Corrumpt_phase2_frames.tres") as SpriteFrames
		var name := StringName("phase_%d_idle" % phase)
		ctx.expect_eq(frames.get_frame_count(name),8,"克拉弗特%d阶段完整八帧" % phase)
		ctx.expect_true(frames.get_animation_loop(name) and frames.get_animation_speed(name) == 8,"克拉弗特%d阶段8fps循环" % phase)
		for index in 8:
			var frame := frames.get_frame_texture(name,index)
			var size: Array = boss.art.native_cell[String(name)]
			ctx.expect_true(frame != null and frame.get_size() == Vector2(size[0],size[1]),"阶段%d帧%d保持统一原生像素画布" % [phase,index])
	return true
