class_name CombatEnemyProjectile
extends Area2D
## 敌方直线投射物：发射时锁定方向，墙体遮挡，只能结算玩家受击框。
var direction := Vector2.RIGHT
var packet: DamagePacket
var target: Node
var tuning: Dictionary
var remaining := 0.0
var radius := 0.0
var tint := Color.WHITE
var sprite: AnimatedSprite2D

func _ready() -> void:
	collision_layer = 16
	collision_mask = 33
	remaining = float(tuning.projectile_lifetime)
	radius = float(tuning.projectile_radius)
	var rgba: Array = tuning.projectile_color
	tint = Color(rgba[0], rgba[1], rgba[2], rgba[3])
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	_setup_visual()
	area_entered.connect(_hit)
	body_entered.connect(func(_body: Node2D) -> void: queue_free())

func _setup_visual() -> void:
	var path := str(tuning.get("projectile_catalog_path", ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not catalog is Dictionary:
		return
	var wanted := str(tuning.get("projectile_visual_id", ""))
	var rows: Array = catalog.get("projectiles", catalog.get("effects", []))
	for entry: Dictionary in rows:
		if str(entry.get("id", "")) != wanted:
			continue
		var frames := SpriteFrames.new()
		frames.set_animation_speed(&"default", float(entry.fps))
		frames.set_animation_loop(&"default", true)
		for relative: String in entry.frames:
			var texture_path := path.get_base_dir().path_join(relative)
			if ResourceLoader.exists(texture_path):
				frames.add_frame(&"default", load(texture_path))
		if frames.get_frame_count(&"default") == 0:
			continue
		sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.centered = false
		sprite.offset = -Vector2(entry.anchor[0], entry.anchor[1])
		sprite.rotation = direction.angle()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		sprite.play()
		return

func _physics_process(delta: float) -> void:
	position += direction * float(tuning.projectile_speed) * delta
	remaining -= delta
	if remaining <= 0.0:
		queue_free()

func _hit(area: Area2D) -> void:
	if area is HurtboxComponent and area.owner_actor == target:
		area.receive_hit(packet)
		queue_free()

func _draw() -> void:
	if sprite != null:
		return
	draw_circle(Vector2.ZERO, radius, tint)
