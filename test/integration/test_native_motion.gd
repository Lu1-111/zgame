extends SceneTree
## 核对正式身体、手臂、掌形和下肢确实联动，而非固定闲置图配程序线段。
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var rig: Node = load("res://scripts/player/pixel_hero_rig.gd").new()
	scene.add_child(rig)
	var hands_intact := true
	for combo in 3:
		var poses := {}
		var clear_floor := true
		for frame in 51:
			rig.kind = "sword"
			rig.sword_pose = "attack"
			rig.combo = combo+1
			rig.progress = frame/50.0
			rig.apply_pose()
			var definition: Dictionary = rig._frame_pose
			poses[str(definition.sha256)] = true
			clear_floor = clear_floor and float(definition.tip[1]) <= float(rig._frame_data.native_anchor[1])
			hands_intact = hands_intact and rig._whole_body.texture == rig.source and not rig._native_hands.visible and not rig._upper_body.visible
		_expect(poses.size() >= 4,"剑第%d段使用原版人物修帧后的完整 PNG" % (combo+1))
		_expect(clear_floor,"剑第%d段的完整姿态保留脚底地面净空" % (combo+1))
	_expect(hands_intact and not rig.has_method("_arm") and not rig.has_method("_hand"),"原素材双手持剑已绘入全身帧，运行时不叠出额外手臂")
	for angle in [-90,-45,0,45,90]:
		var poses := {}
		for time in [-1.0,0.0,0.09,0.20]:
			rig.kind = "rifle"
			rig.aim = Vector2.from_angle(deg_to_rad(angle))
			rig.progress = 0.35
			rig.release_time = time
			rig.apply_pose()
			poses[rig._source_id] = true
		_expect(poses.size() >= 2,"步枪%d度射击前后身体与手臂均使用不同正式帧" % angle)
		var definition: Dictionary = rig.cfg.native_motion.frames[rig._source_id]
		var hand := Vector2(definition.hand[0],definition.hand[1])
		var native: Vector2 = rig._upper_body.to_global(hand+rig._upper_body.offset)
		var weapon: Vector2 = rig.to_global(rig._support_hand-rig._anchor)
		_expect(native.distance_to(weapon) < 0.001 and rig._whole_body.rotation == 0 and rig._native_hands.transform == rig._upper_body.transform,"步枪%d度原手掌与武器保持同一握点，腿部不随枪口翻转" % angle)
	print("NATIVE CHARACTER MOTION: %d PASS, %d FAIL" % [passed,failed])
	quit(1 if failed else 0)

func _expect(condition: bool,label: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL",label])
	if condition:
		passed += 1
	else:
		failed += 1
