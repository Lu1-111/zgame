extends Node2D
## 独立素材试放：测试解锁、平台和石笋轮廓；不产生掉落，不写正式存档。
var cfg: Dictionary
var _snapshot: Dictionary
var _status: Label
var _ui: CanvasLayer
var _overview := false

func _ready() -> void:
	set_meta("disable_save",true)
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://test/data/cave_material_preview.json"))
	_snapshot = GameState.to_save_dict()
	GameState.reset()
	GameState.abilities.append(&"double_jump")
	GameUI._bind_scene(self)
	GameUI.set_process(false)
	GameUI.root_control.hide()
	$Player.checkpoint_position = Vector2(cfg.spawn[0],cfg.spawn[1])
	$Player.cam.set_bounds(Rect2(Vector2.ZERO,Vector2(cfg.bounds[0],cfg.bounds[1])))
	$Player.cam.zoom = Vector2.ONE*float(cfg.camera_zoom)
	$StalagmiteStrip.hazard_contact.connect(_on_spikes)
	_ui = CanvasLayer.new()
	_ui.layer = 30
	add_child(_ui)
	_status = Label.new()
	_status.position = Vector2(cfg.ui.padding[0],cfg.ui.padding[1])
	_status.add_theme_font_override("font",RPGSkin.font())
	_status.add_theme_font_size_override("font_size",int(cfg.ui.font_size))
	_status.add_theme_color_override("font_color",Color(str(cfg.ui.color)))
	_status.add_theme_color_override("font_shadow_color",Color.BLACK)
	_status.add_theme_constant_override("shadow_offset_x",1)
	_status.add_theme_constant_override("shadow_offset_y",1)
	_ui.add_child(_status)
	_status.text = str(cfg.ui.help)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1:
			$EncounterChest.satisfy_condition("encounter")
			_status.text = str(cfg.ui.help)+"\n清场条件满足：锁已移除，按E打开。"
		KEY_2:
			$KeyChest.satisfy_condition("key")
			_status.text = str(cfg.ui.help)+"\n钥匙使用完成：锁已移除，按E打开。"
		KEY_R:
			for name in [&"NormalChest",&"EncounterChest",&"KeyChest"]:
				get_node(NodePath(name)).reset_state()
			_reset_position()
		KEY_F5:
			set_overview(not _overview)

## 切换固定全景镜头；正常预览跟随玩家、素材始终原生世界像素显示。
func set_overview(enabled: bool) -> void:
	_overview = enabled
	$Player.cam.set_physics_process(not enabled)
	$Player.cam.position_smoothing_enabled = not enabled
	$Player.cam.zoom = Vector2.ONE*float(cfg.overview_zoom if enabled else cfg.camera_zoom)
	if enabled:
		$Player.cam.global_position = Vector2(cfg.bounds[0],cfg.bounds[1])/2.0
	$Player.cam.reset_smoothing()

## 标准E交互入口，与现有GameUI契约一致。
func interact_nearby() -> bool:
	var id := _nearest_interaction()
	if id.is_empty(): return false
	var chest := get_node(id)
	_status.text = str(cfg.ui.help)+("\n空箱已打开。" if chest.try_open() else "\n上锁：需先满足对应的清场或钥匙条件。")
	return true

func _nearest_interaction() -> String:
	var closest := ""
	var distance := float(cfg.interaction_range)
	for name in ["NormalChest","EncounterChest","KeyChest"]:
		var chest := get_node(name) as Node2D
		var current: float = $Player.global_position.distance_to(chest.global_position)
		if current<distance and chest.state in [&"closed",&"locked"]:
			closest = name
			distance = current
	return closest

func _on_spikes(body: Node2D) -> void:
	if body==$Player:
		_reset_position.call_deferred()
		_status.text = str(cfg.ui.help)+"\n"+str(cfg.trap_message)

func _reset_position() -> void:
	$Player.position = Vector2(cfg.spawn[0],cfg.spawn[1])
	$Player.velocity = Vector2.ZERO
	$Player.cam.reset_smoothing()

func _exit_tree() -> void:
	if not _snapshot.is_empty():
		GameState.load_from_dict(_snapshot)
	GameUI.set_process(true)
	GameUI.root_control.show()
