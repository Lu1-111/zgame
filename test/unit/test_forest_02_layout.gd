extends RefCounted
## 新草图的尺度、纯空心平台、连通洞室、独立道具及配对通道契约。


func run(ctx) -> bool:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/forest_02.json"))
	var scene := (load("res://scenes/maps/forest_02.tscn") as PackedScene).instantiate()
	var first := (load("res://scenes/maps/forest_01.tscn") as PackedScene).instantiate()
	var jump_height := PlayerTuning.JUMP_VELOCITY * PlayerTuning.JUMP_VELOCITY / (2.0 * PlayerTuning.GRAVITY_UP)
	ctx.expect_true(int(config.bounds[0]) >= 4 * int(ProjectSettings.get_setting("display/window/size/viewport_width")), "forest_02 长度至少四屏")
	ctx.expect_eq(config.enemies.size(),25,"草图25个红色三角放置普通小怪")
	var enemy_types := {}
	for placement: Dictionary in config.enemies:
		enemy_types[str(placement.enemy_id)] = true
		ctx.expect_true(scene.has_node("Enemy_"+str(placement.spawn_id)),"%s 已烘焙入场景" % placement.spawn_id)
	ctx.expect_eq(enemy_types.size(),3,"forest_02 仅采用三种普通小怪")
	ctx.expect_eq(config.encounters.size(),2,"两处封印宝箱关联守箱遭遇组")
	ctx.expect_true(config.npcs.is_empty(), "当前阶段未放入 NPC")
	ctx.expect_true(scene.get_node("Wall_CarvedMass").get_used_cells().size() > 0, "外围与灰色区使用实体墙填充")
	ctx.expect_true(scene.get_node("Wall_EdgeContours").get_child_count() > 0, "斜坡使用精确边缘多边形")
	var surfaces := {}
	for platform: Dictionary in config.platforms:
		surfaces[platform.id] = platform.rect
		ctx.expect_eq(platform.type, "oneway", "%s 只采用空心平台" % platform.id)
		var layer := scene.get_node("Platform_" + str(platform.id)) as TileMapLayer
		ctx.expect_true(not layer.collision_enabled and layer.is_in_group("oneway_platforms"), "%s 保留独立空心类型" % platform.id)
		var body := layer.get_node("OneWayBody") as StaticBody2D
		ctx.expect_eq(body.collision_layer, 128, "%s 只占空心碰撞层" % platform.id)
		ctx.expect_true((body.get_node("Shape") as CollisionShape2D).one_way_collision, "%s 可以从下方穿越" % platform.id)
	for surface: Dictionary in config.floor_samples:
		surfaces[surface.id] = surface.rect
	for route: Array in config.routes:
		var start: Array = surfaces[route[0]]
		var target: Array = surfaces[route[1]]
		var ratio := float(start[1] - target[1]) / jump_height
		ctx.expect_true(ratio >= float(config.jump_height_ratio[0]) and ratio <= float(config.jump_height_ratio[1]), "%s -> %s 高差处于 0.5–0.9 跳高" % route)
	for door: Dictionary in config.doors:
		if str(door.target) != "forest_01":
			continue
		var node := scene.get_node(str(door.id))
		var paired := first.get_node(str(door.target_door))
		ctx.expect_eq(String(node.target_room), "forest_01", "%s 指向 forest_01" % door.id)
		ctx.expect_eq(String(paired.target_door), str(door.id), "%s 与 forest_01 对应高度通道互指" % door.id)
	ctx.expect_true(scene.get_node("DoorWestShortcut").unlock_shortcut_on_exit, "下方首次穿越自动解锁根部捷径")
	ctx.expect_true(not first.get_node("DoorEastShortcut").unlock_shortcut_on_exit, "forest_01 端不能自行解锁")
	ctx.expect_eq(config.chests.size(), 5, "草图三只普通箱、两只战斗封印箱均已放置")
	var locked := 0
	for chest: Dictionary in config.chests:
		locked += 1 if chest.requires_clear else 0
		ctx.expect_eq(str(scene.get_node(str(chest.node)).get_meta("chest_id")), str(chest.id), "%s 有独立宝箱持久化标识" % chest.id)
	ctx.expect_eq(locked, 2, "两只战斗箱保留清怪条件")
	for gate: Dictionary in config.gates:
		ctx.expect_eq(str(scene.get_node(str(gate.id)).get_meta("switch_id")), str(config.switch.id), "%s 关联同色开关" % gate.id)
	var build_source := FileAccess.get_file_as_string("res://tools/maps/build_forest_sketch.gd")
	ctx.expect_true(not build_source.contains("_build_connection_preview"), "重建 forest_01 不会覆盖 forest_02")
	scene.free()
	first.free()
	return true
