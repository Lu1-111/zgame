extends SceneTree
## 真实引擎中渲染握点占位、原武器和替换武器；每一行同帧同锚点。
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	RenderingServer.set_default_clear_color(Color("#111521"))
	var container := Node2D.new()
	root.add_child(container)
	for col in 4:
		var label := Label.new()
		label.position=Vector2(25+col*150,6)
		label.add_theme_font_override("font",RPGSkin.font())
		label.add_theme_font_size_override("font_size",12)
		label.text=["握点占位","原武器","铜金示例","霜蓝示例"][col]
		container.add_child(label)
	var frames := (load("res://assets/PROCESSED/characters/CHR-01/v001/godot/CHR-01_sprite_frames.tres") as SpriteFrames).duplicate(true)
	WeaponRuntime.inject_animations(frames)
	var names := ["sword_1","hammer_1","staff_sweep","guard_rifle"]
	for row in names.size():
		var name: String=names[row]
		var frame: Dictionary=WeaponAppearance.manifest().animations[name].frames[0]
		for col in 4:
			var sprite := Sprite2D.new()
			sprite.centered=false
			sprite.texture=WeaponAppearance.frame_texture(name,0,frames.get_frame_texture(name,0),["placeholder","original","bronze","frost"][col])
			sprite.offset=-Vector2(frame.anchor[0],frame.anchor[1])
			sprite.position=Vector2(90+col*150,100+row*80)
			sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			container.add_child(sprite)
	for tick in 4:await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/previews/weapon_appearances"))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/weapon_appearances/layers.png"))
	print("WEAPON APPEARANCE CAPTURE: placeholder / original / bronze / frost")
	quit(0)
