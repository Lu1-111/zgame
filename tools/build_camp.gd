extends SceneTree
## 生成 camp_01（奶族营地）：单层森林空地，1 个篝火，无敌人。
## 左侧通往森林（forest_01），右侧通往商人之家（camp_02）。
## 用法：godot --headless --path . --script res://tools/build_camp.gd

const TILE := 16
const COLS := 72                                          # 1152px，横向 1.8 屏
const ROWS := 22
const GROUND_TOP := 19                                    # 站立面 y = 304
const GROUND_Y := GROUND_TOP * TILE

const TEX := "res://assets/third_party/metroidvania_forge/ch_02_world_building_foundations/forgotten_forest_example_tileset.png"
const TREES := "res://assets/third_party/anokolisa_high_forest/Assets/Tree-Assets.png"
const BUILD := "res://assets/third_party/anokolisa_high_forest/Assets/Buildings.png"
const PROPS := "res://assets/third_party/anokolisa_high_forest/Assets/Tiles.png"
const TENT := "res://assets/sprites/props/tent.png"


func _initialize() -> void:
	var ts := build_tileset()
	_save(ts, "res://assets/tilesets/forest_ground.tres")

	var root := Node2D.new()
	root.name = "Camp01"
	root.set_meta("room_rect", Rect2i(0, 0, COLS, ROWS))

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = ts
	ground.modulate = Color(0.62, 0.70, 0.62)      # 压暗，贴合夜色
	root.add_child(ground)
	ground.owner = root

	for x in COLS:
		var col_top := 1
		var col_mid := 1
		if x == 0:
			col_top = 0
			col_mid = 0
		elif x == COLS - 1:
			col_top = 2
			col_mid = 2
		ground.set_cell(Vector2i(x, GROUND_TOP), 0, Vector2i(col_top, 0), 0)
		for y in range(1, 3):
			ground.set_cell(Vector2i(x, GROUND_TOP + y), 0, Vector2i(col_mid, y), 0)

	_add_backdrop(root)
	_add_campfire(root, 336)
	_add_props(root)

	# 左侧是边界（不可通行），唯一的出口是东门 → 始点森林
	_add_boundary(root, 0, "WestBoundary")
	_add_boundary(root, COLS * TILE - 8, "EastBoundary")
	_add_door(root, "DoorEast", Vector2i(COLS - 3, GROUND_TOP - 1), "forest_01", "DoorWest", Vector2(-44, -9))

	_add_player(root, Vector2(64, GROUND_Y))

	_save_scene(root, "res://scenes/rooms/camp_01.tscn")
	print("OK: camp_01 built — %d cols, cells=%d" % [COLS, ground.get_used_cells().size()])
	quit()


