extends SceneTree
## 生成 forest_01（幽木）—— 暗色调森林，2×5 屏（1280×1760），箱庭式三层回环结构。
##
## 设计要点（参考樱桃组《空洞骑士》地图访谈 + 箱庭思路）：
##   1. 先立"世界"：一根巨木贯穿全屏，作为唯一地标，任何位置都能看到它。
##   2. 回环（B 区）：左右两条枝路绕树而上，中间汇合，形成一次"绕树一周"。
##   3. 竖井（C 区）：树心之字攀爬，光柱从冠层漏下，作为方向锚点。
##   4. 收束与释放（D 区）：窄跳之后给一块宽枝干做战斗场地。
##   5. 秘密：4 处（暗格 / 壁龛 / 上层藏宝 / 冠层），都要"看得见、绕一下才拿得到"。
##   6. 能力门：冠层比枝干高 8 格（128px），单跳 96px 上不去、二段跳 138px 才够。
##
## 用法：godot --headless --path . --script res://tools/build_forest_dark.gd

const TILE := 16
const COLS := 80
const ROWS := 110
const GROUND_ROW := 106
const GROUND_Y := GROUND_ROW * TILE

const TEX := "res://assets/third_party/metroidvania_forge/ch_02_world_building_foundations/forgotten_forest_example_tileset.png"
const TREES := "res://assets/third_party/anokolisa_high_forest/Assets/Tree-Assets.png"
const BUILD := "res://assets/third_party/anokolisa_high_forest/Assets/Buildings.png"
const PROPS := "res://assets/third_party/anokolisa_high_forest/Assets/Tiles.png"

## 平台：[行, 起始列, 结束列, 区域]
const PLATFORMS := [
	# A 根部凹地
	[102, 6, 20, "A"], [97, 18, 32, "A"], [92, 8, 22, "A"],
	[102, 54, 66, "A"],
	# B 环枝一圈（左右两条路 + 中间汇合）
	[87, 4, 24, "B"], [87, 54, 76, "B"],
	[82, 16, 34, "B"], [82, 44, 62, "B"],
	[78, 30, 50, "B"],
	# C 树心竖井
	[73, 32, 40, "C"], [68, 42, 50, "C"], [63, 32, 40, "C"],
	[58, 42, 50, "C"], [53, 32, 40, "C"], [48, 42, 52, "C"],
	[54, 54, 62, "C"],                       # 壁龛（秘密）
	# D 枝干层
	[43, 6, 44, "D"], [43, 48, 78, "D"],
	[39, 60, 68, "D"],                       # 上层藏宝
	# E 冠层
	[35, 30, 52, "E"], [30, 20, 36, "E"], [25, 40, 56, "E"],
]

## 篝火：[x 像素, 平台行]
const CAMPFIRES := [[14 * 16, 106], [16 * 16, 43]]

## 宝箱：[x 像素, 平台行, 是否秘密]
const CHESTS := [
	[60 * 16, 102, true],    # A 右侧暗格
	[72 * 16, 87, false],    # B 右侧枝路
	[58 * 16, 54, true],     # C 壁龛
	[64 * 16, 39, true],     # D 上层
	[46 * 16, 25, false],    # E 冠层
]

## 敌怪：[类型, x 像素, 平台行]
const ENEMIES := [
	["moss_beetle", 8 * 16, 87],
	["moss_beetle", 30 * 16, 82],
	["milk_slime", 70 * 16, 87],
	["moss_beetle", 36 * 16, 68],
	["moss_beetle", 46 * 16, 58],
	["moss_beetle", 14 * 16, 43],
	["milk_slime", 30 * 16, 43],
	["moss_beetle", 62 * 16, 43],
	["moss_beetle", 34 * 16, 30],
]


func _initialize() -> void:
	var ts := build_tileset()
	_save(ts, "res://assets/tilesets/forest_ground.tres")

	var root := Node2D.new()
	root.name = "Forest01"
	root.set_meta("world_origin", Vector2i(1168, -1408))
	root.set_meta("display_name", "幽木")
	root.set_meta("room_rect", Rect2i(0, 0, COLS, ROWS))

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = ts
	ground.modulate = Color(0.26, 0.38, 0.32)      # 暗青绿，压成夜色
	root.add_child(ground)
	ground.owner = root

	# 地面
	for x in COLS:
		ground.set_cell(Vector2i(x, GROUND_ROW), 0, Vector2i(1, 0), 0)
		for y in range(1, 4):
			ground.set_cell(Vector2i(x, GROUND_ROW + y), 0, Vector2i(1, mini(y, 2)), 0)

	# 平台
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
	_add_light_shafts(root)
	_add_zones(root)

	for c in CAMPFIRES:
		_add_campfire(root, Vector2(c[0], c[1] * TILE))
	for c in CHESTS:
		_add_chest(root, Vector2(c[0], c[1] * TILE), c[2])
	for e in ENEMIES:
		_add_enemy(root, e[0], Vector2(e[1], e[2] * TILE))
	_add_decor(root)

	_add_door(root, "DoorWest", Vector2(16, GROUND_Y - 8), "camp_01", "DoorEast", Vector2(44, -9))
	_add_door(root, "DoorEast", Vector2((COLS - 3) * TILE, 43 * TILE - 8), "cave_01", "DoorEast", Vector2(-44, -9))

	_add_player(root, Vector2(56, GROUND_Y))

	_save_scene(root, "res://scenes/rooms/forest_01.tscn")
	print("OK: 幽木 built — %dx%d, cells=%d" % [COLS, ROWS, ground.get_used_cells().size()])
	quit()


