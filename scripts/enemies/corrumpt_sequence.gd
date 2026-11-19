class_name CorrumptSequence
extends Node2D
## 统一推进转阶段CG与可操作的最终招式；所有演出时长、强度来自JSON。
var boss: Node2D
var active := false
var mode: StringName = &""
var stage: StringName = &""
var elapsed := 0.0
var radius := 0.0
var gravity_pulses := 0
var _initial := Vector2.ZERO
var _phase_changed := false
var _failed := false
var _pull_left := 0.0
var _pulse_left := 0.0
var _camera: Camera2D
var _previous_focus: Node2D
var _focus: Node2D
var _layer: CanvasLayer
var _top: ColorRect
var _bottom: ColorRect
var _flash: ColorRect
var _opening: AnimatedSprite2D
var _core: AnimatedSprite2D
var _wilt: Array[Sprite2D] = []

## 载入与正式Boss同源的逐帧演出素材，创建覆盖整个HUD的紫光层。
func configure(actor: Node2D) -> void:
	boss = actor
	var frames := load(str(boss.profile.sequence.root)+"CorrumptSequence_frames.tres") as SpriteFrames
	_opening = AnimatedSprite2D.new()
	_opening.sprite_frames = frames
	_opening.centered = false
	_opening.offset = -Vector2(boss.profile.sequence.opening_anchor[0],boss.profile.sequence.opening_anchor[1])
	_opening.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_opening.hide()
	add_child(_opening)
	_core = AnimatedSprite2D.new()
	_core.sprite_frames = frames
	_core.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_core.z_index = 2
	_core.play(&"void")
	_core.hide()
	add_child(_core)
	_focus = Node2D.new()
	add_child(_focus)
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	for index in 3:
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.color = Color.BLACK if index < 2 else Color(str(boss.profile.sequence.flash_color))
		_layer.add_child(rect)
		if index == 0:_top = rect
		elif index == 1:_bottom = rect
		else:_flash = rect
	_layer.hide()
	boss.get_tree().root.get_node("EventBus").player_died.connect(_on_player_died)

## 一阶段归零后关闭战斗判定，先绽开、枯萎、上升，再在不透光紫光内换阶段。
func start_transition() -> void:
	active = true
	mode = &"transition"
	_initial = boss.global_position
	boss.brain.state = &"transition"
	boss.clear_combat_entities()
	boss.collision_layer = 0
	for arm in [boss.visual.left_arm,boss.visual.right_arm]:
		var piece := Sprite2D.new()
		piece.texture = arm.sprite_frames.get_frame_texture(arm.animation,arm.frame)
		piece.position = arm.position
		piece.offset = arm.offset
		piece.centered = arm.centered
		piece.flip_h = arm.flip_h
		piece.scale = arm.scale
		piece.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(piece)
		_wilt.append(piece)
	boss.visual.hide()
	_opening.animation = &"opening"
	_opening.frame = 0
	_opening.pause()
	_opening.show()
	_set_stage(&"opening")
	_set_player_lock(true)
	_acquire_camera()
	_layer.show()
	_layout()

## 二阶段归零时启动最后招式，玩家仍可自由操作，胜利延迟至紫光散去后。
func start_defeat() -> void:
	active = true
	mode = &"defeat"
	_failed = false
	_initial = boss.global_position
	boss.brain.state = &"annihilation"
	boss.clear_combat_entities()
	boss.collision_layer = 0
	boss.hurtbox.set_deferred("monitorable",false)
	boss.phase_two.airflow.hide()
	boss.phase_two.warning.clear()
	_acquire_camera()
	_layer.show()
	_set_stage(&"center")
	_layout()

## 演出由Boss物理帧显式驱动，测试与运行共用同一时序。
func tick(delta: float) -> void:
	if not active:return
	if mode == &"failed":
		if bool(boss.context().get("alive",false)):
			active = false
			boss.restart_encounter()
		return
	elapsed += delta
	_layout()
	if mode == &"transition":_tick_transition()
	else:_tick_defeat(delta)
	if is_instance_valid(boss.target):
		var body_center: Vector2 = boss.global_position if boss.phase_index == 2 else boss.global_position+Vector2(0,-float(boss.profile.sequence.opening_anchor[1]-boss.profile.sequence.flower_center[1]))
		_focus.global_position = body_center if mode == &"transition" else (body_center+boss.target.global_position)/2

