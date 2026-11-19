extends RefCounted
## 敌人素材契约：每个游戏编号都有循环待机，专属特效可装载，镜像不改变语义根。
const EFFECT_ENEMIES := ["moss_beetle", "lamp_bug", "acid_slug", "moss_guard", "hive_guard", "acid_mother"]

func run(ctx) -> bool:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_presentation.json"))
	var visual_script: GDScript = load("res://scripts/enemies/enemy_visual.gd")
	var db: Node = ctx.fetch_singleton("DataDB", "res://scripts/autoload/data_db.gd")
	db.load_all()
	for enemy_id: String in config.enemy_order:
		var actor = visual_script.new()
		actor.call("_ready")
		var configured: bool = actor.configure(
			StringName(enemy_id), config.catalog_paths, config.aliases,
			float(config.sprite_scale), config.sprite_resources
		)
		ctx.expect_true(configured, "%s 正式待机素材可装载" % enemy_id)
		ctx.expect_true(
			configured and actor.body.visible and actor.body.is_playing()
			and actor.body.sprite_frames.get_frame_count(&"idle") > 1
			and actor.body.sprite_frames.get_animation_loop(&"idle"),
			"%s 原地循环播放多帧 idle" % enemy_id
		)
		var offset: Vector2 = actor.body.offset
		actor.play_action(&"idle", true)
		ctx.expect_true(actor.scale.x < 0.0 and actor.body.offset == offset, "%s 镜像保持语义根" % enemy_id)
		ctx.expect_true(not actor.effect.visible, "%s 待机不自动播放攻击特效" % enemy_id)
		if enemy_id in EFFECT_ENEMIES:
			var loaded: bool = actor.effects.has(&"attack")
			if loaded:
				var effect: Dictionary = actor.effects[&"attack"]
				loaded = actor.effect.sprite_frames.get_frame_count(StringName(str(effect.name))) == 6
			ctx.expect_true(loaded, "%s 六帧专属特效已接入" % enemy_id)
		ctx.expect_true(not db.get_enemy(StringName(enemy_id)).is_empty(), "%s 与战斗表编号一致" % enemy_id)
		actor.free()
	return true
