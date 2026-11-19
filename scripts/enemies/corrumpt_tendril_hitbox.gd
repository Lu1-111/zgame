class_name CorrumptTendrilHitbox
extends Area2D
## 触手实体使用当前逐帧alpha轮廓；曲线内部空白不作为伤害区域。
var source: Node2D
var sprite: AnimatedSprite2D
var config: Dictionary
var armed := false
var _serial := -1
var _hits: Dictionary = {}
var _cache: Dictionary = {}
var _frame_key := ""
var _shapes: Array[ConvexPolygonShape2D] = []
var _polygons: Array[CollisionPolygon2D] = []
var _polygon_count := 0

func _ready() -> void:
	collision_layer = 16
	collision_mask = 32
	monitoring = false
	monitorable = false

## 同步当前触手姿态；每次砸击最多命中同一目标一次，左右实体独立保留。
func sync_pose(enabled: bool, serial: int) -> void:
	armed = enabled
	if serial != _serial:
		_serial = serial
		_hits.clear()
	if not armed:
		for polygon in _polygons:
			polygon.disabled = true
		return
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
	var key := "%d:%s" % [texture.get_instance_id(),str(sprite.flip_h)]
	if key != _frame_key:
		_frame_key = key
		if not _cache.has(key):
			_cache[key] = _outline(texture)
		var data: Dictionary = _cache[key]
		_polygon_count = data.polygons.size()
		_shapes.assign(data.shapes)
		while _polygons.size() < data.polygons.size():
			var child := CollisionPolygon2D.new()
			add_child(child)
			_polygons.append(child)
		for index in _polygons.size():
			var used: bool = index < data.polygons.size()
			_polygons[index].disabled = not used
			if used:
				_polygons[index].polygon = data.polygons[index]
	else:
		for index in _polygons.size():
			_polygons[index].disabled = index >= _polygon_count
	global_transform = sprite.global_transform*Transform2D(0,sprite.offset)
	_check_contact()

func _outline(texture: Texture2D) -> Dictionary:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image,float(config.collision_alpha_cutoff))
	var contours := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,image.get_size()),float(config.collision_simplify_epsilon))
	var result := {"polygons":[],"shapes":[]}
	for original: PackedVector2Array in contours:
		var polygon := original.duplicate()
		if sprite.flip_h:
			for index in polygon.size():
				polygon[index].x = texture.get_width()-polygon[index].x
			polygon.reverse()
		var area := 0.0
		for index in polygon.size():
			area += polygon[index].cross(polygon[(index+1)%polygon.size()])
		if absf(area)/2 < float(config.minimum_polygon_area):
			continue
		result.polygons.append(polygon)
		for points in Geometry2D.decompose_polygon_in_convex(polygon):
			var shape := ConvexPolygonShape2D.new()
			shape.points = points
			result.shapes.append(shape)
	return result

func _check_contact() -> void:
	if not is_instance_valid(source) or not is_instance_valid(source.target) or _hits.has(source.target):
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.transform = global_transform
	for shape in _shapes:
		query.shape = shape
		for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(query):
			if hit.collider is HurtboxComponent and hit.collider.owner_actor == source.target:
				_hits[source.target] = true
				var type := DamagePacket.DamageType.MAGIC if str(config.damage_type) == "magic" else DamagePacket.DamageType.PHYSICAL
				var packet := DamagePacket.new(roundi(float(source.definition.damage)*float(config.damage_multiplier)),type,0,source.global_position,&"corrumpt")
				packet.origin_actor = source
				source.target.apply_hit(packet)
				return
