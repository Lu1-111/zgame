class_name DebugHotbar
extends HBoxContainer
## M1.5 调试快捷栏：5 槽图标 + 数量（图标取自 ITM-B01 道具包）。
## 正式 HUD 快捷栏（§3.10 规格、拖拽登录、选中放大）在 M2 实装后整体替换本组件。

const ICON_PATH := "res://assets/PROCESSED/items/ITM-B01/v001/icons/ITEM_%s_icon_v001.png"
const SLOT_SIZE := 28.0

var _icons: Array[TextureRect] = []
var _counts: Array[Label] = []
var _panels: Array[PanelContainer] = []


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	for i in 5:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel.add_child(icon)
		var count := Label.new()
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.add_theme_font_size_override("font_size", 8)
		panel.add_child(count)
		add_child(panel)
		_icons.append(icon)
		_counts.append(count)
		_panels.append(panel)
	refresh()


func _process(_delta: float) -> void:
	refresh()


## 依 GameState.hotbar / inventory 刷新图标与数量（空槽半透明）。
func refresh() -> void:
	for i in 5:
		var id := ""
		if i < GameState.hotbar.size():
			id = String(GameState.hotbar[i])
		if id.is_empty():
			_icons[i].texture = null
			_counts[i].text = ""
			_panels[i].modulate = Color(1, 1, 1, 0.35)
			continue
		_panels[i].modulate = Color.WHITE
		_icons[i].texture = load(ICON_PATH % id)
		var count := 0
		for entry in GameState.inventory:
			if entry is Dictionary and String(entry.get("id", "")) == id:
				count = int(entry.get("count", 0))
		_counts[i].text = str(count)
