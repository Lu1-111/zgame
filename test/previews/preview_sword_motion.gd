extends SceneTree
## 导出实际原生持握渲染结果；检查帧、游戏动画与慢放均来自同一动作模组。
const FRAME_DIR := "res://assets/PROCESSED/characters/CHR-01/rpg_v8/"
const PREVIEW := "res://docs/previews/sword_motion_v8.png"
const MOTION_DIR := "res://work/sword_v8/motion/"
const CELL := Vector2i(96,96)
const ANCHOR := Vector2(48,84)
var _motion_config: Dictionary
var _baked_config: Dictionary = {}


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	_motion_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/hero_motion.json"))
	var manifest := str(_motion_config.sword.get("frame_manifest",""))
	if FileAccess.file_exists(manifest):
		_baked_config = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	create_timer(55,true,false,true).timeout.connect(func() -> void: quit(2))
	for directory in [FRAME_DIR,MOTION_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var view := SubViewport.new()
	view.size = Vector2i(CELL.x*8,CELL.y*6)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var rigs: Array[PixelHeroRig] = []
	for row in 6:
		for pose in 8:
			var rig := PixelHeroRig.new()
			rig.position = Vector2(pose*CELL.x,row*CELL.y)+ANCHOR
			view.add_child(rig)
			rig.combo = row%3+1
			rig.facing = 1 if row < 3 else -1
			rig.progress = _pose_progress(rig.combo,pose)
			rig.apply_pose()
			rigs.append(rig)
	await _draw_frame()
	var sheet := view.get_texture().get_image()
	# 已接入完整逐帧素材时只生成预览，不能覆盖制作人选定的正式 PNG。
	if _baked_config.is_empty():
		for combo in 3:
			for pose in 8:
				var image := sheet.get_region(Rect2i(pose*CELL.x,combo*CELL.y,CELL.x,CELL.y))
				if image.save_png(ProjectSettings.globalize_path(FRAME_DIR+"sword_%d_%02d.png" % [combo+1,pose])) != OK:
					quit(1)
	var background := ColorRect.new()
	background.color = Color("#22241f")
	background.size = Vector2(view.size)
	view.add_child(background)
	view.move_child(background,0)
	await _draw_frame()
	var preview := view.get_texture().get_image()
	preview.resize(view.size.x*2,view.size.y*2,Image.INTERPOLATE_NEAREST)
	if preview.save_png(ProjectSettings.globalize_path(PREVIEW)) != OK:
		quit(1)
	for rig in rigs:
		rig.queue_free()
	view.size = Vector2i(1152,620)
	background.size = Vector2(view.size)
	var playback: Array[PixelHeroRig] = []
	for row in 2:
		for combo in 3:
			var group := Node2D.new()
			group.position = Vector2(combo*384+192,row*290+270)
			group.scale = Vector2.ONE*4
			view.add_child(group)
			var rig := PixelHeroRig.new()
			group.add_child(rig)
			rig.combo = combo+1
			rig.facing = 1 if row == 0 else -1
			playback.append(rig)
			_label(view,["Ⅰ  纵斩","Ⅱ  挑斩","Ⅲ  横斩"][combo],Vector2(combo*384+142,row*290+14))
	_label(view,"左右朝向 · 原生手臂与剑柄逐帧绑定 · 3 倍慢放",Vector2(316,590))
	for frame in 48:
		for rig in playback:
			rig.progress = frame/47.0
			rig.apply_pose()
		await _draw_frame()
		if view.get_texture().get_image().save_png(ProjectSettings.globalize_path(MOTION_DIR+"frame_%02d.png" % frame)) != OK:
			quit(1)
	for rig in playback:
		rig.get_parent().queue_free()
	for node in view.get_children():
		if node is Label:
			node.queue_free()
	view.size = Vector2i(768,400)
	background.size = Vector2(view.size)
	playback.clear()
	for side in 2:
		var group := Node2D.new()
		group.position = Vector2(side*384+192,310)
		group.scale = Vector2.ONE*4
		view.add_child(group)
		var rig := PixelHeroRig.new()
		group.add_child(rig)
		rig.facing = 1 if side == 0 else -1
		playback.append(rig)
	var caption := Label.new()
	caption.position = Vector2(180,16)
	caption.add_theme_font_override("font",RPGSkin.font())
	caption.add_theme_font_size_override("font_size",20)
	view.add_child(caption)
	_label(view,"连续三段 · 前段终点衔接后段起点 · 3 倍慢放",Vector2(142,365))
	var chained := ProjectSettings.globalize_path("res://work/sword_v8/chain/")
	DirAccess.make_dir_recursive_absolute(chained)
	for frame in 144:
		var combo := frame/48
		var normalized := float(frame%48)/47
		caption.text = ["Ⅰ  过顶纵斩 → 身侧","Ⅱ  身侧挑斩 → 肩侧","Ⅲ  肩侧起势 → 横斩"][combo]
		for rig in playback:
			rig.combo = combo+1
			rig.progress = _timed_progress(normalized)
			rig.apply_pose()
		await _draw_frame()
		if view.get_texture().get_image().save_png(chained+"frame_%03d.png" % frame) != OK:
			quit(1)
	print("SWORD MOTION V8: 24 transparent frames, 48 parallel frames, 144 chained frames")
	quit()


func _timed_progress(normalized: float) -> float:
	if str(_baked_config.get("time_basis","")) == "attack_duration":
		return normalized
	var module := WeaponRuntime.module("sword")
	var elapsed := normalized*(float(module.startup)+float(module.active)+float(module.recovery))
	var phases: Array = _motion_config.sword.phase_indices
	var phase: float
	if elapsed < float(module.startup):
		phase = float(phases[0])*elapsed/float(module.startup)
	elif elapsed < float(module.startup)+float(module.active):
		phase = lerpf(float(phases[0]),float(phases[1]),(elapsed-float(module.startup))/float(module.active))
	else:
		phase = lerpf(float(phases[1]),float(phases[2]),clampf((elapsed-float(module.startup)-float(module.active))/float(module.recovery),0,1))
	return phase/float(phases[2])


func _pose_progress(combo: int, pose: int) -> float:
	if not _baked_config.is_empty():
		return float(_baked_config.clips["sword_%d" % combo].frames[pose].progress)
	return pose/7.0


func _draw_frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw


func _label(parent: Node, caption: String, point: Vector2) -> void:
	var label := Label.new()
	label.position = point
	label.text = caption
	label.add_theme_font_override("font",RPGSkin.font())
	label.add_theme_font_size_override("font_size",18)
	label.add_theme_color_override("font_color",Color("#dad3ba"))
	parent.add_child(label)
