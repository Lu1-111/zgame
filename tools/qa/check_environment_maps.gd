extends SceneTree
## 真实加载 ENV-B01 的图块与15个美术场景，核对引擎内碰撞和渲染约定。

const BATCH := "res://assets/PROCESSED/environments/ENV-B01/v001/"
var _failed := 0
var _checks := 0


func _initialize() -> void:
	call_deferred("_check_all")


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failed += 1
		push_error("ENV-B01 CHECK: " + description)


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


func _check_all() -> void:
	var manifest := _json(BATCH + "manifest.json")
	for kit: String in manifest["kits"]:
		var tileset := load(BATCH + "godot/" + kit + ".tres") as TileSet
		_expect(tileset != null, kit + " TileSet loads")
		_expect(tileset.tile_size == Vector2i(16, 16), kit + " native tile size")
		var source := tileset.get_source(0) as TileSetAtlasSource
		_expect(source.get_tiles_count() == 16, kit + " 16 atlas regions")
	for room: Dictionary in manifest["rooms"]:
		var folder := BATCH + "maps/" + String(room["id"]) + "/"
		var layout := _json(folder + "layout.json")
		var packed := load(folder + String(room["id"]) + ".tscn") as PackedScene
		_expect(packed != null, String(room["id"]) + " scene loads")
		var instance := packed.instantiate() as Node2D
		root.add_child(instance)
		_expect(instance.get_node("Background").z_index == -30, "background z_index")
		_expect(instance.get_node("Props").z_index <= 1, "decor cannot hide character")
		_expect(not instance.get_node("DesignGuides").visible, "guides hidden by default")
		var markers := instance.get_node("SemanticMarkers")
		_expect(markers.get_child_count() == layout["source_room"]["doors"].size() + 1, "door and spawn semantic markers")
		for platform: Dictionary in layout["platforms"]:
			var node := instance.get_node("Platform_%02d" % int(platform["index"])) as Node2D
			var rect: Array = platform["rect"]
			_expect(node.position == Vector2(float(rect[0]), float(rect[1])), "original platform position")
			var body := node.get_node("ExactSourceCollider") as StaticBody2D
			var shape := (body.get_node("Shape") as CollisionShape2D).shape as RectangleShape2D
			_expect(shape.size == Vector2(float(rect[2]), float(rect[3])), "original rectangle size")
			_expect(body.collision_layer == 1, "world collision layer")
			var layer := node.get_node("Terrain") as TileMapLayer
			_expect(layer.tile_set.tile_size == Vector2i(16, 16), "TileMapLayer uses native grid")
			_expect(not layer.collision_enabled, "exact collider avoids duplicate tile collisions")
		instance.queue_free()
		await process_frame
	print("ENV-B01 GODOT QA: %d/%d PASS (4 TileSets, 15 scenes)" % [_checks - _failed, _checks])
	quit(0 if _failed == 0 else 1)
