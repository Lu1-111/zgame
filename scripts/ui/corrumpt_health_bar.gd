class_name CorrumptHealthBar
extends Control
## 独立首领血条：细金属双边、腐紫填充与延迟残血，不占用头顶空间。
var boss: CorrumptBoss
var _trail := 1.0
var _name_label: Label
var _phase := 1
var _poise_state: StringName = &"normal"
var _poise_time := 0.0
var _shake_left := 0.0
var _shake_elapsed := 0.0
var _base_position := Vector2.ZERO
var _poise_frames: SpriteFrames

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var config: Dictionary = boss.profile.ui
	position = Vector2(config.position[0],config.position[1])
	_base_position = position
	_poise_frames = load(str(config.poise.frames)) as SpriteFrames
	boss.poise_broken.connect(_on_poise_broken)
	boss.poise_restored.connect(_on_poise_restored)
	if boss.poise.broken:
		_poise_state = &"broken"
	size = Vector2(config.size[0],config.size[1])
	_name_label = Label.new()
	_name_label.text = str(boss.profile.name)
	_name_label.add_theme_font_override("font",RPGSkin.font())
	_name_label.add_theme_font_size_override("font_size",int(config.name_font_size))
	_name_label.add_theme_color_override("font_color",Color("#e5ddce"))
	_name_label.add_theme_color_override("font_outline_color",Color("#17121c"))
	_name_label.add_theme_constant_override("outline_size",3)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.size.x = size.x
	add_child(_name_label)

func _process(delta: float) -> void:
	if not is_instance_valid(boss):
		queue_free()
		return
	var ratio := float(boss.hp)/float(boss.definition.hp)
	if _phase != boss.phase_index:
		_phase = boss.phase_index
		_trail = ratio
		_poise_state = &"normal"
		_shake_left = 0
		_name_label.text = str(boss.profile.name)+" · Ⅱ"
	_trail = 0 if boss.hp <= 0 else move_toward(_trail,ratio,float(boss.profile.ui.trail_speed)*delta)
	_tick_poise(delta)
	queue_redraw()

func _on_poise_broken() -> void:
	_poise_state = &"break"
	_start_poise_pulse()

func _on_poise_restored() -> void:
	_poise_state = &"recover"
	_start_poise_pulse()

func _start_poise_pulse() -> void:
	_poise_time = 0
	_shake_elapsed = 0
	_shake_left = float(boss.profile.ui.poise.shake_seconds)
	queue_redraw()

func _tick_poise(delta: float) -> void:
	var cfg: Dictionary = boss.profile.ui.poise
	_poise_time += delta
	if _phase != boss.phase_index or boss.hp <= 0:
		_poise_state = &"normal"
	if _poise_state == &"break" and _poise_time >= float(cfg.break_seconds):
		_poise_state = &"broken"
	elif _poise_state == &"recover" and _poise_time >= float(cfg.recover_seconds):
		_poise_state = &"normal"
	_shake_left = maxf(0,_shake_left-delta)
	_shake_elapsed += delta
	var strength := float(cfg.shake_amplitude)*_shake_left/float(cfg.shake_seconds)
	var phase := _shake_elapsed*TAU*float(cfg.shake_frequency)
	position = _base_position+Vector2(sin(phase),cos(phase))*strength

func _poise_texture() -> Texture2D:
	var cfg: Dictionary = boss.profile.ui.poise
	if _poise_state == &"break":
		var count := _poise_frames.get_frame_count(&"break")
		return _poise_frames.get_frame_texture(&"break",mini(int(_poise_time/float(cfg.break_seconds)*count),count-1))
	if _poise_state == &"recover":
		var count := _poise_frames.get_frame_count(&"recover")
		return _poise_frames.get_frame_texture(&"recover",mini(int(_poise_time/float(cfg.recover_seconds)*count),count-1))
	if _poise_state == &"broken":
		return _poise_frames.get_frame_texture(&"broken",0)
	return null

func _draw() -> void:
	if not is_instance_valid(boss):
		return
	var config: Dictionary = boss.profile.ui
	var bar := Rect2(8,size.y-float(config.health_height)-5,size.x-16,float(config.health_height))
	var ratio := float(boss.hp)/float(boss.definition.hp)
	draw_rect(bar.grow(3),Color(0.04,0.03,0.05,0.85))
	draw_rect(bar.grow(2),Color(str(config.border)),false,1)
	draw_rect(bar,Color("#20131f"))
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*_trail,bar.size.y)),Color(str(config.trail)))
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*ratio,bar.size.y)),Color(str(config.fill)))
	draw_line(bar.position,bar.position+Vector2(bar.size.x*ratio,0),Color("#c499b6"),1)
	for x in [0.0,size.x]:
		var center := Vector2(x,bar.get_center().y)
		draw_colored_polygon(PackedVector2Array([center+Vector2(-4,0),center+Vector2(0,-5),center+Vector2(4,0),center+Vector2(0,5)]),Color(str(config.border)))
	var overlay := _poise_texture()
	if overlay != null:
		draw_texture(overlay,(bar.get_center()-overlay.get_size()/2).floor(),Color(1,1,1,float(config.poise.overlay_alpha)))
