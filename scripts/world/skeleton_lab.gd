extends Node2D
## 独立骨骼实验台：左为原素材逐帧，右为原生骨骼，不触碰游戏存档。

const MODE := preload("res://scripts/player/character_animation_mode.gd")
const ORIGINAL_FRAMES := "res://assets/PROCESSED/characters/CHR-01/v001/godot/CHR-01_sprite_frames.tres"
const ROOT_SYNC := "res://assets/PROCESSED/characters/CHR-01/v001/godot/CHR-01_root_sync.gd"
const ACTIONS := [
	["闲置", "idle"], ["跑动", "run"], ["跳跃", "jump"], ["下落", "fall"],
	["落地", "land"], ["闪避", "dodge"], ["防御举起", "guard"], ["防御放下", "guard_lower"],
	["普攻 · 第一段", "attack_1"], ["普攻 · 第二段", "attack_2"], ["普攻 · 第三段", "attack_3"],
	["受击", "hurt"], ["死亡", "death"], ["坐下", "rest_enter"], ["坐火", "rest"], ["起身", "rest_exit"]
]
const WEAPONS := [["直剑", "sword"], ["奶瓶锤", "hammer"], ["步枪", "rifle"], ["奶杖", "staff"]]
var _cfg: Dictionary = {}
var _sprite: AnimatedSprite2D
var _pixel: PixelHeroRig
var _rig: Node2D
var _ui: Control
var _action: OptionButton
var _weapon: OptionButton
var _play: Button
var _timeline: HSlider
var _status: Label
var _debug: CheckButton
var _playing := true
var _speed := 1.0
var _time := 0.0
var _facing := 1
var _left_origin := Vector2(168,285)
var _right_origin := Vector2(472,285)


func _ready() -> void:
	Engine.max_fps = 60
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cfg = MODE.configuration()
	var frames := (load(ORIGINAL_FRAMES) as SpriteFrames).duplicate(true) as SpriteFrames
	WeaponRuntime.inject_animations(frames)
	var lab: Dictionary = _cfg.get("lab",{})
	var preview_scale := float(lab.get("preview_scale",5))
	var left := Node2D.new()
	left.name = "OriginalFrameReference"
	left.z_index = 20
	left.position = _left_origin
	left.scale = Vector2.ONE*preview_scale
	add_child(left)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "OriginalSprite"
	_sprite.set_script(load(ROOT_SYNC))
	_sprite.sprite_frames = frames
	_sprite.centered = false
	_sprite.pause()
	left.add_child(_sprite)
	_pixel = PixelHeroRig.new()
	_pixel.name = "OriginalPixelHeroRig"
	left.add_child(_pixel)
	var integration: Dictionary = _cfg.get("integration",{})
	var packed := load(str(integration.get("model_scene","res://scenes/player/skeletal/hero_skeleton_test.tscn"))) as PackedScene
	if packed != null:
		_rig = packed.instantiate() as Node2D
		_rig.name = "NativeSkeletonReference"
		_rig.z_index = 20
		_rig.position = _right_origin
		_rig.scale = Vector2.ONE*preview_scale
		add_child(_rig)
	_build_ui()
	_refresh_pose()
	queue_redraw()


func _draw() -> void:
	var lab: Dictionary = _cfg.get("lab",{})
	draw_rect(Rect2(0,0,640,360),Color(str(lab.get("background","#20231f"))))
	for x in [16.0,328.0]:
		draw_rect(Rect2(x,77,296,219),Color("#171b19"))
		draw_rect(Rect2(x,77,296,219),Color("#656857"),false,1)
		draw_line(Vector2(x+12,285),Vector2(x+284,285),Color("#8e8b70"),1)
		for row in range(100,280,20):
			draw_line(Vector2(x+1,row),Vector2(x+295,row),Color(0.45,0.5,0.43,0.08),1)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = RPGSkin.font()
	theme.default_font_size = 11
	_ui.theme = theme
	layer.add_child(_ui)
	_label("角色骨骼实验台",Rect2(18,9,260,23),20)
	_label("原素材切片 · 原生骨骼 / IK · 随时保留逐帧开发",Rect2(289,15,335,20),10)
	_action = OptionButton.new()
	_action.position = Vector2(18,42)
	_action.size = Vector2(122,25)
	for row in ACTIONS:
		_action.add_item(str(row[0]))
	_ui.add_child(_action)
	_action.item_selected.connect(func(_index: int) -> void: _restart())
	_weapon = OptionButton.new()
	_weapon.position = Vector2(148,42)
	_weapon.size = Vector2(90,25)
	for row in WEAPONS:
		_weapon.add_item(str(row[0]))
	_ui.add_child(_weapon)
	_weapon.item_selected.connect(func(_index: int) -> void: _restart())
	_play = _button("暂停",Rect2(246,42,56,25),_toggle_play)
	var speed := OptionButton.new()
	speed.position = Vector2(310,42)
	speed.size = Vector2(78,25)
	for value in [0.25,0.5,1.0,1.5]:
		speed.add_item("%.2f ×" % value)
	speed.select(2)
	_ui.add_child(speed)
	speed.item_selected.connect(func(index: int) -> void: _speed = [0.25,0.5,1.0,1.5][index])
	_debug = CheckButton.new()
	_debug.text = "骨架 F7"
	_debug.position = Vector2(395,42)
	_debug.size = Vector2(105,25)
	_ui.add_child(_debug)
	_debug.toggled.connect(func(_pressed: bool) -> void:
		if is_instance_valid(_rig): _rig.call("toggle_debug"))
	_button("翻转朝向",Rect2(515,42,107,25),func() -> void:
		_facing *= -1
		_refresh_pose())
	_label("原逐帧 / 现有攻击素材",Rect2(28,84,270,20),12)
	_label("Skeleton2D · 蒙皮 · 双手 IK",Rect2(340,84,275,20),12)
	_timeline = HSlider.new()
	_timeline.position = Vector2(18,305)
	_timeline.size = Vector2(390,17)
	_timeline.min_value = 0
	_timeline.max_value = 1
	_timeline.step = 0.001
	_ui.add_child(_timeline)
	_timeline.value_changed.connect(func(value: float) -> void:
		_time = value*_clip_length()
		_refresh_pose())
	_status = _label("",Rect2(420,301,205,25),10)
	_button("骨骼试玩 → 主标题",Rect2(18,331,181,23),func() -> void: _open_title("skeleton"))
	_button("逐帧试玩 → 主标题",Rect2(207,331,181,23),func() -> void: _open_title("frames"))
	_label("Space 暂停 · 鼠标瞄准步枪 · 试玩中 F6 切换",Rect2(399,332,228,20),9)


