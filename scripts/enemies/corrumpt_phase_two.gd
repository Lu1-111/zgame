class_name CorrumptPhaseTwo
extends RefCounted
## 二阶段模式、招式与自由飞行；所有距离、速度、时序来自JSON。
var boss: Node2D
var config: Dictionary
var mode: StringName = &"roam"
var skill: StringName = &""
var stage: StringName = &"idle"
var elapsed := 0.0
var entry_left := 0.0
var wait_left := 0.0
var mode_casts := 0
var switch_left := -1.0
var cycles_left := 0
var dash_direction := Vector2.RIGHT
var dash_left := 0.0
var destination := Vector2.ZERO
var away := 1.0
var recovery_side := 1
var _hit := false
var airflow: AnimatedSprite2D
var warning: DangerWarning
var rounds_fired := 0
var _route: Array[Vector2] = []
var history: Array[StringName] = []

## 接入同一Boss实体与已统一的二阶段素材，基础属性在阶段切换时解析。
func configure(actor: Node2D, value: Dictionary) -> void:
	boss = actor
	config = value
	entry_left = float(config.entry_seconds)
	wait_left = _interval()
	airflow = AnimatedSprite2D.new()
	airflow.sprite_frames = boss.visual.sprite_frames
	airflow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	airflow.z_index = -1
	airflow.play(&"airflow")
	airflow.hide()
	boss.add_child(airflow)
	warning = DangerWarning.new()
	boss.add_child(warning)

## 推进状态；移动忽略墙体/平台，始终限制在地图边界内。
func tick(delta: float) -> void:
	if not is_instance_valid(boss.target) or not bool(boss.context().get("alive",false)):
		warning.clear()
		return
	if entry_left > 0:
		entry_left = maxf(0,entry_left-delta)
		_move_to(boss.target.global_position+Vector2(config.roam_offset[0],-float(config.entry_lift)),_player_speed()*float(config.roam_speed_multiplier)*delta)
		return
	if stage in [&"land",&"ground_stagger"]:
		_tick_ground_recovery(delta)
		return
	if skill != &"":
		elapsed += delta
		_tick_skill(delta)
		return
	boss.brain.state = &"ready"
	_idle_move(delta)
	if switch_left >= 0:
		switch_left -= delta
		if switch_left <= 0:
			set_mode(&"close")
		return
	wait_left -= delta
	if wait_left <= 0:
		if mode == &"roam":
			start_skill(_pick_remote())
		else:
			start_skill(StringName(config.close_sequence[mode_casts]))

## 巡空三次施法后等待4秒；近身进入即旋刃，后续严格遵循2/2/2/1。
func set_mode(value: StringName) -> void:
	if stage in [&"land",&"ground_stagger"]:
		stage = &"idle"
		elapsed = 0
	mode = value
	mode_casts = 0
	switch_left = -1
	wait_left = _interval()
	if mode == &"close":
		start_skill(StringName(config.close_sequence[0]))

## 演练入口与AI共用同一招式状态机。
func start_skill(value: StringName) -> void:
	if skill != &"" or value not in [&"blade",&"impact",&"needles",&"spores"]:
		return
	skill = value
	history.append(value)
	boss.brain.state = &"casting"
	# 每招只在起手前进行一次快速调位；招式期间不再追随目标位置。
	var point := _roam_point() if mode == &"roam" else _side_point(float(config.close_distance))
	if value == &"blade":
		var offset: Array = config.moves.blade.initial_offset
		point = _clamp(boss.target.global_position+Vector2(offset[0],offset[1]))
	_plan_route(point)
	_set_stage(&"reposition")

func _begin_action() -> void:
	var value := skill
	if value == &"blade":
		cycles_left = boss.brain.rng.randi_range(int(config.moves.blade.cycles_min),int(config.moves.blade.cycles_max))
		_set_stage(&"extend")
	elif value == &"impact":
		_set_stage(&"align")
	else:
		rounds_fired = 0
		_set_stage(&"projectile_windup")

func _set_stage(value: StringName) -> void:
	if boss.hp <= 0:
		return
	stage = value
	elapsed = 0
	warning.clear()
	var moving := value == &"dash"
	# 冲击自起手至换边收招全程可穿玩家；预调位也不把玩家推走。
	boss.collision_layer = 0 if moving or skill == &"impact" or value == &"reposition" else 4
	airflow.visible = moving
	if moving:
		_hit = false
		airflow.rotation = dash_direction.angle()
		airflow.position = -dash_direction*float(boss.profile.art.phase2.airflow_offset)

