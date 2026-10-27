extends SceneTree
## 原生骨架原型的独立回归：延迟载入 Player，避免 --script 早于 autoload 编译。
## 运行前将 APPDATA / LOCALAPPDATA 指向 work/skeleton_test/qa 的隔离目录。
## godot --headless --path . --fixed-fps 60 --script res://tests/skeleton_prototype_check.gd

const CONFIG_PATH := "res://data/skeleton_test.json"
const MODEL_PATH := "res://scenes/player/skeletal/hero_skeleton_test.tscn"
const ORIGINAL_FRAMES := "res://assets/PROCESSED/characters/CHR-01/v001/godot/CHR-01_sprite_frames.tres"
const EXTERNAL_LIBRARY := "res://assets/PROCESSED/characters/CHR-01/skeleton_test/hero_bone_animations.tres"
const REQUIRED_CLIPS := ["idle", "run", "jump", "fall", "land", "dodge", "guard", "guard_lower", "sword_1", "sword_2", "sword_3", "rifle", "hammer_1", "hammer_2", "hammer_3", "staff", "hurt", "death", "rest_enter", "rest", "rest_exit"]
const ARM_PATHS := ["Root/Torso/FrontUpperArm/FrontForearm/FrontHand", "Root/Torso/BackUpperArm/BackForearm/BackHand"]
const FOOT_PATHS := ["Root/FrontThigh/FrontShin/FrontFoot", "Root/BackThigh/BackShin/BackFoot"]

var _passed := 0
var _failed := 0
var _room: Node2D
var _state: Node
var _config: Dictionary = {}
var _external_events: Array[StringName] = []

class DialogueProbe extends Node:
	var received := 0
	func is_open() -> bool:
		return true
	func handle_dialogue_input(_event: InputEvent) -> void:
		received += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(90.0, true, false, true).timeout.connect(_timeout)
	_state = root.get_node_or_null("GameState")
	_expect(_state != null and root.has_node("DataDB"), "独立宿主在 autoload 就绪后加载生产脚本")
	if _state == null or not root.has_node("DataDB"):
		_finish()
		return
	_state.set_process(false)
	_state.reset()
	_config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	_expect(not _config.is_empty(), "骨架数据可解析")
	_expect(str(_config.get("integration", {}).get("default_backend", "")) == "frames", "主游戏默认保留逐帧后端")
	_room = Node2D.new()
	_room.name = "IsolatedSkeletonQA"
	root.add_child(_room)
	current_scene = _room
	var packed := load(MODEL_PATH) as PackedScene
	_expect(packed != null, "原生骨架场景可加载")
	if packed == null:
		_finish()
		return
	var rig: Node2D = packed.instantiate()
	_room.add_child(rig)
	await _frames(3)
	var valid := _check_native_structure(rig)
	if valid:
		await _check_native_motion(rig)
	rig.queue_free()
	await _frames(2)
	await _check_player_integration()
	_finish()


