extends SceneTree
## 生成 forest_01（始点森林）：巨木四层结构，2×5 屏（1280×1760）。
## 灵木之根 → 灵木中段 → 灵木上段 → 灵木之顶（顶需二段跳）。
## 用法：godot --headless --path . --script res://tools/build_forest.gd

const TILE := 16
const COLS := 80
const ROWS := 110
const GROUND_ROW := 106
const GROUND_Y := GROUND_ROW * TILE

const TEX := "res://assets/third_party/metroidvania_forge/ch_02_world_building_foundations/forgotten_forest_example_tileset.png"
const TREES := "res://assets/third_party/anokolisa_high_forest/Assets/Tree-Assets.png"
const BUILD := "res://assets/third_party/anokolisa_high_forest/Assets/Buildings.png"
const PROPS := "res://assets/third_party/anokolisa_high_forest/Assets/Tiles.png"

## 平台：[行, 起始列, 结束列]
## 间距取 1.5 倍（原 3 格 → 平均 4.5 格：4 格与 5 格交替，即 64–80px）。
## 平台数 12 → 15；第 4、8 层为横穿左右的长平台（另有上段长平台一条）。
## 树顶比上段高 8 格（128px）：单跳 96px 够不到、二段跳 138px 才上得去。
const PLATFORMS := [
	[102, 8, 22],
	[97, 26, 40],
	[93, 12, 26],
	[88, 4, 75],    # 长平台 1
	[84, 30, 44],
	[79, 16, 30],
	[75, 46, 60],
	[70, 4, 75],    # 长平台 2
	[66, 20, 34],
	[61, 44, 58],
	[57, 10, 24],
	[52, 34, 48],
	[48, 50, 64],
	[43, 6, 79],    # 上段长平台（篝火 / 宝箱 / 出口）
	[35, 28, 52],   # 灵木之顶（比上段高 8 格 = 128px，必须二段跳）
]


func _initialize() -> void:
	var ts := build_tileset()
	_save(ts, "res://assets/tilesets/forest_ground.tres")

	var root := Node2D.new()
	root.name = "Forest01"
	root.set_meta("world_origin", Vector2i(1168, -1408))
	root.set_meta("display_name", "始点森林")
	root.set_meta("room_rect", Rect2i(0, 0, COLS, ROWS))

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = ts
	ground.modulate = Color(0.62, 0.70, 0.62)
	root.add_child(ground)
	ground.owner = root

	# 地面
	for x in COLS:
		ground.set_cell(Vector2i(x, GROUND_ROW), 0, Vector2i(1, 0), 0)
		for y in range(1, 4):
			ground.set_cell(Vector2i(x, GROUND_ROW + y), 0, Vector2i(1, y if y < 3 else 2), 0)
	# 平台：左端左上角、中间平、右端右上角
	for p in PLATFORMS:
		var row: int = p[0]
		var x0: int = p[1]
		var x1: int = p[2]
		for x in range(x0, x1 + 1):
			var col := 1
			if x == x0:
				col = 0
			elif x == x1:
				col = 2
			ground.set_cell(Vector2i(x, row), 0, Vector2i(col, 0), 0)
			ground.set_cell(Vector2i(x, row + 1), 0, Vector2i(col, 1), 0)

	_add_backdrop(root)
	_add_zones(root)

	_add_campfire(root, Vector2(18 * TILE, 43 * TILE))
	_add_chest(root, Vector2(30 * TILE, 43 * TILE))
	_add_platform_props(root)

	# 敌怪：中段三只苔甲虫 + 一只奶滴史莱姆
	# 敌怪：两条横穿长平台各 3 只，其余平台零星分布
	# 敌怪：两条横穿长平台各 3 只，其余平台零星分布（共 11 只）
	_add_enemy(root, "moss_beetle", Vector2(16 * TILE, 88 * TILE))
	_add_enemy(root, "moss_beetle", Vector2(40 * TILE, 88 * TILE))
	_add_enemy(root, "milk_slime", Vector2(62 * TILE, 88 * TILE))
	_add_enemy(root, "moss_beetle", Vector2(16 * TILE, 70 * TILE))
	_add_enemy(root, "moss_beetle", Vector2(44 * TILE, 70 * TILE))
	_add_enemy(root, "milk_slime", Vector2(68 * TILE, 70 * TILE))
	_add_enemy(root, "moss_beetle", Vector2(18 * TILE, 93 * TILE))
	_add_enemy(root, "moss_beetle", Vector2(24 * TILE, 79 * TILE))
	_add_enemy(root, "moss_beetle", Vector2(52 * TILE, 75 * TILE))
	_add_enemy(root, "moss_beetle", Vector2(26 * TILE, 66 * TILE))
	_add_enemy(root, "milk_slime", Vector2(50 * TILE, 61 * TILE))

	# 门：左侧回营地，右上出口去洞窟
	_add_door(root, "DoorWest", Vector2(16, GROUND_Y - 8), "camp_01", "DoorEast", Vector2(44, -9))
	_add_door(root, "DoorEast", Vector2((COLS - 2) * TILE, 43 * TILE - 8), "cave_01", "DoorEast", Vector2(-44, -9))

	_add_player(root, Vector2(64, GROUND_Y))

	_save_scene(root, "res://scenes/rooms/forest_01.tscn")
	print("OK: forest_01 built — %dx%d, cells=%d" % [COLS, ROWS, ground.get_used_cells().size()])
	quit()


