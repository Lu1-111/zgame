extends SceneTree
## ENV-B01 美术地图资源构建器。只写 PROCESSED，不覆盖 scenes/ 可玩关卡。
## 先运行 build_environment_maps.py 和 --import，再运行本脚本。

const BATCH := "res://assets/PROCESSED/environments/ENV-B01/v001/"
const DESIGN := "res://tools/environment_map_design.json"

var _tile_size: int
var _sets: Dictionary = {}
var _failed := false


func _initialize() -> void:
	call_deferred("_build")


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ENV-B01 无法读取：%s" % path)
		_failed = true
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	if not value is Dictionary:
		push_error("ENV-B01 JSON 不是对象：%s" % path)
		_failed = true
		return {}
	return value as Dictionary


func _build() -> void:
	var config := _read_json(DESIGN)
	_tile_size = int(config.get("tile_size", 16))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BATCH + "godot"))
	var manifest := _read_json(BATCH + "manifest.json")
	for kit: String in manifest.get("kits", []):
		_sets[kit] = _make_tileset(kit)
	for room: Dictionary in manifest.get("rooms", []):
		_build_room(room)
	if _failed:
		quit(1)
	else:
		print("ENV-B01: 4 TileSets / 15 layered art scenes / exact source rectangle colliders")
		quit(0)


func _save(resource: Resource, path: String) -> void:
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		push_error("ENV-B01 保存失败：%s (%s)" % [path, error])
		_failed = true


func _make_tileset(kit: String) -> TileSet:
	var definition := _read_json(BATCH + kit + "/kit.json")
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(BATCH + kit + "/" + String(definition["terrain"])) as Texture2D
	atlas.texture_region_size = Vector2i(_tile_size, _tile_size)
	var result := TileSet.new()
	result.tile_size = Vector2i(_tile_size, _tile_size)
	result.add_physics_layer()
	result.set_physics_layer_collision_layer(0, 1)
	result.set_physics_layer_collision_mask(0, 0)
	result.add_source(atlas, 0)
	var half: float = float(_tile_size) / 2.0
	for i in range(16):
		var cell := Vector2i(i % 4, i >> 2)
		atlas.create_tile(cell)
		var td := atlas.get_tile_data(cell, 0)
		td.set_collision_polygons_count(0, 1)
		td.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-half, -half), Vector2(half, -half),
			Vector2(half, half), Vector2(-half, half)
		]))
	_save(result, BATCH + "godot/" + kit + ".tres")
	return result


func _add_node(parent: Node, child: Node, scene_root: Node) -> void:
	parent.add_child(child)
	child.owner = scene_root


func _image(parent: Node, scene_root: Node, image_name: String, path: String, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = image_name
	sprite.centered = false
	sprite.texture = load(path) as Texture2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = z
	_add_node(parent, sprite, scene_root)
	return sprite


func _build_room(record: Dictionary) -> void:
	var id := String(record["id"])
	var folder := BATCH + "maps/" + id + "/"
	var layout := _read_json(folder + "layout.json")
	var scene_root := Node2D.new()
	scene_root.name = id
	scene_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scene_root.set_meta("room_id", id)
	scene_root.set_meta("art_preview_only", true)
	scene_root.set_meta("display_name", String(record["name"]))
	scene_root.set_meta("source_sha256", String(layout["source_sha256"]))
	scene_root.set_meta("size_px", Vector2(float(record["size_px"][0]), float(record["size_px"][1])))
	_image(scene_root, scene_root, "Background", folder + "background.png", -30)
	_image(scene_root, scene_root, "Midground", folder + "midground.png", -12)
	_image(scene_root, scene_root, "Props", folder + "props.png", 1)
	_image(scene_root, scene_root, "HazardDesign", folder + "hazards.png", 2)
	for platform: Dictionary in layout["platforms"]:
		_add_platform(scene_root, platform)
	var guides := _image(scene_root, scene_root, "DesignGuides", folder + "guides.png", 30)
	guides.visible = false
	var markers := Node2D.new()
	markers.name = "SemanticMarkers"
	_add_node(scene_root, markers, scene_root)
	var source_room: Dictionary = layout["source_room"]
	for door: Dictionary in source_room["doors"]:
		var mark := Marker2D.new()
		mark.name = "Door_" + String(door["id"])
		mark.position = Vector2(float(door["pos"][0]), float(door["pos"][1]))
		mark.set_meta("definition", door)
		_add_node(markers, mark, scene_root)
	var spawn := Marker2D.new()
	spawn.name = "Spawn"
	spawn.position = Vector2(float(source_room["spawn"][0]), float(source_room["spawn"][1]))
	_add_node(markers, spawn, scene_root)
	var packed := PackedScene.new()
	var error := packed.pack(scene_root)
	if error != OK:
		push_error("ENV-B01 场景打包失败：%s" % id)
		_failed = true
	else:
		_save(packed, folder + id + ".tscn")
	scene_root.free()


func _add_platform(scene_root: Node2D, platform: Dictionary) -> void:
	var rect: Array = platform["rect"]
	var origin := Node2D.new()
	origin.name = "Platform_%02d" % int(platform["index"])
	origin.position = Vector2(float(rect[0]), float(rect[1]))
	_add_node(scene_root, origin, scene_root)
	var layer := TileMapLayer.new()
	layer.name = "Terrain"
	layer.tile_set = _sets[String(platform["kit"])] as TileSet
	layer.collision_enabled = false
	_add_node(origin, layer, scene_root)
	var atlas := layer.tile_set.get_source(0) as TileSetAtlasSource
	for cell: Dictionary in platform["cells"]:
		var x := int(cell["position"][0])
		var y := int(cell["position"][1])
		var index := int(cell["atlas_index"])
		var w := int(cell["visible_size"][0])
		var h := int(cell["visible_size"][1])
		var coord := Vector2i(index % 4, index >> 2)
		if w == _tile_size and h == _tile_size and x % _tile_size == 0 and y % _tile_size == 0:
			layer.set_cell(Vector2i(floori(float(x) / _tile_size), floori(float(y) / _tile_size)), 0, coord)
		else:
			var sprite := Sprite2D.new()
			sprite.name = "Edge_%d_%d" % [x, y]
			sprite.centered = false
			sprite.position = Vector2(x, y)
			var texture := AtlasTexture.new()
			texture.atlas = atlas.texture
			texture.region = Rect2(coord * _tile_size, Vector2(w, h))
			sprite.texture = texture
			_add_node(origin, sprite, scene_root)
	var body := StaticBody2D.new()
	body.name = "ExactSourceCollider"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector2(float(rect[2]), float(rect[3])) / 2.0
	_add_node(origin, body, scene_root)
	var collision := CollisionShape2D.new()
	collision.name = "Shape"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(float(rect[2]), float(rect[3]))
	collision.shape = shape
	_add_node(body, collision, scene_root)
