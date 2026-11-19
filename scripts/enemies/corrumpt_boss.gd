class_name CorrumptBoss
extends CharacterBody2D
## corrumpt 双阶段首领：定点花苞 → 自由飞行的刀瓣花体。
signal phase_one_defeated
signal poise_broken
signal poise_restored
signal battle_finished(victory: bool)
const PROFILE := "res://data/bosses/claffert.json"
var enemy_id: StringName = &"corrumpt"
var profile: Dictionary
var definition: Dictionary
var statuses: EnemyStatusEffects
var hp := 0:
	set(value):
		if value <= hp or statuses == null or not statuses.healing_blocked():
			hp = value
var poise := EnemyPoise.new()
var brain := CorrumptBrain.new()
var target: Node2D
var arena_bounds := Rect2()
var room_id: StringName = &"forest_02"
var spawn_region_id: StringName = &""
var visual: CorrumptArt
var hurtbox: HurtboxComponent
var facing := -1
var _released := false
var _flash_left := 0.0
var _repel_visual_left := 0.0
var _defeat_time := 0.0
var left_tendril: CorrumptTendrilHitbox
var right_tendril: CorrumptTendrilHitbox
var _attack_serial := 0
var _spikes_spawned := 0
var _spike_start := 0.0
var phase_index := 1
var phase_two: CorrumptPhaseTwo
var sequence: CorrumptSequence
var health_layer: CanvasLayer
var _spawn_position := Vector2.ZERO
var _victory_emitted := false
var spike_warning: DangerWarning

func _ready() -> void:
	_spawn_position = global_position
	profile = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
	var spawn_context := DataDB.enemy_spawn_context(self,room_id)
	room_id = spawn_context.room_id
	spawn_region_id = spawn_context.region_id
	definition = DataDB.get_boss_for_room(enemy_id,room_id,0,spawn_region_id)
	hp = int(definition.hp)
	poise.configure(float(definition.poise))
	brain.configure(profile.combat)
	brain.paralysis_seconds = EnemyStats.paralysis_seconds(definition)
	if arena_bounds.size == Vector2.ZERO:
		arena_bounds = Rect2(Vector2.ZERO,Vector2(profile.arena.size[0],profile.arena.size[1]))
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as Node2D
	add_to_group(&"enemies")
	add_to_group(&"bosses")
	z_index = 20
	collision_layer = 4
	collision_mask = 0
	var size: Array = profile.combat.body_size
	var offset: Array = profile.combat.body_offset
	statuses = EnemyStatusEffects.new()
	add_child(statuses)
	statuses.configure(Vector2(size[0], size[1]), Vector2(offset[0], offset[1]))
	_add_body_shape(self,Vector2(size[0],size[1]),Vector2(offset[0],offset[1]))
	hurtbox = HurtboxComponent.new()
	hurtbox.collision_layer = 32
	hurtbox.collision_mask = 0
	hurtbox.owner_actor = self
	hurtbox.hit_callback = receive_hit
	_add_body_shape(hurtbox,Vector2(size[0],size[1]),Vector2(offset[0],offset[1]))
	add_child(hurtbox)
	visual = CorrumptArt.new()
	visual.profile = profile
	add_child(visual)
	spike_warning = DangerWarning.new()
	spike_warning.position += Vector2(profile.combat.body_offset[0],profile.combat.body_offset[1])
	add_child(spike_warning)
	left_tendril = _make_tendril(visual.left_arm)
	right_tendril = _make_tendril(visual.right_arm)
	var layer := CanvasLayer.new()
	health_layer = layer
	layer.layer = 4
	add_child(layer)
	var bar := CorrumptHealthBar.new()
	bar.boss = self
	layer.add_child(bar)
	sequence = CorrumptSequence.new()
	add_child(sequence)
	sequence.configure(self)

func _make_tendril(arm: AnimatedSprite2D) -> CorrumptTendrilHitbox:
	var entity := CorrumptTendrilHitbox.new()
	entity.source = self
	entity.sprite = arm
	entity.config = profile.combat.moves.slam
	add_child(entity)
	return entity

