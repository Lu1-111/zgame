class_name MagicSlot
extends Control
## 可拖拽的通用物品/快捷/技能格；数据操作交给 UI 控制器。

signal activated(kind: String, index: int)
signal drop_requested(data: Dictionary, kind: String, index: int)
var kind := "inventory"
var index := 0
var item_id := ""
var icon: Texture2D
var amount := 0
var key_text := ""
var selected := false
var locked := false
var mana_blocked := false
var cooldown := 0.0
var cooldown_ratio := 0.0
var _hover := false
var _frame: Texture2D = preload("res://assets/ui/magic/slot.svg")


func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: _hover = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hover = false; queue_redraw())


func _draw() -> void:
	draw_texture_rect(_frame, Rect2(Vector2.ZERO, size), false)
	if selected:
		draw_colored_polygon(PackedVector2Array([Vector2(size.x/2-3,2),Vector2(size.x/2+3,2),Vector2(size.x/2,6)]),Color("#f4dfa0"))
	if selected or _hover:
		draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2), Color("#f0d7a0"), false, 1)
	if icon != null:
		draw_texture_rect(icon, Rect2(Vector2.ONE * 4, size - Vector2.ONE * 8), false, Color(0.45,0.48,0.5) if locked or mana_blocked else Color.WHITE)
	if locked:
		draw_rect(Rect2(size * 0.5 - Vector2(3,0), Vector2(6,6)), Color("#aa9470"))
		draw_arc(size * 0.5 - Vector2(0,1), 3, PI, TAU, 8, Color("#aa9470"), 1)
	if cooldown_ratio > 0.0:
		var ratio := clampf(cooldown_ratio,0.0,1.0)
		for step in ceili(ratio * 32):
			var angle := -PI / 2 + float(step) / 32 * TAU
			var end_angle := -PI / 2 + minf(float(step+1) / 32,ratio) * TAU
			if end_angle-angle > 0.00001:
				draw_colored_polygon(PackedVector2Array([size*0.5,size*0.5+Vector2(cos(angle),sin(angle))*size.length(),size*0.5+Vector2(cos(end_angle),sin(end_angle))*size.length()]),Color(0.01,0.04,0.06,0.78))
	var font := ThemeDB.fallback_font
	if key_text != "":
		draw_string(font, Vector2(3,10), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#efddb1"))
	if amount > 0:
		draw_string(font, Vector2(size.x - 15,size.y - 4), str(amount), HORIZONTAL_ALIGNMENT_RIGHT, 12, 10, Color.WHITE)
	if cooldown > 0:
		draw_string(font, Vector2(4,size.y - 5), "%.1f" % cooldown, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 9, Color.WHITE)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		activated.emit(kind, index)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if locked or item_id == "" or kind in ["skill_hud","equipment_reserved"]:
		return null
	var preview := TextureRect.new()
	preview.texture = icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(36,36)
	preview.size = Vector2(36,36)
	set_drag_preview(preview)
	return {"source":kind,"index":index,"id":item_id}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if locked or not data is Dictionary or not data.has("source"):
		return false
	var accepted := {"hotbar":["inventory","hotbar"],"inventory":["inventory","hotbar","storage"],"materials":["materials","storage"],"storage":["inventory","materials"],"weapon_inventory":["weapon_inventory","weapon_equipped"],"weapon_equipped":["weapon_inventory"],"active_slot":["active_skill","active_slot"],"passive_slot":["passive_skill","passive_slot"]}
	return str(data.source) in accepted.get(kind,[])


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	drop_requested.emit(data, kind, index)
