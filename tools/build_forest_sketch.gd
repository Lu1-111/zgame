extends SceneTree
## 按制作人草图烘焙 forest_01 TileMapLayer；数据唯一来源 data/maps/forest_01.json。
## 用法：Godot --headless --path . --script res://tools/build_forest_sketch.gd

const CONFIG := "res://data/maps/forest_01.json"
const TILESET_PATH := "res://assets/tilesets/forest_sketch.tres"
const ATLAS_PATH := "res://assets/tilesets/forest_sketch_atlas.png"
const WORLD := 1
const ONEWAY := 128
const ACTOR_Z := 20
const DECOR_Z := 1
var config: Dictionary
var presentation: Dictionary
var tile: int
var tileset: TileSet
var wall_material: ShaderMaterial
var failed := false


func _initialize() -> void:
	call_deferred("_build")


func _build() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	presentation = JSON.parse_string(FileAccess.get_file_as_string(config.presentation))
	tile = int(config.tile_size)
	tileset = _make_tileset()
	wall_material = ShaderMaterial.new()
	wall_material.shader = load("res://assets/terrain/forest_01/wall_material.gdshader")
	wall_material.set_shader_parameter("albedo_texture", load(presentation.wall.texture))
	wall_material.set_shader_parameter("texture_world_size", _vec(presentation.wall.world_size))
	wall_material.set_shader_parameter("albedo_tint", Color(presentation.wall.tint))
	_save(tileset, TILESET_PATH)
	var room := Node2D.new()
	room.name = "Forest01"
	room.set_script(load("res://scripts/world/forest_room.gd"))
	room.set_meta("display_name", config.name)
	room.set_meta("layout_data", CONFIG)
	room.set_meta("world_origin", Vector2i(config.world_origin[0], config.world_origin[1]))
	room.set_meta("room_rect", Rect2i(0, 0, int(config.bounds[0]) / tile, int(config.bounds[1]) / tile))
	var backdrop := Sprite2D.new()
	backdrop.name = "AncientTreeBackground"
	backdrop.texture = load(config.background)
	backdrop.centered = false
	backdrop.scale = _vec(config.bounds) / backdrop.texture.get_size()
	backdrop.modulate = Color(config.background_tint)
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	backdrop.z_index = -25
	_attach(room, backdrop)
	for platform: Dictionary in config.platforms:
		_add_platform(room, platform)
	for wall: Dictionary in config.walls:
		_add_wall(room, wall)
	_add_wall_transition_mask(room)
	_add_forest_decor(room)
	for passage: Dictionary in config.doors:
		_add_door(room, passage)
		if passage.has("gate_pos"):
			_add_gate(room, _vec(passage.gate_pos))
	_add_fire(room)
	_add_chest(room)
	_add_player(room, _vec(config.spawn), _vec(config.bounds))
	for placement: Dictionary in config.get("enemies", []):
		var enemy := (load("res://scenes/enemies/combat_enemy.tscn") as PackedScene).instantiate()
		enemy.name = "Enemy_" + str(placement.spawn_id)
		enemy.enemy_id = StringName(placement.enemy_id)
		enemy.position = _vec(placement.pos)
		enemy.patrol_bounds = _vec(placement.patrol_bounds)
		enemy.z_index = ACTOR_Z
		enemy.set_meta("spawn_id", placement.spawn_id)
		enemy.set_meta("platform_id", placement.platform_id)
		_attach(room, enemy)
	_add_prompt(room)
	_pack(room, "res://scenes/rooms/forest_01.tscn")
	room.free()
	_build_connection_preview()
	_write_minimap()
	print("forest_01: %d typed platforms / %d solid walls / 3 passages / 1280x1856" % [config.platforms.size(), config.walls.size()])
	quit(1 if failed else 0)


