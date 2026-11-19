class_name CorrumptEntity
extends Node2D
## 独立针弹、孢子、地刺及冲击波；投射物使用扫掠检测，避免高速穿过实体。
var kind: StringName
var source: Node2D
var target: Node2D
var config: Dictionary
var profile: Dictionary
var bounds := Rect2()
var direction := Vector2.RIGHT
var pattern_index := -1
var lifetime := 0.0
var damage := 0
var radius := 0.0
var hit_size := Vector2.ZERO
var age := 0.0
var ring_max := 0.0
var _hits: Dictionary = {}
var _visual: AnimatedSprite2D
var _last_ring_radius := 0.0
var _native_ring := false
var _ring_material: ShaderMaterial
var _ring_extent := 0.0
var _needle_shape: CapsuleShape2D
var _spore_shape: CircleShape2D
var bounce_count := 0

func _ready() -> void:
	add_to_group(&"corrumpt_entities")
	z_index = 21
	_visual = AnimatedSprite2D.new()
	_visual.sprite_frames = load(str(profile.art.root)+"godot/Corrumpt_combat_frames.tres") as SpriteFrames
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_visual.play(kind)
	add_child(_visual)
	if kind == &"needle":
		rotation = direction.angle()
		_needle_shape = CapsuleShape2D.new()
		_needle_shape.radius = radius
		_needle_shape.height = float(config.collision_length)
	elif kind == &"spore":
		_spore_shape = CircleShape2D.new()
		_spore_shape.radius = radius
	if kind in [&"needle",&"spore"]:
		var visual_size: Array = config.visual_size
		_visual.scale = Vector2(float(visual_size[0]),float(visual_size[1]))/_visual.sprite_frames.get_frame_texture(kind,0).get_size()
	elif kind == &"spike":
		_visual.scale = Vector2(hit_size.x,hit_size.y)/_visual.sprite_frames.get_frame_texture(kind,0).get_size()
		_visual.position.y = -hit_size.y/2
		_visual.pause()
	elif kind == &"impact":
		_visual.scale = hit_size/_visual.sprite_frames.get_frame_texture(kind,0).get_size()
		_visual.position.y = -hit_size.y/2
	if profile.art.get("pixel",{}).has("conversion") and kind in [&"needle",&"spore",&"spike",&"impact"]:
		_visual.scale = Vector2.ONE*float(profile.art.pixel.render_scale)
		if kind in [&"spike",&"impact"]:
			_visual.position.y = -_visual.sprite_frames.get_frame_texture(kind,0).get_height()*_visual.scale.y/2
	var style: Dictionary = profile.art.get("unified",{})
	if style.has("effect_source"):
		# 正式帧已按世界尺寸烘焙，不再按每张图的包围盒二次缩放。
		_visual.scale = Vector2.ONE
	var ring: Dictionary = style.get("ring_rendering",{})
	if String(kind) in ring.get("kinds",[]):
		_native_ring = true
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_visual.visible = false
		_ring_extent = ceilf(ring_max+float(ring.strip_height))
		_ring_material = ShaderMaterial.new()
		_ring_material.shader = load(str(ring.shader)) as Shader
		_ring_material.set_shader_parameter("extent_world",_ring_extent)
		for key: String in ["pixel_pitch","repeat_pixels","strip_height"]:
			_ring_material.set_shader_parameter(key,float(ring[key]))
		material = _ring_material
		_tick_ring()

func _draw() -> void:
	if _native_ring and is_instance_valid(_visual):
		var strip := _visual.sprite_frames.get_frame_texture(kind,_visual.frame)
		draw_texture_rect(strip,Rect2(Vector2.ONE*-_ring_extent,Vector2.ONE*_ring_extent*2),false)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or (source.get("hp") == 0 and not bool(config.get("cinematic_visual",false))):
		queue_free()
		return
	age += delta
	if lifetime > 0 and age >= lifetime:
		queue_free()
		return
	match kind:
		&"needle":
			_move_needle(delta)
		&"spore":
			_move_spore(delta)
		&"spike":
			_visual.frame = 0 if age < lifetime/8 else (3 if age > lifetime*0.85 else 2)
			if not _hits.has(target) and _touches_player(_rectangle(hit_size),0,Vector2(0,-hit_size.y/2)):
				_hits[target] = true
				_hit_player()
		&"impact":
			if bool(config.get("impact_damage",true)) and age <= float(config.active_seconds) and not _hits.has(target) and _touches_player(_rectangle(hit_size),0,Vector2(0,-hit_size.y/2)):
				_hits[target] = true
				_hit_player()
		&"gravity_ring", &"repel_ring":
			_tick_ring()

func _move_needle(delta: float) -> void:
	# 发射时已确定扇形方向，飞行期间始终直行，不再读取玩家位置。
	rotation = direction.angle()
	var step := direction*float(config.speed)*delta
	var hit := _sweep(step,135)
	if not hit.is_empty():
		global_position = hit.position
		if hit.collider == target:
			_hit_player()
		queue_free()
		return
	global_position += step
	if not bounds.has_point(global_position):
		queue_free()