func _add_player(root: Node2D, spawn: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = "SpawnPoint"
	marker.position = spawn
	root.add_child(marker)
	marker.owner = root

	var packed: PackedScene = load("res://scenes/player/player.tscn")
	if packed == null:
		push_error("player.tscn 加载失败")
		return
	var player := packed.instantiate()
	player.name = "Player"
	player.position = spawn
	player.z_index = 20                     # 角色永远在最上层，不被任何装饰遮挡
	root.add_child(player)
	player.owner = root

	var cam := player.get_node_or_null("Camera")
	if cam != null and cam.has_method("set_bounds"):
		cam.set_bounds(Rect2(Vector2.ZERO, Vector2(COLS * TILE, ROWS * TILE)))


func _add_backdrop(root: Node2D) -> void:
	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.color = Color("#0b1310")
	sky.size = Vector2(COLS * TILE, GROUND_Y)
	sky.z_index = -30
	root.add_child(sky)
	sky.owner = root

	var crowns := [
		Rect2(210, 5, 124, 100), Rect2(210, 105, 124, 100),
		Rect2(210, 205, 124, 100), Rect2(210, 305, 124, 74)
	]

	# 远景密林：两排重叠树冠，压暗
	var rows := [[-36, 0.16, 0.23, 0.19, -26], [20, 0.20, 0.28, 0.23, -24]]
	for r in rows.size():
		var row: Array = rows[r]
		for i in 12:
			var rect: Rect2 = crowns[(i + r) % crowns.size()]
			var pos := Vector2(-50 + i * 112 + r * 46, float(row[0]))
			_add_sprite(root, "FarCrown_%d_%d" % [r, i], TREES, rect, pos,
				Color(row[1], row[2], row[3], 1.0), int(row[4]))

	# 中景树冠，补层次
	var mid := [[188, 128, 1], [420, 148, 3], [660, 120, 2], [880, 140, 1], [1030, 126, 3]]
	for i in mid.size():
		var m: Array = mid[i]
		_add_sprite(root, "MidCrown%d" % i, TREES, crowns[int(m[2])],
			Vector2(float(m[0]), float(m[1])), Color(0.24, 0.34, 0.28, 1.0), -14)

	var night := CanvasModulate.new()
	night.name = "NightTint"
	night.color = Color(0.80, 0.88, 0.84)
	root.add_child(night)
	night.owner = root


func _add_campfire(root: Node2D, x_px: int) -> void:
	var fire := AnimatedSprite2D.new()
	fire.name = "Campfire"
	fire.sprite_frames = _make_fire_frames()
	fire.centered = false
	fire.position = Vector2(x_px, GROUND_Y - 54)       # 帧高 70，底边贴地
	fire.autoplay = "burn"
	fire.set_meta("interact", "campfire")
	fire.set_meta("save_point", true)
	root.add_child(fire)
	fire.owner = root

	var light := PointLight2D.new()
	light.name = "FireLight"
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.74, 0.38, 0.95))
	grad.set_color(1, Color(1.0, 0.45, 0.15, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 256
	gtex.height = 256
	light.texture = gtex
	light.energy = 1.9
	light.texture_scale = 2.4
	light.position = Vector2(16, -26)
	fire.add_child(light)
	light.owner = root


func _add_props(root: Node2D) -> void:
	# [名称, 贴图, 区域, 左上角 x, z]
	var items := [
		["TentA", TENT, Rect2(0, 0, 48, 42), 112, 1],
		["TentB", TENT, Rect2(0, 0, 48, 42), 496, 1],
		["Fence", BUILD, Rect2(128, 138, 80, 44), 186, 1],
		["Logs", BUILD, Rect2(16, 160, 46, 16), 286, 1],
		["Plants", PROPS, Rect2(257, 326, 15, 26), 404, 1],
		["Pots", PROPS, Rect2(336, 300, 64, 36), 566, 1],
		["ChestA", PROPS, Rect2(306, 310, 28, 30), 656, 1],
		["Mushrooms", PROPS, Rect2(274, 232, 94, 40), 712, 1],
		["Rubble", BUILD, Rect2(32, 202, 120, 38), 846, 1],
	]
	for item in items:
		var region: Rect2 = item[2]
		var pos := Vector2(float(item[3]), GROUND_Y - region.size.y)
		var s := _add_sprite(root, item[0], item[1], region, pos, Color.WHITE, int(item[4]))
		s.set_meta("prop", true)


func _add_sprite(root: Node2D, sprite_name: String, path: String, region: Rect2,
		pos: Vector2, tint: Color, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = sprite_name
	s.texture = load(path)
	s.region_enabled = region.size != Vector2.ZERO
	if s.region_enabled:
		s.region_rect = region
	s.centered = false
	s.position = pos
	s.modulate = tint
	s.z_index = z
	root.add_child(s)
	s.owner = root
	return s


func _add_boundary(root: Node2D, x_px: int, body_name: String) -> void:
	## 房间左右边界：不可通行的薄墙 + 暗色立面（视觉上像崖壁/树壁）。
	var body := StaticBody2D.new()
	body.name = body_name
	body.position = Vector2(x_px + 4, ROWS * TILE * 0.5)
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	body.owner = root

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, ROWS * TILE)
	shape.shape = rect
	body.add_child(shape)
	shape.owner = root

	var face := ColorRect.new()
	face.name = "Face"
	face.color = Color(0.09, 0.14, 0.11)
	face.position = Vector2(-4, -ROWS * TILE * 0.5)
	face.size = Vector2(8, ROWS * TILE)
	face.z_index = -5
	body.add_child(face)
	face.owner = root


func _add_door(root: Node2D, door_name: String, cell: Vector2i, target: String,
		target_door: String, arrive: Vector2) -> void:
	var area := Area2D.new()
	area.name = door_name
	area.position = Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE * 0.5)
	area.set_meta("target_room", target)
	area.set_meta("target_door", target_door)
	area.set_meta("arrive_offset", arrive)
	area.set_script(load("res://scripts/world/room_door.gd"))
	root.add_child(area)
	area.owner = root

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE * 2)
	shape.shape = rect
	area.add_child(shape)
	shape.owner = root

	var marker := Polygon2D.new()
	marker.name = "Marker"
	marker.polygon = PackedVector2Array([
		Vector2(-TILE * 0.5, -TILE), Vector2(TILE * 0.5, -TILE),
		Vector2(TILE * 0.5, TILE), Vector2(-TILE * 0.5, TILE)
	])
	marker.color = Color(0.42, 0.95, 0.85, 0.34)
	area.add_child(marker)
	marker.owner = root


func _make_fire_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("burn")
	sf.set_animation_speed("burn", 8.0)
	sf.set_animation_loop("burn", true)
	var tex: Texture2D = load(TEX)
	for i in 5:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(512 + i * 32, 266, 32, 54)
		sf.add_frame("burn", at)
	return sf


func build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)

	var src := TileSetAtlasSource.new()
	src.texture = load(TEX)
	src.texture_region_size = Vector2i(TILE, TILE)
	for y in 3:
		for x in 3:
			src.create_tile(Vector2i(x, y))

	# 先挂进 TileSet，TileData 才会继承物理层
	ts.add_source(src, 0)

	for y in 3:
		for x in 3:
			var coords := Vector2i(x, y)
			var td := src.get_tile_data(coords, 0)
			td.set_collision_polygons_count(0, 1)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
			]))
	return ts


func _save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("save failed %s: %d" % [path, err])
	else:
		print("saved ", path)


func _save_scene(node: Node, path: String) -> void:
	var packed := PackedScene.new()
	var perr := packed.pack(node)
	if perr != OK:
		push_error("pack failed: %d" % perr)
		return
	_save(packed, path)