func _check_native_structure(rig: Node2D) -> bool:
	var skeleton := rig.get_node_or_null("Skeleton2D") as Skeleton2D
	var animator := rig.get_node_or_null("AnimationPlayer") as AnimationPlayer
	_expect(skeleton != null, "场景包含原生 Skeleton2D")
	_expect(animator != null, "场景包含可编辑的原生 AnimationPlayer")
	var api_ok := true
	for method in ["sync_pose", "muzzle_global_position", "firing_direction_global", "play_external", "stop_external", "is_external_active", "toggle_debug"]:
		api_ok = api_ok and rig.has_method(method)
	_expect(api_ok and rig.has_signal("external_finished"), "骨架运行时展示、枪口、休息与调试契约齐全")
	if skeleton == null or animator == null or not api_ok:
		return false
	var forbidden := false
	for node in _descendants(rig):
		forbidden = forbidden or node is AnimatedSprite2D
	_expect(not forbidden, "骨骼子树不含 AnimatedSprite2D")
	var bones: Array[Node] = []
	var meshes: Array[Node] = []
	for node in _descendants(rig):
		if node is Bone2D:
			bones.append(node)
		if node is Polygon2D:
			meshes.append(node)
	_expect(bones.size() >= _config.get("bones", []).size() and bones.size() >= 16, "原生骨链覆盖头身双臂双腿")
	var rest_ok := true
	for node in bones:
		var bone := node as Bone2D
		rest_ok = rest_ok and absf(bone.rest.determinant()) > 0.001 and bone.get_length() > 0.0
	_expect(rest_ok, "所有骨骼有非退化 rest 与有效长度")
	_expect(meshes.size() >= _config.get("meshes", []).size() and meshes.size() >= 15, "角色各静态分件通过 Polygon2D 蒙皮")
	var weights_ok := true
	var source_ok := true
	var source_paths: Array[String] = []
	for source: Dictionary in _config.get("sources", {}).values():
		source_paths.append(str(source.get("path", "")))
	var blended_vertices := 0
	for node in meshes:
		var mesh := node as Polygon2D
		weights_ok = weights_ok and mesh.texture != null and mesh.polygon.size() == mesh.uv.size() and mesh.polygon.size() >= 3
		source_ok = source_ok and mesh.texture != null and mesh.texture.resource_path in source_paths
		weights_ok = weights_ok and mesh.get_node_or_null(mesh.skeleton) == skeleton and mesh.get_bone_count() > 0
		var sums: Array[float] = []
		var contributors: Array[int] = []
		sums.resize(mesh.polygon.size())
		contributors.resize(mesh.polygon.size())
		for index in mesh.get_bone_count():
			var path: NodePath = mesh.get_bone_path(index)
			var weights: PackedFloat32Array = mesh.get_bone_weights(index)
			weights_ok = weights_ok and skeleton.get_node_or_null(path) is Bone2D and weights.size() == mesh.polygon.size()
			for vertex in mini(weights.size(), sums.size()):
				weights_ok = weights_ok and is_finite(weights[vertex]) and weights[vertex] >= 0.0 and weights[vertex] <= 1.0
				sums[vertex] += weights[vertex]
				if weights[vertex] > 0.001:
					contributors[vertex] += 1
		for vertex in sums.size():
			weights_ok = weights_ok and is_equal_approx(sums[vertex], 1.0)
			if contributors[vertex] > 1:
				blended_vertices += 1
	_expect(weights_ok, "每个蒙皮顶点权重归一、骨路径有效、UV 与纹理完整")
	_expect(source_ok and rig.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "分件直接引用原正式角色贴图并保持像素采样")
	_expect(blended_vertices > 0, "至少一处关节使用多骨权重而非纯分件刚性旋转")
	var stack := skeleton.get_modification_stack()
	var ik_ok := stack != null and stack.enabled and stack.get_modification_count() >= 4
	if stack != null:
		for index in stack.get_modification_count():
			var modifier := stack.get_modification(index)
			ik_ok = ik_ok and modifier is SkeletonModification2DTwoBoneIK and modifier.enabled
	_expect(ik_ok, "双臂双腿由启用的原生 TwoBoneIK 求解")
	var clips_ok := true
	var forbidden_tracks := false
	var bone_tracks := false
	var goal_tracks := false
	for clip in REQUIRED_CLIPS:
		clips_ok = clips_ok and animator.has_animation(clip)
		if not animator.has_animation(clip):
			continue
		var animation := animator.get_animation(clip)
		clips_ok = clips_ok and animation.length > 0.0 and animation.get_track_count() > 0
		for index in animation.get_track_count():
			var path := str(animation.track_get_path(index))
			forbidden_tracks = forbidden_tracks or path.ends_with(":texture") or path.ends_with(":frame") or path.ends_with(":sprite_frames")
			bone_tracks = bone_tracks or path.begins_with("Skeleton2D/")
			goal_tracks = goal_tracks or path.begins_with("Controls/")
	_expect(clips_ok, "21 个基础/武器/格挡/坐火原生 clip 均存在且有曲线")
	_expect(bone_tracks and goal_tracks and not forbidden_tracks, "动画曲线驱动骨骼与 IK 目标，不以换贴图模拟动作")
	var library := animator.get_animation_library(&"")
	_expect(library != null and library.resource_path == EXTERNAL_LIBRARY and not library.resource_path.contains("::"), "AnimationPlayer 实际引用独立可编辑的外部 AnimationLibrary，未内嵌子资源")
	return true


