class_name RPGSkin
extends RefCounted
## 精细金属与皮革素材统一供面板、按钮、HUD、格子和提示使用。
static var _data: Dictionary = {}
static var _textures: Dictionary = {}


## 加载皮肤布局和高分辨率纹理切片。
static func config() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_skin.json"))
	return _data


## 返回独立材质切片，避免每个控件重复创建贴图。
static func texture(kind: String) -> Texture2D:
	if not _textures.has(kind):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(str(config().atlas))
		var r: Array = config().frames[kind].region
		atlas.region = Rect2(r[0],r[1],r[2],r[3])
		atlas.filter_clip = true
		_textures[kind] = atlas
	return _textures[kind]


## 将旧的图标资源名映射到新绘制的高精细图标；正式物品像素图保持原样。
static func icon_for_path(path: String) -> Texture2D:
	var key := path.get_file().get_basename()
	var index: int = config().icon_order.find(key)
	if index < 0:
		return load(path) as Texture2D
	var cache_key := "icon_"+key
	if not _textures.has(cache_key):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(str(config().icons_atlas))
		var cell := atlas.atlas.get_size()/Vector2(float(config().icon_columns),float(config().icon_rows))
		atlas.region = Rect2(Vector2(index%int(config().icon_columns),floorf(float(index)/float(config().icon_columns)))*cell,cell)
		atlas.filter_clip = true
		_textures[cache_key] = atlas
	return _textures[cache_key]


## 九宫格缩放只拉伸中间皮革和直边，保留金属角饰形状与细节。
static func frame(parent: Control, kind: String, rect: Rect2, behind: bool = false, scale_override: float = 0.0) -> NinePatchRect:
	var node := NinePatchRect.new()
	var factor := scale_override if scale_override > 0 else float(config().frame_scale)
	node.texture = texture(kind)
	node.position = rect.position
	node.size = rect.size/factor
	node.scale = Vector2.ONE*factor
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	node.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	node.show_behind_parent = behind
	var margin: Array = config().frames[kind].margin
	node.patch_margin_left = int(margin[0])
	node.patch_margin_top = int(margin[1])
	node.patch_margin_right = int(margin[2])
	node.patch_margin_bottom = int(margin[3])
	if kind in ["panel","secondary","dialogue","tooltip"]:
		node.draw_center = false
		var backing := ColorRect.new()
		backing.position = Vector2(10,10)/factor
		backing.size = (rect.size-Vector2(20,20))/factor
		backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backing.show_behind_parent = true
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; uniform vec2 canvas_size; varying vec4 panel_color; void vertex(){panel_color=COLOR;} void fragment(){vec2 p=UV*canvas_size; float grain=fract(sin(dot(floor(p*2.0),vec2(12.9898,78.233)))*43758.5453); float light=0.025*(1.0-UV.y); COLOR=vec4(vec3(0.025,0.062,0.070)+grain*0.022+light,1.0)*panel_color;}"
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("canvas_size",rect.size)
		backing.material = material
		node.add_child(backing)
		node.resized.connect(func() -> void: backing.size = node.size-Vector2(20,20)/factor)
	parent.add_child(node)
	return node


## 数值条沿垂直方向分层高光，框架仍由独立金属材质提供。
static func bar_fill(color: Color) -> StyleBoxTexture:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(config().bar_gradient_offsets)
	var colors := PackedColorArray()
	for value in config().bar_gradient_values:
		colors.append(Color(color.r*float(value),color.g*float(value),color.b*float(value),1))
	gradient.colors = colors
	var fill := GradientTexture2D.new()
	fill.width = 16
	fill.height = 32
	fill.gradient = gradient
	fill.fill_from = Vector2.ZERO
	fill.fill_to = Vector2.DOWN
	var style := StyleBoxTexture.new()
	style.texture = fill
	return style


## 将现有按钮换成雕刻金属材质，保留原生键鼠与拖拽语义。
static func dress_button(button: Button) -> void:
	var clear := StyleBoxEmpty.new()
	for state in ["normal","hover","pressed","disabled"]:
		button.add_theme_stylebox_override(state,clear)
	var art := frame(button,"button",Rect2(Vector2.ZERO,button.size),true,_button_scale(button.size))
	button.resized.connect(func() -> void:
		var factor := _button_scale(button.size)
		art.scale = Vector2.ONE*factor
		art.size = button.size/factor)
	button.add_theme_color_override("font_color",Color("#f3e4c2"))
	button.add_theme_color_override("font_hover_color",Color("#fff3cd"))
	button.add_theme_color_override("font_outline_color",Color("#0e181b"))
	button.add_theme_constant_override("outline_size",1)
	button.mouse_entered.connect(func() -> void: art.modulate = Color(1.2,1.13,1.02))
	button.mouse_exited.connect(func() -> void: art.modulate = Color.WHITE)


static func _button_scale(size: Vector2) -> float:
	return maxf(0.01,minf(float(config().frame_scale),minf(size.x*0.16/108.0,size.y*0.45/68.0)))


## 高分辨率原画裁掉透明外边后按比例缩至系统光标尺寸。
static func cursor_texture() -> Texture2D:
	if not _textures.has("cursor_native"):
		var image := Image.load_from_file(ProjectSettings.globalize_path(str(config().cursor_source)))
		image = image.get_region(image.get_used_rect())
		var target := int(config().cursor_size)
		var ratio := float(target)/float(maxi(image.get_width(),image.get_height()))
		image.resize(maxi(1,roundi(image.get_width()*ratio)),maxi(1,roundi(image.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
		_textures["cursor_native"] = ImageTexture.create_from_image(image)
	return _textures.cursor_native


## 引擎关闭时释放系统光标纹理引用。
static func release_cursor() -> void:
	_textures.erase("cursor_native")
