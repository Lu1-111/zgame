extends SceneTree
## 用真实玩家发招与真实 Hurtbox 查询验证边缘、空白区、镜像及单次命中。
var _passed := 0
var _failed := 0
var _room: Node2D

class Probe extends Node2D:
	var hits := 0
	## 记录真实受击次数，不把目标击杀以便验证重复扫描。
	func receive(packet: DamagePacket) -> int:
		hits += 1
		return packet.amount


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(30,true,false,true).timeout.connect(func() -> void: quit(2))
	_room = Node2D.new()
	root.add_child(_room)
	current_scene = _room
	var state := root.get_node("GameState")
	var cfg := SwordAttackEffect.configuration()
	var manifest := SwordAttackEffect.frame_manifest()
	var module := WeaponRuntime.module("sword")
	var duration := float(module.startup)+float(module.active)+float(module.recovery)
	for facing in [1,-1]:
		for combo in range(1,4):
			state.reset()
			state.weapon_id = &"sword_01"
			var actor: Node = load("res://scenes/player/player.tscn").instantiate()
			actor.set_script(load("res://test/fixtures/aimed_player.gd"))
			actor.aim_point = Vector2(facing*1000,0)
			_room.add_child(actor)
			await _frames(3)
			actor.set_physics_process(false)
			actor.sm.to(&"Attack",{"combo":combo})
			var index: int = [5,5,4][combo-1]
			var entries: Array = manifest.clips["sword_%d" % combo].frames
			actor._clock = actor._last_attack_time+(float(entries[index].progress)+float(entries[index+1].progress))*duration/2
			actor._sync_rig_pose()
			actor.spawn_melee_effect(combo)
			var effect: SwordAttackEffect
			for child in actor.get_children():
				if child is SwordAttackEffect:
					effect = child
			effect.sample_attack_progress((actor._clock-actor._last_attack_time)/duration)
			var edge := Vector2(-INF,0)
			for item: Dictionary in effect._frame.visuals:
				for point: Array in item.polygon:
					if float(point[0]) > edge.x:
						edge = Vector2(point[0],point[1])
			var near := _probe(effect.to_global(edge+Vector2(float(cfg.contact_padding)/2,0)),2)
			var far := _probe(effect.to_global(edge+Vector2(float(cfg.contact_padding)+4,0)),1)
			var empty := _empty_point(effect.get_contact_polygons())
			var hole := _probe(effect.to_global(empty),1)
			var own_hp := int(state.hp)
			actor.hurtbox.global_position = near.global_position
			await _frames(5)
			_expect(near.hits == 1,"第%d段/朝向%d：剑光外侧 1 像素能接触，多个受击框和连续扫描只结算一次" % [combo,facing])
			_expect(far.hits == 0,"第%d段/朝向%d：超出 2 像素容差不会受伤" % [combo,facing])
			_expect(hole.hits == 0,"第%d段/朝向%d：弧线或尖刺包围框中的空白处没有隐形伤害" % [combo,facing])
			_expect(int(state.hp) == own_hp and not actor.hitbox._active,"第%d段/朝向%d：不命中自己，旧矩形判定没有同时启用" % [combo,facing])
			actor.sm.to(&"Idle")
			await _frames(2)
			_expect(not is_instance_valid(effect),"第%d段/朝向%d：取消攻击立即关闭剑光与接触" % [combo,facing])
			actor.queue_free()
			near.queue_free()
			far.queue_free()
			hole.queue_free()
			await _frames(2)
	# 没有剑光的起手帧也应当只沿实际可见剑身接触。
	state.reset()
	state.weapon_id = &"sword_01"
	var blade_actor: Node = load("res://scenes/player/player.tscn").instantiate()
	blade_actor.set_script(load("res://test/fixtures/aimed_player.gd"))
	blade_actor.aim_point = Vector2(1000,0)
	_room.add_child(blade_actor)
	await _frames(3)
	blade_actor.set_physics_process(false)
	blade_actor.sm.to(&"Attack",{"combo":3})
	blade_actor._clock = blade_actor._last_attack_time+float(module.startup)+0.001
	blade_actor._sync_rig_pose()
	blade_actor.spawn_melee_effect(3)
	var blade_effect: SwordAttackEffect
	for child in blade_actor.get_children():
		if child is SwordAttackEffect:
			blade_effect = child
	blade_effect.sample_attack_progress((blade_actor._clock-blade_actor._last_attack_time)/duration)
	var center := Vector2.ZERO
	for point: Array in blade_effect._frame.blade:
		center += Vector2(point[0],point[1])
	center /= blade_effect._frame.blade.size()
	var blade_probe := _probe(blade_effect.to_global(center),1)
	await _frames(4)
	_expect(blade_effect._frame.visuals.is_empty() and blade_probe.hits == 1,"尚未出现剑光时，实际剑身仍能接触受击框")
	blade_actor._clock = blade_actor._last_attack_time+float(module.startup)+float(module.active)+0.001
	var late_probe := _probe(blade_probe.global_position,1)
	await _frames(3)
	_expect(not is_instance_valid(blade_effect) and late_probe.hits == 0,"有效段结束即关闭剑光和接触，收招中不会继续伤人")
	blade_actor.sm.to(&"Attack",{"combo":3})
	blade_actor._clock = blade_actor._last_attack_time+float(module.startup)
	blade_actor.spawn_melee_effect(3)
	var swapping: SwordAttackEffect
	for child in blade_actor.get_children():
		if child is SwordAttackEffect:
			swapping = child
	blade_actor.cancel_weapon_action()
	_expect(swapping.is_queued_for_deletion(),"装备交换取消攻击时，当帧清除剑光实体")
	blade_actor.sm.to(&"Idle")
	blade_actor.queue_free()
	blade_probe.queue_free()
	late_probe.queue_free()
	await _frames(2)
	Engine.time_scale = 1
	print("SWORD CONTACT PHYSICS: %d PASS, %d FAIL" % [_passed,_failed])
	quit(1 if _failed else 0)


func _probe(point: Vector2, areas: int) -> Probe:
	var probe := Probe.new()
	probe.position = point
	_room.add_child(probe)
	for index in areas:
		var hurt := HurtboxComponent.new()
		hurt.owner_actor = probe
		hurt.hit_callback = probe.receive
		hurt.collision_layer = 32
		hurt.collision_mask = 0
		hurt.monitoring = false
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 0.2
		collision.shape = shape
		hurt.add_child(collision)
		probe.add_child(hurt)
	return probe


func _empty_point(polygons: Array[PackedVector2Array]) -> Vector2:
	var bounds := Rect2(polygons[0][0],Vector2.ZERO)
	for polygon in polygons:
		for point in polygon:
			bounds = bounds.expand(point)
	for x in [0.5,0.35,0.65,0.2,0.8]:
		for y in [0.5,0.35,0.65,0.2,0.8]:
			var point := bounds.position+bounds.size*Vector2(x,y)
			var clear := true
			for polygon in polygons:
				if Geometry2D.is_point_in_polygon(point,polygon):
					clear = false
				for index in polygon.size():
					if point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[index],polygon[(index+1)%polygon.size()])) < 1:
						clear = false
			if clear:
				return point
	_expect(false,"接触轮廓应当保留弧线或尖刺周围的空白")
	return bounds.end+Vector2(10,10)


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _expect(condition: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL",label])
	if condition:
		_passed += 1
	else:
		_failed += 1
