extends "res://tools/maps/build_forest_sketch.gd"
## 按 forest_02 草图烘焙可玩房间；空白洞室之外一律填实，复用始点森林的材质。

const MAP_CONFIG := "res://data/maps/forest_02.json"
var map_config_path := MAP_CONFIG
var room_script_path := "res://scripts/world/forest_02_room.gd"
var output_scene_path := "res://scenes/maps/forest_02.tscn"
var output_room_name := "Forest02"
var _open_polygons: Array[PackedVector2Array] = []
var _partial_cells: Array[Vector2i] = []
var _holes: Array[PackedVector2Array] = []


func _build() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(map_config_path))
	presentation = JSON.parse_string(FileAccess.get_file_as_string(config.presentation))
	tile = int(config.tile_size)
	tileset = load(TILESET_PATH)
	wall_material = ShaderMaterial.new()
	wall_material.shader = load("res://assets/environments/terrain/forest_01/wall_material.gdshader")
	wall_material.set_shader_parameter("albedo_texture", load(presentation.wall.texture))
	wall_material.set_shader_parameter("texture_world_size", _vec(presentation.wall.world_size))
	wall_material.set_shader_parameter("albedo_tint", Color(presentation.wall.tint))
	for area: Dictionary in config.walkable_areas:
		var polygon := PackedVector2Array()
		for point: Array in area.polygon:
			polygon.append(_vec(point))
		_union_open_area(polygon)
	var radius := float(config.smoothing.radius)
	for index in _open_polygons.size():
		_open_polygons[index] = _round_contour(_open_polygons[index], radius)
	for index in _holes.size():
		_holes[index] = _round_contour(_holes[index], radius)
	var room := Node2D.new()
	room.name = output_room_name
	room.set_script(load(room_script_path))
	room.set_meta("display_name", config.name)
	room.set_meta("layout_data", map_config_path)
	room.set_meta("world_origin", Vector2i(config.world_origin[0], config.world_origin[1]))
	room.set_meta("room_rect", Rect2i(0, 0, int(config.bounds[0]) / tile, int(config.bounds[1]) / tile))
	_add_backdrop(room)
	_add_carved_walls(room)
	for platform: Dictionary in config.platforms:
		_add_platform(room, platform)
	_add_wall_transition_mask(room)
	var mask := (wall_material.get_shader_parameter("coverage_texture") as Texture2D).get_image()
	for cell in _partial_cells:
		mask.set_pixelv(cell, Color.WHITE)
	wall_material.set_shader_parameter("coverage_texture", ImageTexture.create_from_image(mask))
	_add_contour_distance()
	_add_forest_decor(room)
	for decoration: Sprite2D in room.get_node("ForestDetailProps").get_children():
		var used := decoration.texture.get_image().get_used_rect()
		decoration.offset.y = decoration.texture.get_height() / 2.0 - (used.position.y if str(decoration.name).begins_with("HangingVine") else used.end.y)
	_add_new_decorations(room)
	_add_mechanisms(room)
	_add_shortcut_barrier(room)
	_add_fire(room)
	_add_chests(room)
	for definition: Dictionary in config.doors:
		_add_door(room, definition)
		room.get_node(str(definition.id)).set("unlock_shortcut_on_exit", bool(definition.get("unlock_on_exit", false)))
	_add_reserved_exit(room)
	_add_player(room, _vec(config.spawn), _vec(config.bounds))
	_add_enemies(room)
	_add_boundary(room)
	_write_overview()
	_pack(room, output_scene_path)
	room.free()
	print("%s: %dx%d / %d platforms / %d chests / %d enemies" % [config.id,config.bounds[0],config.bounds[1],config.platforms.size(),config.chests.size(),config.enemies.size()])
	quit(1 if failed else 0)


func _add_enemies(room: Node2D) -> void:
	for placement: Dictionary in config.enemies:
		var enemy := (load("res://scenes/enemies/combat_enemy.tscn") as PackedScene).instantiate()
		enemy.name = "Enemy_" + str(placement.spawn_id)
		enemy.enemy_id = StringName(placement.enemy_id)
		enemy.position = _vec(placement.pos)
		enemy.patrol_bounds = _vec(placement.patrol_bounds)
		enemy.z_index = ACTOR_Z
		enemy.set_meta("spawn_id",placement.spawn_id)
		enemy.set_meta("platform_id",placement.platform_id)
		_attach(room,enemy)


