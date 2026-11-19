extends AnimatedSprite2D
## 克拉弗特两阶段完整逐帧闲置；一阶段同步根座，二阶段同步无根花心。
@export_enum("phase_1_idle","phase_2_idle") var idle_animation := "phase_1_idle"
var profile: Dictionary

func _ready() -> void:
	profile = JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses/claffert.json"))
	sprite_frames = load(str(profile.art.root)+"godot/Claffert_idle_frames.tres")
	if idle_animation == "phase_2_idle" and profile.art.has("phase2"):
		sprite_frames = load(str(profile.art.phase2.root)+"godot/Corrumpt_phase2_frames.tres")
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame_changed.connect(_sync_root)
	animation_changed.connect(_sync_root)
	play(StringName(idle_animation))
	_sync_root()

func _sync_root() -> void:
	if profile.is_empty() or not profile.art.anchors.has(str(animation)):
		return
	var anchor: Array = profile.art.anchors[str(animation)][frame]
	offset = -Vector2(anchor[0],anchor[1])
