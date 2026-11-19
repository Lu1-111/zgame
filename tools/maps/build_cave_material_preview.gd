extends SceneTree
## 生成可复用洞穴TileSet与独立素材试放场景；不登记或替换任何正式房间。
var art: Dictionary
var cfg: Dictionary
var room: Node2D
var atlas: TileSetAtlasSource
var lookup: Dictionary = {}

func _initialize() -> void:
	call_deferred("_build")

func _build() -> void:
	art = JSON.parse_string(FileAccess.get_file_as_string("res://data/art/cave_v001.json"))
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://test/data/cave_material_preview.json"))
	var size := int(art.tile_size)
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i.ONE*size
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0,int(art.physics_layers.world))
	atlas = TileSetAtlasSource.new()
	atlas.texture = load(str(art.terrain.atlas))
	atlas.texture_region_size = tiles.tile_size
	tiles.add_source(atlas,0)
	for spec: Dictionary in art.terrain.variants:
		var cell := Vector2i(spec.atlas[0],spec.atlas[1])
		lookup[spec.id] = cell
		atlas.create_tile(cell)
		var image := (load(str(spec.path)) as Texture2D).get_image()
		var mask := BitMap.new()
		mask.create_from_image_alpha(image,float(cfg.collision_alpha_threshold))
		var data := atlas.get_tile_data(cell,0)
		for polygon: PackedVector2Array in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,image.get_size()),0.0):
			var points := PackedVector2Array()
			for point in polygon:
				points.append(point-Vector2.ONE*size/2.0)
			var index := data.get_collision_polygons_count(0)
			data.set_collision_polygons_count(0,index+1)
			data.set_collision_polygon_points(0,index,points)
	var error := ResourceSaver.save(tiles,str(art.terrain.tileset))
	if error!=OK:
		quit(error)
		return
	room = Node2D.new()
	room.name = "CaveMaterialPreview"
	room.set_script(load("res://test/scripts/cave_material_preview.gd"))
	room.set_meta("disable_save",true)
	room.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 背景在640×360逻辑屏幕层原生显示，不再放大两倍去填整张地图。
	var background_layer := CanvasLayer.new()
	background_layer.name = "CaveBackground"
	background_layer.layer = -30
	_attach(room,background_layer)
	var backdrop := Sprite2D.new()
	backdrop.name = "DeepCavern"
	backdrop.texture = load(str(art.assets.deep_cavern.path))
	backdrop.centered = false
	backdrop.modulate = Color(str(cfg.background_tint))
	backdrop.z_index = -30
	_attach(background_layer,backdrop)
	var ambient := CanvasModulate.new()
	ambient.color = Color(str(cfg.ambient))
	_attach(room,ambient)
	var ground := TileMapLayer.new()
	ground.name = "CaveTerrain"
	ground.tile_set = tiles
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/environments/terrain/cave/v001/continuous_rock.gdshader")
	material.set_shader_parameter("rock_field",load(str(art.terrain.continuous_field)))
	material.set_shader_parameter("field_size",(load(str(art.terrain.continuous_field)) as Texture2D).get_size())
	ground.material = material
	_attach(room,ground)
	var solid: Dictionary = {}
	for box: Array in cfg.solid_rects:
		for y in range(int(box[1])/size,int(box[1]+box[3])/size):
			for x in range(int(box[0])/size,int(box[0]+box[2])/size):
				solid[Vector2i(x,y)]=true
	for box: Array in cfg.cut_rects:
		for y in range(int(box[1])/size,int(box[1]+box[3])/size):
			for x in range(int(box[0])/size,int(box[0]+box[2])/size):
				solid.erase(Vector2i(x,y))
	for cell: Vector2i in solid:
		var id := _tile_id(cell,solid)
		ground.set_cell(cell,0,lookup[id])
	for spec: Dictionary in cfg.platforms:
		var platform := StaticBody2D.new()
		platform.set_script(load("res://scripts/world/cave_platform.gd"))
		platform.set("segment_count",int(spec.count))
		platform.position = Vector2(spec.pos[0],spec.pos[1])
		_attach(room,platform)
	for spec: Dictionary in cfg.props:
		var prop := Node2D.new()
		prop.name = str(spec.id)
		prop.set_script(load("res://scripts/world/cave_prop.gd"))
		prop.set("asset_id",str(spec.id))
		prop.position = Vector2(spec.pos[0],spec.pos[1])
		# 硬地外缘的视觉/碰撞顶面凹凸来自同一alpha；装饰按实际顶面落脚。
		var cell := Vector2i(floori(prop.position.x/size),floori(prop.position.y/size))
		if solid.has(cell):
			prop.position.y = _surface_y(ground,cell,roundi(prop.position.x)%size)
		_attach(room,prop)
	for spec: Dictionary in cfg.chests:
		var chest := Node2D.new()
		chest.name = str(spec.name)
		chest.set_script(load("res://scripts/world/cave_chest.gd"))
		chest.set("unlock_condition",str(spec.condition))
		chest.position = Vector2(spec.pos[0],spec.pos[1])
		var cell := Vector2i(floori(chest.position.x/size),floori(chest.position.y/size))
		chest.position.y = _surface_y(ground,cell,roundi(chest.position.x)%size)
		_attach(room,chest)
	for spec: Dictionary in cfg.hazards:
		var strip := Area2D.new()
		strip.name = "StalagmiteStrip"
		strip.set_script(load("res://scripts/world/cave_spike_strip.gd"))
		strip.set("segment_count",int(spec.count))
		strip.position = Vector2(spec.pos[0],spec.pos[1])+Vector2(0,size/8.0)
		_attach(room,strip)
	var hero := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	hero.name = "Player"
	hero.position = Vector2(cfg.spawn[0],cfg.spawn[1])
	hero.z_index = 20
	_attach(room,hero)
	var packed := PackedScene.new()
	packed.pack(room)
	error = ResourceSaver.save(packed,"res://test/scenes/cave_material_preview.tscn")
	room.free()
	print("CAVE PREVIEW: 80 TileSet variants, native props, light, chests, spikes, one-way platforms")
	quit(error)

