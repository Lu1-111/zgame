class_name ProjectileBubble
extends Area2D
## 奶泡弹（skill_bubble，参考书 §3.6）：直线飞行，命中受击框结算后消散，撞墙消失。
## 命中减速 30% 的施加在敌侧 AI（M1 敌人实装时消费）。
## M1.5：方向 2D 化（随鼠标瞄准发射）；命中/撞墙时播 AttackEffect 命中冲击（纯视觉）。

signal hit_landed(target: Node, final_damage: int)
var visual_kind := ""
var projectile_kind := "" ## 枪械弹幕类别与基础碰撞路径分开。
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
var pierce := false
var shockwave_ratio := 0.0
var _spent := false


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
	if projectile_kind == "arrow":
		var spec: Dictionary = WeaponAttributes.config().rifle.projectile_visuals.arrow
		var bolt := Sprite2D.new()
		bolt.texture = load(str(spec.texture))
		bolt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bolt.centered = false
		bolt.offset = -Vector2(spec.anchor[0], spec.anchor[1])
		bolt.rotation = dir.angle()
		add_child(bolt)
	if visual_kind != "bullet":
		area_entered.connect(_on_area_entered)
		body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var end := global_position + dir * speed * delta
	if visual_kind == "bullet":
		_sweep_bullet(end)
	else:
		global_position = end
	_life -= delta
	queue_redraw()
	if _life <= 0.0:
		queue_free()

func _sweep_bullet(end: Vector2) -> void:
	var query := PhysicsRayQueryParameters2D.create(global_position, end, collision_mask)
	query.collide_with_areas = true
	query.hit_from_inside = true
	var excluded: Array[RID] = [get_rid()]
	var space := get_world_2d().direct_space_state
	while not _spent:
		query.exclude = excluded
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			global_position = end
			return
		global_position = hit.position
		if hit.collider is Area2D:
			_on_area_entered(hit.collider)
			excluded.append(hit.rid)
		else:
			_on_body_entered(hit.collider)

func _on_area_entered(area: Area2D) -> void:
	var actor: Node = area.owner_actor if area is HurtboxComponent and is_instance_valid(area.owner_actor) else area
	if _spent or packet == null or _hit.has(actor):
		return
	# 归属过滤：擦过发射者自己的受击框时不停留、不消耗
	if actor == source_actor:
		return
	if area.has_method("receive_hit"):
		_hit[actor] = true
		var damage: int = area.receive_hit(packet)
		hit_landed.emit(actor, damage)
		if shockwave_ratio > 0.0:
			_shockwave(actor)
			var arc := ElectromagneticArc.new()
			arc.radius = float(WeaponAttributes.config().rifle.shockwave_radius)
			get_tree().current_scene.add_child(arc)
			arc.global_position = global_position
		else:
			_play_impact()
		if not pierce:
			_spent = true
			queue_free()

func _shockwave(primary: Node) -> void:
	var rules: Dictionary = WeaponAttributes.config().rifle
	var circle := CircleShape2D.new()
	circle.radius = float(rules.shockwave_radius)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 32
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var space := get_world_2d().direct_space_state
	var hit_actors := {primary: true}
	var splash := packet.copy_for_target()
	splash.amount = roundi(packet.amount * shockwave_ratio)
	splash.normal_poise = float(rules.shockwave_poise)
	for hit in space.intersect_shape(query, int(rules.shockwave_max_contacts)):
		var area := hit.collider as HurtboxComponent
		if area == null:
			continue
		var actor := area.owner_actor if is_instance_valid(area.owner_actor) else area
		if actor == source_actor or hit_actors.has(actor):
			continue
		var sight := PhysicsRayQueryParameters2D.create(global_position, area.global_position, 1)
		if not space.intersect_ray(sight).is_empty():
			continue
		hit_actors[actor] = true
		area.receive_hit(splash)

func _on_body_entered(_body: Node2D) -> void:
	if _spent:
		return
	_spent = true
	_play_impact()  # 撞墙消散
	queue_free()


## 命中冲击（纯视觉，无判定窗；法术/物理选 FX-B01 对应冲击特效）。
func _play_impact() -> void:
	AttackEffect.play_impact(get_tree().current_scene, global_position,
			packet != null and packet.type == DamagePacket.DamageType.MAGIC)


func _draw() -> void:
	if projectile_kind == "arrow":
		return
	if visual_kind == "bullet":
		var core := Color("#d7cfb0")
		var trail := Color(0.9, 0.85, 0.7, 0.3)
		if projectile_kind == "electromagnetic":
			var spec: Dictionary = WeaponAttributes.config().rifle.projectile_visuals.electromagnetic
			core = Color(str(spec.bullet_color))
			trail = Color(str(spec.trail_color))
		draw_line(-dir*10,dir*2,core,2,false)
		draw_line(-dir*16,-dir*6,trail,1,false)
		return
	if is_instance_valid(_weapon_visual):
		return
	draw_circle(Vector2.ZERO, RADIUS + 2.0, Color(0.55, 0.75, 1.0, 0.25))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.7, 0.85, 1.0, 0.95))
	draw_circle(-dir * 3.0, RADIUS * 0.6, Color(0.7, 0.85, 1.0, 0.4))
