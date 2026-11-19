extends Node2D
## 十个独立森林备选：真实角色、实体地形、机关、升降篮、清场封印与跨图评审接口。
const SESSION := preload("res://test/scripts/forest_candidates/session.gd")
const ART := preload("res://test/scripts/forest_candidates/art.gd")
@export var candidate_id := "05A"
var config: Dictionary
var progress: Dictionary
var rules: Dictionary
var player: Player
var _gates: Dictionary = {}
var _lifts: Dictionary = {}
var _markers: Dictionary = {}
var _poll := 0.0
var _panel: VBoxContainer
var _status: Label
var _ability_button: Button
var _map_panel: Panel
var _map_dot: ColorRect
var _map_origin := Vector2.ZERO
var _map_scale := 1.0
var _overlay_open := false
var _ui_root: Control
var _arrival_gate := ""
var _source_beam: Line2D
var _mirror_beam: Line2D

func _ready() -> void:
	set_meta("forest_candidate",true)
	set_meta("disable_save",true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	rules = SESSION.rules()
	config = JSON.parse_string(FileAccess.get_file_as_string("res://test/data/forest_candidates/%s.json" % candidate_id))
	var session := SESSION.begin(get_tree())
	progress = SESSION.progress(get_tree(),candidate_id)
	session.choices[candidate_id.left(2)] = candidate_id
	GameState.reset()
	GameState.weapon_id = StringName(str(rules.start_weapon))
	GameState.current_room = &"forest_02"
	GameState.checkpoint_room = GameState.current_room
	GameState.checkpoint_id = &"candidate_checkpoint"
	player = $Player as Player
	for child in get_children():
		child.process_mode = Node.PROCESS_MODE_PAUSABLE
		if child is CombatEnemy:
			child.target = player
			var spawn_id := str(child.get_meta("spawn_id"))
			if spawn_id in progress.killed:
				child.set_physics_process(false)
				child.queue_free()
			else:
				child.defeated.connect(_on_defeated.bind(spawn_id))
	for gate: Dictionary in config.gates:
		_gates[gate.id] = get_node("Gate_"+str(gate.id))
	_spawn_interactions()
	_build_light_conduit()
	_setup_lifts()
	_apply_double_jump(bool(session.double_jump))
	var spawn := _vector(config.spawn)
	if not progress.checkpoint.is_empty():
		spawn = _vector(progress.checkpoint)
	if str(session.arrival.get("candidate","")) == candidate_id:
		_arrival_gate = str(rules.entry_gates.get(candidate_id,{}).get(str(session.arrival.get("port","")),""))
		for port: Dictionary in config.ports:
			if str(port.id) == str(session.arrival.get("port","")):
				spawn = _vector(port.pos)-Vector2(0,float(rules.body_half))
	session.arrival = {}
	player.position = spawn
	player.checkpoint_position = spawn
	GameState.checkpoint_position = [spawn.x,spawn.y]
	player.cam.set_bounds(Rect2(Vector2.ZERO,_vector(config.bounds)))
	player.cam.global_position = spawn
	player.cam.zoom = Vector2.ONE*float(rules.camera_zoom)
	player.cam.reset_smoothing()
	_build_ui()
	_refresh()
	queue_redraw()

func _spawn_interactions() -> void:
	var points: Array = []
	points.append_array(config.controls)
	points.append_array(config.chests)
	points.append_array(config.markers)
	for port: Dictionary in config.ports:
		var entry := port.duplicate(true)
		entry.kind = "portal"
		points.append(entry)
	for definition: Dictionary in points:
		var marker := Node2D.new()
		marker.set_script(ART)
		marker.name = "Interact_"+str(definition.id)
		marker.position = _vector(definition.pos)
		marker.set("kind",definition.kind)
		if candidate_id=="06B" and definition.kind=="switch":
			marker.set("kind","fan")
		elif candidate_id=="06A" and str(definition.id)=="B":
			marker.set("kind","mirror")
		marker.set("caption",str(definition.id))
		marker.set_meta("definition",definition)
		marker.set_meta("interaction_offset_y",rules.drawing.hint_offset)
		marker.set_meta("interaction_text","E  "+("接口 → forest_"+str(definition.destination) if definition.kind == "portal" else str(definition.id)))
		add_child(marker)
		_markers[definition.id] = marker
	for index in config.water_regions.size():
		var region: Dictionary = config.water_regions[index]
		var water := Node2D.new()
		water.name = "Water_%d" % index
		water.set_script(ART)
		water.set("kind","water")
		water.position = Vector2(region.rect[0],region.rect[1])
		water.set("extent",Vector2(region.rect[2],region.rect[3]))
		add_child(water)

func _setup_lifts() -> void:
	for definition: Dictionary in config.lifts:
		var body := AnimatableBody2D.new()
		body.name = definition.id
		body.collision_layer = 1
		body.collision_mask = 0
		body.sync_to_physics = false
		var index := int(progress.values.get(definition.id,0))
		body.position = Vector2(float(definition.x),float(definition.stops[index]))
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = _vector(rules.lift_size)
		shape.shape = rect
		shape.position.y = rect.size.y/2
		body.add_child(shape)
		var art := Node2D.new()
		art.set_script(ART)
		art.set("kind","lift")
		art.set("extent",rect.size)
		body.add_child(art)
		add_child(body)
		_lifts[definition.id] = {"body":body,"definition":definition,"target":index}

func _physics_process(delta: float) -> void:
	if config.is_empty() or get_tree().paused:
		return
	if not _arrival_gate.is_empty() and player.position.x < (_gates[_arrival_gate] as Node2D).position.x-float(rules.body_half)-float(rules.gate_margin):
		_arrival_gate = ""
		_refresh()
	for lift: Dictionary in _lifts.values():
		var body := lift.body as AnimatableBody2D
		var target := float(lift.definition.stops[int(lift.target)])
		var next_y := move_toward(body.position.y,target,float(rules.lift_speed)*delta)
		var feet := player.position.y+float(rules.body_half)
		var riding := absf(feet-body.position.y)<=float(rules.platform_tolerance) and absf(player.position.x-body.position.x)<float(rules.lift_size[0])/2 and player.velocity.y>=0
		if riding:
			player.position.y += next_y-body.position.y
		body.position.y = next_y
	_poll += delta
	if _poll >= float(rules.poll_seconds):
		_poll = 0
		_refresh()

func _process(_delta: float) -> void:
	if not is_instance_valid(_status) or not is_instance_valid(player):
		return
	_panel.position = Vector2(get_viewport_rect().size.x-float(rules.ui.width)-10,float(rules.ui.position[1]))
	var cleared: int = progress.killed.size()
	var completed := bool(progress.flags.get("solved",false)) or bool(progress.flags.get("all_combat",false)) or (candidate_id=="09B" and bool(progress.flags.get("either_route",false)))
	var state := "已打通" if completed else "探索中"
	_status.text = "%s %s · %s · 清怪 %d/%d" % [candidate_id,config.name,state,cleared,config.enemies.size()]
	_ability_button.text = "二段跳：%s F7" % ("开" if GameState.abilities.has(&"double_jump") else "关")
	if _overlay_open:
		_map_dot.position = _map_origin+player.position*_map_scale-_map_dot.size/2

func _refresh() -> void:
	var groups: Array = []
	for enemy: Dictionary in config.enemies:
		if not groups.has(int(enemy.group)):
			groups.append(int(enemy.group))
	for group: int in groups:
		var complete := true
		for enemy: Dictionary in config.enemies:
			if int(enemy.group)==group and not str(enemy.spawn_id) in progress.killed:
				complete = false
		if complete:
			progress.flags["group_%d" % group] = true
	if not config.enemies.is_empty() and progress.killed.size() == config.enemies.size():
		progress.flags.all_combat = true
	progress.flags.either_route = bool(progress.flags.get("group_1",false)) or bool(progress.flags.get("group_2",false))
	progress.flags.between_01 = bool(progress.flags.get("group_0",false)) or bool(progress.flags.get("group_1",false))
	progress.flags.between_12 = bool(progress.flags.get("group_1",false)) or bool(progress.flags.get("group_2",false))
	for definition: Dictionary in config.gates:
		(_gates[definition.id] as ForestMistGate).set_open(bool(progress.flags.get(definition.condition,false)) or str(definition.id)==_arrival_gate,str(definition.id)!=_arrival_gate)
	for index in config.water_regions.size():
		get_node("Water_%d" % index).visible = not bool(progress.flags.get(config.water_regions[index].condition,false))
	if is_instance_valid(_source_beam):
		_source_beam.visible = bool(progress.flags.get("A",false))
		_mirror_beam.visible = _source_beam.visible
		var index := int(progress.values.get("B",0))
		var point: Vector2 = _markers.B.position-Vector2(0,32)
		var target: Vector2 = _markers.C.position-Vector2(0,32) if index==int(rules.mirror_solution) else point+_vector(rules.mirror_wrong_offsets[index])
		_mirror_beam.points = PackedVector2Array([point,target])
	for id: String in _markers:
		var marker: Node2D = _markers[id]
		var definition: Dictionary = marker.get_meta("definition")
		marker.set("activated",id in progress.opened or bool(progress.flags.get(id,false)))
		marker.set("value",int(progress.values.get(id,0)))
		marker.queue_redraw()
	queue_redraw()

func _on_defeated(_enemy: CombatEnemy, spawn_id: String) -> void:
	if not spawn_id in progress.killed:
		progress.killed.append(spawn_id)
	_refresh()

## 最近交互点沿用正式HUD提示；没有交互点时不占用E。
func _nearest_interaction() -> String:
	if not is_instance_valid(player):
		return ""
	var nearest := ""
	var distance := float(rules.interaction_range)
	for id: String in _markers:
		var marker: Node2D = _markers[id]
		var d := player.position.distance_to(marker.position-Vector2(0,float(rules.body_half)))
		if d < distance:
			distance = d
			nearest = str(marker.name)
	return nearest

## 操作真实机关、检查点、空宝箱与评审接口。
func interact_nearby() -> bool:
	var nearest := _nearest_interaction()
	if nearest.is_empty():
		return false
	var marker := get_node(nearest) as Node2D
	var definition: Dictionary = marker.get_meta("definition")
	match str(definition.kind):
		"portal":
			_travel(definition)
		"chest":
			var combat_ready := bool(progress.flags.get("either_route",false)) if candidate_id=="09B" else bool(progress.flags.get("all_combat",false))
			if not config.enemies.is_empty() and not combat_ready:
				GameUI.toast("先清理本区域敌人")
			elif candidate_id.left(2) in ["05","06"] and not bool(progress.flags.get("solved",false)):
				GameUI.toast("机关尚未打通")
			elif not str(definition.id) in progress.opened:
				progress.opened.append(str(definition.id))
				if candidate_id.begins_with("07"):
					progress.flags.solved = true
				GameUI.toast("已打开空宝箱 · 奖励待定")
		"fire":
			_checkpoint(marker.position)
			GameUI.toast("试玩检查点已更新，资源恢复")
		_:
			operate(str(definition.action),marker.position)
	_refresh()
	return true

## 应用机关动作；逻辑与交互距离分离，便于物理验收复位和封印状态。
func operate(action: String, point: Vector2 = Vector2.ZERO) -> void:
	match candidate_id:
		"05A":
			if action=="A":
				progress.flags.water_a = true
				progress.flags.A = true
				GameUI.toast("中渠排空，根井露出")
			elif action=="B" and bool(progress.flags.get("water_a",false)):
				progress.flags.solved = true
				progress.flags.B = true
				GameUI.toast("底渠排空，回访捷径开放")
		"05B":
			if action=="lift_left":
				var lift: Dictionary = _lifts.LeftLift
				_set_lift("LeftLift",1-int(lift.target))
				progress.flags.A = true
			elif action=="prepare_right":
				progress.flags.B = true
				_set_lift("RightLift",1)
				GameUI.toast("右篮已召至中层，登篮后操作C")
			elif action=="lift_right" and bool(progress.flags.get("B",false)):
				_set_lift("RightLift",1 if int(_lifts.RightLift.target)==2 else 2)
				progress.flags.solved = true
				GameUI.toast("右篮升降，底廊捷径开放")
		"06A":
			if action=="A":
				progress.flags.A = true
			elif action=="B":
				progress.values.B = (int(progress.values.get("B",0))+1)%int(rules.mirror_steps)
			if bool(progress.flags.get("A",false)) and int(progress.values.get("B",0))==int(rules.mirror_solution):
				progress.flags.solved = true
				progress.flags.C = true
				GameUI.toast("光路命中接收器，上廊与东门开放")
			else:
				GameUI.toast("光源%s · 镜座 %d/%d" % ["开启" if bool(progress.flags.get("A",false)) else "关闭",int(progress.values.get("B",0))+1,int(rules.mirror_steps)])
		"06B":
			if rules.valve_counts.has(action):
				progress.values[action] = (int(progress.values.get(action,0))+1)%int(rules.valve_counts[action])
			var connected := true
			for valve: String in ["A","B","C"]:
				connected = connected and int(progress.values.get(valve,0))==int(rules.valve_solution[valve])
				progress.flags[valve] = connected
			if connected:
				progress.flags.solved = true
			GameUI.toast("导风 A:%s B:%s C:%s" % [_wind("A"),_wind("B"),_wind("C")])
		_:
			if action=="checkpoint":
				_checkpoint(point)
				GameUI.toast("中段歇脚点已记录")
			elif action=="shortcut":
				progress.flags.shortcut = true
				GameUI.toast("回访捷径已开启")
	_refresh()

func _wind(id: String) -> String:
	return "通" if bool(progress.flags.get(id,false)) else "断"

func _checkpoint(point: Vector2) -> void:
	var center := point-Vector2(0,float(rules.body_half))
	progress.checkpoint = [center.x,center.y]
	player.checkpoint_position = center
	GameState.checkpoint_position = progress.checkpoint.duplicate()
	GameState.hp = GameState.hp_max
	GameState.sta = GameState.sta_max
	GameState.mana = GameState.mana_max

func _set_lift(id: String, stop: int) -> void:
	_lifts[id].target = stop
	progress.values[id] = stop

func _travel(port: Dictionary) -> void:
	if bool(port.ability) and not GameState.abilities.has(&"double_jump"):
		GameUI.toast("高架接口需要二段跳；F7可切换能力对比")
		return
	var key := candidate_id.left(2)+":"+str(port.destination)
	if not rules.links.has(key):
		GameUI.toast("预留接口 → forest_%s，正式连接待定案；F6可返回选图" % port.destination)
		return
	var target := SESSION.target_id(get_tree(),str(port.destination),candidate_id.right(1))
	SESSION.enter(get_tree(),target,str(rules.links[key]))

func _apply_double_jump(enabled: bool) -> void:
	SESSION.begin(get_tree()).double_jump = enabled
	GameState.abilities.erase(&"double_jump")
	if enabled:
		GameState.abilities.append(&"double_jump")
	if is_instance_valid(player):
		player.on_landed(0)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key in [KEY_M,KEY_ESCAPE] and _overlay_open:
		_toggle_map()
	elif key==KEY_M and GameUI.mode=="":
		_toggle_map()
	elif key==KEY_F6:
		_gallery()
	elif key==KEY_F7 and GameUI.mode=="":
		_apply_double_jump(not GameState.abilities.has(&"double_jump"))
		GameUI.toast("二段跳："+("开启" if GameState.abilities.has(&"double_jump") else "关闭"))
	elif key==KEY_F8:
		_reset()
	elif key==KEY_R and GameUI.mode=="":
		player.respawn()
		player.sm.to(&"Idle")
	else:
		return
	get_viewport().set_input_as_handled()

func _gallery() -> void:
	GameUI._force_close()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://test/scenes/forest_candidates.tscn")

func _reset() -> void:
	SESSION.begin(get_tree()).maps.erase(candidate_id)
	SESSION.enter(get_tree(),candidate_id)

func _build_ui() -> void:
	_ui_root = Control.new()
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameUI.root_control.add_child(_ui_root)
	_panel = VBoxContainer.new()
	_panel.size.x = float(rules.ui.width)
	_panel.add_theme_font_size_override("font_size",int(rules.ui.font))
	_ui_root.add_child(_panel)
	_status = Label.new()
	_status.add_theme_font_override("font",RPGSkin.font())
	_status.add_theme_font_size_override("font_size",int(rules.ui.font))
	_panel.add_child(_status)
	var row := HBoxContainer.new()
	_panel.add_child(row)
	var selector := OptionButton.new()
	var rows := SESSION.candidates()
	for index in rows.size():
		selector.add_item(str(rows[index].id)+" "+str(rows[index].title))
		if str(rows[index].id)==candidate_id:
			selector.select(index)
	selector.item_selected.connect(func(index: int) -> void: SESSION.enter(get_tree(),str(rows[index].id)))
	row.add_child(selector)
	_button(row,"选图 F6",_gallery)
	_button(row,"重置 F8",_reset)
	var shortcuts := HBoxContainer.new()
	_panel.add_child(shortcuts)
	_button(shortcuts,"地图 M",_toggle_map)
	_ability_button = _button(shortcuts,"二段跳 F7",func() -> void: _apply_double_jump(not GameState.abilities.has(&"double_jump")))
	_button(shortcuts,"回检查点 R",func() -> void: player.respawn(); player.sm.to(&"Idle"))
	var help := Label.new()
	help.text = "E 交互 · A/D 移动 · Space 跳跃 · 左键攻击\n"+str(config.kind)+" · 评审场景"
	help.position = _vector(rules.ui.help_position)
	help.add_theme_font_override("font",RPGSkin.font())
	help.add_theme_font_size_override("font_size",int(rules.ui.font))
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(help)
	_map_panel = Panel.new()
	_map_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_child(_map_panel)
	_map_panel.hide()
	var rect := Rect2(float(rules.ui.map_rect[0]),float(rules.ui.map_rect[1]),float(rules.ui.map_rect[2]),float(rules.ui.map_rect[3]))
	var world_size := _vector(config.bounds)
	_map_scale = minf(rect.size.x/world_size.x,rect.size.y/world_size.y)
	_map_origin = rect.position+(rect.size-world_size*_map_scale)/2
	var picture := TextureRect.new()
	picture.position = _map_origin
	picture.size = world_size*_map_scale
	picture.texture = load("res://test/assets/forest_candidates/%s_map.png" % candidate_id)
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_panel.add_child(picture)
	_map_dot = ColorRect.new()
	_map_dot.color = Color(rules.palette.gold)
	_map_dot.size = Vector2.ONE*float(rules.ui.map_player_radius)*2
	_map_panel.add_child(_map_dot)
	var close := Button.new()
	close.text = "M / Esc 关闭地图"
	close.position = rect.position
	close.pressed.connect(_toggle_map)
	_map_panel.add_child(close)

func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font",RPGSkin.font())
	button.add_theme_font_size_override("font_size",int(rules.ui.font))
	button.pressed.connect(func() -> void: GameUI.finish_dialogue_input(); callback.call())
	parent.add_child(button)
	return button

func _toggle_map() -> void:
	_overlay_open = not _overlay_open
	_map_panel.visible = _overlay_open
	get_tree().paused = _overlay_open
	player.clear_action_buffers()

func _draw() -> void:
	if config.is_empty():
		return
	if candidate_id=="06B":
		for id: String in ["A","B","C"]:
			var point: Vector2 = _markers[id].position-Vector2(0,36)
			draw_circle(point,8,Color(rules.palette.active if bool(progress.flags.get(id,false)) else rules.palette.stone))

func _build_light_conduit() -> void:
	if candidate_id!="06A":
		return
	var a: Vector2 = _markers.A.position-Vector2(0,32)
	var b: Vector2 = _markers.B.position-Vector2(0,32)
	var c: Vector2 = _markers.C.position-Vector2(0,32)
	# 导光槽嵌在墙内，只有细线视觉，无可穿行的碰撞缺口。
	var groove := Line2D.new()
	groove.points = PackedVector2Array([a,b,c])
	groove.width = float(rules.drawing.pixel)*4
	groove.default_color = Color(rules.palette.stone)
	groove.z_index = 1
	add_child(groove)
	for index in 2:
		var beam := Line2D.new()
		beam.points = PackedVector2Array([a,b]) if index==0 else PackedVector2Array([b,c])
		beam.width = float(rules.drawing.line)
		beam.default_color = Color(rules.palette.gold)
		beam.z_index = 1
		add_child(beam)
		if index==0:
			_source_beam = beam
		else:
			_mirror_beam = beam

func _exit_tree() -> void:
	if is_instance_valid(_ui_root):
		_ui_root.queue_free()

func _vector(value: Array) -> Vector2:
	return Vector2(value[0],value[1])