func _add_shortcut_barrier(room: Node2D) -> void:
	if not config.has("shortcut_gate"):
		return
	var definition: Dictionary = config.shortcut_gate
	_add_mist_gate(room,definition)


func _add_mist_gate(room: Node2D, definition: Dictionary) -> void:
	var body := StaticBody2D.new()
	body.name = definition.id
	body.position = _vec(definition.pos)
	body.collision_layer = WORLD
	body.collision_mask = 0
	body.set_script(load("res://scripts/world/forest_mist_gate.gd"))
	body.set("visual_size",_vec(definition.visual_size))
	body.set_meta("surface_role","encounter_gate")
	body.set_meta("clear_flag",definition.clear_flag)
	_attach(room,body)
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rectangle := RectangleShape2D.new()
	rectangle.size = _vec(definition.size)
	shape.shape = rectangle
	_attach(body,shape,room)


func _add_backdrop(room: Node2D) -> void:
	var texture := load(config.background) as Texture2D
	var count := int(presentation.background_panels)
	var width := float(config.bounds[0]) / count
	for index in count:
		var sprite := Sprite2D.new()
		sprite.name = "AncientTreeBackground_%d" % index
		sprite.texture = texture
		sprite.centered = false
		sprite.flip_h = index % 2 == 1
		sprite.position.x = index * width
		sprite.scale = Vector2(width, float(config.bounds[1])) / texture.get_size()
		sprite.modulate = Color(config.background_tint)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.z_index = -25
		_attach(room, sprite)


func _add_carved_walls(room: Node2D) -> void:
	var layer := TileMapLayer.new()
	layer.name = "Wall_CarvedMass"
	layer.tile_set = tileset
	layer.material = wall_material
	layer.set_meta("platform_type", "solid")
	layer.set_meta("surface_role", "wall")
	layer.add_to_group("solid_walls", true)
	_attach(room, layer)
	var contours := StaticBody2D.new()
	contours.name = "Wall_EdgeContours"
	contours.collision_layer = WORLD
	contours.collision_mask = 0
	contours.set_meta("surface_role", "wall")
	contours.add_to_group("solid_walls", true)
	_attach(room, contours)
	var width := int(config.bounds[0]) / tile
	var height := int(config.bounds[1]) / tile
	for y in height:
		for x in width:
			var rect := Rect2(Vector2(x, y) * tile, Vector2.ONE * tile)
			var pieces: Array[PackedVector2Array] = [PackedVector2Array([rect.position, rect.position + Vector2(tile, 0), rect.end, rect.position + Vector2(0, tile)])]
			for polygon in _open_polygons:
				if not _polygon_bounds(polygon).intersects(rect):
					continue
				var remaining: Array[PackedVector2Array] = []
				for piece in pieces:
					remaining.append_array(Geometry2D.clip_polygons(piece, polygon))
				pieces = remaining
				if pieces.is_empty():
					break
			for hole in _holes:
				if _polygon_bounds(hole).intersects(rect):
					var quad := PackedVector2Array([rect.position, rect.position + Vector2(tile, 0), rect.end, rect.position + Vector2(0, tile)])
					pieces.append_array(Geometry2D.intersect_polygons(quad, hole))
			if pieces.size() == 1 and absf(_polygon_area(pieces[0]) - tile * tile) < 0.1:
				layer.set_cell(Vector2i(x, y), 0, Vector2i(3, 0))
			elif not pieces.is_empty():
				_partial_cells.append(Vector2i(x, y))
				for piece in pieces:
					var shape := CollisionPolygon2D.new()
					shape.polygon = piece
					_attach(contours, shape, room)
					var art := Polygon2D.new()
					art.polygon = piece
					art.material = wall_material
					_attach(contours, art, room)
	# 可站立的墙顶增加薄苔与垂根；它们只是墙体描边，不生成任何实心平台。
	var edges := Node2D.new()
	edges.name = "MossyWallEdges"
	edges.z_index = DECOR_Z
	_attach(room, edges)
	# 沿真实轮廓连续铺设与 forest_01 同源的厚苔岩表层，曲线处不反复挤压图块端帽。
	for polygon: PackedVector2Array in _open_polygons + _holes:
		for path in _floor_paths(polygon):
			_add_wall_rim(room, edges, path)