func _add_backdrop(root: Node2D) -> void:
	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.color = Color("#05090a")
	sky.size = Vector2(COLS * TILE, ROWS * TILE)
	sky.z_index = -40
	root.add_child(sky)
	sky.owner = root

	# 巨木主干：用树皮贴图竖着拼，比平涂色块有质感
	var trunk_rect := Rect2(0, 90, 80, 110)
	for row in 14:
		for col in 4:
			var x := COLS * TILE * 0.5 - 210 + col * 78
			var y := 180 + row * 108
			_add_sprite(root, "Bark_%d_%d" % [row, col], TREES, trunk_rect,
				Vector2(x, y), Color(0.21, 0.16, 0.12, 1.0), -29)

	# 冠层树冠 + 中景树冠
	var crowns := [
		Rect2(210, 5, 124, 100), Rect2(210, 105, 124, 100),
		Rect2(210, 205, 124, 100), Rect2(210, 305, 124, 74)
	]
	for i in 16:
		_add_sprite(root, "Canopy%d" % i, TREES, crowns[i % crowns.size()],
			Vector2(-40 + i * 92, -24 + (i % 3) * 22), Color(0.11, 0.17, 0.13, 1.0), -34)
	for i in 8:
		_add_sprite(root, "MidLeaf%d" % i, TREES, crowns[(i + 2) % crowns.size()],
			Vector2(-60 + i * 180, 1180 + (i % 3) * 150), Color(0.08, 0.12, 0.10, 1.0), -35)

	# 树根
	for i in 6:
		var side := -1.0 if i % 2 == 0 else 1.0
		var root_poly := Polygon2D.new()
		root_poly.name = "RootShade%d" % i
		var base_x := COLS * TILE * 0.5 + side * (200 + (i / 2) * 80)
		root_poly.polygon = PackedVector2Array([
			Vector2(base_x - 70, 1360 + i * 30), Vector2(base_x + 70, 1360 + i * 30),
			Vector2(base_x + 170 * side, 1696), Vector2(base_x + 70 * side, 1696)
		])
		root_poly.color = Color(0.06, 0.045, 0.032, 0.9)
		root_poly.z_index = -27
		root.add_child(root_poly)
		root_poly.owner = root

	var night := CanvasModulate.new()
	night.name = "NightTint"
	night.color = Color(0.80, 0.88, 0.90)
	root.add_child(night)
	night.owner = root

	# 底部雾：越靠下越暗，增加纵深
	var fog := Polygon2D.new()
	fog.name = "DepthFog"
	fog.polygon = PackedVector2Array([
		Vector2(0, ROWS * TILE - 520), Vector2(COLS * TILE, ROWS * TILE - 520),
		Vector2(COLS * TILE, ROWS * TILE), Vector2(0, ROWS * TILE)
	])
	fog.vertex_colors = PackedColorArray([
		Color(0.02, 0.03, 0.03, 0.0), Color(0.02, 0.03, 0.03, 0.0),
		Color(0.02, 0.03, 0.03, 0.5), Color(0.02, 0.03, 0.03, 0.5)
	])
	fog.z_index = 2
	root.add_child(fog)
	fog.owner = root


func _add_light_shafts(root: Node2D) -> void:
	## 从冠层漏下的光柱：上亮下淡（顶点色渐变），既是氛围也是"往上走"的指引。
	var shafts := [
		[300, 260, 120, 1200, 0.055],
		[560, 100, 140, 1380, 0.075],
		[900, 380, 110, 1080, 0.05],
	]
	for s in shafts:
		var beam := Polygon2D.new()
		beam.name = "LightShaft%d" % int(s[0])
		var x: float = s[0]
		var y: float = s[1]
		var w: float = s[2]
		var h: float = s[3]
		var a: float = s[4]
		beam.polygon = PackedVector2Array([
			Vector2(x, y), Vector2(x + w, y),
			Vector2(x + w + 46, y + h), Vector2(x - 46, y + h)
		])
		beam.vertex_colors = PackedColorArray([
			Color(0.62, 0.92, 0.80, a), Color(0.62, 0.92, 0.80, a),
			Color(0.45, 0.80, 0.70, 0.0), Color(0.45, 0.80, 0.70, 0.0)
		])
		beam.z_index = -18
		root.add_child(beam)
		beam.owner = root


