extends SceneTree
## 同比例核对三段独立刀光、角色挥剑与大型剑气的画面。
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(960,520)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var background := ColorRect.new()
	background.color = Color("#20221d")
	background.size = Vector2(view.size)
	view.add_child(background)
	var module := WeaponRuntime.module("sword")
	for index in 3:
		var group := Node2D.new()
		group.position = Vector2(index*320,18)
		group.scale = Vector2.ONE*3
		view.add_child(group)
		var rig := PixelHeroRig.new()
		group.add_child(rig)
		rig.position = Vector2(42,76)
		rig.combo = index+1
		rig.progress = 4.0/7
		rig.apply_pose()
		var fx := AnimatedSprite2D.new()
		var kind := str(module.effects[index])
		fx.sprite_frames = WeaponRuntime.effect_frames(kind)
		fx.scale = WeaponRuntime.effect_scale(kind)
		fx.position = rig.position+Vector2(module.sockets[index][0],module.sockets[index][1]-17)
		group.add_child(fx)
		fx.frame = 2 if index != 2 else 1
		_label(view,["Ⅰ  纵斩","Ⅱ  挑斩","Ⅲ  横斩"][index],Vector2(index*320+104,14))
	var blade := AnimatedSprite2D.new()
	blade.sprite_frames = WeaponRuntime.effect_frames("sword_wave",true)
	blade.scale = WeaponRuntime.effect_scale("sword_wave")*1.7
	blade.position = Vector2(500,410)
	view.add_child(blade)
	blade.frame = 1
	_label(view,"剑气",Vector2(130,384))
	_label(view,"沿路径贯穿 · 540 像素",Vector2(655,406))
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := view.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/sword_effects_v5.png"))
	print("Sword effects preview: %d" % error)
	quit(error)

func _label(parent: Node, text: String, point: Vector2) -> void:
	var label := Label.new()
	label.position = point
	label.text = text
	label.add_theme_font_override("font",RPGSkin.font())
	label.add_theme_font_size_override("font_size",18)
	label.add_theme_color_override("font_color",Color("#dad3ba"))
	parent.add_child(label)