func _floor_paths(polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	var floors: Array[bool] = []
	var start := 0
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		var midpoint := (a + b) / 2.0
		var floor_edge := not is_equal_approx(a.x, b.x) and absf(b.y - a.y) <= absf(b.x - a.x) and _is_open(midpoint + Vector2.UP) and not _is_open(midpoint + Vector2.DOWN)
		floors.append(floor_edge)
		if not floor_edge:
			start = index
	var result: Array[PackedVector2Array] = []
	var path := PackedVector2Array()
	for step in range(1, polygon.size() + 1):
		var index := (start + step) % polygon.size()
		if floors[index]:
			if path.is_empty():
				path.append(polygon[index])
			path.append(polygon[(index + 1) % polygon.size()])
		elif not path.is_empty():
			if path[0].x > path[-1].x:
				path.reverse()
			result.append(path)
			path = PackedVector2Array()
	return result


func _add_wall_rim(room: Node2D, parent: Node2D, path: PackedVector2Array) -> void:
	var style: Dictionary = presentation[str(presentation.wall.surface_style)]
	var region := _rect(style.region)
	var texture := load(style.texture) as Texture2D
	var lengths: Array[float] = [0.0]
	for index in range(1, path.size()):
		lengths.append(lengths[-1] + path[index - 1].distance_to(path[index]))
	var total := lengths[-1]
	if total <= 0.0:
		return
	var cap := minf(float(presentation.wall.surface_cap), total / 2.0)
	var middle := total - cap * 2.0
	var count := maxi(1, ceili(middle / float(presentation.wall.surface_segment)))
	var segment_width := middle / count
	var cuts := lengths.duplicate()
	cuts.append(cap)
	cuts.append(total - cap)
	for index in range(1, count):
		cuts.append(cap + index * segment_width)
	cuts.sort()
	var samples := PackedVector2Array()
	var distances: Array[float] = []
	var cursor := 0
	for distance: float in cuts:
		if not distances.is_empty() and is_equal_approx(distances[-1], distance):
			continue
		while cursor < path.size() - 2 and distance > lengths[cursor + 1]:
			cursor += 1
		var fraction := (distance - lengths[cursor]) / maxf(0.0001, lengths[cursor + 1] - lengths[cursor])
		samples.append(path[cursor].lerp(path[cursor + 1], fraction))
		distances.append(distance)
	var normals := PackedVector2Array()
	for index in samples.size():
		var tangent := (samples[mini(index + 1, samples.size() - 1)] - samples[maxi(index - 1, 0)]).normalized()
		normals.append(Vector2(-tangent.y, tangent.x))
	var vertical_scale := float(presentation.wall.surface_thickness) / float(style.body_source_depth)
	var top := -(float(style.surface_y) - region.position.y) * vertical_scale
	var bottom := top + region.size.y * vertical_scale
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var triangles := PackedInt32Array()
	var source_cap := float(style.cap_source_width)
	for index in range(samples.size() - 1):
		var d0 := distances[index]
		var d1 := distances[index + 1]
		var u0: float
		var u1: float
		if d1 <= cap + 0.0001:
			u0 = region.position.x + source_cap * d0 / cap
			u1 = region.position.x + source_cap * d1 / cap
		elif d0 >= total - cap - 0.0001:
			u0 = region.end.x - source_cap + source_cap * (d0 - total + cap) / cap
			u1 = region.end.x - source_cap + source_cap * (d1 - total + cap) / cap
		else:
			var segment := clampi(floori(((d0 + d1) / 2.0 - cap) / segment_width), 0, count - 1)
			u0 = region.position.x + source_cap + (region.size.x - source_cap * 2.0) * (d0 - cap - segment * segment_width) / segment_width
			u1 = region.position.x + source_cap + (region.size.x - source_cap * 2.0) * (d1 - cap - segment * segment_width) / segment_width
		var positions := [samples[index] + normals[index] * top, samples[index + 1] + normals[index + 1] * top, samples[index + 1] + normals[index + 1] * bottom, samples[index] + normals[index] * bottom]
		var base := vertices.size()
		for point: Vector2 in positions:
			vertices.append(Vector3(point.x, point.y, 0))
		uv.append(Vector2(u0, region.position.y) / texture.get_size())
		uv.append(Vector2(u1, region.position.y) / texture.get_size())
		uv.append(Vector2(u1, region.end.y) / texture.get_size())
		uv.append(Vector2(u0, region.end.y) / texture.get_size())
		for vertex in [0, 1, 2, 0, 2, 3]:
			triangles.append(base + vertex)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = triangles
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var rim := MeshInstance2D.new()
	rim.name = "RockRootRim_%02d" % parent.get_child_count()
	rim.mesh = mesh
	rim.texture = texture
	rim.modulate = Color(style.tint)
	rim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rim.set_meta("surface_role", "wall_trim")
	rim.set_meta("source_style", "forest_01_solid")
	_attach(parent, rim, room)


func _add_new_decorations(room: Node2D) -> void:
	var parent := Node2D.new()
	parent.name = "NewForestDecorations"
	parent.z_index = DECOR_Z
	_attach(room, parent)
	for definition: Dictionary in presentation.new_decorations:
		var asset: Dictionary = presentation.decoration_assets[definition.asset]
		var sprite := Sprite2D.new()
		sprite.name = definition.id
		sprite.texture = load(asset.texture)
		var used := _rect(asset.visible_rect)
		if bool(asset.get("pixel_native",false)):
			var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/drafts/forest_decorations.json"))
			var point := _vec(definition.pos).round()
			point.y = roundf(_decor_surface_y(point,str(definition.anchor),rules))
			var embed := float(rules.contact_embed) * (-1.0 if definition.anchor == "ceiling" else 1.0)
			point.y += embed
			sprite.centered = false
			sprite.position = point-_vec(asset.anchor_pixel)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.set_meta("contact_point",point)
			sprite.set_meta("anchor_pixel",_vec(asset.anchor_pixel))
		else:
			sprite.scale = Vector2.ONE * float(definition.width) / used.size.x
			sprite.position = _vec(definition.pos)
			sprite.position.y += float(asset.embed_y)
			sprite.offset.x = sprite.texture.get_width() / 2.0 - used.get_center().x
			sprite.offset.y = sprite.texture.get_height() / 2.0 - (used.position.y if definition.anchor == "ceiling" else used.end.y)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.flip_h = definition.flip_h
		sprite.modulate = Color(asset.tint)
		sprite.set_meta("decorative", true)
		sprite.set_meta("asset_id", definition.asset)
		sprite.set_meta("anchor", definition.anchor)
		_attach(parent, sprite, room)


func _decor_surface_y(point: Vector2, anchor: String, rules: Dictionary) -> float:
	var nearest := point.y
	var distance := float(rules.surface_snap_distance)
	var contours: Array[PackedVector2Array] = []
	contours.append_array(_open_polygons)
	contours.append_array(_holes)
	for polygon: PackedVector2Array in contours:
		for index in polygon.size():
			var a := polygon[index]
			var b := polygon[(index+1)%polygon.size()]
			if is_equal_approx(a.x,b.x) or absf(b.y-a.y) > absf(b.x-a.x):
				continue
			if point.x < minf(a.x,b.x) or point.x > maxf(a.x,b.x):
				continue
			var y := lerpf(a.y,b.y,(point.x-a.x)/(b.x-a.x))
			var candidate := Vector2(point.x,y)
			var probe := Vector2.DOWN * float(rules.contact_probe)
			var floor_edge := _is_open(candidate-probe) and not _is_open(candidate+probe)
			var ceiling_edge := not _is_open(candidate-probe) and _is_open(candidate+probe)
			if (floor_edge if anchor == "ground" else ceiling_edge) and absf(y-point.y) < distance:
				distance = absf(y-point.y)
				nearest = y
	return nearest


func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var result := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		result = result.expand(point)
	return result


func _polygon_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in polygon.size():
		area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return absf(area) / 2.0


func _is_open(point: Vector2) -> bool:
	for hole in _holes:
		if Geometry2D.is_point_in_polygon(point, hole):
			return false
	for polygon in _open_polygons:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


func _union_open_area(area: PackedVector2Array) -> void:
	# 孔洞是回环包围的实体墙，后续扩展洞室时只裁去相交的孔洞部分。
	var remaining_holes: Array[PackedVector2Array] = []
	for hole in _holes:
		remaining_holes.append_array(Geometry2D.clip_polygons(hole, area))
	_holes = remaining_holes
	var pending := area
	var separate: Array[PackedVector2Array] = []
	for existing in _open_polygons:
		var merged := Geometry2D.merge_polygons(existing, pending)
		var outlines: Array[PackedVector2Array] = []
		var new_holes: Array[PackedVector2Array] = []
		for contour in merged:
			if Geometry2D.is_polygon_clockwise(contour):
				new_holes.append(contour)
			else:
				outlines.append(contour)
		if outlines.size() == 1:
			pending = outlines[0]
			_holes.append_array(new_holes)
		else:
			separate.append(existing)
	separate.append(pending)
	_open_polygons = separate


func _round_contour(polygon: PackedVector2Array, radius: float) -> PackedVector2Array:
	var rounded := PackedVector2Array()
	for index in polygon.size():
		var a := polygon[posmod(index - 1, polygon.size())]
		var b := polygon[index]
		var c := polygon[(index + 1) % polygon.size()]
		var distance := minf(radius, minf(a.distance_to(b), c.distance_to(b)) * float(config.smoothing.edge_fraction))
		var entry := b.move_toward(a, distance)
		var exit := b.move_toward(c, distance)
		for step in range(int(config.smoothing.segments) + 1):
			var t := float(step) / float(config.smoothing.segments)
			rounded.append(entry.lerp(b, t).lerp(b.lerp(exit, t), t))
	return rounded


func _add_contour_distance() -> void:
	var cell := float(config.smoothing.distance_cell)
	var maximum := float(config.smoothing.distance_max)
	var width := ceili(float(config.bounds[0]) / cell)
	var height := ceili(float(config.bounds[1]) / cell)
	var distances := PackedFloat32Array()
	distances.resize(width * height)
	var outside := PackedFloat32Array()
	outside.resize(width * height)
	for y in height:
		for x in width:
			var open := _is_open((Vector2(x, y) + Vector2.ONE / 2.0) * cell)
			distances[y * width + x] = 0.0 if open else maximum / cell
			outside[y * width + x] = maximum / cell if open else 0.0
	distances = _distance_transform(distances, width, height)
	outside = _distance_transform(outside, width, height)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var signed_distance := (distances[y * width + x] - outside[y * width + x]) * cell
			signed_distance -= signf(signed_distance) * cell / 2.0
			var encoded := clampf(0.5 + signed_distance / (maximum * 2.0), 0, 1)
			image.set_pixel(x, y, Color(encoded, encoded, encoded, 1))
	wall_material.set_shader_parameter("use_contour_distance", true)
	wall_material.set_shader_parameter("distance_max", maximum)
	wall_material.set_shader_parameter("contour_distance", ImageTexture.create_from_image(image))


func _distance_transform(distances: PackedFloat32Array, width: int, height: int) -> PackedFloat32Array:
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var index := y * width + x
			distances[index] = minf(distances[index], minf(minf(distances[index - 1], distances[index - width]) + 1.0, minf(distances[index - width - 1], distances[index - width + 1]) + sqrt(2.0)))
	for y in range(height - 2, 0, -1):
		for x in range(width - 2, 0, -1):
			var index := y * width + x
			distances[index] = minf(distances[index], minf(minf(distances[index + 1], distances[index + width]) + 1.0, minf(distances[index + width + 1], distances[index + width - 1]) + sqrt(2.0)))
	return distances


func _add_chests(room: Node2D) -> void:
	var style: Dictionary = presentation.chest
	var texture := load(style.texture) as Texture2D
	var contact := texture.get_image().get_used_rect().end.y
	for definition: Dictionary in config.chests:
		var chest := Sprite2D.new()
		chest.name = definition.node
		chest.texture = texture
		chest.position = _vec(definition.pos)
		chest.offset.y = texture.get_height() / 2.0 - contact
		chest.scale = Vector2.ONE * float(style.width) / texture.get_width()
		chest.z_index = DECOR_Z
		chest.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		chest.modulate = Color(style.sealed_tint if definition.requires_clear else style.normal_tint)
		chest.set_meta("interact", "chest")
		chest.set_meta("chest_id", definition.id)
		chest.set_meta("requires_clear", definition.requires_clear)
		chest.set_meta("encounter_id", definition.encounter_id)
		_attach(room, chest)
		if definition.requires_clear:
			var seal := Node2D.new()
			seal.name = "CombatSeal"
			seal.position.y = -contact / 2.0
			seal.set_script(load("res://scripts/world/forest_mechanism_art.gd"))
			seal.set("kind", "chest")
			_attach(chest, seal, room)


func _add_mechanisms(room: Node2D) -> void:
	var mechanism := Node2D.new()
	mechanism.name = config.switch.node
	mechanism.set_script(load("res://scripts/world/forest_mechanism_art.gd"))
	mechanism.position = _vec(config.switch.pos)
	mechanism.set("kind", "switch")
	mechanism.set_meta("switch_id", config.switch.id)
	mechanism.set_meta("interaction_text", "E  激活古根机关")
	mechanism.set_meta("interaction_offset_y", float(presentation.mechanism.hint_offset))
	mechanism.z_index = DECOR_Z
	_attach(room, mechanism)
	var switch_art := Sprite2D.new()
	switch_art.name = "RuinSwitchSprite"
	switch_art.texture = load(presentation.mechanism.switch_texture)
	var used := _rect(presentation.mechanism.switch_visible_rect)
	switch_art.scale = Vector2.ONE * float(presentation.mechanism.switch_width) / used.size.x
	switch_art.offset.y = switch_art.texture.get_height() / 2.0 - used.end.y
	switch_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	switch_art.modulate = Color(presentation.mechanism.switch_tint)
	_attach(mechanism, switch_art, room)
	for definition: Dictionary in config.gates:
		var body := StaticBody2D.new()
		body.name = definition.id
		body.position = _vec(definition.pos)
		body.collision_layer = WORLD
		body.collision_mask = 0
		body.set_meta("switch_id", definition.switch_id)
		body.set_meta("surface_role", "mechanism_gate")
		_attach(room, body)
		var shape := CollisionShape2D.new()
		shape.name = "Shape"
		var rectangle := RectangleShape2D.new()
		rectangle.size = _vec(definition.size)
		shape.shape = rectangle
		_attach(body, shape, room)
		var art := Node2D.new()
		art.name = "SealArt"
		art.set_script(load("res://scripts/world/forest_mechanism_art.gd"))
		art.set("kind", "gate")
		art.set("gate_size", rectangle.size)
		art.set("horizontal", definition.orientation == "horizontal")
		art.z_index = DECOR_Z
		_attach(body, art, room)


func _write_overview() -> void:
	var scale := 2
	var size := Vector2i(int(config.bounds[0]) / scale, int(config.bounds[1]) / scale)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color("#14292b"))
	var coverage := (wall_material.get_shader_parameter("coverage_texture") as Texture2D).get_image()
	for y in coverage.get_height():
		for x in coverage.get_width():
			if coverage.get_pixel(x, y).r > 0.5:
				image.fill_rect(Rect2i(x * tile / scale, y * tile / scale, tile / scale, tile / scale), Color("#686b54"))
	for platform: Dictionary in config.platforms:
		var rect := _rect(platform.rect)
		image.fill_rect(Rect2i(rect.position / scale, rect.size / scale), Color("#83d3ec"))
	for chest: Dictionary in config.chests:
		image.fill_rect(Rect2i(_vec(chest.pos) / scale - Vector2(6, 10), Vector2(12, 10)), Color("#c578df"))
	image.fill_rect(Rect2i(_vec(config.campfire.pos) / scale - Vector2(6, 10), Vector2(12, 10)), Color("#ffce3a"))
	image.fill_rect(Rect2i(_vec(config.switch.pos) / scale - Vector2(6, 16), Vector2(12, 16)), Color(config.switch.color))
	for gate: Dictionary in config.gates:
		image.fill_rect(Rect2i((_vec(gate.pos) - _vec(gate.size) / 2.0) / scale, _vec(gate.size) / scale), Color(config.switch.color))
	image.save_png(ProjectSettings.globalize_path("res://docs/previews/forest_02_layout.png"))


