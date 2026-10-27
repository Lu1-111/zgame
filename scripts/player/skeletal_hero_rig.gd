@tool
class_name SkeletalHeroRig
extends Node2D
## 原生骨骼展示后端：AnimationPlayer 曲线、Skeleton2D 蒙皮和双骨 IK。
## 本脚本不修改角色状态、战斗伤害、存档或贴图序列。

signal external_finished(animation: StringName)

@export var editor_ik_preview := true
@export_enum("sword", "rifle", "hammer", "staff") var idle_weapon := "sword"

var _cfg: Dictionary = {}
var _runtime: Dictionary = {}
var _skeleton: Skeleton2D
var _player: AnimationPlayer
var _grip: Node2D
var _front_target: Node2D
var _back_target: Node2D
var _front_foot_target: Node2D
var _back_foot_target: Node2D
var _front_upper: Bone2D
var _front_fore: Bone2D
var _front_hand: Bone2D
var _back_upper: Bone2D
var _back_fore: Bone2D
var _back_hand: Bone2D
var _front_foot: Bone2D
var _back_foot: Bone2D
var _torso: Bone2D
var _head: Bone2D
var _mount: Node2D
var _weapon: Node2D
var _bones: Array[Bone2D] = []
var _rest: Array[Transform2D] = []
var _ik_modifiers: Array[SkeletonModification2DTwoBoneIK] = []
var _ik_local_limits: Array[Vector2] = []
var _overlay: BoneOverlay
var _external: StringName = &""
var _external_time := 0.0
var _external_complete := false
var _clip: StringName = &"idle"
var _weapon_kind := "sword"
var _aim := Vector2.RIGHT
var _bound := false

class BoneOverlay extends Node2D:
	var rig: Node2D
	func _draw() -> void:
		if not is_instance_valid(rig) or rig._runtime.is_empty():
			return
		var color := Color(str(rig._runtime.debug_color))
		var width := float(rig._runtime.debug_line_width)
		var radius := float(rig._runtime.debug_joint_radius)
		for bone: Bone2D in rig._bones:
			var start := to_local(bone.global_position)
			var end := to_local(bone.to_global(Vector2(bone.length, 0)))
			draw_line(start, end, color, width, true)
			draw_circle(start, radius, color, false, width, true)
		for control: Node2D in [rig._grip, rig._front_target, rig._back_target, rig._front_foot_target, rig._back_foot_target]:
			var point := to_local(control.global_position)
			draw_line(point - Vector2(radius, radius), point + Vector2(radius, radius), color, width, true)
			draw_line(point + Vector2(radius, -radius), point + Vector2(-radius, radius), color, width, true)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not _bind():
		return
	_evaluate(&"idle", 0.0)
	_solve_limbs()

func _process(delta: float) -> void:
	if not _bound:
		return
	if Engine.is_editor_hint():
		var stack := _skeleton.get_modification_stack()
		if stack != null:
			stack.enabled = editor_ik_preview
		if editor_ik_preview:
			_solve_limbs()
	elif not _external.is_empty() and is_visible_in_tree():
		_external_time += delta
		_evaluate(_external, _external_time)
		_solve_limbs()
		_finish_external_if_needed()
	if is_instance_valid(_overlay) and _overlay.visible:
		_overlay.queue_redraw()

## 只同步显示姿态；支持状态机名称或 AnimationLibrary 内的动作名称。
func sync_pose(state: StringName, time: float, weapon: String, combo: int, aim: Vector2, facing: int, progress: float = -1.0) -> void:
	if not _bound and not _bind():
		return
	if not _external.is_empty():
		return
	_weapon_kind = weapon if weapon in ["sword", "rifle", "hammer", "staff"] else idle_weapon
	_aim = aim
	if facing != 0:
		scale.x = absf(scale.x) * signf(float(facing))
	var clip := _resolve_clip(state, _weapon_kind, combo)
	var sample_time := maxf(time, 0.0)
	if progress >= 0.0 and _player.has_animation(clip):
		sample_time = clampf(progress, 0.0, 1.0) * _player.get_animation(clip).length
	_evaluate(clip, sample_time)
	if _weapon_kind == "rifle" and clip == &"rifle":
		_aim_rifle(time)
	_solve_limbs()