func _add_body_shape(parent: Node, size_value: Vector2, offset: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size_value
	shape.shape = rectangle
	shape.position = offset
	parent.add_child(shape)

func _physics_process(delta: float) -> void:
	if sequence != null and sequence.active:
		sequence.tick(delta)
		return
	var action_speed := statuses.action_speed()
	visual.set_action_speed(action_speed)
	delta *= action_speed
	_flash_left = maxf(0,_flash_left-delta)
	_repel_visual_left = maxf(0,_repel_visual_left-delta)
	visual.modulate = Color(1.8,1.4,1.8) if _flash_left > 0 else Color.WHITE
	visual.position = poise.feedback_offset(delta)
	if brain.state == &"dead":
		_defeat_time += delta
		visual.modulate.a = maxf(0,1-_defeat_time/float(profile.combat.defeat_fade_seconds))
		return
	if phase_index == 2:
		if brain.state == &"paralyzed":
			brain.elapsed += delta
			visual.freeze()
			if brain.elapsed >= brain.paralysis_seconds:
				poise.recover()
				brain.state = &"ready"
				poise_restored.emit()
				phase_two.resume_after_paralysis()
			return
		phase_two.tick(delta)
		return
	for event: StringName in brain.tick(delta,context()):
		if event == &"recover_poise":
			poise.recover()
			poise_restored.emit()
		elif event == &"repel":
			_repel()
		else:
			_prepare_attack(event)
	if brain.state == &"casting":
		_tick_attack()
	elif brain.state == &"paralyzed":
		visual.freeze()
		visual.modulate *= Color(0.65,0.6,0.8)
	elif _repel_visual_left > 0:
		var progress := 1-_repel_visual_left/float(profile.combat.moves.repel.duration)
		visual.pose(&"repel",mini(3,int(progress*4)),facing)
	elif visual.action != &"phase_1_idle":
		visual.show_idle()
	_sync_tendrils()

## 选招上下文实时计算，孢子与飞针/引力共用范围外条件。
func context() -> Dictionary:
	var alive := is_instance_valid(target) and GameState.hp > 0
	var near := false
	var close := false
	if alive:
		var difference := target.global_position-global_position
		near = absf(difference.x) <= float(profile.combat.melee_range) and absf(difference.y) <= float(profile.combat.same_layer_tolerance)
		close = difference.length() <= float(profile.combat.close_range)
	return {"alive":alive,"near":near,"close":close,"spores":live_spores() > 0}

## 仅统计本首领仍然存活的独立孢子，不把其他战斗的孢子混入选招条件。
func live_spores() -> int:
	var count := 0
	for entity in get_tree().get_nodes_in_group(&"corrumpt_entities"):
		if entity is CorrumptEntity and not entity.is_queued_for_deletion() and entity.source == self and entity.kind == &"spore":
			count += 1
	return count

## 演练及复现入口：普通AI仍只通过候选权重选招。
func request_attack(move_name: StringName) -> void:
	if hp <= 0:
		return
	if phase_index == 2:
		phase_two.start_skill(move_name)
		return
	if hp <= 0 or not profile.combat.moves.has(String(move_name)) or move_name == &"repel":
		return
	_prepare_attack(brain.begin_attack(context(),move_name))

func _prepare_attack(move_name: StringName) -> void:
	spike_warning.clear()
	if move_name == &"spikes":spike_warning.seek_warning(0)
	_released = false
	_spikes_spawned = 0
	_spike_start = float(profile.combat.moves.spikes.first_distance)
	if is_instance_valid(target):_spike_start = minf(_spike_start,absf(target.global_position.x-global_position.x))
	_attack_serial += 1
	if is_instance_valid(target):
		facing = -1 if target.global_position.x < global_position.x else 1

func _tick_attack() -> void:
	var name_value := brain.move
	var cfg: Dictionary = profile.combat.moves[String(name_value)]
	var time := brain.elapsed
	var release := 0.0
	var finish := 0.0
	var pose_index := 0
	var pose_animation := name_value
	match name_value:
		&"slam":
			var swing_start := float(cfg.raise_seconds)+float(cfg.hold_seconds)
			release = swing_start+float(cfg.swing_seconds)
			finish = release+float(cfg.active_seconds)+float(cfg.recovery_seconds)
			if time < float(cfg.raise_seconds):
				var poses: Array = cfg.raise_frames
				pose_index = int(poses[mini(poses.size()-1,int(time/float(cfg.raise_seconds)*poses.size()))])
			elif time < swing_start:
				pose_index = int(cfg.hold_frame)
			elif time < release:
				pose_animation = StringName(cfg.swing_animation)
				var poses: Array = cfg.swing_frames
				pose_index = int(poses[mini(poses.size()-1,int((time-swing_start)/float(cfg.swing_seconds)*poses.size()))])
			elif time < release+float(cfg.active_seconds):
				pose_index = int(cfg.impact_frame)
			else:
				var poses: Array = cfg.recovery_frames
				pose_index = int(poses[mini(poses.size()-1,int((time-release-float(cfg.active_seconds))/float(cfg.recovery_seconds)*poses.size()))])
		&"spikes":
			var warning_seconds := float(DamageFeedback.config().danger_warning.seconds)
			spike_warning.seek_warning(time/warning_seconds)
			if time < warning_seconds:
				visual.show_idle()
				return
			var bury_time := time-warning_seconds
			release = spike_release_seconds()
			var wave_seconds := (int(cfg.count)-1)*float(cfg.spawn_interval)+float(cfg.active_seconds)
			finish = release+wave_seconds+float(cfg.recovery_seconds)
			pose_index = mini(3,int(bury_time/float(cfg.bury_seconds)*4)) if bury_time < float(cfg.bury_seconds) else 3
			if time > release+wave_seconds:
				pose_index = 4+mini(3,int((time-release-wave_seconds)/float(cfg.recovery_seconds)*4))
		_:
			release = float(cfg.windup_seconds)
			finish = release+float(cfg.get("active_seconds",0))+float(cfg.recovery_seconds)
			pose_index = mini(1,int(time/release*2)) if time < release else (2 if time < (release+finish)/2 else 3)
	visual.pose(pose_animation,pose_index,facing)
	if name_value == &"spikes" and time >= release:
		_tick_spikes(time-release,cfg)
	elif not _released and time >= release:
		_released = true
		_release(name_value,cfg)
	if time >= finish:
		var next := brain.finish_attack(context())
		if next != &"":
			_prepare_attack(next)
		else:
			visual.show_idle()
	_sync_tendrils()

## 地刺首道严格在红光消失1.5秒后生成，入地动作包含在这段等待中。
func spike_release_seconds() -> float:
	return float(DamageFeedback.config().danger_warning.seconds)+float(profile.combat.moves.spikes.delay_seconds)

func _sync_tendrils() -> void:
	var active := phase_index == 1 and brain.state == &"casting" and brain.move == &"slam" and bool(profile.combat.moves.slam.contact_damage)
	left_tendril.sync_pose(active and facing < 0,_attack_serial)
	right_tendril.sync_pose(active and facing > 0,_attack_serial)

func _tick_spikes(wave_age: float, cfg: Dictionary) -> void:
	while _spikes_spawned < int(cfg.count) and wave_age >= _spikes_spawned*float(cfg.spawn_interval):
		var late := wave_age-_spikes_spawned*float(cfg.spawn_interval)
		if late < float(cfg.active_seconds):
			_spawn_spike(_spikes_spawned,cfg,late)
		_spikes_spawned += 1

func _spawn_spike(index: int, cfg: Dictionary, elapsed_seconds: float) -> void:
	var point := global_position+Vector2(facing*(_spike_start+index*float(cfg.spacing)),0)
	var floor_hit := _ground(point,cfg)
	if floor_hit.is_empty():
		return
	var entity := _entity(&"spike",cfg,floor_hit.position,float(cfg.active_seconds))
	entity.hit_size = Vector2(float(cfg.width),float(cfg.height))
	entity.age = elapsed_seconds
	add_sibling(entity)

func _release(move_name: StringName, cfg: Dictionary) -> void:
	match move_name:
		&"slam":
			var offset: Array = cfg.hit_offset
			var size_value: Array = cfg.hit_size
			var entity := _entity(&"impact",cfg,global_position+Vector2(float(offset[0])*facing,float(offset[1])+float(size_value[1])/2),float(cfg.impact_seconds))
			entity.hit_size = Vector2(size_value[0],size_value[1])
			add_sibling(entity)
		&"spikes":
			_spawn_spike(0,cfg,0)
		&"needles":
			if not is_instance_valid(target):
				return
			var height := float(cfg.spawn_height) if phase_index == 1 else float(cfg.phase2_spawn_height)
			var center := global_position+Vector2.UP*height
			var aimed_angle := (target.global_position-center).angle()
			for index in int(cfg.count):
				var angle := aimed_angle+deg_to_rad(float(cfg.fan_step_degrees))*float(index-int(cfg.aimed_needle_index))
				var point := center+Vector2.from_angle(angle)*float(cfg.spawn_radius)
				var entity := _entity(&"needle",cfg,point,float(cfg.lifetime))
				entity.pattern_index = index
				entity.direction = Vector2.from_angle(angle)
				entity.radius = float(cfg.radius)
				add_sibling(entity)
		&"gravity":
			var center := global_position+Vector2.UP*float(profile.combat.body_size[1])/2
			var ring := _entity(&"gravity_ring",cfg,center,float(cfg.active_seconds))
			ring.ring_max = _offscreen_radius(center)*float(cfg.ring_extent_ratio)
			add_sibling(ring)
			if is_instance_valid(target):
				target.apply_boss_force(global_position,float(cfg.pull_speed),float(cfg.pull_seconds),float(cfg.stun_seconds),true,float(cfg.safe_radius))
		&"spores":
			var center := global_position+Vector2.UP*float(profile.combat.body_size[1])/2 if phase_index == 1 else global_position
			for index in int(cfg.count):
				var direction := Vector2.from_angle(brain.rng.randf_range(0,TAU))
				var point := center+direction*float(cfg.spawn_radius)
				point = point.clamp(arena_bounds.position,arena_bounds.end)
				var entity := _entity(&"spore",cfg,point,float(cfg.lifetime))
				entity.direction = direction
				entity.radius = float(cfg.radius)
				add_sibling(entity)

func _entity(kind_value: StringName, cfg: Dictionary, point: Vector2, seconds: float) -> CorrumptEntity:
	var entity := CorrumptEntity.new()
	entity.kind = kind_value
	entity.profile = profile
	entity.config = cfg
	entity.source = self
	entity.target = target
	entity.bounds = arena_bounds
	entity.position = get_parent().to_local(point)
	entity.lifetime = seconds
	entity.damage = roundi(float(definition.damage)*float(cfg.damage_multiplier))
	return entity

func _ground(point: Vector2, cfg: Dictionary) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(point+Vector2.UP*float(cfg.ground_probe_up),point+Vector2.DOWN*float(cfg.ground_probe_down),129)
	return get_world_2d().direct_space_state.intersect_ray(query)

func _offscreen_radius(center: Vector2) -> float:
	var transform := get_viewport().get_canvas_transform().affine_inverse()
	var rect := get_viewport_rect()
	var radius_value := 0.0
	for corner in [rect.position,Vector2(rect.end.x,0),rect.end,Vector2(0,rect.end.y)]:
		radius_value = maxf(radius_value,center.distance_to(transform*corner))
	return radius_value

func _repel() -> void:
	var cfg: Dictionary = profile.combat.moves.repel
	_repel_visual_left = float(cfg.duration)
	var entity := _entity(&"repel_ring",cfg,global_position,float(cfg.duration))
	entity.ring_max = float(cfg.radius)
	entity.radius = float(profile.combat.body_size[0])/2
	add_sibling(entity)
	if is_instance_valid(target):
		var outer := maxf(float(profile.combat.melee_range),float(profile.combat.moves.spikes.first_distance)+(int(profile.combat.moves.spikes.count)-1)*float(profile.combat.moves.spikes.spacing)+float(profile.combat.moves.spikes.width)/2)
		var speed := (outer+float(cfg.outside_range_margin)-absf(target.global_position.x-global_position.x))/float(cfg.push_seconds)
		target.apply_boss_force(Vector2(global_position.x,target.global_position.y),maxf(speed,float(cfg.push_speed)),float(cfg.push_seconds),float(cfg.stun_seconds),false)

## 与普通怪物共用百分比抗性；施法期不削韧，瘫痪期加伤且不能刷新时长。
func receive_hit(packet: DamagePacket) -> int:
	if hp <= 0 or packet == null:
		return 0
	if phase_index == 2 and phase_two.entry_left > 0:
		return 0
	var damage := EnemyStats.damage_taken(definition,packet,float(RPGService.config().base_attributes.defense_constant),InventoryService.talent_effect("defense_ignore_pct"))
	if brain.state == &"paralyzed":
		damage = roundi(float(damage)*float(profile.combat.paralysis_damage_multiplier))
	hp = maxi(0,hp-damage)
	_flash_left = float(profile.combat.flash_seconds)
	if damage > 0:
		var number := DamageNumber.new()
		number.amount = damage
		number.magic = packet.type == DamagePacket.DamageType.MAGIC
		add_sibling(number)
		number.global_position = global_position+Vector2.UP*float(profile.combat.body_size[1])
	if hp <= 0:
		_defeat()
	elif brain.state in [&"ready",&"cooldown"] and _repel_visual_left <= 0:
		var poise_multiplier := phase_two.poise_damage_multiplier() if phase_index == 2 else 1.0
		if poise.receive(packet, poise_multiplier * statuses.poise_multiplier()):
			brain.paralyze()
			poise_broken.emit()
	return damage

## 接收武器异常，入场与阶段演出使用首领自身免疫窗口。
func apply_status(id: String, duration: float, multiplier: float = 1.0) -> void:
	if hp > 0 and not sequence.active and (phase_index != 2 or phase_two.entry_left <= 0):
		statuses.apply(id, duration, multiplier)

## 异常伤害可结束当前阶段，并使用既定转场和最终演出。
func apply_status_damage(amount: int) -> void:
	if hp <= 0 or sequence.active:
		return
	hp = maxi(0, hp - amount)
	if hp == 0:
		_defeat()

func _defeat() -> void:
	statuses.clear()
	visual.set_action_speed(1.0)
	if phase_index == 1 and bool(profile.phase2_combat.enabled):
		sequence.start_transition()
		return
	sequence.start_defeat()

## 清理战斗弹幕和碰撞窗口；转场/最终招式仅保留新生成的演出特效。
func clear_combat_entities() -> void:
	spike_warning.clear()
	_sync_tendrils()
	for entity in get_tree().get_nodes_in_group(&"corrumpt_entities"):
		if entity is CorrumptEntity and entity.source == self:
			entity.set_physics_process(false)
			entity.hide()
			entity.queue_free()

## 紫光散去后才结算胜利；曾在虚空阶段死亡的玩家不提前获得击败进度。
func complete_void_defeat(victory: bool) -> void:
	brain.state = &"dead" if victory else &"failed"
	battle_finished.emit(victory)
	if not victory or _victory_emitted:return
	_victory_emitted = true
	health_layer.hide()
	EventBus.enemy_died.emit(enemy_id,global_position)
	EventBus.boss_defeated.emit(enemy_id)

## 最终招式导致玩家死亡时，待重生后重新创建首领，允许正常重试。
func restart_encounter() -> void:
	var fresh: Node2D = (load("res://scenes/enemies/corrumpt.tscn") as PackedScene).instantiate()
	fresh.position = get_parent().to_local(_spawn_position)
	fresh.target = target
	fresh.arena_bounds = arena_bounds
	fresh.room_id = room_id
	get_parent().add_child(fresh)
	if get_parent().get("boss") == self:get_parent().set("boss",fresh)
	if "--phase2" in OS.get_cmdline_user_args():fresh.begin_phase_two()
	queue_free()

## 正式流程只在不透明紫光内切换二阶段；演练可直接调用，不提前结算击败。
func begin_phase_two(lift: bool = true) -> void:
	if phase_index == 2:
		return
	spike_warning.clear()
	phase_index = 2
	brain.state = &"ready"
	brain.move = &""
	brain.elapsed = 0
	_sync_tendrils()
	for entity in get_tree().get_nodes_in_group(&"corrumpt_entities"):
		if entity is CorrumptEntity and entity.source == self:
			entity.set_physics_process(false)
			entity.queue_free()
	definition = DataDB.get_boss_for_room(enemy_id,room_id,1,spawn_region_id)
	statuses.clear()
	hp = int(definition.hp)
	poise.configure(float(definition.poise))
	brain.paralysis_seconds = EnemyStats.paralysis_seconds(definition)
	visual.enter_phase_two()
	statuses.configure(Vector2.ONE * float(profile.phase2_combat.body_radius) * 2.0, Vector2.ZERO)
	if lift:global_position += Vector2.UP*float(profile.phase2_combat.body_radius)
	for parent: Node in [self,hurtbox]:
		for child in parent.get_children():
			if child is CollisionShape2D:
				var circle := CircleShape2D.new()
				circle.radius = float(profile.phase2_combat.body_radius)
				child.shape = circle
				child.position = Vector2.ZERO
	phase_two = CorrumptPhaseTwo.new()
	phase_two.configure(self,profile.phase2_combat)
	phase_one_defeated.emit()
