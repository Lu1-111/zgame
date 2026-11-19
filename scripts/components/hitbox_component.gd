class_name HitboxComponent
extends Area2D
## 攻击判定框（层4 player_hitbox，扫描层6 hurtbox）：
## activate() 开窗期间每物理帧扫描重叠的受击框，对每个目标只结算一次。
## 命中回调（顿帧/屏震/飘字）由宿主连接 hit_landed 处理。

signal hit_landed(target: Node, final_damage: int)

var packet: DamagePacket = null
var source_actor: Node = null   ## 攻击归属方（与 HurtboxComponent.owner_actor 比对，排除命中自己）
var _already_hit: Dictionary = {}
var _active := false
var manual_scan := false
var deduplicate_actors := false


func _ready() -> void:
	collision_layer = 8   # player_hitbox
	collision_mask = 32   # hurtbox
	monitoring = false
	# 形状去共享：同一场景多实例各自改尺寸时不互相污染
	var cs := get_node_or_null("Shape") as CollisionShape2D
	if cs != null and cs.shape != null:
		cs.shape = cs.shape.duplicate()


## 开启判定窗（packet 必填）；持续到 deactivate() 或 free。
func activate(p_packet: DamagePacket) -> void:
	packet = p_packet
	_already_hit.clear()
	_active = true
	monitoring = not manual_scan


## 关闭判定窗。
func deactivate() -> void:
	_active = false
	monitoring = false
	packet = null


func _physics_process(_delta: float) -> void:
	if manual_scan or not _active or packet == null:
		return
	for area in get_overlapping_areas():
		try_hit_area(area)


## 将接触结果送入统一结算，保留归属过滤与单次命中；多受击框可按宿主去重。
func try_hit_area(area: Area2D) -> void:
	if not _active or packet == null or not is_instance_valid(area):
		return
	if area is HurtboxComponent and area.owner_actor != null and area.owner_actor == source_actor:
		return
	var key: Node = area
	if deduplicate_actors and area is HurtboxComponent and is_instance_valid(area.owner_actor):
		key = area.owner_actor
	if _already_hit.has(key) or not area.has_method("receive_hit"):
		return
	_already_hit[key] = true
	var dmg := int(area.receive_hit(packet))
	hit_landed.emit(area, dmg)


## 当帧查询可见轮廓对应的凸形，避免 Area2D 重叠缓存落后高速剑光一帧。
func scan_shape_contacts(shapes: Array[Shape2D], world_transform: Transform2D, max_results: int) -> void:
	if not _active or packet == null or not is_inside_tree():
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.transform = world_transform
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for shape in shapes:
		query.shape = shape
		for result in get_world_2d().direct_space_state.intersect_shape(query,max_results):
			try_hit_area(result.collider as Area2D)