func _tick_transition() -> void:
	var cfg: Dictionary = boss.profile.sequence.transition
	match stage:
		&"opening":
			var progress := clampf(elapsed/float(cfg.opening_seconds),0,1)
			_opening.animation = &"opening"
			_opening.pause()
			_opening.frame = mini(int(progress*_opening.sprite_frames.get_frame_count(&"opening")),_opening.sprite_frames.get_frame_count(&"opening")-1)
			for piece in _wilt:
				piece.modulate = Color.WHITE.lerp(Color(str(boss.profile.sequence.wilt_color)),progress)
				piece.modulate.a = 1-progress
			if elapsed >= float(cfg.opening_seconds):_set_stage(&"rise")
		&"rise":
			boss.global_position = _initial+Vector2.UP*float(cfg.rise_distance)*clampf(elapsed/float(cfg.rise_seconds),0,1)
			if elapsed >= float(cfg.rise_seconds):_set_stage(&"hover")
		&"hover":
			if elapsed >= float(cfg.hover_seconds):_set_stage(&"flash_in")
		&"flash_in":
			_flash.modulate.a = clampf(elapsed/float(cfg.flash_in_seconds),0,1)
			if elapsed >= float(cfg.flash_in_seconds):
				_flash.modulate.a = 1
				_set_stage(&"opaque")
		&"opaque":
			_flash.modulate.a = 1
			if not _phase_changed:
				_phase_changed = true
				var center: Vector2 = boss.global_position+Vector2(0,-float(boss.profile.sequence.opening_anchor[1]-boss.profile.sequence.flower_center[1]))
				boss.begin_phase_two(false)
				boss.global_position = center
				boss.collision_layer = 0
				boss.visual.show()
				_opening.hide()
			if elapsed >= float(cfg.flash_hold_seconds):_set_stage(&"flash_out")
		&"flash_out":
			_flash.modulate.a = 1-clampf(elapsed/float(cfg.flash_out_seconds),0,1)
			if elapsed >= float(cfg.flash_out_seconds):
				active = false
				boss.phase_two.entry_left = 0
				boss.brain.state = &"ready"
				boss.collision_layer = 4
				_restore()

func _tick_defeat(delta: float) -> void:
	var cfg: Dictionary = boss.profile.sequence.defeat
	if not bool(boss.context().get("alive",false)):_failed = true
	match stage:
		&"center":
			boss.global_position = _initial.lerp(boss.arena_bounds.get_center(),clampf(elapsed/float(cfg.center_seconds),0,1))
			boss.visual.flower_pose(&"phase_2_idle")
			if elapsed >= float(cfg.center_seconds):
				_set_stage(&"grow")
				_core.show()
		&"grow":
			var progress := clampf(elapsed/float(cfg.grow_seconds),0,1)
			var base := float(boss.profile.art.phase2.core_radius)
			radius = lerpf(base,base*float(cfg.radius_multiplier),progress)
			_core.scale = Vector2.ONE*radius/float(boss.profile.sequence.void_source_radius)
			var shake := Vector2(sin(elapsed*TAU*float(cfg.shake_frequency)),cos(elapsed*TAU*float(cfg.shake_frequency)))*float(cfg.shake_amplitude)
			boss.visual.position = shake
			_core.position = shake
			_pulse_left -= delta
			if _pulse_left <= 0:
				_emit_gravity()
				_pulse_left += float(cfg.gravity_interval)
				_pull_left = float(cfg.pull_seconds)
			if _pull_left > 0 and is_instance_valid(boss.target) and boss.target.has_method("apply_void_pull"):
				boss.target.apply_void_pull(boss.global_position,float(cfg.pull_speed),minf(delta,_pull_left))
			_pull_left = maxf(0,_pull_left-delta)
			_void_contact(int(cfg.damage_per_frame))
			if elapsed >= float(cfg.grow_seconds):
				boss.clear_combat_entities()
				_pull_left = 0
				_set_stage(&"flash_in")
		&"flash_in":
			_flash.modulate.a = clampf(elapsed/float(cfg.flash_in_seconds),0,1)
			if elapsed >= float(cfg.flash_in_seconds):_set_stage(&"opaque")
		&"opaque":
			_flash.modulate.a = 1
			boss.visual.hide()
			_core.hide()
			if elapsed >= float(cfg.flash_hold_seconds):_set_stage(&"flash_out")
		&"flash_out":
			_flash.modulate.a = 1-clampf(elapsed/float(cfg.flash_out_seconds),0,1)
			if elapsed >= float(cfg.flash_out_seconds):
				_restore()
				var won := not _failed and bool(boss.context().get("alive",false))
				boss.complete_void_defeat(won)
				active = not won
				mode = &"failed" if not won else &""

