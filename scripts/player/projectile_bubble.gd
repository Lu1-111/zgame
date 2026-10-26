class_name ProjectileBubble
extends Area2D
## 奶泡弹（skill_bubble，参考书 §3.6）：直线飞行，命中受击框结算后消散，撞墙消失。
## 命中减速 30% 的施加在敌侧 AI（M1 敌人实装时消费）。
## M1.5：方向 2D 化（随鼠标瞄准发射）；命中/撞墙时播 AttackEffect 命中冲击（纯视觉）。

signal hit_landed(target: Node, final_damage: int)
var visual_kind := ""
var _weapon_visual: AnimatedSprite2D

const SPEED := 380.0        ## 飞行速度（手感参数，M1 调参区）
const LIFETIME := 1.2       ## 存活秒数（防泄漏）
const RADIUS := 5.0

var dir := Vector2.RIGHT        ## 飞行方向（单位向量，2D 任意角度）
var speed := SPEED              ## 飞行速度（武器/道具投射物可覆写，如奶弹 420 / 法球 260）
var packet: DamagePacket = null
var source_actor: Node = null   ## 发射者归属（出生点贴着发射者，必须排除其受击框）
var _life := LIFETIME
var _hit: Dictionary = {}


## 由玩家在发射前注入方向与伤害包（零向量时回退朝右）。
func setup(p_dir: Vector2, p_packet: DamagePacket) -> void:
	dir = p_dir.normalized() if p_dir.length() > 0.01 else Vector2.RIGHT
	packet = p_packet


func _ready() -> void:
	collision_layer = 8        # player_hitbox
	collision_mask = 32 | 1    # hurtbox + world（撞墙消散）
	monitoring = true
	if visual_kind in ["arrow","staff"]:
		_weapon_visual = AnimatedSprite2D.new()
		_weapon_visual.sprite_frames = WeaponRuntime.effect_frames(visual_kind,true)
		_weapon_visual.scale = WeaponRuntime.effect_scale(visual_kind)
		_weapon_visual.rotation = dir.angle()
		add_child(_weapon_visual)
		if visual_kind == "arrow":
			_weapon_visual.frame = 3
		else:
			_weapon_visual.play()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += dir * speed * delta
	_life -= delta
	queue_redraw()
	if _life <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if packet == null or _hit.has(area):
		return
	# 归属过滤：擦过发射者自己的受击框时不停留、不消耗
	if area is HurtboxComponent and area.owner_actor != null and area.owner_actor == source_actor:
		return
	if area.has_method("receive_hit"):
		_hit[area] = true
		var damage: int = area.receive_hit(packet)
		hit_landed.emit(area.owner_actor if area is HurtboxComponent else area,damage)
		_play_impact()
		queue_free()


func _on_body_entered(_body: Node2D) -> void:
	_play_impact()  # 撞墙消散
	queue_free()


## 命中冲击（纯视觉，无判定窗；法术/物理选 FX-B01 对应冲击特效）。
func _play_impact() -> void:
	AttackEffect.play_impact(get_tree().current_scene, global_position,
			packet != null and packet.type == DamagePacket.DamageType.MAGIC)


func _draw() -> void:
	if is_instance_valid(_weapon_visual):
		return
	draw_circle(Vector2.ZERO, RADIUS + 2.0, Color(0.55, 0.75, 1.0, 0.25))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.7, 0.85, 1.0, 0.95))
	draw_circle(-dir * 3.0, RADIUS * 0.6, Color(0.7, 0.85, 1.0, 0.4))
