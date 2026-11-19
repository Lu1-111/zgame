extends RefCounted
## 新地图尺寸、配对通道、清场区域、空宝箱和美术来源契约。
func run(ctx) -> bool:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/forest_03.json"))
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/forest_02.json"))
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(config.presentation))
	var scene := (load("res://scenes/maps/forest_03.tscn") as PackedScene).instantiate()
	ctx.expect_eq(int(config.bounds[0]),4*int(ProjectSettings.get_setting("display/window/size/viewport_width")),"forest_03宽度恰为四屏")
	ctx.expect_eq(config.bounds[1],previous.bounds[1],"forest_03与02等高")
	ctx.expect_eq(config.enemies.size(),17,"草图15个小怪、2个精英落点均已放置")
	var types := {}
	var elite_count := 0
	var ids := {}
	for spawn: Dictionary in config.enemies:
		types[str(spawn.enemy_id)] = true
		ids[str(spawn.spawn_id)] = true
		elite_count += int(str(spawn.enemy_id) == "moss_guard")
		ctx.expect_true(scene.has_node("Enemy_"+str(spawn.spawn_id)),"怪物实际入场景 "+str(spawn.spawn_id))
	ctx.expect_eq(types.size(),5,"仅指定四小怪与苔甲卫")
	ctx.expect_eq(elite_count,2,"两处菱形均为苔甲卫")
	ctx.expect_eq(config.chests.size(),4,"两普通箱与两战斗箱")
	for chest: Dictionary in config.chests:
		ctx.expect_true(str(chest.item) == "" and int(chest.count) == 0,"宝箱物品保持空白 "+str(chest.id))
	for encounter: Dictionary in config.encounters:
		ctx.expect_true(not encounter.spawn_ids.is_empty(),"清怪条件有明确成员 "+str(encounter.id))
		for id: String in encounter.spawn_ids:
			ctx.expect_true(ids.has(id),"清怪成员确实存在 "+id)
	for gate: Dictionary in config.gates:
		var body := scene.get_node(str(gate.id)) as StaticBody2D
		ctx.expect_eq(body.collision_layer,1,"雾墙确实阻挡实体 "+str(gate.id))
		ctx.expect_eq(str(body.get_meta("clear_flag")),str(gate.clear_flag),"雾墙具有永久清场标记 "+str(gate.id))
	ctx.expect_eq(str(scene.get_node("DoorWest").target_door),"DoorEast","下层连接02右下通道")
	ctx.expect_eq(str(scene.get_node("DoorWestShortcut").shortcut_id),"forest_02_canopy_link","上层连接新捷径")
	ctx.expect_true(scene.get_node("DoorWestShortcut").unlock_shortcut_on_exit,"03侧首次通过才解锁")
	ctx.expect_true(scene.get_node("ExitEast").get_meta("reserved") and str(scene.get_node("ExitEast").get_meta("target_room")) == "","右上出口未连接其他地图")
	var surfaces := {}
	for p: Dictionary in config.platforms:
		surfaces[p.id] = p.rect
		ctx.expect_eq(str(p.type),"oneway","蓝线平台全部为空心 "+str(p.id))
	for p: Dictionary in config.floor_samples:
		surfaces[p.id] = p.rect
	var height := PlayerTuning.JUMP_VELOCITY*PlayerTuning.JUMP_VELOCITY/(2*PlayerTuning.GRAVITY_UP)
	for route: Array in config.routes:
		var rise := float(surfaces[route[0]][1])-float(surfaces[route[1]][1])
		ctx.expect_true(rise >= 0 and rise <= height*0.9,"路线不超过0.9跳高 %s→%s" % route)
	ctx.expect_true(art.new_decorations.size() >= 30,"已加入森林系列场景装饰")
	for id in ["glow_fungi","seedpod_vines","root_arch"]:
		ctx.expect_true(FileAccess.file_exists(str(art.decoration_assets[id].texture)),"新增装饰原画存在 "+id)
	for child in scene.get_node("NewForestDecorations").get_children():
		ctx.expect_true(child is Sprite2D and child.z_index <= 1,"装饰不覆盖角色层 "+str(child.name))
	scene.free()
	return true
