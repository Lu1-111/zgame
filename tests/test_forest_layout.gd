extends RefCounted
## 草图地图契约：平台语义、真实碰撞层、路线尺度、通道配对与捷径序列化。

func run(ctx) -> bool:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/forest_01.json"))
	var scene := (load("res://scenes/rooms/forest_01.tscn") as PackedScene).instantiate()
	var preview := (load("res://scenes/rooms/forest_02.tscn") as PackedScene).instantiate()
	var platforms := {}
	var half_height := float(config.interaction.body_half_height)
	var jump_height := PlayerTuning.JUMP_VELOCITY * PlayerTuning.JUMP_VELOCITY / (2.0 * PlayerTuning.GRAVITY_UP)
	ctx.expect_eq(int(config.bounds[0]), int(ProjectSettings.get_setting("display/window/size/viewport_width")) * 2, "地图宽度等于两屏")
	for platform: Dictionary in config.platforms:
		platforms[platform.id] = platform.rect
		var layer := scene.get_node("Platform_" + str(platform.id)) as TileMapLayer
		ctx.expect_true(layer != null and layer.get_used_cells().size() > 0, "%s 已烘焙 TileMapLayer" % platform.id)
		ctx.expect_eq(str(layer.get_meta("platform_type")), str(platform.type), "%s 有独立类型标签" % platform.id)
		var cell := layer.get_cell_tile_data(Vector2i.ZERO)
		ctx.expect_eq(str(cell.get_custom_data("platform_type")), str(platform.type), "%s 图块自定义数据可识别" % platform.id)
		if platform.type == "oneway":
			var body := layer.get_node("OneWayBody") as StaticBody2D
			ctx.expect_eq(body.collision_layer, 128, "%s 只占 oneway 层" % platform.id)
			ctx.expect_true((body.get_node("Shape") as CollisionShape2D).one_way_collision, "%s 启用从下方穿过" % platform.id)
			ctx.expect_true(not layer.collision_enabled, "%s 没有重复 TileMap 碰撞" % platform.id)
		else:
			ctx.expect_eq(layer.tile_set.get_physics_layer_collision_layer(0), 1, "%s 实心碰撞在 world 层" % platform.id)
	for route: Array in config.routes:
		var start: Array = platforms[route[0]]
		var end: Array = platforms[route[1]]
		var rise := float(start[1] - end[1])
		var gap := maxf(0.0, maxf(float(end[0] - start[0] - start[2]), float(start[0] - end[0] - end[2])))
		ctx.expect_true(rise / jump_height >= float(config.jump_height_ratio[0]) and rise / jump_height <= float(config.jump_height_ratio[1]), "%s → %s 台阶为跳高的 0.8–0.9 倍" % route)
		ctx.expect_true(gap <= PlayerTuning.DODGE_SPEED * PlayerTuning.DODGE_TIME * float(config.max_gap_dodges), "%s → %s 缺口不超过两次闪避" % route)
	for wall: Dictionary in config.walls:
		var layer := scene.get_node("Wall_" + str(wall.id)) as TileMapLayer
		ctx.expect_true(layer.get_used_cells().size() > 0 and layer.collision_enabled, "%s 红框区域已填实" % wall.id)
	for definition: Dictionary in config.doors:
		if definition.target == "forest_02":
			var other := preview.get_node(str(definition.target_door))
			ctx.expect_eq(str(other.get("target_room")), "forest_01", "%s 目标门互指房间" % definition.id)
			ctx.expect_eq(str(other.get("target_door")), str(definition.id), "%s 目标门互指通道" % definition.id)
	ctx.expect_eq(float(config.spawn[1]) + half_height, float(platforms.root_floor[1]), "出生点脚底对齐地面")
	var gs: Node = ctx.fetch_singleton("GameState", "res://scripts/autoload/game_state.gd")
	gs.reset()
	gs.opened_shortcuts.append(&"forest_01_roots")
	var save: Dictionary = gs.to_save_dict()
	gs.reset()
	gs.load_from_dict(save)
	ctx.expect_true(gs.opened_shortcuts.has(&"forest_01_roots"), "捷径解锁状态可序列化往返")
	gs.load_from_dict({})
	ctx.expect_true(gs.opened_shortcuts.is_empty(), "旧存档缺失捷径字段时保持关闭")
	gs.reset()
	scene.free()
	preview.free()
	return true
