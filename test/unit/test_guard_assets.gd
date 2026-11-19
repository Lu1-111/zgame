extends RefCounted
## 检查四种格挡共用动作规格并使用完整、原生像素密度的逐帧素材。

## 验证动画帧数、锚点和原角色五官轮廓，以及当前减伤规则。
func run(host) -> bool:
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/guard_frames.json"))
	var motion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/hero_motion.json"))
	var combat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_presentation.json"))
	host.expect_eq(art.weapons.size(),4,"四类武器都有格挡完整逐帧素材")
	host.expect_eq(art.poses.size(),int(motion.guard.hold_frame)+1,"举起帧数与维持帧索引一致")
	host.expect_eq(float(motion.guard.damage_reduction),0.5,"无技能普通格挡减伤50%")
	host.expect_eq(str(art.body_pipeline),"native_character_frames","格挡直接保留原角色肩臂，不重新绘制细线手臂")
	var offset := Vector2i(art.anchor[0]-art.native_anchor[0],art.anchor[1]-art.native_anchor[1])
	for pose: Dictionary in art.poses:
		var source: Dictionary = motion.native_motion.frames[pose.source]
		host.expect_eq(FileAccess.get_sha256(pose.source_path),pose.source_sha256,"身体与手臂源自当前攻击帧："+str(pose.source))
		host.expect_eq(pose.source_path,source.path,"身体来源对应正式攻击帧："+str(pose.source))
		host.expect_eq(FileAccess.get_sha256(pose.body_path),pose.body_sha256,"完整身体像素来源可追溯："+str(pose.source))
	host.expect_true(float(art.poses[-1].hand[1]) >= float(art.pose_contract.hold_hand_min_y),"维持帧双手架在胸前，不抬到头部")
	var hashes := {}
	for kind: String in art.weapons:
		var spec: Dictionary = combat.animations["guard_"+kind]
		var source: Dictionary = art.weapon_sources[kind]
		if source.has("renderer"):
			host.expect_eq(FileAccess.get_sha256(source.renderer),source.sha256,kind+"复用原攻击武器绘制器，未另外定义外形")
			host.expect_eq(FileAccess.get_sha256("res://data/hero_motion.json"),source.motion_sha256,kind+"使用攻击武器当前尺寸与配色")
		else:
			host.expect_eq(FileAccess.get_sha256(source.path),source.sha256,kind+"直接提取正式攻击帧中的武器像素")
			host.expect_eq(source.path,motion.native_motion.frames[source.frame].path,kind+"武器来源与攻击帧一一对应")
			if source.has("complete_handle"):
				host.expect_eq(FileAccess.get_sha256(source.complete_handle.reference),source.complete_handle.reference_sha256,kind+"完整握柄沿用原攻击握柄的像素色板")
		host.expect_true(source.animation in combat.weapon_modules[kind].animations,kind+"格挡武器对应当前普攻模组")
		host.expect_eq(spec.frame_paths.size(),art.poses.size(),kind+"使用相同的动作帧数")
		host.expect_eq(float(spec.fps),1.0/float(motion.guard.raise_frame_seconds),kind+"使用相同准备时序")
		for index in spec.frame_paths.size():
			var image := Image.load_from_file(ProjectSettings.globalize_path(spec.frame_paths[index]))
			host.expect_eq(image.get_size(),Vector2i(art.canvas[0],art.canvas[1]),"完整格挡画布：%s/%d" % [kind,index])
			host.expect_eq(spec.anchors[index],art.anchor,"原人物尺寸与脚底锚点：%s/%d" % [kind,index])
			var hash := FileAccess.get_sha256(spec.frame_paths[index])
			host.expect_true(not hashes.has(hash),"武器外形独立：%s/%d" % [kind,index])
			hashes[hash] = true
			host.expect_eq(FileAccess.get_sha256(source.frames[index].weapon_path),source.frames[index].weapon_sha256,"同源武器图层：%s/%d" % [kind,index])
			if index == int(motion.guard.hold_frame):
				var layer := Image.load_from_file(ProjectSettings.globalize_path(source.frames[index].weapon_path))
				var top := layer.get_used_rect().position.y-offset.y
				host.expect_true(top >= int(art.pose_contract.hold_weapon_min_y),kind+"维持帧武器位于身前且不越过头顶")
			var pose: Dictionary = art.poses[index]
			var native := Image.load_from_file(ProjectSettings.globalize_path(pose.source_path))
			var weapon := Image.load_from_file(ProjectSettings.globalize_path(source.frames[index].weapon_path))
			var preserved := true
			var checked := 0
			for region: Array in pose.arm_regions:
				for y in range(int(region[1]),int(region[1]+region[3])):
					for x in range(int(region[0]),int(region[0]+region[2])):
						var point := Vector2i(x,y)
						var masked := false
						for rect: Array in pose.weapon_masks:
							masked = masked or Rect2i(rect[0],rect[1],rect[2],rect[3]).has_point(point)
						var color := native.get_pixel(x+int(pose.source_origin[0]),y+int(pose.source_origin[1]))
						if masked or color.a < 0.9 or weapon.get_pixelv(point+offset).a > 0.05 or (color.b > color.r*1.015 and color.b > color.g*1.005):
							continue
						checked += 1
						preserved = preserved and _same_rgb(image.get_pixelv(point+offset),color,2)
			host.expect_true(checked > 50 and preserved,"未被武器遮挡的肩臂保留攻击原轮廓与色板：%s/%d" % [kind,index])
			var visible := true
			var weapon_pixels := 0
			for y in weapon.get_height():
				for x in weapon.get_width():
					var color := weapon.get_pixel(x,y)
					if color.a < 0.9:
						continue
					var palm := false
					for region: Array in pose.palm_regions:
						palm = palm or Rect2i(region[0],region[1],region[2],region[3]).has_point(Vector2i(x,y)-offset)
					if palm:
						continue
					weapon_pixels += 1
					visible = visible and _same_rgb(image.get_pixel(x,y),color,4)
			host.expect_true(weapon_pixels > 30 and visible,"掌指以外武器全部可见，不用胸腹或整条手臂遮掉握柄与枪身：%s/%d" % [kind,index])
	return true


func _same_rgb(a: Color, b: Color, tolerance: int) -> bool:
	return absi(a.r8-b.r8) <= tolerance and absi(a.g8-b.g8) <= tolerance and absi(a.b8-b.b8) <= tolerance
