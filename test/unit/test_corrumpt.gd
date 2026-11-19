extends RefCounted
## 选招和伤害纯函数验收，不依赖画面或概率偶然命中。
func run(ctx) -> bool:
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses/claffert.json"))
	var cfg: Dictionary = profile.combat
	ctx.expect_true(profile.id == "corrumpt" and profile.combat_enabled and cfg.implemented_phase == 2,"corrumpt双阶段已开放")
	ctx.expect_true(cfg.moves.size() == 6 and cfg.moves.slam.reach_body_lengths >= 3 and cfg.moves.slam.reach_body_lengths <= 4,"六招齐全，砸击伸展3至4身位")
	ctx.expect_true(cfg.moves.slam.hold_seconds == 0.2 and cfg.moves.slam.swing_seconds == 0.5 and cfg.moves.slam.swing_frames.size() >= 6,"砸击停顿0.2秒、六个中间帧挥落0.5秒")
	ctx.expect_true(cfg.moves.spikes.delay_seconds == 1.5 and cfg.moves.spikes.active_seconds == 0.4 and cfg.moves.spikes.spawn_interval == 0.2 and cfg.moves.spikes.spacing == cfg.moves.spikes.width,"地刺红光后等1.5秒，每0.2秒相邻推进，每道存活0.4秒")
	ctx.expect_true(is_equal_approx(float(cfg.attack_chance),1.0/3) and cfg.cooldown == 2 and cfg.moves.repel.cooldown == 0,"主攻击每秒1/3，冷却2秒，震退按近距离累计4秒触发")
	ctx.expect_true(cfg.moves.needles.visual_size == [40.0,16.0] and cfg.moves.needles.homing_seconds == 0 and cfg.moves.needles.lifetime == 0 and cfg.moves.needles.fan_step_degrees == 15,"40×16飞针不再追踪，瞄准中央针并按15度间隔展开")
	ctx.expect_eq(float(profile.art.pixel.render_scale),1.0,"与玩家和小怪相同，每个原生像素对应一个世界单位")
	var unified: Dictionary = profile.art.unified
	var hero := Image.load_from_file(ProjectSettings.globalize_path(unified.player_reference))
	var body := Image.load_from_file(ProjectSettings.globalize_path(str(profile.art.root)+"frames/phase_1_idle/00.png"))
	ctx.expect_eq(body.get_used_rect().size.y,hero.get_used_rect().size.y*2,"Boss实际透明包围高度为两个闲置角色高")
	ctx.expect_true(body.get_used_rect().size.y == 84 and profile.art.pixel.body_canvas == [128.0,128.0],"本体可见高度84像素，固定128×128画布")
	ctx.expect_true(cfg.moves.slam.lift_height > float(unified.body_visible_height) and unified.raise_heights[-1] == cfg.moves.slam.lift_height,"抬起触手高于花苞冠顶")
	ctx.expect_true(unified.arm_fit == "isotropic_reach" and unified.ring_rendering.pixel_pitch == 1,"触手等比采样，扩散圆环保持一个世界单位的原生纹素")
	for index in 4:
		var idle := Image.load_from_file(ProjectSettings.globalize_path(str(profile.art.root)+"frames/arm_idle/%02d.png" % index))
		var visible_pixels := 0
		for y in idle.get_height():
			for x in idle.get_width():
				var side_x := x-float(unified.arm_anchor[0])+float(unified.arm_attachment[0])
				var floor_y := y-float(unified.arm_anchor[1])+float(unified.arm_attachment[1])
				if side_x > float(unified.body_visible_width)/2 and floor_y <= 0 and idle.get_pixel(x,y).a > 0:
					visible_pixels += 1
		ctx.expect_true(visible_pixels > 16,"待机帧%d左右镜像后均有清晰露出本体的触手，不会整根缩没" % index)
	for index in 8:
		var old := Image.load_from_file(ProjectSettings.globalize_path(str(unified.body_runtime_reference_root)+"frames/phase_1_idle/%02d.png" % index))
		var current := Image.load_from_file(ProjectSettings.globalize_path(str(profile.art.root)+"frames/phase_1_idle/%02d.png" % index))
		ctx.expect_true(old.get_data() == current.get_data(),"特效重绘不修改已确认本体第%d帧" % index)
	var allowed_colors: Dictionary = {}
	for hex: String in unified.palette:
		allowed_colors[Color(hex).to_rgba32()] = true
	for name: String in profile.art.pixel.animations:
		for index in profile.art.pixel.animations[name].frames.size():
			var image := Image.load_from_file(ProjectSettings.globalize_path(str(profile.art.root)+"frames/%s/%02d.png" % [name,index]))
			var valid := true
			for y in image.get_height():
				for x in image.get_width():
					var color := image.get_pixel(x,y)
					if color.a != 0 and (color.a != 1 or not allowed_colors.has(color.to_rgba32())):
						valid = false
			ctx.expect_true(valid,"%s帧%d沿用本体色板与硬透明原生像素" % [name,index])
			if unified.effect_sizes.has(name):
				var size: Array = unified.effect_sizes[name]
				ctx.expect_true(image.get_size() == Vector2i(size[0],size[1]),"%s帧%d按世界尺寸烘焙，无运行二次缩放" % [name,index])
	# 对每张完整对照帧逐像素验证同一本体，触手不得覆盖或替换本体的外形、纹样与颜色。
	var anchor := Vector2i(unified.preview_anchor[0],unified.preview_anchor[1])-Vector2i(unified.body_anchor[0],unified.body_anchor[1])
	for name: String in ["phase_1_idle","slam","slam_downstroke","spikes","needles","gravity","spores","repel"]:
		for index in profile.art.pixel.animations[name].frames.size():
			var full := Image.load_from_file(ProjectSettings.globalize_path(str(profile.art.root)+"preview_frames/%s/%02d.png" % [name,index]))
			var identical := true
			for y in body.get_height():
				for x in body.get_width():
					if body.get_pixel(x,y).a >= 0.5 and body.get_pixel(x,y) != full.get_pixel(x+anchor.x,y+anchor.y):
						identical = false
			ctx.expect_true(identical,"%s帧%d的花苞本体逐像素相同" % [name,index])
	for action_name: String in profile.art.pixel.animations:
		var action: Dictionary = profile.art.pixel.animations[action_name]
		if action.kind != "body":
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(str(profile.art.root)+"frames/%s/00.png" % action_name))
		var colors: Dictionary = {}
		for y in image.get_height():
			for x in image.get_width():
				var color := image.get_pixel(x,y)
				if color.a > 0:
					colors[color.to_rgba32()] = true
		ctx.expect_true(colors.size() <= 32,"%s正式低分辨率图像实际颜色不超过32种" % action_name)
	ctx.expect_true(cfg.moves.needles.count == 10 and cfg.moves.spores.count == 7 and cfg.moves.spores.lifetime == 8 and cfg.moves.spores.max_bounces == 2 and cfg.moves.spores.damage_multiplier == 1,"一阶段十针、七方向孢子，孢子第二次反弹或8秒消失")
	var brain := CorrumptBrain.new()
	brain.configure(cfg,42)
	brain.paralysis_seconds = EnemyStats.paralysis_seconds(profile.phases[0])
	var near := {"alive":true,"near":true,"close":false,"spores":false}
	var far := {"alive":true,"near":false,"close":false,"spores":false}
	ctx.expect_eq(brain.eligible_weights(near),{"slam":40.0,"spikes":40.0,"needles":20.0},"同层近距离权重40/40/20")
	ctx.expect_eq(brain.eligible_weights(far),{"needles":30.0,"spores":30.0,"gravity":40.0},"远距离飞针/孢子/引力30/30/40")
	var occupied := far.duplicate()
	occupied.spores = true
	ctx.expect_eq(brain.eligible_weights(occupied),brain.eligible_weights(far),"有无孢子不改变主招式候选")
	ctx.expect_true(brain.tick(0.001,near).size() == 1 and brain.move in [&"slam",&"spikes"],"进入近战范围立即随机砸击或地刺")
	brain.begin_attack(near,&"gravity")
	ctx.expect_true(not brain.paralyze(),"施法期不进入瘫痪")
	ctx.expect_true(brain.finish_attack(near) in [&"slam",&"spikes"] and brain.state == &"casting","引力后重新检测近战范围，立即串招")
	brain.finish_attack(near)
	brain.tick(1.99,near)
	ctx.expect_eq(brain.state,&"cooldown","攻击后完整两秒冷却")
	brain.tick(0.01,near)
	ctx.expect_eq(brain.state,&"ready","冷却结束回准备")
	ctx.expect_true(brain.paralyze(),"准备期可破韧")
	brain.tick(3.99,far)
	ctx.expect_eq(brain.state,&"paralyzed","一阶段300韧性瘫痪持续四秒")
	var wake := brain.tick(0.01,far)
	ctx.expect_true(wake.size() == 2 and wake[0] == &"recover_poise" and brain.state == &"casting","瘫痪结束恢复韧性并立即攻击")
	brain.state = &"casting"
	brain.close_accumulated = 0
	var close := far.duplicate()
	close.close = true
	ctx.expect_true(not brain.tick(3.99,close).has(&"repel"),"近距离累计不足4秒不震退")
	ctx.expect_true(brain.tick(0.02,close).has(&"repel"),"累计4秒震退，不受主招式限制")
	var distribution := {"needles":0,"spores":0,"gravity":0}
	for index in 2000:
		distribution[String(brain.begin_attack(far))] += 1
	for name in distribution:
		ctx.expect_true(absf(float(distribution[name])/2000-float(cfg.far_weights[name])/100) < 0.04,"远程招式按30/30/40权重抽取")
	var defense := {"defense":0,"resist":{"physical":25,"magic":75}}
	var physical := DamagePacket.new(100)
	var magic := DamagePacket.new(100,DamagePacket.DamageType.MAGIC)
	ctx.expect_eq(EnemyStats.damage_taken(defense,physical,120),75,"物理抗性只减物理伤害")
	ctx.expect_eq(EnemyStats.damage_taken(defense,magic,120),25,"奶术抗性只减奶术伤害")
	ctx.expect_eq(EnemyStats.resolve(defense,{"enemy_multiplier":3}).resist,defense.resist,"抗性不乘区域倍率")
	defense.defense = 120
	physical.ignore_defense = true
	ctx.expect_eq(EnemyStats.damage_taken(defense,physical,120),75,"无视防御仍受抗性减伤")
	var enemies: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for enemy: Dictionary in enemies.enemies:
		ctx.expect_true(enemy.has("base_hp") and enemy.has("base_damage") and enemy.poise > 0 and enemy.resist == {"physical":0.0,"magic":0.0},"%s完整登记基础属性、韧性与双抗0" % enemy.id)
	ctx.expect_eq(profile.resist,{"physical":0.0,"magic":0.0},"corrumpt双抗0")
	return true
