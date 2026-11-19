extends "res://tools/maps/build_forest_02.gd"
## 将评审数据烘焙为真正的TileMap、轮廓碰撞与薄平台场景；正式地图不参与生成。
const CANDIDATES := "res://test/data/forest_candidates/manifest.json"

func _build() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATES))
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(manifest.rules)))
	var controller := load("res://test/scripts/forest_candidates/room.gd") as Script
	if controller == null:
		quit(1)
		return
	var only := ""
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		only = args[0]
	for row: Dictionary in manifest.candidates:
		if not only.is_empty() and str(row.id)!=only:
			continue
		config = JSON.parse_string(FileAccess.get_file_as_string(str(row.config)))
		presentation = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/forest_03_art.json"))
		tile = int(config.tile_size)
		tileset = load(TILESET_PATH)
		_open_polygons.clear()
		_holes.clear()
		_partial_cells.clear()
		for polygon: Array in config.outer_polygons:
			_open_polygons.append(_candidate_polygon(polygon))
		for polygon: Array in config.hole_polygons:
			_holes.append(_candidate_polygon(polygon))
		wall_material = ShaderMaterial.new()
		wall_material.shader = load("res://assets/environments/terrain/forest_01/wall_material.gdshader")
		wall_material.set_shader_parameter("albedo_texture",load(presentation.wall.texture))
		wall_material.set_shader_parameter("texture_world_size",_vec(presentation.wall.world_size))
		wall_material.set_shader_parameter("albedo_tint",Color(presentation.wall.tint))
		var room := Node2D.new()
		room.name = "ForestCandidate"+str(row.id)
		room.set_script(controller)
		room.set("candidate_id",str(row.id))
		room.set_meta("display_name",config.name)
		room.set_meta("layout_data",row.config)
		room.set_meta("disable_save",true)
		room.set_meta("forest_candidate",true)
		_add_backdrop(room)
		_add_carved_walls(room)
		for platform: Dictionary in config.platforms:
			_add_platform(room,platform)
		_add_wall_transition_mask(room)
		var coverage := (wall_material.get_shader_parameter("coverage_texture") as Texture2D).get_image()
		for cell in _partial_cells:
			coverage.set_pixelv(cell,Color.WHITE)
		wall_material.set_shader_parameter("coverage_texture",ImageTexture.create_from_image(coverage))
		_add_contour_distance()
		for gate: Dictionary in config.gates:
			var rect := _rect(gate.rect)
			var body := StaticBody2D.new()
			body.name = "Gate_"+str(gate.id)
			body.set_script(load("res://scripts/world/forest_mist_gate.gd"))
			body.set("visual_size",rect.size)
			body.position = rect.get_center()
			body.collision_layer = WORLD
			body.collision_mask = 0
			body.z_index = DECOR_Z
			_attach(room,body)
			var shape := CollisionShape2D.new()
			var box := RectangleShape2D.new()
			box.size = rect.size
			shape.shape = box
			_attach(body,shape,room)
		_add_player(room,_vec(config.spawn),_vec(config.bounds))
		for placement: Dictionary in config.enemies:
			var enemy := (load("res://scenes/enemies/combat_enemy.tscn") as PackedScene).instantiate()
			enemy.name = "Enemy_"+str(placement.spawn_id)
			enemy.enemy_id = StringName(str(placement.enemy_id))
			enemy.position = _vec(placement.pos)
			enemy.patrol_bounds = _vec(placement.patrol_bounds)
			enemy.z_index = ACTOR_Z
			enemy.set_meta("spawn_id",placement.spawn_id)
			_attach(room,enemy)
		_add_boundary(room)
		_add_candidate_grass(room)
		var ability := Node2D.new()
		ability.name = "DoubleJumpMarker"
		ability.set_script(load("res://test/scripts/forest_candidates/art.gd"))
		ability.set("kind","ability")
		ability.set("caption","二段跳")
		ability.set("caption_position",_vec(rules.drawing.ability_label_offset))
		ability.position = _vec(config.ability_test.takeoff)+Vector2(0,float(rules.body_half))+_vec(rules.drawing.ability_icon_offset)
		_attach(room,ability)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(str(row.scene).get_base_dir()))
		_pack(room,str(row.scene))
		print("BAKED %s: %d ledges / %d enemies / %d gates" % [row.id,config.platforms.size(),config.enemies.size(),config.gates.size()])
		room.free()
		await process_frame
	quit(1 if failed else 0)

func _candidate_polygon(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Array in points:
		result.append(_vec(point))
	return result

func _add_candidate_grass(room: Node2D) -> void:
	# 仅使用世界像素绘制小草并将原点贴在实地；薄台与角色层不被装饰覆盖。
	for index in range(0,config.platforms.size(),4):
		var rect := _rect(config.platforms[index].rect)
		var grass := Node2D.new()
		grass.set_script(load("res://test/scripts/forest_candidates/art.gd"))
		grass.name = "NativeGrass_%d" % index
		grass.set("kind","grass")
		grass.position = Vector2(rect.get_center().x,rect.position.y)
		grass.z_index = DECOR_Z
		_attach(room,grass)