func _add_zones(root: Node2D) -> void:
	var zones := [
		["Zone_Roots", "灵木之根", Vector2(0, 85 * TILE), Rect2(0, 85 * TILE, COLS * TILE, 21 * TILE)],
		["Zone_Trunk", "灵木中段", Vector2(0, 52 * TILE), Rect2(0, 52 * TILE, COLS * TILE, 33 * TILE)],
		["Zone_Upper", "灵木上段", Vector2(0, 43 * TILE), Rect2(0, 43 * TILE, COLS * TILE, 9 * TILE)],
		["Zone_Crown", "灵木之顶", Vector2(0, 0), Rect2(0, 0, COLS * TILE, 43 * TILE)],
	]
	for z in zones:
		var n := Node2D.new()
		n.name = z[0]
		n.position = z[2]
		n.set_meta("zone_name", z[1])
		n.set_meta("zone_rect", z[3])
		root.add_child(n)
		n.owner = root


func _add_backdrop(root: Node2D) -> void:
	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.color = Color("#0a120f")
	sky.size = Vector2(COLS * TILE, ROWS * TILE)
	sky.z_index = -30
	root.add_child(sky)
	sky.owner = root

	# 树冠剪影：顶部密集，中段稀疏
	var crowns := [
		Rect2(210, 5, 124, 100), Rect2(210, 105, 124, 100),
		Rect2(210, 205, 124, 100), Rect2(210, 305, 124, 74)
	]
	for i in 14:
		var rect: Rect2 = crowns[i % crowns.size()]
		_add_sprite(root, "CrownTop%d" % i, TREES, rect,
			Vector2(-30 + i * 96, -20 + (i % 3) * 26), Color(0.14, 0.20, 0.17, 1.0), -24)
	for i in 10:
		var rect2: Rect2 = crowns[(i + 2) % crowns.size()]
		_add_sprite(root, "CrownMid%d" % i, TREES, rect2,
			Vector2(-40 + i * 136, 520 + (i % 4) * 210), Color(0.10, 0.15, 0.13, 1.0), -26)
	for i in 6:
		var rect3: Rect2 = crowns[(i + 1) % crowns.size()]
		_add_sprite(root, "CrownLow%d" % i, TREES, rect3,
			Vector2(-20 + i * 220, 1180 + (i % 3) * 150), Color(0.09, 0.13, 0.11, 1.0), -26)

	# 树干：用建筑包的梁柱拼出主干（贴在中轴两侧）
	for i in 9:
		var seg := _add_sprite(root, "TrunkSeg%d" % i, BUILD, Rect2(0, 0, 80, 48),
			Vector2(COLS * TILE * 0.5 - 40 + (i % 2) * 8, 300 + i * 150),
			Color(0.30, 0.22, 0.15, 0.55), -22)
		seg.set_meta("decor", true)

	# 树干主体：中轴一根深色木柱 + 竖纹，让平台像是长在树上
	var trunk := ColorRect.new()
	trunk.name = "TrunkBody"
	trunk.color = Color(0.15, 0.10, 0.07, 1.0)
	trunk.position = Vector2(COLS * TILE * 0.5 - 190, 210)
	trunk.size = Vector2(380, 1480)
	trunk.z_index = -25
	root.add_child(trunk)
	trunk.owner = root
	for i in 7:
		var stripe := ColorRect.new()
		stripe.name = "TrunkStripe%d" % i
		stripe.color = Color(0.10, 0.07, 0.05, 1.0) if i % 2 == 0 else Color(0.20, 0.14, 0.09, 1.0)
		stripe.position = Vector2(COLS * TILE * 0.5 - 190 + 20 + i * 52, 210)
		stripe.size = Vector2(10 + (i % 3) * 6, 1480)
		stripe.z_index = -24
		root.add_child(stripe)
		stripe.owner = root

	# 树根：底部两侧斜向的暗色三角
	for i in 4:
		var side := -1.0 if i % 2 == 0 else 1.0
		var root_poly := Polygon2D.new()
		root_poly.name = "RootShade%d" % i
		var base_x := COLS * TILE * 0.5 + side * (190 + (i / 2) * 70)
		root_poly.polygon = PackedVector2Array([
			Vector2(base_x - 60, 1180 + i * 40), Vector2(base_x + 60, 1180 + i * 40),
			Vector2(base_x + 140 * side, 1696), Vector2(base_x + 60 * side, 1696)
		])
		root_poly.color = Color(0.12, 0.08, 0.05, 0.85)
		root_poly.z_index = -25
		root.add_child(root_poly)
		root_poly.owner = root

	var night := CanvasModulate.new()
	night.name = "NightTint"
	night.color = Color(0.82, 0.90, 0.86)
	root.add_child(night)
	night.owner = root


