extends RefCounted
## 战斗演练独立契约：验证新资源包七动作，禁止以旧待机资源替代。
func run(ctx) -> bool:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_combat_b04.json"))
	var visual_script: GDScript = load("res://scripts/enemies/combat_enemy_visual.gd")
	for enemy_id: String in config.enemy_order:
		var actor = visual_script.new()
		actor.call("_ready")
		var configured: bool = actor.configure(StringName(enemy_id), config.catalog_paths, config.aliases, float(config.sprite_scale))
		ctx.expect_true(configured, "%s 新战斗素材可装载" % enemy_id)
		var complete := true
		var root := Vector2.ZERO
		for action: StringName in [&"idle", &"move", &"telegraph", &"attack", &"recover", &"hurt", &"death"]:
			complete = complete and actor.entries.has(action)
			if not actor.entries.has(action):
				continue
			var e: Dictionary = actor.entries[action]
			var count := 8 if action == &"death" else 4
			complete = complete and actor.body.sprite_frames.get_frame_count(action) == count
			var anchor := Vector2(e.anchor[0], e.anchor[1])
			if action == &"idle":
				root = anchor
			complete = complete and anchor == root
		ctx.expect_true(complete, "%s 新素材七动作完整且锚点一致" % enemy_id)
		actor.play_action(&"attack", false, float(config.attack_duration))
		var offset: Vector2 = actor.body.offset
		actor.play_action(&"attack", true, float(config.attack_duration))
		ctx.expect_true(actor.scale.x < 0.0 and actor.body.offset == offset, "%s 战斗动作镜像保持语义根" % enemy_id)
		actor.free()
	return true