func _add_zones(root: Node2D) -> void:
	var zones := [
		["Zone_Roots", "根部凹地", Rect2(0, 92 * TILE, COLS * TILE, 18 * TILE)],
		["Zone_Ring", "环枝一圈", Rect2(0, 76 * TILE, COLS * TILE, 16 * TILE)],
		["Zone_Heart", "树心竖井", Rect2(0, 43 * TILE, COLS * TILE, 33 * TILE)],
		["Zone_Branch", "枝干层", Rect2(0, 35 * TILE, COLS * TILE, 8 * TILE)],
		["Zone_Crown", "冠层", Rect2(0, 0, COLS * TILE, 35 * TILE)],
	]
	for z in zones:
		var n := Node2D.new()
		n.name = z[0]
		n.position = (z[2] as Rect2).position
		n.set_meta("zone_name", z[1])
		n.set_meta("zone_rect", z[2])
		root.add_child(n)
		n.owner = root


func _add_campfire(root: Node2D, pos: Vector2) -> void:
	var fire := AnimatedSprite2D.new()
	fire.name = "Campfire%d" % int(pos.x)
	fire.sprite_frames = _make_fire_frames()
	fire.centered = false
	fire.position = pos - Vector2(0, 54)
	fire.autoplay = "burn"
	fire.set_meta("interact", "campfire")
	fire.set_meta("save_point", true)
	fire.z_index = 1
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
	light.energy = 2.0
	light.texture_scale = 2.6
	light.position = Vector2(16, -26)
	fire.add_child(light)
	light.owner = root


func _add_chest(root: Node2D, pos: Vector2, secret: bool) -> void:
	var area := Area2D.new()
	area.name = "Chest%d" % int(pos.x)
	area.position = pos
	area.set_meta("interact", "chest")
	area.set_meta("loot", "hp_shard")
	area.set_meta("secret", secret)
	root.add_child(area)
	area.owner = root

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = load(PROPS)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(306, 310, 28, 30)
	sprite.centered = false
	sprite.position = Vector2(-14, -30)
	sprite.z_index = 1
	area.add_child(sprite)
	sprite.owner = root

	# 秘密宝箱加一点微光，暗示"这里有东西"
	if secret:
		var glow := PointLight2D.new()
		glow.name = "Glow"
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.85, 0.45, 0.5))
		g.set_color(1, Color(1.0, 0.7, 0.3, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 128
		gt.height = 128
		glow.texture = gt
		glow.energy = 0.9
		glow.texture_scale = 0.9
		glow.position = Vector2(0, -16)
		sprite.add_child(glow)
		glow.owner = root

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 30)
	shape.shape = rect
	shape.position = Vector2(0, -15)
	area.add_child(shape)
	shape.owner = root


func _add_decor(root: Node2D) -> void:
	## 装饰：发光蘑菇（带小光源）、倒木、碎石、陶罐。全部 z ≤ 1。
	var items := [
		["MushGlowA", PROPS, Rect2(274, 232, 94, 40), Vector2(10 * 16, 102 * 16), 1],
		["MushGlowB", PROPS, Rect2(274, 232, 94, 40), Vector2(58 * 16, 102 * 16), 1],
		["MushGlowC", PROPS, Rect2(274, 232, 94, 40), Vector2(34 * 16, 78 * 16), 1],
		["PlantsA", PROPS, Rect2(257, 326, 15, 26), Vector2(18 * 16, 97 * 16), 1],
		["PlantsB", PROPS, Rect2(274, 315, 22, 37), Vector2(50 * 16, 43 * 16), 1],
		["LogsA", BUILD, Rect2(16, 160, 46, 16), Vector2(26 * 16, 106 * 16), 1],
		["LogsB", BUILD, Rect2(16, 160, 46, 16), Vector2(40 * 16, 43 * 16), 1],
		["RubbleA", BUILD, Rect2(32, 202, 120, 38), Vector2(66 * 16, 87 * 16), 1],
		["RubbleB", BUILD, Rect2(32, 202, 120, 38), Vector2(22 * 16, 43 * 16), 1],
		["PotsA", PROPS, Rect2(336, 300, 64, 36), Vector2(64 * 16, 43 * 16), 1],
	]
	for d in items:
		var region: Rect2 = d[2]
		var pos: Vector2 = (d[3] as Vector2) - Vector2(0, region.size.y)
		_add_sprite(root, d[0], d[1], region, pos, Color(0.85, 0.95, 0.9, 1.0), int(d[4]))

	# 蘑菇的柔光
	for spot in [Vector2(12 * 16, 100 * 16), Vector2(60 * 16, 100 * 16), Vector2(36 * 16, 76 * 16)]:
		var l := PointLight2D.new()
		l.name = "Glow_%d_%d" % [int(spot.x), int(spot.y)]
		var g := Gradient.new()
		g.set_color(0, Color(0.5, 1.0, 0.85, 0.35))
		g.set_color(1, Color(0.2, 0.8, 0.7, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 192
		gt.height = 192
		l.texture = gt
		l.energy = 0.7
		l.texture_scale = 1.4
		l.position = spot
		l.z_index = -1
		root.add_child(l)
		l.owner = root


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
	marker.color = Color(0.42, 0.95, 0.85, 0.30)
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
	player.z_index = 20
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