func _process(delta: float) -> void:
	if _playing:
		_time = fposmod(_time+delta*_speed,_clip_length())
	_refresh_pose()
	_timeline.set_value_no_signal(_time/_clip_length())
	_status.text = "%s   %.2f / %.2f s" % [_clip(),_time,_clip_length()]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_toggle_play()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F7:
			_debug.button_pressed = not _debug.button_pressed
			get_viewport().set_input_as_handled()


func _toggle_play() -> void:
	_playing = not _playing
	_play.text = "暂停" if _playing else "播放"


func _restart() -> void:
	_time = 0
	_refresh_pose()


func _clip() -> StringName:
	var action := str(ACTIONS[_action.selected][1])
	if action.begins_with("attack_"):
		var kind := str(WEAPONS[_weapon.selected][1])
		return StringName(kind+"_"+action.trim_prefix("attack_")) if kind in ["sword","hammer"] else StringName(kind)
	return StringName(action)


func _clip_length() -> float:
	var clips: Dictionary = _cfg.get("clips",{})
	var definition: Dictionary = clips.get(str(_clip()),{})
	return maxf(0.01,float(definition.get("length",1.0)))


func _refresh_pose() -> void:
	if _action == null:
		return
	var clip := _clip()
	var kind := str(WEAPONS[_weapon.selected][1])
	var progress := clampf(_time/_clip_length(),0,1)
	var combo := int(String(clip).get_slice("_",1)) if String(clip).begins_with("sword_") or String(clip).begins_with("hammer_") else 1
	var aim := get_global_mouse_position()-_right_origin
	var facing := (-1 if aim.x < 0 else 1) if clip == &"rifle" else _facing
	if is_instance_valid(_rig):
		_rig.call("sync_pose",clip,_time,kind,combo,aim,facing,progress)
	var pixel_active := String(clip).begins_with("sword_") or clip == &"rifle"
	_pixel.visible = pixel_active
	_sprite.visible = not pixel_active
	_sprite.pause()
	if pixel_active:
		_pixel.kind = "rifle" if clip == &"rifle" else "sword"
		_pixel.combo = combo
		_pixel.facing = facing
		_pixel.aim = (get_global_mouse_position()-_left_origin)/_pixel.get_parent().scale
		_pixel.progress = _legacy_attack_progress(kind,progress) if kind == "sword" else progress
		var module := WeaponRuntime.module(_pixel.kind)
		var duration := float(module.startup)+float(module.active)+float(module.recovery)
		var elapsed := progress*duration
		_pixel.release_time = elapsed-float(module.startup) if elapsed >= float(module.startup) else -1.0
		_pixel.apply_pose()
	else:
		var animation := &"guard" if clip == &"guard_lower" else (&"staff_sweep" if clip == &"staff" else clip)
		if not _sprite.sprite_frames.has_animation(animation):
			animation = &"idle"
		_sprite.animation = animation
		_sprite.flip_h = facing < 0
		var sample := 1-progress if clip == &"guard_lower" else progress
		_seek_original(animation,sample)


func _legacy_attack_progress(kind: String,progress: float) -> float:
	var module := WeaponRuntime.module(kind)
	var elapsed := progress*(float(module.startup)+float(module.active)+float(module.recovery))
	var phases: Array = _pixel.cfg.sword.phase_indices
	if elapsed < float(module.startup):
		return float(phases[0])*elapsed/float(module.startup)/float(phases[2])
	if elapsed < float(module.startup)+float(module.active):
		return lerpf(float(phases[0]),float(phases[1]),(elapsed-float(module.startup))/float(module.active))/float(phases[2])
	return lerpf(float(phases[1]),float(phases[2]),clampf((elapsed-float(module.startup)-float(module.active))/float(module.recovery),0,1))/float(phases[2])


func _seek_original(animation: StringName,progress: float) -> void:
	var frames := _sprite.sprite_frames
	var duration := 0.0
	for index in frames.get_frame_count(animation):
		duration += frames.get_frame_duration(animation,index)
	var remaining := progress*duration
	for index in frames.get_frame_count(animation):
		var frame_duration := frames.get_frame_duration(animation,index)
		if remaining <= frame_duration or index == frames.get_frame_count(animation)-1:
			_sprite.set_frame_and_progress(index,clampf(remaining/frame_duration,0,1))
			WeaponRuntime.sync_sprite(_sprite)
			return
		remaining -= frame_duration


func _open_title(backend: String) -> void:
	MODE.select(backend)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _label(text: String,rect: Rect2,font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("#d3cdb9"))
	_ui.add_child(label)
	return label


func _button(text: String,rect: Rect2,callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size",11)
	button.pressed.connect(callback)
	_ui.add_child(button)
	RPGSkin.dress_button(button)
	return button