## 返回实际手骨武器挂点上的枪口坐标。
func muzzle_global_position() -> Vector2:
	if not _bound:
		return global_position
	return _weapon.to_global(_weapon.muzzle_local_position())

## 子弹方向与可见枪管一致，翻转与俯仰都会参与计算。
func firing_direction_global() -> Vector2:
	return _weapon.global_transform.x.normalized() if _bound else Vector2.RIGHT

## 播放暂停世界时仍可推进的坐下、休息、起身动作。
func play_external(animation: StringName) -> void:
	if not _bound and not _bind():
		return
	if not _player.has_animation(animation):
		return
	_external = animation
	_external_time = 0.0
	_external_complete = false
	_evaluate(_external, _external_time)
	_solve_limbs()

## 停止外部动作，下一次同步立即恢复状态机姿态。
func stop_external() -> void:
	_external = &""
	_external_time = 0.0
	_external_complete = false

## 返回是否正在由休息等外部流程控制显示。
func is_external_active() -> bool:
	return not _external.is_empty()

## 返回外部动作名，供展示后端切换时保留进度。
func get_external_animation() -> StringName:
	return _external

## 返回外部动作已播放的秒数。
func get_external_time() -> float:
	return _external_time

## 定位外部动作时间，不产生角色状态变化。
func seek_external(time: float) -> void:
	if _external.is_empty() or not _bound:
		return
	_external_time = maxf(time, 0.0)
	_external_complete = false
	_evaluate(_external, _external_time)
	_solve_limbs()

## 判断原生骨架、蒙皮控制点和动画库是否完整可用。
func is_ready_for_animation() -> bool:
	return _bound and _player.has_animation(&"idle") and _skeleton.get_modification_stack() != null

## 显示或隐藏真正参与蒙皮的骨骼与 IK 目标。
func toggle_debug() -> void:
	if not _bound and not _bind():
		return
	_overlay.visible = not _overlay.visible
	_overlay.queue_redraw()

## 设置骨骼调试叠加层，供测试台使用。
func set_debug_enabled(enabled: bool) -> void:
	if not _bound and not _bind():
		return
	_overlay.visible = enabled
	_overlay.queue_redraw()

func _bind() -> bool:
	if _bound:
		return true
	var path := "res://data/skeleton_test.json"
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return false
	_cfg = parsed
	_runtime = _cfg.get("runtime", {})
	_skeleton = get_node_or_null("Skeleton2D") as Skeleton2D
	_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	_grip = get_node_or_null("Controls/Grip") as Node2D
	_front_target = get_node_or_null("Controls/FrontTarget") as Node2D
	_back_target = get_node_or_null("Controls/BackTarget") as Node2D
	_front_foot_target = get_node_or_null("Controls/FrontFoot") as Node2D
	_back_foot_target = get_node_or_null("Controls/BackFoot") as Node2D
	_weapon = get_node_or_null("WeaponVisual") as Node2D
	if _skeleton == null or _player == null or _grip == null or _front_target == null or _back_target == null or _front_foot_target == null or _back_foot_target == null or _weapon == null or _runtime.is_empty():
		return false
	_front_upper = _bone("Root/Torso/FrontUpperArm")
	_front_fore = _bone("Root/Torso/FrontUpperArm/FrontForearm")
	_front_hand = _bone("Root/Torso/FrontUpperArm/FrontForearm/FrontHand")
	_back_upper = _bone("Root/Torso/BackUpperArm")
	_back_fore = _bone("Root/Torso/BackUpperArm/BackForearm")
	_back_hand = _bone("Root/Torso/BackUpperArm/BackForearm/BackHand")
	_front_foot = _bone("Root/FrontThigh/FrontShin/FrontFoot")
	_back_foot = _bone("Root/BackThigh/BackShin/BackFoot")
	_torso = _bone("Root/Torso")
	_head = _bone("Root/Torso/Neck/Head")
	if _front_hand == null or _back_hand == null or _front_upper == null or _front_fore == null or _back_upper == null or _back_fore == null or _front_foot == null or _back_foot == null or _torso == null or _head == null:
		return false
	_mount = _front_hand.get_node_or_null("WeaponMount") as Node2D
	if _mount == null or not _weapon.has_method("configure") or not _weapon.has_method("muzzle_local_position"):
		return false
	_bones.clear()
	_rest.clear()
	for entry: Dictionary in _cfg.get("bones", []):
		var bone := _bone(str(entry.path))
		if bone != null:
			_bones.append(bone)
			_rest.append(bone.rest)
	_cache_ik_local_limits()
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_weapon_kind = idle_weapon
	_weapon.configure(_weapon_kind, _cfg)
	_overlay = BoneOverlay.new()
	_overlay.name = "BoneOverlay"
	_overlay.rig = self
	_overlay.visible = false
	_overlay.z_index = 100
	add_child(_overlay)
	_bound = true
	return true

