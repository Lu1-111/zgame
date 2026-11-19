extends StaticBody2D
## 分段铺设原生石台，表面齐平、下缘交错；碰撞只取顶部，支持从下方跳过。
@export_range(1,100) var segment_count := 1

func _ready() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/art/cave_v001.json"))
	collision_layer = int(config.physics_layers.one_way)
	collision_mask = 0
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var width := 0.0
	for index in segment_count:
		var spec: Dictionary = config.assets["platform_%02d" % (index%2+1)]
		var sprite := Sprite2D.new()
		sprite.texture = load(str(spec.path))
		sprite.centered = false
		sprite.position.x = width
		width += float(spec.size[0])
		add_child(sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var thickness := float(config.platform.collision_thickness)
	rect.size = Vector2(width,thickness)
	shape.shape = rect
	shape.position = Vector2(width,thickness)/2.0
	shape.one_way_collision = true
	shape.one_way_collision_margin = float(config.platform.collision_margin)
	add_child(shape)
