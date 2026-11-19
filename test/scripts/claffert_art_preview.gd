extends Node2D
## 独立美术查看场景，没有敌人AI、碰撞、掉落或关卡连接。
var sprites: Array[AnimatedSprite2D] = []

func _ready() -> void:
	var viewport := get_viewport_rect().size
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses/claffert.json"))
	var forest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/forest_01.json"))
	var backdrop := Sprite2D.new()
	backdrop.texture = load(forest.background)
	backdrop.centered = false
	backdrop.scale = viewport/backdrop.texture.get_size()
	backdrop.modulate = Color(0.32,0.36,0.4)
	backdrop.z_index = -20
	add_child(backdrop)
	for phase in [1,2]:
		var sprite := AnimatedSprite2D.new()
		if phase == 1 and profile.art.has("unified"):
			sprite.set_script(load("res://scripts/enemies/corrumpt_art.gd"))
			sprite.set("profile",profile)
		else:
			sprite.set_script(load("res://scripts/enemies/claffert_idle_art.gd"))
			sprite.set("idle_animation","phase_%d_idle" % phase)
		sprite.position = Vector2(viewport.x*(0.25 if phase == 1 else 0.75),viewport.y-48)
		if phase == 2:
			sprite.position.y = viewport.y*float(profile.art.get("phase_2_preview_center_y",0.52))
		var canvas: Array = profile.art.native_cell["phase_%d_idle" % phase]
		sprite.scale = Vector2.ONE*(minf(viewport.x/2-20,float(profile.art.preview_width))/float(canvas[0]))
		if profile.art.has("pixel"):
			sprite.scale = Vector2.ONE*float(profile.art.pixel.get("render_scale",1))
		if phase == 2 and profile.art.has("visible_widths") and not profile.art.has("pixel"):
			sprite.scale = Vector2.ONE*float(profile.art.get("phase_2_preview_visible_width",260))/float(profile.art.visible_widths.phase_2_idle)
		add_child(sprite)
		sprites.append(sprite)
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = str(profile.name)+" · 两阶段闲置"
	title.position = Vector2(20,12)
	title.add_theme_font_override("font",RPGSkin.font())
	title.add_theme_font_size_override("font_size",18)
	title.add_theme_color_override("font_color",Color("#e4dce6"))
	layer.add_child(title)
	for phase in [1,2]:
		var caption := Label.new()
		caption.text = "%s · %s · 基础生命%d" % ["Ⅰ" if phase == 1 else "Ⅱ",profile.phases[phase-1].name,int(profile.phases[phase-1].base_hp)]
		caption.position = Vector2(viewport.x*(0.25 if phase == 1 else 0.75)-128,viewport.y-34)
		caption.add_theme_font_override("font",RPGSkin.font())
		caption.add_theme_font_size_override("font_size",12)
		caption.add_theme_color_override("font_color",Color("#ded3df"))
		layer.add_child(caption)
