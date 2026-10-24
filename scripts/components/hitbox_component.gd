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
	monitoring = true


## 关闭判定窗。
func deactivate() -> void:
	_active = false
	monitoring = false
	packet = null


func _physics_process(_delta: float) -> void:
	if not _active or packet == null:
		return
	for area in get_overlapping_areas():
		if _already_hit.has(area):
			continue
		# 归属过滤：层6 是双方共用受击层，绝不命中攻击归属者自己的受击框
		if area is HurtboxComponent and area.owner_actor != null and area.owner_actor == source_actor:
			continue
		if area.has_method("receive_hit"):
			_already_hit[area] = true
			var dmg := int(area.receive_hit(packet))
			hit_landed.emit(area, dmg)
