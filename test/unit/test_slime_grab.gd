extends RefCounted
## 验证红色警告的可见时段、新动作资源以及旧动作仍可使用。
func run(ctx) -> bool:
	var base := "res://assets/PROCESSED/enemies/ENM-SLIME-GRAB/v001/"
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "catalog.json"))
	var full: Dictionary = catalog.effects.back()
	ctx.expect_eq(full.frames.size(), 16, "史莱姆抓取保留16个完整动作帧")
	var region: Array = catalog.warningRegion
	var sign_timing := true
	for n in full.frames.size():
		var texture: Texture2D = load(base + str(full.frames[n]))
		var image: Image = texture.get_image()
		var red := 0
		for y in range(int(region[1]), int(region[1] + region[3])):
			for x in range(int(region[0]), int(region[0] + region[2])):
				var c := image.get_pixel(x, y)
				if c.a >= 0.5 and c.r >= 0.67 and c.g < 0.35 and c.b < 0.4 and c.r > c.g * 1.7:
					red += 1
		var expected: bool = n in [1, 2, 3]
		sign_timing = sign_timing and (red > 2) == expected
	ctx.expect_true(sign_timing, "红色感叹号仅在蓄势帧出现，伸手前完全消失")
	var resource: SpriteFrames = load(base + "godot/ENM-03_all_actions.tres")
	ctx.expect_true(resource.has_animation(&"idle") and resource.has_animation(&"death"), "新增抓取未删除史莱姆原有动作")
	ctx.expect_eq(resource.get_frame_count(&"grab_ready"), 4, "抓取蓄势4帧")
	ctx.expect_eq(resource.get_frame_count(&"grab_attack"), 8, "触手伸出与闭合8帧")
	ctx.expect_eq(resource.get_frame_count(&"grab_recover"), 4, "触手释放与收回4帧")
	for config_name: String in ["enemy_presentation", "enemy_combat_b04"]:
		var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + config_name + ".json"))
		var tuning: Dictionary = config.per_enemy.milk_slime
		ctx.expect_eq(tuning.animation_map.attack, "grab_attack", config_name + " 已启用触手抓取")
		ctx.expect_true(float(tuning.attack_hit_start) >= float(tuning.attack_duration) * 5.0 / 8.0, config_name + " 命中延后到触手闭合")
	return true