func _bone(path: String) -> Bone2D:
	return _skeleton.get_node_or_null(NodePath(path)) as Bone2D

func _resolve_clip(state: StringName, weapon: String, combo: int) -> StringName:
	if _player.has_animation(state):
		return state
	var key := str(state).to_lower()
	match key:
		"attack":
			if weapon in ["sword", "hammer"]:
				return StringName("%s_%d" % [weapon, clampi(combo, 1, 3)])
			return StringName(weapon)
		"actionskillcleave", "skill_cleave": return &"sword_3"
		"skill", "actionskillheal", "skill_heal", "actionskillbolt", "skill_bolt": return &"staff"
		"guardrelease", "guard_release": return &"guard_lower"
		"dead": return &"death"
		_:
			var candidate := StringName(key)
			return candidate if _player.has_animation(candidate) else &"idle"

func _evaluate(clip: StringName, time: float) -> void:
	if not _player.has_animation(clip):
		return
	for index in _bones.size():
		_bones[index].transform = _rest[index]
	var animation := _player.get_animation(clip)
	var sample := maxf(time, 0.0)
	if animation.loop_mode != Animation.LOOP_NONE and animation.length > 0.0:
		sample = fmod(sample, animation.length)
	else:
		sample = minf(sample, animation.length)
	_player.play(clip)
	_player.seek(sample, true)
	_player.pause()
	_clip = clip
	_weapon.configure(_weapon_kind, _cfg)
	_weapon.visible = str(clip) not in _cfg.get("hidden_weapon_clips", [])

func _aim_rifle(time: float) -> void:
	var aim_origin := global_position
	# Player 的 aim_vector 以角色中心为原点；测试台则以骨架根为原点。
	var holder := get_parent() as Node2D
	if holder != null and holder.has_method("aim_vector"):
		aim_origin = holder.global_position
	var target := to_local(aim_origin + _aim)
	var direction := (target - _grip.position).normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var aim_angle := direction.angle()
	_torso.rotation += clampf(aim_angle * float(_runtime.rifle_torso_aim), -float(_runtime.max_torso_aim), float(_runtime.max_torso_aim))
	_head.rotation += clampf(aim_angle * float(_runtime.rifle_head_aim), -float(_runtime.max_head_aim), float(_runtime.max_head_aim))
	var home := _vec(_runtime.rifle_grip)
	for iteration in int(_runtime.aim_iterations):
		direction = (target - _grip.position).normalized()
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
		_grip.position = home + Vector2(direction.x * float(_runtime.rifle_pitch_side), direction.y * float(_runtime.rifle_pitch_lift))
		_grip.rotation = direction.angle()
	# 扳机后的后坐沿枪管反向，仍通过双臂 IK 带动原素材手掌。
	var recoil := maxf(0.0, 1.0 - maxf(time, 0.0) / float(_runtime.rifle_recoil_seconds))
	_grip.position -= direction * float(_runtime.rifle_recoil) * recoil
	_solve_limbs()
	for iteration in int(_runtime.aim_iterations):
		var muzzle := to_local(muzzle_global_position())
		var mount := to_local(_mount.global_position)
		if muzzle.distance_to(target) < float(_runtime.aim_min_distance):
			break
		var barrel_offset := muzzle - mount
		var target_direction := (target - mount).normalized()
		_grip.rotation += barrel_offset.angle_to(target_direction)
		_solve_limbs()

