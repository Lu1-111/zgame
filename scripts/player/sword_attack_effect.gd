class_name SwordAttackEffect
extends Node2D
## 剑刃、剑光与接触轮廓共用逐帧数据；实际伤害沿凸形逐段查询，不填满弧线内部。
signal hit_landed(target: Node, final_damage: int)

const CONFIG_PATH := "res://data/sword_contact.json"
static var _config: Dictionary = {}
static var _manifest: Dictionary = {}
var packet: DamagePacket
var source_actor: Node
var combo := 1
var _started_at := 0.0
var _module: Dictionary
var _frame: Dictionary = {}
var _pose_name := ""
var _opacity := 1.0
var _hitbox: HitboxComponent
var _query_shapes: Array[Shape2D] = []
var _contact_polygons: Array[PackedVector2Array] = []
var _shape_cache: Dictionary = {}


## 读取特效与接触的同源轮廓配置。
static func configuration() -> Dictionary:
	if _config.is_empty():
		_config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	return _config


## 读取正在播放的完整人物帧及其持剑姿态时间表。
static func frame_manifest() -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(str(configuration().frame_manifest)))
	return _manifest


## 发射随本次剑攻击更新的剑光和精确接触实体。
static func spawn(parent: Node, attack_packet: DamagePacket, actor: Node, combo_index: int) -> SwordAttackEffect:
	var effect := SwordAttackEffect.new()
	effect.packet = attack_packet
	effect.source_actor = actor
	effect.combo = clampi(combo_index,1,configuration().profiles.size())
	parent.add_child(effect)
	return effect


func _ready() -> void:
	_module = WeaponRuntime.module("sword")
	if is_instance_valid(source_actor) and source_actor.has_method("normal_attack_module"):_module=source_actor.normal_attack_module()
	z_index = 1
	if is_instance_valid(source_actor):
		position = source_actor._pixel_rig.position
		scale.x = float(source_actor.facing)
		_started_at = float(source_actor._last_attack_time)
	if packet != null:
		_hitbox = HitboxComponent.new()
		_hitbox.name = "SwordContact"
		_hitbox.source_actor = source_actor
		_hitbox.manual_scan = true
		_hitbox.deduplicate_actors = true
		add_child(_hitbox)
		_hitbox.activate(packet)
		_hitbox.hit_landed.connect(func(target: Node, damage: int) -> void: hit_landed.emit(target,damage))
	else:
		set_physics_process(false)
	sample_attack_progress(0)


## 按人物攻击总进度采样完整剑光帧，供运行与离屏预览共用。
func sample_attack_progress(progress: float) -> void:
	var manifest := frame_manifest()
	var entries: Array = manifest.clips["sword_%d" % combo].frames
	var entry: Dictionary = entries[0]
	for candidate: Dictionary in entries:
		if float(candidate.progress) <= clampf(progress,0,1):
			entry = candidate
		else:
			break
	var name := str(entry.pose)
	if name != _pose_name:
		_pose_name = name
		_frame = configuration().frames[name]
		if not _shape_cache.has(name):
			var shapes: Array[Shape2D] = []
			var polygons: Array[PackedVector2Array] = []
			for contact: Dictionary in _frame.contacts:
				var polygon := _polygon(contact.polygon)
				var shape := ConvexPolygonShape2D.new()
				shape.points = polygon
				shapes.append(shape)
				polygons.append(polygon)
			_shape_cache[name] = {"shapes":shapes,"polygons":polygons}
		_query_shapes = _shape_cache[name].shapes
		_contact_polygons = _shape_cache[name].polygons
	var elapsed := clampf(progress,0,1)*(float(_module.startup)+float(_module.active)+float(_module.recovery))
	var active_progress := clampf((elapsed-float(_module.startup))/float(_module.active),0,1)
	var fade := float(configuration().fade_start)
	_opacity = 1.0 if active_progress <= fade else (1-active_progress)/(1-fade)
	queue_redraw()


## 提供实际使用的接触轮廓，便于预览叠加与边界测试。
func get_contact_polygons() -> Array[PackedVector2Array]:
	return _contact_polygons


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(source_actor) or source_actor.sm.current_name() != &"Attack" or source_actor.weapon_type() != "sword" or float(source_actor._last_attack_time) != _started_at:
		_close()
		return
	var elapsed := float(source_actor._clock)-_started_at
	if elapsed >= float(_module.startup)+float(_module.active):
		_close()
		return
	sample_attack_progress(elapsed/(float(_module.startup)+float(_module.active)+float(_module.recovery)))
	if elapsed >= float(_module.startup) and _hitbox != null:
		_hitbox.scan_shape_contacts(_query_shapes,global_transform,int(configuration().max_contacts))


func _close() -> void:
	if _hitbox != null:
		_hitbox.deactivate()
	queue_free()


func _draw() -> void:
	for visual: Dictionary in _frame.get("visuals",[]):
		var color := Color(str(configuration().colors[str(visual.layer)]))
		color.a *= float(visual.strength)*_opacity
		draw_colored_polygon(_polygon(visual.polygon),color)


func _polygon(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Array in values:
		result.append(Vector2(point[0],point[1]))
	return result
