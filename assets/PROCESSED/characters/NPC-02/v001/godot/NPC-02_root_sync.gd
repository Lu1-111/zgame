extends AnimatedSprite2D

const FRAME_ANCHORS = {
	&"idle": Vector2(32, 58),
	&"talk": Vector2(32, 58),
	&"trade_offer": Vector2(32, 58),
	&"trade_confirm": Vector2(32, 58)
}

func _ready():
	animation_changed.connect(_sync_root)
	_sync_root()

func _sync_root():
	offset = -FRAME_ANCHORS.get(animation, Vector2(32, 58))