func _add_campfire(root: Node2D, pos: Vector2) -> void:
	var fire := AnimatedSprite2D.new()
	fire.name = "Campfire"
	fire.sprite_frames = _make_fire_frames()
	fire.centered = false
	fire.position = pos - Vector2(0, 54)
	fire.autoplay = "burn"
	fire.set_meta("interact", "campfire")
	fire.set_meta("save_point", true)
	root.add_child(fire)
	fire.owner = root

	var light := PointLight2D.new()
	light.name = "FireLight"
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.74, 0.38, 0.9))
	grad.set_color(1, Color(1.0, 0.45, 0.15, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 256
	gtex.height = 256
	light.texture = gtex
	light.energy = 1.7
	light.texture_scale = 2.2
	light.position = Vector2(16, -26)
	fire.add_child(light)
	light.owner = root


func _add_chest(root: Node2D, pos: Vector2) -> void:
	var area := Area2D.new()
	area.name = "Chest"
	area.position = pos
	area.set_meta("interact", "chest")
	area.set_meta("loot", "hp_shard")
	root.add_child(area)
	area.owner = root

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = load(PROPS)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(306, 310, 28, 30)
	sprite.centered = false
	sprite.position = Vector2(-14, -30)
	sprite.z_index = 2
	area.add_child(sprite)
	sprite.owner = root

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 30)
	shape.shape = rect
	shape.position = Vector2(0, -15)
	area.add_child(shape)
	shape.owner = root


func _add_platform_props(root: Node2D) -> void:
	var deco := [
		["MushA", PROPS, Rect2(274, 232, 94, 40), Vector2(12 * TILE, 102 * TILE)],
		["MushB", PROPS, Rect2(274, 232, 94, 40), Vector2(22 * TILE, 79 * TILE)],
		["PlantsA", PROPS, Rect2(257, 326, 15, 26), Vector2(16 * TILE, 93 * TILE)],
		["PlantsB", PROPS, Rect2(274, 315, 22, 37), Vector2(48 * TILE, 61 * TILE)],
		["RubbleA", BUILD, Rect2(32, 202, 120, 38), Vector2(30 * TILE, 97 * TILE)],
		["RubbleB", BUILD, Rect2(32, 202, 120, 38), Vector2(36 * TILE, 43 * TILE)],
		["Logs", BUILD, Rect2(16, 160, 46, 16), Vector2(14 * TILE, 57 * TILE)],
		["Pots", PROPS, Rect2(336, 300, 64, 36), Vector2(24 * TILE, 43 * TILE)],
	]
	for d in deco:
		var region: Rect2 = d[2]
		var pos: Vector2 = d[3] - Vector2(0, region.size.y)
		_add_sprite(root, d[0], d[1], region, pos, Color.WHITE, 1)


func _add_enemy(root: Node2D, enemy_id: String, pos: Vector2) -> void:
	var packed: PackedScene = load("res://scenes/enemies/enemy.tscn")
	if packed == null:
		push_error("enemy.tscn 缺失")
		return
	var e := packed.instantiate()
	e.name = "Enemy_%s_%d_%d" % [enemy_id, int(pos.x), int(pos.y)]
	e.set("enemy_id", StringName(enemy_id))
	e.position = pos
	e.z_index = 20
	root.add_child(e)
	e.owner = root


func _add_door(root: Node2D, door_name: String, pos: Vector2, target: String,
		target_door: String, arrive: Vector2) -> void:
	var area := Area2D.new()
	area.name = door_name
	area.position = pos
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
	shape.position = Vector2(TILE * 0.5, 0)
	area.add_child(shape)
	shape.owner = root

	var marker := Polygon2D.new()
	marker.name = "Marker"
	marker.polygon = PackedVector2Array([
		Vector2(0, -TILE), Vector2(TILE, -TILE), Vector2(TILE, TILE), Vector2(0, TILE)
	])
	marker.color = Color(0.42, 0.95, 0.85, 0.32)
	area.add_child(marker)
	marker.owner = root


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
	player.z_index = 20                     # 角色永远在最上层
	root.add_child(player)
	player.owner = root

	var cam := player.get_node_or_null("Camera")
	if cam != null and cam.has_method("set_bounds"):
		cam.set_bounds(Rect2(Vector2.ZERO, Vector2(COLS * TILE, ROWS * TILE)))


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
	ts.add_source(src, 0)
	for y in 3:
		for x in 3:
			var td := src.get_tile_data(Vector2i(x, y), 0)
			td.set_collision_polygons_count(0, 1)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
			]))
	return ts


func _save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if ResourceSaver.save(res, path) != OK:
		push_error("save failed " + path)


func _save_scene(node: Node, path: String) -> void:
	var packed := PackedScene.new()
	if packed.pack(node) != OK:
		push_error("pack failed")
		return
	_save(packed, path)
