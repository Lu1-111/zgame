extends RefCounted
## 只核对原版人物逐帧素材，不依赖骨架轨迹。


## 验证恢复的 v8 完整帧、持握、净空、镜像和三段衔接。
func run(host) -> bool:
	var rig := PixelHeroRig.new()
	rig._ready()
	host.expect_true(rig.has_sword_frames(),"原版形象的完整逐帧剑素材已接入")
	if not rig.has_sword_frames():
		rig.free()
		return false
	var data: Dictionary = rig._frame_data
	host.expect_eq(int(data.version),8,"恢复对话动图对应的 v8 连斩素材")
	host.expect_true(not rig.has_sword_ready_pose(),"收招后恢复该版本的原人物闲置动画")
	host.expect_eq(str(data.kind),"native_pixel_frames","逐帧来源为正式原人物修帧，不使用重新生成的人物或骨架输出")
	for facing in [1,-1]:
		rig.facing = facing
		for combo in range(1,4):
			var attached := true
			var composed := true
			var mirrored := true
			for sample in range(-1,122):
				rig.sword_pose = "attack"
				rig.combo = combo
				rig.progress = sample/120.0
				rig.apply_pose()
				var d := Vector2.from_angle(rig._sword_angle)
				attached = attached and (rig._support_hand-(rig._grip-d*3)).length() < 0.001
				attached = attached and (rig._rear_hand-(rig._grip-d*float(data.rear_hand_spacing))).length() < 0.001
				composed = composed and rig._whole_body.texture == rig.source and rig._whole_body.material == null
				composed = composed and not rig._upper_body.visible and not rig._native_hands.visible
				var local := rig._support_hand-rig._anchor
				var world := rig.to_global(local)-rig.to_global(Vector2.ZERO)
				mirrored = mirrored and absf(world.x-facing*local.x) < 0.001 and absf(world.y-local.y) < 0.001
			host.expect_true(attached,"第%d段/朝向%d：双手在每张帧内同握一柄剑" % [combo,facing])
			host.expect_true(composed,"第%d段/朝向%d：只播放完整 PNG，没有运行时手臂变换或独立转剑" % [combo,facing])
			host.expect_true(mirrored,"第%d段/朝向%d：左右朝向正确镜像同一张帧" % [combo,facing])
	var intact := true
	var clear_floor := true
	for pose: Dictionary in data.poses.values():
		intact = intact and str(pose.path).contains("/rpg_v8/") and FileAccess.get_sha256(str(pose.path)) == str(pose.sha256)
		clear_floor = clear_floor and float(pose.tip[1]) <= float(data.native_anchor[1])
	host.expect_true(data.poses.size() == 24 and intact,"24 张完整 PNG 与选定 v8 素材逐字节一致，人物没有重新制作")
	host.expect_true(clear_floor,"三段全部姿态的剑尖保留脚底地面净空")
	var overhead: Dictionary = data.poses.sword_1_00
	var side: Dictionary = data.poses.sword_1_07
	var shoulder: Dictionary = data.poses.sword_2_07
	host.expect_true(float(overhead.hand[1]) <= 24 and float(overhead.tip[1]) < 0 and float(side.hand[1]) > 40,"第一段恢复过顶纵斩至身侧")
	host.expect_true(float(shoulder.hand[1]) < float(side.hand[1]) and float(shoulder.angle_degrees) < 0,"第二段恢复身侧挑斩至肩侧")
	host.expect_true(is_zero_approx(float(data.poses.sword_3_07.angle_degrees)),"第三段从肩侧起势完成向前突刺")
	for combo in [1,2]:
		var finish: Dictionary = data.clips["sword_%d" % combo].frames[-1]
		var next: Dictionary = data.clips["sword_%d" % (combo+1)].frames[0]
		var end_pose: Dictionary = data.poses[str(finish.pose)]
		var next_pose: Dictionary = data.poses[str(next.pose)]
		host.expect_eq(str(end_pose.sha256),str(next_pose.sha256),"第%d段终点与下一段起点的完整帧图像一致" % combo)
		host.expect_eq(end_pose.hand,next_pose.hand,"第%d段终点与下一段起点的手臂握点一致" % combo)
	host.expect_eq(WeaponRuntime.module("sword").effects,["sword_down","sword_up","sword_thrust"],"三段对应下劈、上挑和突刺剑光")
	rig.free()
	return true