func _tick_skill(delta: float) -> void:
	if stage == &"reposition":
		boss.visual.flower_pose(&"phase_2_idle")
		if _move_route(_player_speed()*float(config.reposition_speed_multiplier)*delta):
			_begin_action()
		return
	if skill in [&"needles",&"spores"]:
		var cfg: Dictionary = boss.profile.combat.moves[String(skill)].duplicate(true)
		cfg.merge(config.moves[String(skill)],true)
		boss.visual.flower_pose(&"phase_2_idle")
		if stage == &"projectile_windup":
			var next_round := float(cfg.windup_seconds)+rounds_fired*float(cfg.round_interval)
			while rounds_fired < int(cfg.rounds) and (elapsed >= next_round or is_equal_approx(elapsed,next_round)):
				boss._release(skill,cfg)
				rounds_fired += 1
				next_round = float(cfg.windup_seconds)+rounds_fired*float(cfg.round_interval)
			if rounds_fired == int(cfg.rounds):
				_set_stage(&"projectile_recover")
		elif stage == &"projectile_recover" and elapsed >= float(cfg.recovery_seconds):
			_finish()
		return
	var cfg: Dictionary = config.moves[String(skill)]
	if skill == &"blade":
		match stage:
			&"extend":
				boss.visual.flower_pose(&"phase_2_extend",elapsed/float(cfg.extend_seconds))
				if elapsed >= float(cfg.extend_seconds): _set_stage(&"spin_start")
			&"spin_start":
				boss.visual.flower_pose(&"phase_2_spin_start",elapsed/float(cfg.spin_start_seconds))
				if elapsed >= float(cfg.spin_start_seconds): _set_stage(&"approach")
			&"approach":
				boss.visual.flower_pose(&"phase_2_spin")
				if _move_to(destination,_skill_speed(float(cfg.approach_speed))*delta): _set_stage(&"hover")
			&"hover":
				boss.visual.flower_pose(&"phase_2_spin")
				_warn_before(float(cfg.hover_seconds))
				if elapsed >= float(cfg.hover_seconds):
					dash_direction = (boss.target.global_position-boss.global_position).normalized()
					dash_left = float(cfg.dash_distance)
					_set_stage(&"dash")
			&"dash":
				boss.visual.flower_pose(&"phase_2_spin")
				if _dash(delta,cfg,float(config.blade_radius)):
					cycles_left -= 1
					_set_stage(&"hover" if cycles_left > 0 else &"spin_stop")
			&"spin_stop":
				boss.visual.flower_pose(&"phase_2_spin_stop",elapsed/float(cfg.spin_stop_seconds))
				if elapsed >= float(cfg.spin_stop_seconds): _set_stage(&"retract")
			&"retract":
				boss.visual.flower_pose(&"phase_2_retract",elapsed/float(cfg.retract_seconds))
				if elapsed >= float(cfg.retract_seconds): _finish()
	else:
		boss.visual.flower_pose(&"phase_2_idle")
		match stage:
			&"align":
				if _move_to(Vector2(boss.global_position.x,destination.y),_skill_speed(float(cfg.align_speed))*delta):
					away = signf(boss.global_position.x-boss.target.global_position.x)
					if is_zero_approx(away): away = 1
					destination = _clamp(boss.global_position+Vector2(away*float(cfg.charge_distance),0))
					_set_stage(&"charge")
			&"charge":
				if _move_to(destination,_skill_speed(float(cfg.charge_speed))*delta): _set_stage(&"hold")
			&"hold":
				_warn_before(float(cfg.hold_seconds))
				if elapsed >= float(cfg.hold_seconds):
					var toward := signf(boss.target.global_position.x-boss.global_position.x)
					dash_direction = Vector2(-away if is_zero_approx(toward) else toward,0)
					dash_left = float(cfg.dash_distance)
					_set_stage(&"dash")
			&"dash":
				if _dash(delta,cfg,float(config.body_radius)):
					recovery_side = -1 if boss.brain.rng.randi_range(0,1) == 0 else 1
					_plan_route(_side_point(float(cfg.recover_side_distance),recovery_side))
					_set_stage(&"recover_side")
			&"recover_side":
				# 玩家主动走到落点时重新选择其同侧安全点；不在其他施法阶段追踪移动。
				if destination.distance_to(boss.target.global_position) < _clearance():
					_plan_route(_side_point(float(cfg.recover_side_distance),recovery_side))
				if _move_route(_skill_speed(float(cfg.recover_speed))*delta): _finish()

