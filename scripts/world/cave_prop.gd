extends Node2D
## 洞穴装饰按清单原生像素显示；原点是接地中心，晶石独立生成点光。
@export var asset_id := "crystal_01"
var _light: PointLight2D
var _energy := 0.0
var _seconds := 0.0
var _pulse: Dictionary

func _ready() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/art/cave_v001.json"))
	var spec: Dictionary = config.assets[asset_id]
	z_index = int(spec.z_index)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sprite := Sprite2D.new()
	sprite.texture = load(str(spec.path))
	sprite.centered = false
	sprite.position = -Vector2(spec.anchor[0],spec.anchor[1])
	add_child(sprite)
	if spec.has("light"):
		_pulse = config.crystal
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color.WHITE,Color.TRANSPARENT])
		var texture := GradientTexture2D.new()
		texture.gradient = ramp
		texture.width = int(_pulse.light_texture_size)
		texture.height = texture.width
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2.ONE / 2.0
		texture.fill_to = Vector2(1.0,0.5)
		_light = PointLight2D.new()
		_light.texture = texture
		_light.color = Color(str(spec.light.color))
		_light.position.y = -float(spec.size[1]) / 2.0
		_light.texture_scale = float(spec.light.radius) * 2.0 / texture.width
		_energy = float(spec.light.energy)
		_light.energy = _energy
		_light.range_z_min = -1
		_light.range_z_max = 20
		add_child(_light)
	else:
		set_process(false)

func _process(delta: float) -> void:
	_seconds += delta
	_light.energy = _energy * (1.0 + sin(_seconds * TAU / float(_pulse.pulse_seconds))*float(_pulse.pulse_amount))