func _solve_limbs() -> void:
	if not _bound:
		return
	var stack := _skeleton.get_modification_stack()
	if stack == null or not stack.enabled:
		return
	_update_ik_global_limits()
	var direction := _grip.global_transform.x.normalized()
	var wrist := _grip.global_position - direction * float(_runtime.hand_mount_offset) * absf(global_scale.x)
	_front_target.global_position = _clamp_arm_target(_front_upper, _front_fore, wrist)
	_skeleton.execute_modifications(0.0, 0)
	_align_bone(_front_hand, direction)
	_weapon.global_transform = _mount.global_transform
	var spacing := float(_runtime.other_offhand)
	if _weapon_kind == "sword":
		spacing = float(_runtime.sword_offhand)
	elif _weapon_kind == "rifle":
		spacing = float(_runtime.rifle_offhand)
	var rear_wrist := _mount.global_position + direction * (spacing - float(_runtime.hand_mount_offset)) * absf(global_scale.x)
	_back_target.global_position = _clamp_arm_target(_back_upper, _back_fore, rear_wrist)
	_skeleton.execute_modifications(0.0, 0)
	_align_bone(_front_hand, direction)
	_align_bone(_back_hand, direction)
	_align_bone(_front_foot, _front_foot_target.global_transform.x.normalized())
	_align_bone(_back_foot, _back_foot_target.global_transform.x.normalized())
	_weapon.global_transform = _mount.global_transform
	if is_instance_valid(_overlay) and _overlay.visible:
		_overlay.queue_redraw()

func _cache_ik_local_limits() -> void:
	# 原生 TwoBoneIK 的距离限制使用全局单位；资源中保存的是角色原像素单位。
	# 仅缓存一次原始值，避免重复求解时把已经缩放过的限制再次相乘。
	_ik_modifiers.clear()
	_ik_local_limits.clear()
	var stack := _skeleton.get_modification_stack()
	if stack == null:
		return
	for index in stack.modification_count:
		var modifier := stack.get_modification(index) as SkeletonModification2DTwoBoneIK
		if modifier != null:
			_ik_modifiers.append(modifier)
			_ik_local_limits.append(Vector2(modifier.target_minimum_distance, modifier.target_maximum_distance))

func _update_ik_global_limits() -> void:
	var magnitude := absf(_skeleton.global_scale.x)
	for index in _ik_modifiers.size():
		var modifier := _ik_modifiers[index]
		var limits := _ik_local_limits[index] * magnitude
		# 先扩上限或先缩下限，保证编辑器检查时不会短暂出现 min 大于 max。
		if limits.y >= modifier.target_maximum_distance:
			modifier.target_maximum_distance = limits.y
			modifier.target_minimum_distance = limits.x
		else:
			modifier.target_minimum_distance = limits.x
			modifier.target_maximum_distance = limits.y

func _clamp_arm_target(upper: Bone2D, fore: Bone2D, target: Vector2) -> Vector2:
	var shoulder := to_local(upper.global_position)
	var offset := to_local(target) - shoulder
	var length := clampf(offset.length(), float(_runtime.ik_min_distance), upper.length + fore.length - float(_runtime.arm_reach_margin))
	var direction := offset.normalized() if not offset.is_zero_approx() else Vector2.RIGHT
	return to_global(shoulder + direction * length)

func _align_bone(bone: Bone2D, direction: Vector2) -> void:
	var holder := bone.get_parent() as Node2D
	bone.rotation = holder.global_transform.basis_xform_inv(direction).angle()

func _finish_external_if_needed() -> void:
	if _external_complete or not _player.has_animation(_external):
		return
	var animation := _player.get_animation(_external)
	if animation.loop_mode != Animation.LOOP_NONE or _external_time < animation.length:
		return
	_external_complete = true
	var completed := _external
	external_finished.emit(completed)
	if _external != completed:
		return
	if completed == &"rest_enter":
		play_external(&"rest")
	elif completed == &"rest_exit":
		stop_external()

func _vec(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))