func _make_tileset() -> TileSet:
	var image := Image.create(tile * 4, tile, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var colors: Dictionary = config.palette
	for y in tile:
		for x in tile:
			var grain := (x + y * 3) % 11 == 0
			var top := Color(colors.solid_top) if y < 3 else Color(colors.solid_fill)
			if y == 3:
				top = Color(colors.solid_edge)
			elif grain and y > 3:
				top = Color(colors.solid_grain)
			image.set_pixel(x, y, top)
			image.set_pixel(tile + x, y, Color(colors.solid_grain if grain else colors.solid_dark))
			if y < int(config.oneway_thickness):
				image.set_pixel(tile * 2 + x, y, Color(colors.oneway_edge if y == 0 else colors.oneway_fill))
			image.set_pixel(tile * 3 + x, y, Color(colors.wall_grain if grain else colors.wall_fill))
	image.save_png(ProjectSettings.globalize_path(ATLAS_PATH))
	var source := TileSetAtlasSource.new()
	# ImageTexture 内嵌到 TileSet，可在首次生成时直接保存，不依赖尚未导入的 PNG。
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(tile, tile)
	var result := TileSet.new()
	result.tile_size = Vector2i(tile, tile)
	result.add_physics_layer()
	result.set_physics_layer_collision_layer(0, WORLD)
	result.add_physics_layer()
	result.set_physics_layer_collision_layer(1, ONEWAY)
	result.add_custom_data_layer()
	result.set_custom_data_layer_name(0, "platform_type")
	result.set_custom_data_layer_type(0, TYPE_STRING)
	result.add_custom_data_layer()
	result.set_custom_data_layer_name(1, "surface_role")
	result.set_custom_data_layer_type(1, TYPE_STRING)
	result.add_source(source, 0)
	for index in 4:
		source.create_tile(Vector2i(index, 0))
		var data := source.get_tile_data(Vector2i(index, 0), 0)
		data.set_custom_data("platform_type", "oneway" if index == 2 else "solid")
		data.set_custom_data("surface_role", "wall" if index == 3 else "platform")
		var physics := 1 if index == 2 else 0
		var half := float(tile) / 2.0
		var bottom := -half + float(config.oneway_thickness) if index == 2 else half
		data.set_collision_polygons_count(physics, 1)
		data.set_collision_polygon_points(physics, 0, PackedVector2Array([
			Vector2(-half, -half), Vector2(half, -half), Vector2(half, bottom), Vector2(-half, bottom)]))
		if index == 2:
			data.set_collision_polygon_one_way(physics, 0, true)
	return result


func _add_platform(room: Node2D, platform: Dictionary) -> void:
	var rect := _rect(platform.rect)
	var thin: bool = platform.type == "oneway"
	var layer := TileMapLayer.new()
	layer.name = "Platform_" + str(platform.id)
	layer.position = rect.position
	layer.tile_set = tileset
	layer.collision_enabled = not thin
	layer.self_modulate = Color(1, 1, 1, 0)
	layer.set_meta("platform_id", platform.id)
	layer.set_meta("platform_type", platform.type)
	layer.set_meta("world_rect", rect)
	layer.add_to_group("oneway_platforms" if thin else "solid_platforms", true)
	_attach(room, layer)
	for x in int(rect.size.x) / tile:
		for y in ceili(rect.size.y / tile):
			layer.set_cell(Vector2i(x, y), 0, Vector2i(2 if thin else (0 if y == 0 else 1), 0))
	_add_platform_art(room, layer, rect.size, thin)
	if thin:
		# 现有角色的 S 下穿与 mantle 查询 StaticBody2D；保留整段精确碰撞体。
		var body := StaticBody2D.new()
		body.name = "OneWayBody"
		body.collision_layer = ONEWAY
		body.collision_mask = 0
		body.set_meta("platform_id", platform.id)
		body.set_meta("platform_type", "oneway")
		_attach(layer, body, room)
		var shape := CollisionShape2D.new()
		shape.name = "Shape"
		var rectangle := RectangleShape2D.new()
		rectangle.size = rect.size
		shape.shape = rectangle
		shape.position = rect.size / 2.0
		shape.one_way_collision = true
		_attach(body, shape, room)


func _add_wall(room: Node2D, wall: Dictionary) -> void:
	var polygon := PackedVector2Array()
	for point: Array in wall.polygon:
		polygon.append(_vec(point))
	var layer := TileMapLayer.new()
	layer.name = "Wall_" + str(wall.id)
	layer.tile_set = tileset
	layer.material = wall_material
	layer.set_meta("platform_id", wall.id)
	layer.set_meta("platform_type", "solid")
	layer.set_meta("surface_role", "wall")
	layer.set_meta("source_polygon", polygon)
	layer.add_to_group("solid_walls", true)
	_attach(room, layer)
	for y in int(config.bounds[1]) / tile:
		for x in int(config.bounds[0]) / tile:
			if Geometry2D.is_point_in_polygon(Vector2(x, y) * tile + Vector2.ONE * tile / 2.0, polygon):
				layer.set_cell(Vector2i(x, y), 0, Vector2i(3, 0))


func _add_platform_art(room: Node2D, layer: TileMapLayer, size: Vector2, thin: bool) -> void:
	var style: Dictionary = presentation.oneway if thin else presentation.solid
	var region := _rect(style.region)
	var cap := float(style.cap_world_width)
	var source_cap := float(style.cap_source_width)
	var vertical_scale := size.y / float(style.body_source_depth)
	var top := -(float(style.surface_y) - region.position.y) * vertical_scale
	var texture := load(style.texture) as Texture2D
	var left := Rect2(region.position, Vector2(source_cap, region.size.y))
	var right := Rect2(Vector2(region.end.x - source_cap, region.position.y), Vector2(source_cap, region.size.y))
	var middle := Rect2(region.position + Vector2(source_cap, 0), region.size - Vector2(source_cap * 2, 0))
	_add_art_slice(room, layer, texture, left, Vector2(0, top), Vector2(cap / source_cap, vertical_scale), Color(style.tint), "ArtLeftCap")
	_add_art_slice(room, layer, texture, right, Vector2(size.x - cap, top), Vector2(cap / source_cap, vertical_scale), Color(style.tint), "ArtRightCap")
	var width := size.x - cap * 2
	var count := maxi(1, ceili(width / float(style.segment_world_width)))
	var segment_width := width / count
	for index in count:
		_add_art_slice(room, layer, texture, middle, Vector2(cap + index * segment_width, top), Vector2(segment_width / middle.size.x, vertical_scale), Color(style.tint), "ArtCenter_%02d" % index)


func _add_art_slice(room: Node2D, parent: Node2D, texture: Texture2D, region: Rect2, pos: Vector2, sprite_scale: Vector2, tint: Color, node_name: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	atlas.filter_clip = true
	sprite.texture = atlas
	sprite.centered = false
	sprite.position = pos
	sprite.scale = sprite_scale
	sprite.modulate = tint
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_attach(parent, sprite, room)


func _add_forest_decor(room: Node2D) -> void:
	var decor := Node2D.new()
	decor.name = "ForestDetailProps"
	decor.z_index = DECOR_Z
	_attach(room, decor)
	for definition: Dictionary in presentation.decorations:
		var sprite := Sprite2D.new()
		sprite.name = definition.id
		sprite.texture = load(definition.texture)
		sprite.position = _vec(definition.pos)
		sprite.offset.y = -sprite.texture.get_height() / 2.0
		sprite.scale = Vector2.ONE * float(definition.scale)
		sprite.flip_h = bool(definition.flip_h)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_attach(decor, sprite, room)
	for index in presentation.vines.size():
		var definition: Dictionary = presentation.vines[index]
		var vine := Sprite2D.new()
		vine.name = "HangingVine_%02d" % index
		vine.texture = load(presentation.vine_texture)
		vine.position = _vec(definition.pos)
		vine.offset.y = vine.texture.get_height() / 2.0
		vine.scale = Vector2.ONE * float(definition.scale)
		vine.flip_h = bool(definition.flip_h)
		vine.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_attach(decor, vine, room)


func _add_door(room: Node2D, definition: Dictionary) -> void:
	var door := Area2D.new()
	door.name = definition.id
	door.position = _vec(definition.pos)
	door.set_script(load("res://scripts/world/forest_passage.gd"))
	door.set("target_room", StringName(definition.target))
	door.set("target_door", StringName(definition.target_door))
	door.set("shortcut_id", StringName(definition.get("shortcut", "")))
	door.set_meta("target_room", definition.target)
	door.set_meta("target_door", definition.target_door)
	door.set_meta("arrive_offset", _vec(definition.arrive_offset))
	_attach(room, door)
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rectangle := RectangleShape2D.new()
	rectangle.size = _vec(config.interaction.door_size)
	shape.shape = rectangle
	_attach(door, shape, room)
	var arrow := Polygon2D.new()
	var direction := -1.0 if str(definition.id).begins_with("DoorWest") else 1.0
	arrow.polygon = PackedVector2Array([Vector2(-tile * direction, -tile / 4.0), Vector2(0, -tile / 4.0), Vector2(0, -tile / 2.0), Vector2(tile * direction, 0), Vector2(0, tile / 2.0), Vector2(0, tile / 4.0), Vector2(-tile * direction, tile / 4.0)])
	arrow.color = Color("#b9e5ca")
	arrow.z_index = DECOR_Z
	_attach(door, arrow, room)


func _add_wall_transition_mask(room: Node2D) -> void:
	var width := int(config.bounds[0]) / tile
	var height := int(config.bounds[1]) / tile
	var mask_image := Image.create(width,height,false,Image.FORMAT_RGBA8)
	mask_image.fill(Color.BLACK)
	for child in room.get_children():
		if child is TileMapLayer and str(child.get_meta("platform_type","")) == "solid":
			for cell in child.get_used_cells():
				var point: Vector2i = cell + Vector2i(child.position / tile)
				if point.x >= 0 and point.x < width and point.y >= 0 and point.y < height:
					mask_image.set_pixelv(point,Color.WHITE)
	wall_material.set_shader_parameter("coverage_texture",ImageTexture.create_from_image(mask_image))
	wall_material.set_shader_parameter("world_bounds",_vec(config.bounds))
	wall_material.set_shader_parameter("cell_size",float(tile))
	wall_material.set_shader_parameter("transition_width",float(presentation.wall.edge_width))
	wall_material.set_shader_parameter("edge_tint",Color(presentation.wall.edge_tint))


func _add_gate(room: Node2D, pos: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "ShortcutGate"
	body.position = pos
	body.collision_mask = 0
	body.set_meta("shortcut_id", config.connection_preview.shortcut)
	_attach(room, body)
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rectangle := RectangleShape2D.new()
	rectangle.size = _vec(config.interaction.gate_size)
	shape.shape = rectangle
	_attach(body, shape, room)
	var style: Dictionary = presentation.gate
	var region := _rect(style.region)
	var texture := load(style.texture) as Texture2D
	for side in [-1, 1]:
		var post := Node2D.new()
		post.name = "WoodPost_%d" % side
		post.position = Vector2(float(style.post_spacing) * side / 2.0, -rectangle.size.y / 2.0)
		post.rotation = PI / 2.0
		post.z_index = DECOR_Z
		_attach(body, post, room)
		_add_art_slice(room, post, texture, region, Vector2.ZERO, Vector2(rectangle.size.y / region.size.x, float(style.post_width) / region.size.y), Color.WHITE, "Bark")
	for direction in [-1, 1]:
		var brace := Line2D.new()
		brace.name = "RootBinding_%d" % direction
		brace.points = PackedVector2Array([Vector2(-rectangle.size.x, -rectangle.size.y * direction / 3.0), Vector2(rectangle.size.x, rectangle.size.y * direction / 3.0)])
		brace.width = float(style.brace_width)
		brace.default_color = Color(style.brace_tint)
		brace.z_index = DECOR_Z
		_attach(body, brace, room)


func _add_fire(room: Node2D) -> void:
	var fire := AnimatedSprite2D.new()
	fire.name = "Campfire"
	fire.position = _vec(config.campfire.pos)
	fire.offset = Vector2(0, -27)
	fire.z_index = DECOR_Z
	fire.set_meta("interact", "campfire")
	fire.set_meta("save_point", true)
	fire.set_meta("checkpoint_id", config.campfire.id)
	var frames := SpriteFrames.new()
	frames.add_animation("burn")
	frames.set_animation_speed("burn", 8)
	var texture := load("res://assets/third_party/metroidvania_forge/ch_02_world_building_foundations/forgotten_forest_example_tileset.png") as Texture2D
	for index in 5:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(512 + index * 32, 266, 32, 54)
		frames.add_frame("burn", atlas)
	fire.sprite_frames = frames
	fire.autoplay = "burn"
	_attach(room, fire)


func _add_chest(room: Node2D) -> void:
	var chest := Sprite2D.new()
	chest.name = "Chest"
	chest.position = _vec(config.chest.pos)
	chest.texture = load("res://assets/PROCESSED/environments/ENV-B01/v001/ENV-01/props/chest.png")
	chest.offset = Vector2(0, -chest.texture.get_height() / 2.0)
	chest.modulate = Color("#d7a6ef")
	chest.z_index = DECOR_Z
	chest.set_meta("interact", "chest")
	chest.set_meta("chest_id", config.chest.id)
	_attach(room, chest)


func _add_player(room: Node2D, spawn: Vector2, bounds: Vector2) -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.name = "Player"
	player.position = spawn
	player.z_index = ACTOR_Z
	_attach(room, player)
	player.get_node("Camera").set_bounds(Rect2(Vector2.ZERO, bounds))
	var marker := Marker2D.new()
	marker.name = "SpawnPoint"
	marker.position = spawn
	_attach(room, marker)


func _add_prompt(room: Node2D) -> void:
	var label := Label.new()
	label.name = "InteractionPrompt"
	label.z_index = DECOR_Z
	label.add_theme_font_size_override("font_size", int(config.interaction.font_size))
	_attach(room, label)


func _build_connection_preview() -> void:
	var definition: Dictionary = config.connection_preview
	var room := Node2D.new()
	room.name = "Forest02ConnectionPreview"
	room.set_script(load("res://scripts/world/forest_room.gd"))
	room.set("connection_preview", true)
	var art := (load(definition.scene) as PackedScene).instantiate()
	art.name = "Environment"
	_attach(room, art)
	for door: Dictionary in definition.doors:
		_add_door(room, door)
	_add_gate(room, _vec(definition.gate_pos))
	var lever := Polygon2D.new()
	lever.name = "ShortcutSwitch"
	lever.position = _vec(definition.switch_pos)
	lever.polygon = PackedVector2Array([Vector2(-8, 0), Vector2(-8, -32), Vector2(8, -32), Vector2(8, 0)])
	lever.color = Color("#e9be66")
	lever.z_index = DECOR_Z
	_attach(room, lever)
	_add_player(room, _vec(definition.spawn), _vec(definition.bounds))
	_add_prompt(room)
	_pack(room, "res://scenes/rooms/forest_02.tscn")
	room.free()


func _write_minimap() -> void:
	const SCALE := 2
	var image := Image.create(int(config.bounds[0]) / SCALE, int(config.bounds[1]) / SCALE, false, Image.FORMAT_RGBA8)
	image.fill(Color("#14292b"))
	for wall: Dictionary in config.walls:
		var polygon := PackedVector2Array()
		for point: Array in wall.polygon:
			polygon.append(_vec(point) / SCALE)
		for y in image.get_height():
			for x in image.get_width():
				if Geometry2D.is_point_in_polygon(Vector2(x, y), polygon):
					image.set_pixel(x, y, Color("#6b5a51"))
	for platform: Dictionary in config.platforms:
		var rect := _rect(platform.rect)
		image.fill_rect(Rect2i(rect.position / SCALE, rect.size / SCALE), Color("#83d3ec" if platform.type == "oneway" else "#d7796e"))
	for marker: Dictionary in [config.campfire, config.chest]:
		var pos := _vec(marker.pos) / SCALE
		image.fill_rect(Rect2i(pos - Vector2(8, 12), Vector2(16, 12)), Color("#ffce3a" if marker == config.campfire else "#c578df"))
	for door: Dictionary in config.doors:
		image.fill_rect(Rect2i(_vec(door.pos) / SCALE - Vector2(4, 12), Vector2(8, 24)), Color("#99edbf"))
	image.save_png(ProjectSettings.globalize_path("res://docs/previews/forest_01_layout.png"))


func _vec(array: Array) -> Vector2:
	return Vector2(array[0], array[1])


func _rect(array: Array) -> Rect2:
	return Rect2(array[0], array[1], array[2], array[3])


func _attach(parent: Node, child: Node, owner_root: Node = null) -> void:
	parent.add_child(child)
	child.owner = owner_root if owner_root != null else parent


func _pack(node: Node, path: String) -> void:
	var scene := PackedScene.new()
	if scene.pack(node) != OK:
		failed = true
	_save(scene, path)


func _save(resource: Resource, path: String) -> void:
	if ResourceSaver.save(resource, path) != OK:
		push_error("保存地图资源失败：" + path)
		failed = true