func _check_native_motion(rig: Node2D) -> void:
	var skeleton := rig.get_node("Skeleton2D") as Skeleton2D
	var textures := _texture_snapshot(rig)
	var material_intact := true
	var torso_samples := {}
	var head_samples := {}
	var hand_samples := {}
	var foot_samples := {}
	var grip_error := 0.0
	var foot_error := 0.0
	for combo in [1, 2, 3]:
		for step in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]:
			rig.sync_pose(&"Attack", 0.0, "sword", combo, Vector2.RIGHT, 1, step)
			await _frames(1)
			material_intact = material_intact and textures == _texture_snapshot(rig)
			torso_samples[_transform_key(skeleton.get_node("Root/Torso"))] = true
			head_samples[_transform_key(skeleton.get_node("Root/Torso/Neck/Head"))] = true
			for index in ARM_PATHS.size():
				var hand := skeleton.get_node(ARM_PATHS[index]) as Bone2D
				var target := rig.get_node("Controls/FrontTarget" if index == 0 else "Controls/BackTarget") as Node2D
				hand_samples[_transform_key(hand)] = true
				grip_error = maxf(grip_error, hand.global_position.distance_to(target.global_position))
	for time in [0.0, 0.08, 0.16, 0.24, 0.32]:
		rig.sync_pose(&"Run", time, "hammer", 1, Vector2.RIGHT, 1)
		await _frames(1)
		for index in FOOT_PATHS.size():
			var foot := skeleton.get_node(FOOT_PATHS[index]) as Bone2D
			var goal := rig.get_node("Controls/FrontFoot" if index == 0 else "Controls/BackFoot") as Node2D
			foot_samples[_transform_key(foot)] = true
			foot_error = maxf(foot_error, foot.global_position.distance_to(goal.global_position))
		material_intact = material_intact and textures == _texture_snapshot(rig)
	_expect(torso_samples.size() > 3 and head_samples.size() > 3, "剑三连击有头部、躯干的原生骨曲线联动")
	_expect(hand_samples.size() > 8 and grip_error < 1.0, "双臂骨链实际运动，双手末端跟随 IK 握点（误差 %.3f px）" % grip_error)
	_expect(foot_samples.size() > 4 and foot_error < 1.0, "行走腿骨与双脚目标联动（误差 %.3f px）" % foot_error)
	_expect(material_intact, "整个攻击与行走期间所有蒙皮纹理保持同一静态资源")
	var directional_ok := true
	var head_aims := {}
	for facing in [1, -1]:
		for degrees in [-75.0, -35.0, 0.0, 40.0, 75.0]:
			var direction := Vector2(cos(deg_to_rad(degrees)) * facing, sin(deg_to_rad(degrees)))
			var aim_offset := direction * 300.0
			rig.sync_pose(&"Attack", 0.1, "rifle", 1, aim_offset, facing, 0.5)
			await _frames(1)
			var actual: Vector2 = rig.firing_direction_global()
			var muzzle: Vector2 = rig.muzzle_global_position()
			var to_cursor := (rig.global_position + aim_offset - muzzle).normalized()
			directional_ok = directional_ok and actual.is_finite() and actual.normalized().dot(to_cursor) > 0.995
			directional_ok = directional_ok and muzzle.is_finite()
			head_aims[_transform_key(skeleton.get_node("Root/Torso/Neck/Head"))] = true
			material_intact = material_intact and textures == _texture_snapshot(rig)
	_expect(directional_ok and head_aims.size() >= 5, "步枪上下/左右瞄准驱动枪口与头身骨骼，方向连续且有效")
	_expect(material_intact, "步枪各瞄准方向不替换身体分件贴图")
	rig.scale = Vector2(5, 5)
	rig.sync_pose(&"Attack", 0.1, "sword", 1, Vector2(300, 0), 1, 0.4)
	await _frames(1)
	var scaled_error := 0.0
	for index in ARM_PATHS.size():
		var hand := skeleton.get_node(ARM_PATHS[index]) as Bone2D
		var target := rig.get_node("Controls/FrontTarget" if index == 0 else "Controls/BackTarget") as Node2D
		scaled_error = maxf(scaled_error, hand.global_position.distance_to(target.global_position))
	_expect(scaled_error < 1.0, "测试台放大五倍后原生 IK 仍能抵达握点（误差 %.3f px）" % scaled_error)
	rig.scale = Vector2.ONE
	rig.external_finished.connect(_external_finished)
	rig.play_external(&"rest_enter")
	_expect(rig.is_external_active(), "坐火入座能够接管骨架展示")
	await _frames(100)
	_expect(_external_events.has(&"rest_enter"), "非循环坐火动画会发出完成信号")
	rig.play_external(&"rest")
	await _frames(4)
	_expect(rig.is_external_active(), "坐火循环保持外部动画所有权")
	rig.stop_external()
	_expect(not rig.is_external_active(), "坐火展示可退出并归还状态机")
	var original := load(ORIGINAL_FRAMES) as SpriteFrames
	_expect(original != null and original.has_animation(&"idle") and original.has_animation(&"hammer_1") and original.has_animation(&"staff_sweep"), "原角色正式逐帧资源及锤杖动作仍可加载")