func _dash(delta: float, cfg: Dictionary, radius: float) -> bool:
	var before := boss.global_position
	var step := minf(dash_left,_skill_speed(float(cfg.dash_speed))*delta)
	var after := _clamp(before+dash_direction*step)
	boss.global_position = after
	_contact(before,after,radius,cfg)
	var travelled := before.distance_to(after)
	dash_left = maxf(0,dash_left-travelled)
	return dash_left <= float(config.motion_epsilon) or travelled+float(config.motion_epsilon) < step

func _contact(before: Vector2, after: Vector2, radius: float, cfg: Dictionary) -> void:
	if _hit:
		return
	var shape := CapsuleShape2D.new()
	shape.radius = radius
	shape.height = before.distance_to(after)+radius*2
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(dash_direction.angle()-PI/2,(before+after)/2)
	query.collision_mask = 32
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit: Dictionary in boss.get_world_2d().direct_space_state.intersect_shape(query):
		if hit.collider is HurtboxComponent and hit.collider.owner_actor == boss.target:
			_hit = true
			var damage_type := DamagePacket.DamageType.MAGIC if str(cfg.damage_type) == "magic" else DamagePacket.DamageType.PHYSICAL
			var packet := DamagePacket.new(roundi(float(boss.definition.damage)*float(cfg.damage_multiplier)),damage_type,float(cfg.knockback),boss.target.global_position-dash_direction*radius,&"corrumpt")
			packet.origin_actor = boss
			if boss.target.has_method("apply_boss_charge"):
				boss.target.apply_boss_charge(packet,float(cfg.knockback_seconds),float(cfg.stun_seconds))
			else:
				boss.target.apply_hit(packet)
			return

func _finish() -> void:
	if boss.hp <= 0:
		return
	skill = &""
	stage = &"idle"
	airflow.hide()
	warning.clear()
	boss.collision_layer = 4
	boss.brain.state = &"ready"
	boss.visual.show_idle()
	mode_casts += 1
	if mode == &"roam" and mode_casts >= 3:
		switch_left = float(config.roam_after_third_wait)
	elif mode == &"close" and mode_casts >= config.close_sequence.size():
		set_mode(&"roam")
	elif mode == &"close":
		_begin_ground_recovery()
	else:
		wait_left = _interval()

func _begin_ground_recovery() -> void:
	var query := PhysicsRayQueryParameters2D.create(boss.global_position,Vector2(boss.global_position.x,boss.arena_bounds.end.y),int(config.ground_recovery.ground_mask))
	var ground := boss.get_world_2d().direct_space_state.intersect_ray(query)
	var floor_y: float = ground.position.y if not ground.is_empty() else boss.arena_bounds.end.y
	# 固定闲置母版的下缘落点，避免碰撞圆比花瓣略大而产生悬空间隙。
	destination = _clamp(Vector2(boss.global_position.x,floor_y-float(config.ground_recovery.grounded_bottom)))
	_set_stage(&"land")
	boss.brain.state = &"cooldown"
	boss.collision_layer = 0

func _tick_ground_recovery(delta: float) -> void:
	if stage == &"land":
		boss.visual.flower_pose(&"phase_2_idle")
		if _move_to(destination,float(config.ground_recovery.landing_speed)*delta):
			_set_stage(&"ground_stagger")
			boss.visual.flower_pose(&"phase_2_idle",float(config.ground_recovery.grounded_frame)/boss.visual.sprite_frames.get_frame_count(&"phase_2_idle"))
			boss.visual.freeze()
		return
	elapsed += delta
	boss.visual.freeze()
	if elapsed >= float(config.ground_recovery.stagger_seconds):
		stage = &"idle"
		start_skill(StringName(config.close_sequence[mode_casts]))

## 只有落地后的四秒硬直窗口提高削韧；降落、施法与真正破韧态不放大。
func poise_damage_multiplier() -> float:
	return float(config.ground_recovery.poise_damage_multiplier) if mode == &"close" and stage == &"ground_stagger" and boss.brain.state == &"cooldown" else 1.0

## 瘫痪恢复后按当前模式的下一招立即起手，不再额外叠加待机时长。
func resume_after_paralysis() -> void:
	if stage in [&"land",&"ground_stagger"]:
		stage = &"idle"
	wait_left = 0
	if switch_left >= 0:
		switch_left = 0
	tick(0)