func _move_spore(delta: float) -> void:
	var remaining := float(config.speed)*delta
	var epsilon := float(config.collision_epsilon)
	for collision_index in int(config.max_bounces)+1:
		var step := direction*remaining
		var terrain := _spore_terrain_hit(step)
		var travel: Vector2 = terrain.position-global_position if not terrain.is_empty() else step
		if _spore_hits_player(travel):
			_hit_player()
			queue_free()
			return
		global_position += travel
		if terrain.is_empty():
			break
		bounce_count += 1
		if bounce_count >= int(config.max_bounces):
			queue_free()
			return
		var normal: Vector2 = terrain.normal
		direction = direction.bounce(normal).normalized()
		if bool(terrain.get("overlap",false)):
			global_position = terrain.point+normal*(radius+epsilon)
		else:
			global_position += normal*epsilon
		remaining = maxf(0,remaining-travel.length())
		if remaining <= epsilon:
			break
	if not bounds.has_point(global_position):
		queue_free()

func _spore_hits_player(step: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = radius
	shape.height = step.length()+radius*2
	query.shape = shape
	query.transform = Transform2D(direction.angle()-PI/2,global_position+step/2)
	query.collision_mask = 32
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(query):
		if hit.collider is HurtboxComponent and hit.collider.owner_actor == target:
			return true
	return false

func _spore_terrain_hit(step: Vector2) -> Dictionary:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _spore_shape
	query.transform = Transform2D(0,global_position)
	query.collision_mask = int(config.terrain_mask)
	query.collide_with_areas = bool(config.get("terrain_areas",false))
	query.margin = 0
	var space := get_world_2d().direct_space_state
	var rest := space.get_rest_info(query)
	if not rest.is_empty():
		return {"position":global_position,"normal":rest.normal,"point":rest.point,"overlap":true}
	query.motion = step
	var fraction := space.cast_motion(query)
	if fraction[0] >= 1:
		return {}
	var safe := global_position+step*float(fraction[0])
	query.motion = Vector2.ZERO
	query.transform.origin = global_position+step*float(fraction[1])+direction*float(config.collision_epsilon)
	query.margin = float(config.collision_epsilon)
	rest = space.get_rest_info(query)
	return {"position":safe,"normal":rest.normal if not rest.is_empty() else -direction}

func _sweep(step: Vector2, mask: int) -> Dictionary:
	# 使用与放大针体相符的胶囊扫掠，擦到角色或墙边也会命中，避免只按中心线判断。
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _needle_shape
	query.transform = Transform2D(direction.angle()-PI/2,global_position)
	query.collision_mask = mask
	query.margin = 0
	if source is CollisionObject2D:
		query.exclude = [source.get_rid()]
	var space := get_world_2d().direct_space_state
	var overlaps := space.intersect_shape(query)
	if not overlaps.is_empty():
		return {"position":global_position,"collider":overlaps[0].collider}
	query.motion = step
	var fractions := space.cast_motion(query)
	if float(fractions[0]) >= 1:
		return {}
	var safe := global_position+step*float(fractions[0])
	query.motion = Vector2.ZERO
	query.transform.origin = global_position+step*float(fractions[1])+step.normalized()*float(config.sweep_probe_pixels)
	overlaps = space.intersect_shape(query)
	return {"position":safe,"collider":overlaps[0].collider if not overlaps.is_empty() else null}

func _rectangle(size_value: Vector2) -> RectangleShape2D:
	var shape := RectangleShape2D.new()
	shape.size = size_value
	return shape

func _touches_player(shape: Shape2D, sphere_radius: float = 0.0, offset := Vector2.ZERO) -> bool:
	if not is_instance_valid(target):
		return false
	if shape is CircleShape2D:
		shape.radius = sphere_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0,global_position+offset)
	query.collision_mask = 32
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(query):
		if result.collider is HurtboxComponent and result.collider.owner_actor == target:
			return true
	return false

func _hit_player() -> void:
	if is_instance_valid(target) and target.has_method("apply_hit"):
		var type := DamagePacket.DamageType.MAGIC if str(config.get("damage_type","physical")) == "magic" else DamagePacket.DamageType.PHYSICAL
		var packet := DamagePacket.new(damage,type,0,source.global_position,&"corrumpt")
		packet.origin_actor = source
		target.apply_hit(packet)

func _tick_ring() -> void:
	var current := ring_max*clampf(age/lifetime,0,1)
	if _native_ring:
		_ring_material.set_shader_parameter("radius_world",current)
		modulate.a = 1.0-age/lifetime
		queue_redraw()
	else:
		var texture := _visual.sprite_frames.get_frame_texture(kind,0)
		_visual.scale = Vector2.ONE*current*2/texture.get_width()
		_visual.modulate.a = 1.0-age/lifetime
	if kind == &"repel_ring" and not bool(config.get("visual_only",false)) and is_instance_valid(target) and not _hits.has(target):
		var distance := global_position.distance_to(target.global_position)
		if distance <= current and distance >= _last_ring_radius-radius:
			_hits[target] = true
			target.apply_boss_force(global_position,float(config.push_speed),float(config.push_seconds),float(config.stun_seconds),false)
	_last_ring_radius = current