func _emit_gravity() -> void:
	var cfg: Dictionary = boss.profile.combat.moves.gravity.duplicate(true)
	cfg.cinematic_visual = true
	cfg.active_seconds = boss.profile.sequence.defeat.gravity_seconds
	var ring: CorrumptEntity = boss._entity(&"gravity_ring",cfg,boss.global_position,float(cfg.active_seconds))
	ring.ring_max = boss._offscreen_radius(boss.global_position)*float(cfg.ring_extent_ratio)
	boss.add_sibling(ring)
	gravity_pulses += 1

func _void_contact(damage: int) -> void:
	if not is_instance_valid(boss.target):return
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	query.shape = shape
	query.transform = Transform2D(0,boss.global_position+_core.position)
	query.collision_mask = 32
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit: Dictionary in boss.get_world_2d().direct_space_state.intersect_shape(query):
		if hit.collider is HurtboxComponent and hit.collider.owner_actor == boss.target:
			if boss.target.has_method("apply_void_contact_damage"):boss.target.apply_void_contact_damage(damage)
			else:boss.target.apply_hit(DamagePacket.new(damage))
			return

func _set_stage(value: StringName) -> void:
	stage = value
	elapsed = 0

func _layout() -> void:
	var size := get_viewport_rect().size
	var bars := size.y*float(boss.profile.sequence.letterbox_fraction) if mode == &"transition" else 0.0
	_top.size = Vector2(size.x,bars)
	_bottom.size = Vector2(size.x,bars)
	_bottom.position = Vector2(0,size.y-bars)
	_flash.size = size
	if stage not in [&"flash_in",&"opaque",&"flash_out"]:_flash.modulate.a = 0

func _set_player_lock(value: bool) -> void:
	var ui := boss.get_tree().root.get_node_or_null("GameUI")
	if ui != null:
		if value:ui._force_close()
		ui.cinematic_active = value
	if is_instance_valid(boss.health_layer):boss.health_layer.visible = not value
	if is_instance_valid(boss.target) and boss.target.has_method("set_cinematic_lock"):
		boss.target.set_cinematic_lock(value)

func _acquire_camera() -> void:
	if is_instance_valid(boss.target) and boss.target.has_method("set_cinematic_lock"):
		_camera = boss.target.cam
		_previous_focus = _camera.focus_target
		_focus.global_position = boss.global_position
		_camera.set_focus_target(_focus)

func _restore() -> void:
	_set_player_lock(false)
	if is_instance_valid(_camera):_camera.set_focus_target(_previous_focus if is_instance_valid(_previous_focus) else null)
	if is_instance_valid(_layer):_layer.hide()
	for piece in _wilt:piece.hide()
	if is_instance_valid(boss.visual):boss.visual.position = Vector2.ZERO

func _on_player_died() -> void:
	if active and mode == &"defeat":_failed = true

func _exit_tree() -> void:
	if is_instance_valid(boss) and boss.is_inside_tree():_restore()