func _add_reserved_exit(room: Node2D) -> void:
	if not config.has("reserved_exit"):
		return
	var exit := Area2D.new()
	exit.name = config.reserved_exit.id
	exit.position = _vec(config.reserved_exit.pos)
	exit.set_script(load("res://scripts/world/forest_reserved_exit.gd"))
	exit.set_meta("target_room", config.reserved_exit.target)
	exit.set_meta("reserved", true)
	_attach(room, exit)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = _vec(config.reserved_exit.size)
	shape.shape = rectangle
	_attach(exit, shape, room)
	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(-tile, -tile / 4.0), Vector2.ZERO, Vector2(0, -tile / 2.0), Vector2(tile, 0), Vector2(0, tile / 2.0), Vector2.ZERO, Vector2(-tile, tile / 4.0)])
	arrow.color = Color("#b9e5ca")
	arrow.z_index = DECOR_Z
	_attach(exit, arrow, room)


func _add_boundary(room: Node2D) -> void:
	# 预留出口暂未有下一张可玩地图，边界只防止走出世界。
	var body := StaticBody2D.new()
	body.name = "OuterBoundary"
	body.collision_mask = 0
	_attach(room, body)
	for side in [0, 1]:
		var shape := CollisionShape2D.new()
		var boundary := WorldBoundaryShape2D.new()
		boundary.normal = Vector2.RIGHT if side == 0 else Vector2.LEFT
		boundary.distance = 0 if side == 0 else -float(config.bounds[0])
		shape.shape = boundary
		_attach(body, shape, room)
