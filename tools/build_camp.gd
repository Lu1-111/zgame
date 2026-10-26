extends "res://tools/build_forest_sketch.gd"
## 重建两层安全营地；复用巨木森林的碰撞类型、苔岩平台和墙体过渡。

const CAMP_CONFIG := "res://data/maps/camp_01.json"


func _build() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(CAMP_CONFIG))
	presentation = JSON.parse_string(FileAccess.get_file_as_string(config.presentation))
	tile = int(config.tile_size)
	tileset = load(TILESET_PATH)
	wall_material = ShaderMaterial.new()
	wall_material.shader = load("res://assets/terrain/forest_01/wall_material.gdshader")
	wall_material.set_shader_parameter("albedo_texture", load(presentation.wall.texture))
	wall_material.set_shader_parameter("texture_world_size", _vec(presentation.wall.world_size))
	wall_material.set_shader_parameter("albedo_tint", Color(presentation.wall.tint))
	var room := Node2D.new()
	room.name = "Camp01"
	room.set_script(load("res://scripts/world/camp_room.gd"))
	room.set_meta("layout_data", CAMP_CONFIG)
	room.set_meta("display_name", config.name)
	room.set_meta("safe_zone", true)
	room.set_meta("world_origin", Vector2i(config.world_origin[0],config.world_origin[1]))
	room.set_meta("room_rect", Rect2i(0,0,int(config.bounds[0])/tile,int(config.bounds[1])/tile))
	var backdrop := Sprite2D.new()
	backdrop.name = "MoonlitForestBackground"
	backdrop.texture = load(config.background)
	backdrop.centered = false
	backdrop.scale = _vec(config.bounds) / backdrop.texture.get_size()
	backdrop.modulate = Color(config.background_tint)
	backdrop.z_index = -25
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_attach(room,backdrop)
	for definition: Dictionary in config.platforms:
		_add_platform(room,definition)
	for definition: Dictionary in config.walls:
		_add_wall(room,definition)
	_add_wall_transition_mask(room)
	_add_forest_decor(room)
	for definition: Dictionary in config.props:
		_add_camp_prop(room,definition)
	_add_fire(room)
	_add_chest(room)
	# 按可见实物底边而非透明画布底边落地。
	for prop: Dictionary in config.props:
		var sprite := room.get_node(str(prop.id)) as Sprite2D
		var source_rect := _rect(presentation.regions[prop.asset])
		sprite.offset.y = source_rect.size.y / 2.0 - float(presentation.ground_contacts[prop.asset])
	for decoration: Dictionary in presentation.decorations:
		var sprite := room.get_node("ForestDetailProps/" + str(decoration.id)) as Sprite2D
		sprite.offset.y = sprite.texture.get_height() / 2.0 - float(decoration.contact_y)
	var chest := room.get_node("ChestA") as Sprite2D
	chest.offset.y = chest.texture.get_height() / 2.0 - float(presentation.chest_contact_y)
	for definition: Dictionary in config.lights:
		_add_camp_light(room,definition)
	for definition: Dictionary in config.doors:
		_add_camp_exit(room,definition)
	_add_player(room,_vec(config.spawn),_vec(config.bounds))
	for definition: Dictionary in config.npcs:
		_add_npc(room,definition)
	var dialogue := (load("res://scenes/ui/npc_dialogue.tscn") as PackedScene).instantiate()
	dialogue.layer = int(config.interaction.dialogue_layer)
	_attach(room,dialogue)
	_pack(room,"res://scenes/rooms/camp_01.tscn")
	room.free()
	print("camp_01: 1280x640 / 2 floors / 2 oneway steps / 6 NPCs / safe spawn / east to forest_01")
	quit(1 if failed else 0)


func _add_camp_prop(room: Node2D, definition: Dictionary) -> void:
	var sprite := Sprite2D.new()
	sprite.name = definition.id
	var region := _rect(presentation.regions[definition.asset])
	var atlas := AtlasTexture.new()
	atlas.atlas = load(presentation.atlas)
	atlas.region = region
	atlas.filter_clip = true
	sprite.texture = atlas
	sprite.position = _vec(definition.pos)
	sprite.offset.y = -region.size.y / 2.0
	sprite.scale = Vector2.ONE * float(definition.width) / region.size.x
	sprite.z_index = DECOR_Z
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.set_meta("prop",true)
	sprite.set_meta("asset_id",definition.asset)
	_attach(room,sprite)


func _add_chest(room: Node2D) -> void:
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gameplay_ui.json"))
	var chest := Sprite2D.new()
	chest.name = config.chest.node
	chest.texture = load(settings.camp_supplies.texture)
	chest.position = _vec(config.chest.pos)
	chest.offset.y = -chest.texture.get_height() / 2.0
	chest.z_index = DECOR_Z
	chest.set_meta("interact","chest")
	chest.set_meta("chest_id",config.chest.id)
	_attach(room,chest)


func _add_npc(room: Node2D, definition: Dictionary) -> void:
	var npc := (load("res://scenes/npcs/npc.tscn") as PackedScene).instantiate()
	npc.name = definition.node
	npc.npc_id = StringName(definition.id)
	npc.display_name = definition.name
	npc.frames = load(definition.frames)
	npc.dialogue = PackedStringArray(definition.dialogue)
	npc.position = _vec(definition.pos)
	npc.patrol_radius = float(config.interaction.npc_patrol_radius)
	npc.walk_speed = float(config.interaction.npc_walk_speed)
	npc.interact_radius = float(config.interaction.npc_range)
	npc.z_index = ACTOR_Z
	npc.set_meta("role",definition.role)
	_attach(room,npc)


func _add_camp_exit(room: Node2D, definition: Dictionary) -> void:
	var door := Area2D.new()
	door.name = definition.id
	door.set_script(load("res://scripts/world/forest_passage.gd"))
	door.target_room = StringName(definition.target_room)
	door.target_door = StringName(definition.target_door)
	door.position = _vec(definition.pos)
	door.set_meta("target_room",definition.target_room)
	door.set_meta("target_door",definition.target_door)
	door.set_meta("arrive_offset",_vec(definition.arrive_offset))
	_attach(room,door)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = _vec(config.interaction.door_size)
	shape.shape = rectangle
	_attach(door,shape,room)


func _add_camp_light(room: Node2D, definition: Dictionary) -> void:
	var light := PointLight2D.new()
	light.name = definition.id
	light.position = _vec(definition.pos)
	light.color = Color(definition.color)
	light.energy = float(definition.energy)
	var gradient := Gradient.new()
	gradient.set_color(0,Color.WHITE)
	gradient.set_color(1,Color(1,1,1,0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1,0.5)
	texture.width = int(definition.radius) * 2
	texture.height = int(definition.radius) * 2
	light.texture = texture
	_attach(room,light)
