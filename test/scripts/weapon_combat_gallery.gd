extends Node2D
## 正式Player演练：逐段与完整连招，不读写旅途存档，不复制攻击时序。
var player: Player
var weapons: Array[Dictionary] = []
var choices := OptionButton.new()
var info := Label.new()
var status := Label.new()
var segment_buttons: Array[Button] = []
var _continuous := false
var _playing := false
var _last_segment := 1
var _last_full := false
var _elapsed := 0.0
var _completed := 0.0
var _loop := CheckBox.new()
var _delay := 0.0

func _ready() -> void:
	set_meta("disable_save",true)
	GameUI.hide()
	RenderingServer.set_default_clear_color(Color("#141a24"))
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	GameState.reset()
	RPGService.ensure_state()
	var floor_body := StaticBody2D.new()
	floor_body.name="Floor"
	floor_body.position=Vector2(320,277)
	floor_body.collision_layer=1
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size=Vector2(640,20)
	collider.shape=shape
	floor_body.add_child(collider)
	add_child(floor_body)
	player=(load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	player.set_script(load("res://test/scripts/weapon_demo_player.gd"))
	player.name="Player"
	player.position=Vector2(405,250)
	add_child(player)
	player.cam.enabled=false
	var ui := CanvasLayer.new()
	ui.name="UI"
	add_child(ui)
	var box := VBoxContainer.new()
	box.position=Vector2(12,12)
	box.custom_minimum_size=Vector2(220,0)
	var theme := Theme.new()
	theme.default_font=RPGSkin.font()
	theme.default_font_size=12
	box.theme=theme
	ui.add_child(box)
	_label(box,"武器攻击演练",17)
	for id: String in DataDB.weapons:
		var definition := DataDB.get_weapon(StringName(id))
		if bool(definition.get("legacy",false)):continue
		weapons.append(definition)
	weapons.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return str(a.id)<str(b.id))
	for weapon in weapons:choices.add_item(str(weapon.name))
	choices.item_selected.connect(_select)
	box.add_child(choices)
	info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size=Vector2(220,105)
	box.add_child(info)
	var row := HBoxContainer.new()
	box.add_child(row)
	for index in 3:
		var button := Button.new()
		button.text="第%d段" % [index+1]
		button.pressed.connect(_play.bind(index+1,false))
		row.add_child(button)
		segment_buttons.append(button)
	_button(box,"连续攻击",_play.bind(1,true))
	var controls := HBoxContainer.new()
	box.add_child(controls)
	_button(controls,"重播",func() -> void:_play(_last_segment,_last_full))
	_button(controls,"左右朝向",_flip)
	_loop.text="循环播放"
	box.add_child(_loop)
	status.custom_minimum_size=Vector2(220,55)
	box.add_child(status)
	_label(box,"单段用时包含起手、判定与收招\n倍率大于1时更快 · 技能独立配置",11)
	_select(0)
	queue_redraw()

func _select(index: int) -> void:
	_playing=false
	_continuous=false
	player.cancel_weapon_action()
	player.sm.to(&"Idle")
	GameState.weapon_id=StringName(weapons[index].id)
	player.reset_weapon_traits()
	player._update_animation()
	for i in segment_buttons.size():segment_buttons[i].disabled=i>=player.max_combo()
	var weapon := weapons[index]
	var special := str(weapon.get("special_description","无"))
	if weapon.special_effects.any(func(e: Dictionary) -> bool:return not bool(e.implemented)):special+="（异常/技能占位）"
	info.text="%s · %s\n攻击力 %d · 削韧 ×%.1f\n攻速 ×%.2f · 每段 %.3f 秒\n%s" % [weapon.id,weapon.weapon_type,weapon.attack,weapon.poise_multiplier,weapon.attack_speed_multiplier,WeaponAttributes.duration(weapon),special]
	if weapon.weapon_type == "rifle":
		info.text += "\n每次耗弹 %s%%" % weapon.ammo_cost_pct
	status.text="选择单段或连续攻击"

func _play(segment: int,full: bool) -> void:
	player.cancel_weapon_action()
	player.sm.to(&"Idle")
	player.position=Vector2(405,250)
	player.velocity=Vector2.ZERO
	GameState.ammo_units = WeaponAttributes.ammo_capacity()
	player._rifle_ready_at = 0.0
	player.attack_combo=0
	_last_segment=segment
	_last_full=full
	_continuous=full
	_playing=true
	_elapsed=0
	_delay=0
	player.sm.to(&"Attack",{"combo":segment})

func _flip() -> void:
	player.set("demo_facing",-int(player.get("demo_facing")))
	player.set_facing(int(player.get("demo_facing")))
	if _playing:_play(_last_segment,_last_full)

func _physics_process(delta: float) -> void:
	if player==null:return
	if _playing:
		_elapsed+=delta
		if player.sm.current_name()==&"Attack":
			player.attack_chain=_continuous
			status.text="第%d/%d段 · %s\n削韧 %.1f · 已播放 %.2f 秒" % [player.attack_combo,player.max_combo(),player.attack_phase,WeaponAttributes.poise_damage(player.weapon_cfg(),player.attack_combo),_elapsed]
		else:
			_playing=false
			_completed=_elapsed
			_delay=0.7
			status.text="播放完成 · %.2f 秒\n%s" % [_completed,"完整连招" if _last_full else "第%d段" % _last_segment]
	elif _loop.button_pressed:
		_delay-=delta
		if _delay<=0:_play(_last_segment,_last_full)

func _draw() -> void:
	draw_rect(Rect2(250,20,374,300),Color("#1b2330"))
	draw_line(Vector2(250,267),Vector2(624,267),Color("#758091"),1)
	for x in range(270,625,16):draw_line(Vector2(x,268),Vector2(x,272),Color("#495362"),1)

func _label(parent: Node,text: String,size: int) -> void:
	var label := Label.new()
	label.text=text
	label.add_theme_font_size_override("font_size",size)
	parent.add_child(label)

func _button(parent: Node,text: String,callback: Callable) -> void:
	var button := Button.new()
	button.text=text
	button.pressed.connect(callback)
	parent.add_child(button)
