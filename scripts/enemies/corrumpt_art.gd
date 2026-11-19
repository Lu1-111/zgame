class_name CorrumptArt
extends AnimatedSprite2D
var _action_rate := 1.0
var _body_rate := 1.0
## 共同花苞持续播放逐帧心跳，触手使用独立绘制帧；本体不随招式重绘、镜像或缩放。
var profile: Dictionary
var action: StringName = &"phase_1_idle"
var pose_frame := 0
var left_arm: AnimatedSprite2D
var right_arm: AnimatedSprite2D
var active_arm: AnimatedSprite2D
var phase_two := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = false
	sprite_frames = load(str(profile.art.root)+"godot/Corrumpt_combat_frames.tres") as SpriteFrames
	frame_changed.connect(_align_root)
	animation_changed.connect(_align_root)
	if profile.art.has("unified"):
		left_arm = _make_arm(-1)
		right_arm = _make_arm(1)
	show_idle()

func _make_arm(side: int) -> AnimatedSprite2D:
	var cfg: Dictionary = profile.art.unified
	var arm := AnimatedSprite2D.new()
	arm.sprite_frames = sprite_frames
	arm.centered = false
	arm.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arm.z_index = -1
	arm.position = Vector2(float(cfg.arm_attachment[0])*side,float(cfg.arm_attachment[1]))
	arm.offset = Vector2(-float(cfg.arm_anchor[0]),-float(cfg.arm_anchor[1]))
	arm.flip_h = side < 0
	if side < 0:
		arm.offset.x = float(cfg.arm_anchor[0])-float(cfg.arm_canvas[0])
	add_child(arm)
	arm.play(&"arm_idle")
	return arm

## 切回花苞原版八帧心跳待机。
func show_idle() -> void:
	if phase_two:
		flower_pose(&"phase_2_idle")
		return
	action = &"phase_1_idle"
	flip_h = false
	if animation != action or not is_playing():
		play(action)
	if profile.art.has("unified"):
		_body_rate = 1.0
		speed_scale = _action_rate
		for arm: AnimatedSprite2D in [left_arm,right_arm]:
			if arm.animation != &"arm_idle" or not arm.is_playing():
				arm.play(&"arm_idle")
	_align_root()

## 状态机显式选择绘制帧，预警时停留在对应姿态；所有动作使用同一像素画布和固定根。
func pose(move_name: StringName, index: int, direction: int) -> void:
	action = move_name
	pose_frame = clampi(index,0,sprite_frames.get_frame_count(move_name)-1)
	if profile.art.has("unified"):
		# 本体始终播放同一套待机帧，不翻转、不复位；只有触手选择左右完整逐帧动作。
		if not is_playing():
			play(&"phase_1_idle")
		flip_h = false
		_body_rate = float(profile.art.unified.cast_pulse_speed) if move_name in [&"needles",&"gravity",&"spores",&"repel"] else 1.0
		speed_scale = _body_rate * _action_rate
		var active := left_arm if direction < 0 else right_arm
		active_arm = active
		var other := right_arm if direction < 0 else left_arm
		if String(move_name) in profile.art.unified.two_arm_casts:
			other.animation = move_name
			other.pause()
			other.frame = pose_frame
		elif other.animation != &"arm_idle" or not other.is_playing():
			other.play(&"arm_idle")
		active.animation = move_name
		active.pause()
		active.frame = pose_frame
		_align_root()
		return
	animation = action
	pause()
	flip_h = direction < 0
	frame = clampi(index,0,sprite_frames.get_frame_count(action)-1)
	_align_root()

## 瘫痪/死亡冻结所有逐帧层，恢复时继续原本体帧，不切换另一套本体。
func freeze() -> void:
	pause()
	for arm in [left_arm,right_arm]:
		if is_instance_valid(arm):
			arm.pause()

## 二阶段沿用已标准化花心，隐藏根部触手；全部状态仍使用PNG逐帧。
func enter_phase_two() -> void:
	phase_two = true
	for arm in [left_arm,right_arm]:
		arm.hide()
		arm.pause()
	sprite_frames = load(str(profile.art.phase2.root)+"godot/Corrumpt_phase2_frames.tres")
	flip_h = false
	flower_pose(&"phase_2_idle")

## 切换花体逐帧姿态；progress小于0时按资源帧速循环播放。
func flower_pose(name_value: StringName, progress: float = -1.0) -> void:
	action = name_value
	_body_rate = 1.0
	speed_scale = _action_rate
	if progress < 0:
		if animation != name_value or not is_playing():
			play(name_value)
	else:
		animation = name_value
		pause()
		frame = mini(sprite_frames.get_frame_count(name_value)-1,int(clampf(progress,0,1)*sprite_frames.get_frame_count(name_value)))
	_align_root()

## 根据冰缓缩放本体和待机触手的帧率。
func set_action_speed(ratio: float) -> void:
	_action_rate = ratio
	speed_scale = _body_rate * _action_rate
	for arm in [left_arm, right_arm]:
		if is_instance_valid(arm):
			arm.speed_scale = _action_rate

func _align_root() -> void:
	if sprite_frames == null:
		return
	if phase_two:
		scale = Vector2.ONE
		offset = -Vector2(profile.art.phase2.anchor[0],profile.art.phase2.anchor[1])
		return
	if profile.art.has("pixel"):
		var anchor: Array = profile.art.pixel.body_anchor
		scale = Vector2.ONE*float(profile.art.pixel.get("render_scale",1))
		offset = Vector2(-float(anchor[0]),-float(anchor[1]))
		if flip_h:
			offset.x = float(anchor[0])-float(profile.art.pixel.body_canvas[0])
		return
	var table: Dictionary = profile.art.get("combat_anchors",{})
	var anchors: Array = table.get(String(animation),profile.art.anchors.phase_1_idle)
	var point: Array = anchors[mini(frame,anchors.size()-1)]
	var safe_frame := clampi(frame,0,sprite_frames.get_frame_count(animation)-1)
	var texture := sprite_frames.get_frame_texture(animation,safe_frame)
	if texture == null:
		return
	var native_width := float(profile.art.combat_native_widths.get(String(animation),444))
	scale = Vector2.ONE*float(profile.combat.visual_width)/native_width
	offset = Vector2(-float(point[0]),-float(point[1]))
	if flip_h:
		offset.x = float(point[0])-texture.get_width()