func _idle_move(delta: float) -> void:
	if mode == &"roam":
		_move_to(_roam_point(),_player_speed()*float(config.roam_speed_multiplier)*delta)

func _roam_point() -> Vector2:
	var player: Vector2 = boss.target.global_position
	var side := -1 if boss.global_position.x < player.x else 1
	var offset := Vector2(config.roam_offset[0],config.roam_offset[1])
	var candidates := [_clamp(player+Vector2(side*offset.x,offset.y)),_clamp(player+Vector2(-side*offset.x,offset.y)),_clamp(player+Vector2(side*offset.x,-offset.y)),_clamp(player+Vector2(-side*offset.x,-offset.y)),_clamp(player+Vector2(0,-absf(offset.x))),_clamp(player+Vector2(0,absf(offset.x)))]
	for candidate: Vector2 in candidates:
		if absf(candidate.y-player.y) < float(config.min_roam_height_gap) or candidate.distance_to(player) < float(config.min_roam_distance):
			continue
		var q := PhysicsShapeQueryParameters2D.new()
		var circle := CircleShape2D.new()
		circle.radius = float(config.body_radius)
		q.shape = circle
		q.transform = Transform2D(0,candidate)
		q.collision_mask = int(config.avoid_wall_mask)
		if boss.get_world_2d().direct_space_state.intersect_shape(q).is_empty():
			return candidate
	return candidates[0]

func _interval() -> float:
	return float(config.roam_skill_interval if mode == &"roam" else config.skill_interval)

func _player_speed() -> float:
	return float(boss.target.movement_speed()) if boss.target.has_method("movement_speed") else float(config.player_speed_fallback)

func _skill_speed(base: float) -> float:
	return base*float(config.close_skill_speed_multiplier) if mode == &"close" else base

func _warn_before(duration: float) -> void:
	var seconds := float(DamageFeedback.config().danger_warning.seconds)
	warning.seek_warning((elapsed-(duration-seconds))/seconds)

func _clearance() -> float:
	return float(config.body_radius)+float(config.route_player_radius)+float(config.route_clearance)

func _side_point(distance: float, side: int = 0) -> Vector2:
	if side == 0:
		side = -1 if boss.global_position.x < boss.target.global_position.x else 1
	var center: Vector2 = boss.target.global_position
	var point := _clamp(center+Vector2(side*distance,0))
	if point.distance_to(center) < _clearance():
		point = _clamp(center-Vector2(side*distance,0))
	return point

func _plan_route(point: Vector2) -> void:
	destination = _clamp(point)
	_route.clear()
	var center: Vector2 = boss.target.global_position
	var before: Vector2 = boss.global_position
	var closest := Geometry2D.get_closest_point_to_segment(center,before,destination)
	if closest.distance_to(center) < _clearance():
		# 选择边界内较短的上下绕行折线，避免换边时穿过玩家的身体。
		var detour := _clearance()+float(config.route_margin)
		var upper := _clamp(center+Vector2.UP*detour).y
		var lower := _clamp(center+Vector2.DOWN*detour).y
		var y := upper
		if center.y-upper < _clearance() or (lower-center.y >= _clearance() and absf(before.y-lower)+absf(destination.y-lower) < absf(before.y-upper)+absf(destination.y-upper)):
			y = lower
		_route.append(Vector2(before.x,y))
		_route.append(Vector2(destination.x,y))
	_route.append(destination)

func _move_route(distance: float) -> bool:
	while not _route.is_empty():
		var cost := boss.global_position.distance_to(_route[0])
		if not _move_to(_route[0],distance):
			return false
		distance = maxf(0,distance-cost)
		_route.pop_front()
	return true

func _move_to(point: Vector2, distance: float) -> bool:
	var target := _clamp(point)
	boss.global_position = boss.global_position.move_toward(target,distance)
	return boss.global_position.is_equal_approx(target)

func _clamp(point: Vector2) -> Vector2:
	var bounds: Rect2 = boss.arena_bounds.grow(-float(config.boundary_margin))
	return point.clamp(bounds.position,bounds.end)

func _pick_remote() -> StringName:
	var value: float = boss.brain.rng.randf()*float(config.roam_weights.needles+config.roam_weights.spores)
	return &"needles" if value < float(config.roam_weights.needles) else &"spores"
