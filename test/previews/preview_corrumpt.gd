extends SceneTree
## 离屏复现左右砸击与六招画面，不自动打开可见游戏实例。
var boss: Node
var player: Node

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	change_scene_to_file("res://test/scenes/previews/corrumpt_arena.tscn")
	for index in 12:
		await process_frame
	boss = current_scene.boss
	player = current_scene.player
	boss.set_physics_process(false)
	player.set_physics_process(false)
	player.position = Vector2(470,543)
	player.cam.set_physics_process(false)
	player.cam.global_position = Vector2(690,365)
	player.cam.reset_smoothing()
	var output := "res://work/corrumpt_pixel/capture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	# 两次砸击按真实预警、击中、收招时序渲染完整序列。
	var frame_index := 0
	var playlist := "ffconcat version 1.0\n"
	var cfg: Dictionary = boss.profile.combat.moves.slam
	var stages: Array = []
	for index in cfg.raise_frames.size():
		stages.append([float(index)/cfg.raise_frames.size()*float(cfg.raise_seconds),float(cfg.raise_seconds)/cfg.raise_frames.size()])
	stages.append([float(cfg.raise_seconds),float(cfg.hold_seconds)])
	var swing := float(cfg.raise_seconds)+float(cfg.hold_seconds)
	for index in cfg.swing_frames.size():
		stages.append([swing+float(index)/cfg.swing_frames.size()*float(cfg.swing_seconds),float(cfg.swing_seconds)/cfg.swing_frames.size()])
	var landing := swing+float(cfg.swing_seconds)
	stages.append([landing,float(cfg.active_seconds)])
	for index in cfg.recovery_frames.size():
		stages.append([landing+float(cfg.active_seconds)+float(index)/cfg.recovery_frames.size()*float(cfg.recovery_seconds),float(cfg.recovery_seconds)/cfg.recovery_frames.size()])
	stages.append([landing+float(cfg.active_seconds)+float(cfg.recovery_seconds),0.25])
	for side in [-1,1]:
		player.position = boss.position+Vector2(side*180,-17)
		player.cam.global_position = boss.position+Vector2(side*90,-110)
		player.cam.reset_smoothing()
		boss.request_attack(&"slam")
		for stage: Array in stages:
			boss.brain.elapsed = float(stage[0])+0.0001
			boss._tick_attack()
			await _draw_frame(output+"/%03d.png" % frame_index)
			playlist += "file 'capture/%03d.png'\nduration %.8f\n" % [frame_index,float(stage[1])]
			frame_index += 1
	playlist += "file 'capture/%03d.png'\n" % (frame_index-1)
	FileAccess.open("res://work/corrumpt_pixel/slam_preview.txt",FileAccess.WRITE).store_string(playlist)
	# 静帧使用真正实体以检查透明度、尺寸、对齐和各招式外观。
	for entry: Array in [["slam",landing+float(cfg.active_seconds)*0.5],["spikes",1.55],["needles",0.52],["gravity",0.4],["spores",0.68],["repel",0.1]]:
		for entity in get_nodes_in_group(&"corrumpt_entities"):
			entity.queue_free()
		await process_frame
		boss.brain.state = &"ready"
		boss.brain.elapsed = 0
		player.position = boss.position+Vector2(-180,-17)
		player.cam.global_position = boss.position+Vector2(-90,-110)
		player.cam.reset_smoothing()
		if entry[0] == "repel":
			boss.brain.state = &"ready"
			boss._repel()
			boss.visual.pose(&"repel",2,-1)
		else:
			boss.request_attack(StringName(entry[0]))
			boss._physics_process(float(entry[1]))
		for entity in get_nodes_in_group(&"corrumpt_entities"):
			entity.set_physics_process(false)
			if entity.kind == &"spike":
				entity._physics_process(entity.lifetime*0.5)
			if entity.kind in [&"gravity_ring",&"repel_ring"]:
				entity.age = entity.lifetime*0.4
				entity._tick_ring()
		await _draw_frame("res://docs/previews/corrumpt_%s.png" % entry[0])
	print("CORRUMPT PREVIEW: %d native pixel poses with exact stage durations / 6 move captures" % frame_index)
	quit()

func _draw_frame(path: String) -> void:
	for index in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