func _check_player_integration() -> void:
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	_expect(packed != null, "原玩家场景仍可加载")
	if packed == null:
		return
	var actor: Node = packed.instantiate()
	actor.set_script(load("res://tools/fixtures/aimed_player.gd"))
	actor.name = "Player"
	actor.position = Vector2(200, 200)
	_room.add_child(actor)
	await _frames(3)
	actor.set_physics_process(false)
	actor.set_process(false)
	var api_ok := actor.has_method("set_animation_backend") and actor.has_method("uses_skeletal_animation") and actor.has_method("get_animation_backend")
	_expect(api_ok, "Player 暴露可回退的公共展示后端接口")
	if not api_ok:
		actor.queue_free()
		return
	_expect(actor.get_animation_backend() == "frames", "普通 Player 实例启动时仍使用逐帧默认方案")
	actor.set_animation_backend("frames")
	actor.sm.to(&"Idle")
	actor._update_animation()
	_expect(not actor.uses_skeletal_animation() and actor.sprite.visible and (not is_instance_valid(actor._skeletal_rig) or not actor._skeletal_rig.visible), "逐帧 idle 仅显示原 Sprite")
	_state.hp = 57
	_state.sta = 63
	_state.mana = 29
	_state.weapon_id = &"sword_01"
	actor.sm.to(&"Attack", {"combo": 2})
	actor.sm.tick(0.05)
	actor._clock += 0.05
	actor._update_animation()
	var state_before: Dictionary = _state.to_save_dict().duplicate(true)
	var motion_before := _motion_snapshot(actor)
	var switching_ok := true
	var visible_ok := true
	var paused_ok := true
	var selected: bool = actor.set_animation_backend("skeleton")
	_expect(selected and actor.uses_skeletal_animation(), "普通玩家可以真正启用原生骨架后端")
	if not selected or not actor.uses_skeletal_animation():
		actor.queue_free()
		return
	for repeat in 3:
		actor.set_animation_backend("skeleton")
		actor._update_animation()
		switching_ok = switching_ok and state_before == _state.to_save_dict() and motion_before == _motion_snapshot(actor)
		visible_ok = visible_ok and actor._skeletal_rig.visible and not actor.sprite.visible and not actor._pixel_rig.visible
		paused_ok = paused_ok and not actor.sprite.is_playing()
		actor.set_animation_backend("frames")
		actor._update_animation()
		switching_ok = switching_ok and state_before == _state.to_save_dict() and motion_before == _motion_snapshot(actor)
		visible_ok = visible_ok and not actor._skeletal_rig.visible and actor._pixel_rig.visible and not actor.sprite.visible
	_expect(switching_ok, "攻击中往返切换不改 HP/体力/奶力/装备/背包/存档、状态机、连击计时、速度或碰撞")
	_expect(visible_ok, "空闲与攻击切换时始终只有一个角色展示管线可见")
	_expect(paused_ok, "骨骼模式暂停隐藏的原 AnimatedSprite2D")
	_expect(not state_before.has("animation_backend") and not state_before.has("skeleton"), "展示偏好不混入正式存档 schema")
	actor.set_animation_backend("skeleton")
	_state.weapon_id = &"bow_01"
	actor.aim_point = actor.global_position + Vector2(100, -90)
	actor.sm.to(&"Attack")
	actor._clock += 0.1
	actor._update_animation()
	actor.spawn_weapon_projectile()
	var bullet: Node2D = null
	for child in _room.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/player/projectile_bubble.gd":
			bullet = child as Node2D
	var muzzle: Vector2 = actor._skeletal_rig.muzzle_global_position()
	var direction: Vector2 = actor._skeletal_rig.firing_direction_global()
	_expect(bullet != null, "骨骼模式仍沿原战斗链生成真实投射物")
	if bullet != null:
		_expect(bullet.global_position.distance_to(muzzle) < 0.01 and bullet.dir.dot(direction) > 0.9999, "真实子弹从当前骨架枪口按当前骨架方向发射")
		bullet.queue_free()
	actor.set_animation_backend("frames")
	actor.sm.to(&"Idle")
	actor._update_animation()
	_expect(actor.sprite.visible and actor.sprite.is_playing() and not actor._skeletal_rig.visible, "切回逐帧后旧 idle 动画重新播放")
	actor.play_presentation_animation(&"rest_enter")
	actor._seek_frame_time(0.12)
	actor.set_animation_backend("skeleton")
	var rest_switch_ok: bool = actor.get_presentation_animation() == &"rest_enter" and actor._skeletal_rig.is_external_active()
	rest_switch_ok = rest_switch_ok and absf(float(actor._skeletal_rig.get_external_time()) - 0.12) < 0.001
	actor.set_animation_backend("frames")
	rest_switch_ok = rest_switch_ok and actor.get_presentation_animation() == &"rest_enter" and actor.sprite.visible and actor.sprite.is_playing()
	rest_switch_ok = rest_switch_ok and absf(float(actor._presentation_external_time()) - 0.12) < 0.001
	_expect(rest_switch_ok, "坐火演出中往返切换保留动作及播放进度，原动画可继续完成")
	actor.stop_presentation_animation()
	_check_ui_switch(actor)
	actor.queue_free()
	await _frames(2)