func _tile_id(cell: Vector2i,solid: Dictionary) -> String:
	var top := not solid.has(cell+Vector2i.UP)
	var bottom := not solid.has(cell+Vector2i.DOWN)
	var left := not solid.has(cell+Vector2i.LEFT)
	var right := not solid.has(cell+Vector2i.RIGHT)
	var variant := absi(cell.x*13+cell.y*7+int(cfg.terrain_seed))
	for pair: Array in [[top and left,"tl"],[top and right,"tr"],[bottom and left,"bl"],[bottom and right,"br"]]:
		if pair[0]: return "outer_%s_%02d" % [pair[1],variant%4]
	for pair: Array in [[top,"top"],[bottom,"bottom"],[left,"left"],[right,"right"]]:
		if pair[0]: return "edge_%s_%02d" % [pair[1],variant%8]
	for pair: Array in [[Vector2i(-1,-1),"tl"],[Vector2i(1,-1),"tr"],[Vector2i(-1,1),"bl"],[Vector2i(1,1),"br"]]:
		if not solid.has(cell+pair[0]): return "inner_%s_%02d" % [pair[1],variant%4]
	return "fill_%02d" % (posmod(cell.x,4)+posmod(cell.y,4)*4)

func _surface_y(ground: TileMapLayer,cell: Vector2i,x: int) -> float:
	var coords := ground.get_cell_atlas_coords(cell)
	var rect := Rect2i(coords*int(art.tile_size),Vector2i.ONE*int(art.tile_size))
	var image := atlas.texture.get_image().get_region(rect)
	for y in image.get_height():
		if image.get_pixel(x,y).a>float(cfg.collision_alpha_threshold):
			return float(cell.y*int(art.tile_size)+y)
	return float(cell.y*int(art.tile_size))

func _attach(parent: Node,node: Node) -> void:
	parent.add_child(node)
	node.owner = room
