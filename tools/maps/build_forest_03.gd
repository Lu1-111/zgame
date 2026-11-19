extends "res://tools/maps/build_forest_02.gd"
## forest_03复用森林墙体、距离场与苔缘构建器，独立保存布局与运行层。
func _build() -> void:
	map_config_path = "res://data/maps/forest_03.json"
	room_script_path = "res://scripts/world/forest_03_room.gd"
	output_scene_path = "res://scenes/maps/forest_03.tscn"
	output_room_name = "Forest03"
	super._build()

func _add_mechanisms(room: Node2D) -> void:
	for gate: Dictionary in config.gates:
		_add_mist_gate(room,gate)

func _write_overview() -> void:
	var scale := 2
	var image := Image.create(int(config.bounds[0])/scale,int(config.bounds[1])/scale,false,Image.FORMAT_RGBA8)
	image.fill(Color("#14292b"))
	var coverage := (wall_material.get_shader_parameter("coverage_texture") as Texture2D).get_image()
	for y in coverage.get_height():
		for x in coverage.get_width():
			if coverage.get_pixel(x,y).r > 0.5:
				image.fill_rect(Rect2i(x*tile/scale,y*tile/scale,tile/scale,tile/scale),Color("#686b54"))
	for platform: Dictionary in config.platforms:
		var rect := _rect(platform.rect)
		image.fill_rect(Rect2i(rect.position/scale,rect.size/scale),Color("#83d3ec"))
	for chest: Dictionary in config.chests:
		image.fill_rect(Rect2i(_vec(chest.pos)/scale-Vector2(6,10),Vector2(12,10)),Color("#c578df" if chest.requires_clear else "#e9cf62"))
	for enemy: Dictionary in config.enemies:
		var elite := str(enemy.enemy_id) == "moss_guard"
		image.fill_rect(Rect2i(_vec(enemy.pos)/scale-Vector2(5,14),Vector2(10,14)),Color("#e68549" if elite else "#bb4554"))
	image.fill_rect(Rect2i(_vec(config.campfire.pos)/scale-Vector2(6,10),Vector2(12,10)),Color("#6cc27d"))
	for gate: Dictionary in config.gates:
		image.fill_rect(Rect2i((_vec(gate.pos)-_vec(gate.size)/2)/scale,_vec(gate.size)/scale),Color("#f4ffff"))
	image.save_png(ProjectSettings.globalize_path("res://docs/previews/forest_03_layout.png"))
