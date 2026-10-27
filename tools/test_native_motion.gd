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
		var heads := {}
		var legs := {}
		for frame in 8:
			rig.kind = "sword"
			rig.combo = combo+1
			rig.progress = frame/7.0
			rig.apply_pose()
			poses[rig._source_id] = true
			var definition: Dictionary = rig.cfg.native_motion.frames[rig._source_id]
			var image: Image = rig.source.get_image()
			var origin := Vector2i(definition.origin[0],definition.origin[1])
			heads[image.get_region(Rect2i(origin+Vector2i(23,14),Vector2i(21,22))).get_data().hex_encode().hash()] = true
			legs[image.get_region(Rect2i(origin+Vector2i(19,48),Vector2i(28,11))).get_data().hex_encode().hash()] = true
			hands_intact = hands_intact and rig._native_hands.texture == rig.source and rig._native_hands.transform == rig._whole_body.transform
			hands_intact = hands_intact and rig._native_hands.offset == rig._whole_body.offset
			var grip := Vector2(definition.hand[0],definition.hand[1])
			for mask: Array in definition.masks:
				hands_intact = hands_intact and not Rect2(mask[0],mask[1],mask[2],mask[3]).has_point(grip)
			hands_intact = hands_intact and rig._whole_body.rotation == 0
		_expect(poses.size() >= 5 and heads.size() >= 3,"剑第%d段使用至少五个正式姿态，头肩确实换帧" % (combo+1))
		_expect(legs.size() >= 3,"剑第%d段下肢支撑与俯身也随动作改变" % (combo+1))
	_expect(hands_intact and not rig.has_method("_arm") and not rig.has_method("_hand"),"握点保留原生手掌，取消线段手臂与方块手，不会叠出第三只手")
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