func _check_ui_switch(actor: Node) -> void:
	var ui := root.get_node_or_null("GameUI")
	_expect(ui != null, "主游戏 UI 单例存在")
	if ui == null:
		return
	ui.player = actor
	ui.scene = _room
	actor.set_animation_backend("frames")
	var toggle := InputEventKey.new()
	toggle.keycode = KEY_F6
	toggle.pressed = true
	ui._input(toggle)
	_expect(actor.uses_skeletal_animation(), "F6 入口实际切换玩家展示后端")
	ui._show_pause()
	var button := ui.modal.get_node_or_null("AnimationBackend") as Button
	var paused_before := paused
	if button != null:
		button.pressed.emit()
	_expect(paused_before and button != null and not actor.uses_skeletal_animation() and paused, "暂停菜单可切回逐帧，世界保持暂停")
	ui._force_close()
	var dialogue := DialogueProbe.new()
	_room.add_child(dialogue)
	dialogue.add_to_group(&"npc_dialogue")
	ui._input(toggle)
	_expect(not actor.uses_skeletal_animation() and dialogue.received == 1, "对话优先消费 F6，避免任意键推进时误切展示")
	dialogue.free()


func _motion_snapshot(actor: Node) -> Dictionary:
	var machine: Node = actor.sm
	var state_node: Variant = machine.get("current")
	return {"state": machine.current_name(), "timer": state_node.get("_t") if state_node != null else null, "clock": actor._clock, "attack_start": actor._last_attack_time, "combo": actor.attack_combo, "phase": actor.attack_phase, "charge": actor.attack_charge, "velocity": actor.velocity, "position": actor.position, "mask": actor.collision_mask, "layer": actor.collision_layer}


func _texture_snapshot(rig: Node) -> Dictionary:
	var result := {}
	for node in _descendants(rig):
		if node is Polygon2D:
			var texture := (node as Polygon2D).texture
			result[str(rig.get_path_to(node))] = texture.get_instance_id() if texture != null else 0
	return result


func _transform_key(node: Node2D) -> String:
	return str(node.global_transform)


func _descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result


func _external_finished(animation: StringName) -> void:
	_external_events.append(animation)


func _frames(count: int) -> void:
	for index in count:
		await process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		_failed += 1
		print("FAIL: %s" % label)


func _timeout() -> void:
	push_error("骨架独立回归超时，强制终止以避免后台实例残留")
	quit(2)


func _finish() -> void:
	print("SKELETON PROTOTYPE: %d PASS, %d FAIL" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
