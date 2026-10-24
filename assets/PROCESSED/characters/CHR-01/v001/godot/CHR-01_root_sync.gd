extends AnimatedSprite2D

const FRAME_ANCHORS = {
	&"idle": Vector2(32, 58),
	&"run": Vector2(32, 58),
	&"jump": Vector2(32, 58),
	&"fall": Vector2(32, 58),
	&"land": Vector2(32, 58),
	&"double_jump": Vector2(32, 58),
	&"dodge": Vector2(32, 58),
	&"air_dodge": Vector2(32, 58),
	&"guard": Vector2(32, 58),
	&"parry": Vector2(32, 58),
	&"guard_break": Vector2(32, 58),
	&"hurt": Vector2(32, 58),
	&"hammer_1": Vector2(48, 90),
	&"hammer_2": Vector2(48, 90),
	&"hammer_3": Vector2(48, 90),
	&"blaster_fire": Vector2(32, 58),
	&"blaster_charge": Vector2(48, 90),
	&"staff_sweep": Vector2(48, 90),
	&"orb_cast": Vector2(48, 90),
	&"cast": Vector2(32, 58),
	&"heal": Vector2(32, 58),
	&"interact": Vector2(32, 58),
	&"rest_enter": Vector2(32, 58),
	&"rest": Vector2(32, 58),
	&"rest_exit": Vector2(32, 58),
	&"death": Vector2(32, 58)
}

func _ready():
	animation_changed.connect(_sync_root)
	_sync_root()

func _sync_root():
	offset = -FRAME_ANCHORS.get(animation, Vector2(32, 58))
