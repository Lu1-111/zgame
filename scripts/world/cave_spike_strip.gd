extends Area2D
## 石笋逐段交错铺排，碰撞沿可见alpha轮廓；只报告接触，伤害数值由所属房间提供。
signal hazard_contact(body: Node2D)
@export_range(1,100) var segment_count := 1
var _contacting: Array[Node2D] = []

func _ready() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/art/cave_v001.json"))
	collision_layer = int(config.physics_layers.hazard)
	collision_mask = int(config.physics_layers.player)
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for index in segment_count:
		var spec: Dictionary = config.assets["stalagmites_%02d" % (index%4+1)]
		var texture := load(str(spec.path)) as Texture2D
		var offset := Vector2(index*float(spec.repeat_step)-float(spec.anchor[0]),-float(spec.anchor[1]))
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.position = offset
		add_child(sprite)
		var mask := BitMap.new()
		mask.create_from_image_alpha(texture.get_image())
		for polygon: PackedVector2Array in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,texture.get_size()),0.0):
			var shape := CollisionPolygon2D.new()
			shape.polygon = polygon
			shape.position = offset
			add_child(shape)
	body_entered.connect(_enter)
	body_exited.connect(_leave)

func _enter(body: Node2D) -> void:
	if not _contacting.has(body):
		_contacting.append(body)

func _leave(body: Node2D) -> void:
	_contacting.erase(body)

func _physics_process(_delta: float) -> void:
	for body in _contacting.duplicate():
		if is_instance_valid(body):
			hazard_contact.emit(body)
		else:
			_contacting.erase(body)
