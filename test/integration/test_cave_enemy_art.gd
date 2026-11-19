extends SceneTree
## 检查七种洞穴敌怪的原生逐帧资源、实际播放和不写正式存档的检视入口。
var checks := 0
var failures := 0
var playback_timings: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://test/scenes/cave_enemy_gallery.tscn")
	for tick in 8: await process_frame
	var gallery := current_scene
	var cfg: Dictionary = gallery.cfg
	_expect(is_equal_approx(float(cfg.animation_speed_multiplier),0.75),"新增洞穴敌怪统一0.75倍播放")
	_expect(cfg.enemies.size()==7 and cfg.effects.size()==4,"七种敌怪与四种独立效果")
	_expect(root.get_node("SaveSystem").save_game()==ERR_UNAVAILABLE,"检视页禁止保存旅途")
	var total_frames := 0
	var action_count := 0
	for index in cfg.enemies.size():
		var row: Dictionary = cfg.enemies[index]
		for key in ["base_hp","base_damage","poise"]:
			_expect(row[key]==null,"未擅填战斗数值："+row.id+"/"+key)
		_expect(row.resist.physical==null and row.resist.magic==null,"双抗保持待定")
		gallery.select_enemy(index)
		var actor: AnimatedSprite2D = gallery.actor
		_expect(actor.scale==Vector2.ONE and actor.offset==-Vector2(row.anchor[0],row.anchor[1]),"固定原生比例与锚点："+row.id)
		for action_index in row.actions.size():
			var action: Dictionary = row.actions[action_index]
			gallery.select_action(action_index)
			var name := StringName(str(action.id))
			var frames := actor.sprite_frames
			_expect(is_equal_approx(frames.get_animation_speed(name),float(action.base_fps)*0.75) and actor.speed_scale==1.0,"资源帧率0.75倍且未二次减速")
			_expect(frames.has_animation(name) and frames.get_frame_count(name)==action.frames.size(),"实际帧资源完整："+row.id+"/"+action.id)
			for frame_index in frames.get_frame_count(name):
				var texture := frames.get_frame_texture(name,frame_index)
				_expect(texture!=null and texture.get_size()==Vector2(row.canvas[0],row.canvas[1]),"每帧保持同一画布")
				total_frames+=1
			frames.set_animation_loop(name,false)
			# 资源切换所在帧的delta含同步加载耗时，先跨过两帧再测全新播放，避免把加载前时间算进动作。
			for tick in 2:await process_frame
			actor.stop()
			var started := Time.get_ticks_msec()
			actor.play(name)
			await actor.animation_finished
			var elapsed := float(Time.get_ticks_msec()-started)/1000.0
			playback_timings.append({"entity":row.id,"action":action.id,"expected_seconds":action.duration_seconds,"actual_seconds":elapsed})
			_expect(absf(elapsed-float(action.duration_seconds))<0.09,"完整实播时长增加至原4/3：%s/%s 实测%.3f秒/目标%.3f秒" % [row.id,action.id,elapsed,float(action.duration_seconds)])
			_expect(actor.frame==frames.get_frame_count(name)-1,"完整动作播至末帧")
			action_count+=1
	for index in cfg.effects.size():
		gallery.select_effect(index+1)
		var row: Dictionary = cfg.effects[index]
		var effect: AnimatedSprite2D = gallery.effect
		var frames := effect.sprite_frames
		var name := frames.get_animation_names()[0]
		_expect(is_equal_approx(frames.get_animation_speed(name),float(row.actions[0].base_fps)*0.75) and effect.speed_scale==1.0,"效果同样减为0.75倍，无重复乘数")
		_expect(str(name)==str(row.actions[0].id),"效果目录动作名与SpriteFrames一致")
		_expect(effect.visible and effect.scale==Vector2.ONE,"独立效果按原生像素显示："+row.id)
		for frame_index in frames.get_frame_count(name):
			_expect(frames.get_frame_texture(name,frame_index).get_size()==Vector2(row.canvas[0],row.canvas[1]),"效果画布完整")
			total_frames+=1
		frames.set_animation_loop(name,false)
		for tick in 2:await process_frame
		effect.stop()
		var started := Time.get_ticks_msec()
		effect.play(name)
		await effect.animation_finished
		var elapsed := float(Time.get_ticks_msec()-started)/1000.0
		playback_timings.append({"entity":row.id,"action":str(name),"expected_seconds":row.actions[0].duration_seconds,"actual_seconds":elapsed})
		_expect(absf(elapsed-float(row.actions[0].duration_seconds))<0.09,"效果完整实播时长同步增加：%s 实测%.3f秒/目标%.3f秒" % [row.id,elapsed,float(row.actions[0].duration_seconds)])
	_expect(action_count==27 and total_frames==184,"27套本体动作，共184张本体与效果帧")
	var output := FileAccess.open("res://work/qa/cave_enemy_playback_timings.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(playback_timings,"\t"))
	print("CAVE ENEMY ART: %d checks / %d failures / %d actions / %d frames" % [checks,failures,action_count,total_frames])
	quit(1 if failures else 0)

func _expect(condition: bool, label: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: "+label)
