extends CanvasLayer
## 下方居中的半透明奇幻对话框；交谈期间独占键鼠并冻结世界。
@onready var panel: ColorRect = $Panel
@onready var speaker: Label = $Panel/Speaker
@onready var line: Label = $Panel/Line
@onready var hint: Label = $Panel/Hint
var portrait: TextureRect
var active_npc: Node
var _opened_frame := -1
var _previous_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	add_to_group(&"npc_dialogue")
	panel.color = Color.TRANSPARENT
	panel.size = Vector2(480,88)
	$Panel/Border.hide()
	var background := RPGSkin.frame(panel,"dialogue",Rect2(Vector2.ZERO,panel.size))
	background.modulate.a = float(RPGService.config().dialogue.opacity)
	panel.move_child(background,0)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.position = Vector2(14,13)
	portrait.size = Vector2(54,58)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(portrait)
	speaker.position = Vector2(94,8)
	speaker.size = Vector2(370,20)
	speaker.add_theme_font_size_override("font_size",13)
	line.position = Vector2(94,31)
	line.size = Vector2(367,38)
	line.add_theme_font_size_override("font_size",11)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.position = Vector2(284,69)
	hint.size = Vector2(177,14)
	hint.add_theme_font_size_override("font_size",9)
	panel.visible = false


func _process(_delta: float) -> void:
	var size := get_viewport().get_visible_rect().size
	panel.position = Vector2((size.x-panel.size.x)/2,size.y-panel.size.y-float(RPGService.config().dialogue.bottom_margin))


## 开始一次会话；保留原暂停状态，人物输入不能穿透到游戏。
func begin_dialogue(npc: Node) -> void:
	active_npc = npc
	_previous_paused = get_tree().paused
	_opened_frame = Engine.get_process_frames()
	get_tree().paused = true
	GameUI.player.clear_action_buffers()


## 显示说话人、头像、正文与页码。
func show_line(display_name: String, text: String, index: int, total: int, texture: Texture2D = null) -> void:
	panel.visible = true
	speaker.text = display_name
	line.text = text
	hint.text = "任意按键继续  %d / %d" % [index,total]
	if texture != null:
		var face := AtlasTexture.new()
		face.atlas = texture
		face.region = Rect2(12,0,40,42)
		portrait.texture = face


## 是否有会话占用输入。
func is_open() -> bool:
	return panel.visible


func _input(event: InputEvent) -> void:
	if is_open():
		handle_dialogue_input(event)
		get_viewport().set_input_as_handled()


## 任意键或鼠标按下推进一句；忽略长按回声和开启会话的同一次按键。
func handle_dialogue_input(event: InputEvent) -> void:
	if not is_open() or Engine.get_process_frames() <= _opened_frame:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	if pressed and is_instance_valid(active_npc):
		active_npc.advance_dialogue()


## 最后一句结束后恢复世界，并清除用于结束会话的玩法输入。
func close_dialogue() -> void:
	var was_open := panel.visible
	panel.visible = false
	active_npc = null
	if was_open:
		get_tree().paused = _previous_paused
		GameUI.finish_dialogue_input()


func _exit_tree() -> void:
	if is_instance_valid(panel) and panel.visible:
		get_tree().paused = _previous_paused
