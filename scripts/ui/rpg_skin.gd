class_name RPGSkin
extends RefCounted
## 克制的暗色奇幻界面：细边、衬线文字、独立油画技能和简洁物品图标。
static var _data: Dictionary = {}
static var _textures: Dictionary = {}
static var _font: SystemFont

## 读取全局界面配置。
static func config() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_skin.json"))
	return _data

## 提供跨平台中文衬线字体，缺失时交给系统回退。
static func font() -> Font:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(config().font_families)
		_font.font_weight = 400
	return _font

## 根据资源名选用简洁物品画或油画技能。
static func icon_for_path(path: String) -> Texture2D:
	var key := path.get_file().get_basename().trim_prefix("ITEM_").trim_suffix("_icon_v001")
	if _textures.has(key):
		return _textures[key]
	var result: Texture2D
	if config().item_icons.has(key):
		result = load(str(config().item_icons[key]))
	else:
		var index: int = config().skill_order.find(key)
		if index < 0:
			return load(path) as Texture2D
		var atlas := AtlasTexture.new()
		atlas.atlas = load(str(config().skills_atlas))
		var cell := atlas.atlas.get_size()/Vector2(5,4)
		atlas.region = Rect2(Vector2(index%5,floorf(index/5.0))*cell+Vector2.ONE*3,cell-Vector2.ONE*6)
		atlas.filter_clip = true
		result = atlas
	_textures[key] = result
	return result

## 共用切角压边和低对比暗金装饰，所有界面保持同一视觉语言。
static func frame(parent: Control, kind: String, rect: Rect2, behind: bool = false, _scale_override: float = 0.0) -> Control:
	var node := QuietFrame.new()
	node.kind = kind
	node.position = rect.position
	node.size = rect.size
	node.show_behind_parent = behind
	parent.add_child(node)
	return node

## 状态条保留微弱明暗变化。
static func bar_fill(color: Color) -> StyleBoxTexture:
	var gradient := Gradient.new()
	gradient.set_color(0,color.lightened(0.10))
	gradient.set_color(1,color.darkened(0.16))
	var fill := GradientTexture2D.new()
	fill.width = 4
	fill.height = 8
	fill.gradient = gradient
	fill.fill_from = Vector2.ZERO
	fill.fill_to = Vector2.DOWN
	var style := StyleBoxTexture.new()
	style.texture = fill
	return style

## 按钮以暗金边框、内阴影和选中底色表达交互层次。
static func dress_button(button: Button) -> void:
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.55,0.51,0.40,0.13 if state in ["hover","focus"] else (0.23 if state == "pressed" else 0.035))
		style.border_color = Color(config().trim.highlight if state in ["hover","focus","pressed"] else config().colors.rule)
		style.set_border_width_all(1)
		style.set_corner_radius_all(2)
		style.shadow_color = Color(0,0,0,0.22)
		style.shadow_size = 1
		style.shadow_offset = Vector2(0,1)
		button.add_theme_stylebox_override(state,style)
	button.add_theme_font_override("font",font())
	button.add_theme_color_override("font_color",Color(config().colors.text))
	button.add_theme_color_override("font_hover_color",Color(config().colors.selected))
	button.add_theme_color_override("font_focus_color",Color(config().colors.selected))
	button.add_theme_color_override("font_outline_color",Color.TRANSPARENT)
	button.add_theme_constant_override("outline_size",0)

## 滚动条与面板共用低对比金灰色，避免保留引擎默认亮灰控件。
static func dress_theme(theme: Theme) -> void:
	for direction in ["VScrollBar","HScrollBar"]:
		for state in ["scroll","grabber","grabber_highlight","grabber_pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(config().colors.rule if state == "scroll" else config().colors.edge if state == "grabber" else config().trim.highlight)
			style.content_margin_left = 3
			style.content_margin_right = 3
			style.content_margin_top = 3
			style.content_margin_bottom = 3
			theme.set_stylebox(state,direction,style)

## 简洁的象牙色箭形光标。
static func cursor_texture() -> Texture2D:
	if not _textures.has("cursor_native"):
		_textures["cursor_native"] = load(str(config().cursor_source))
	return _textures.cursor_native

## 关闭场景时释放系统光标引用。
static func release_cursor() -> void:
	_textures.erase("cursor_native")
