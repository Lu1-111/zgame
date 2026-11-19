class_name DangerWarning
extends AnimatedSprite2D
## 可复用的短促红色预警，既可独立播放，也可跟随招式剩余时长定位。
var _seconds := 0.0
var _elapsed := 0.0
var _automatic := false

func _init() -> void:
	var cfg: Dictionary = DamageFeedback.config().danger_warning
	sprite_frames = load(str(cfg.frames)) as SpriteFrames
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = Vector2(cfg.offset[0],cfg.offset[1])
	modulate.a = float(cfg.opacity)
	scale = Vector2.ONE*float(cfg.scale)
	z_index = 1
	hide()
	set_process(false)

## 从产生到消失完整播放一次，缺省持续0.2秒。
func play_warning(seconds: float = -1.0) -> void:
	_seconds = seconds if seconds > 0 else float(DamageFeedback.config().danger_warning.seconds)
	_elapsed = 0
	_automatic = true
	set_process(true)
	seek_warning(0)

## 用归一化进度驱动逐帧，与冲撞起点精确同步。
func seek_warning(progress: float) -> void:
	if progress < 0 or progress >= 1:
		hide()
		return
	show()
	animation = &"warning"
	frame = mini(int(progress*sprite_frames.get_frame_count(animation)),sprite_frames.get_frame_count(animation)-1)
	pause()

## 取消招式或死亡时立即清除残留预警。
func clear() -> void:
	_automatic = false
	set_process(false)
	hide()

func _process(delta: float) -> void:
	if _automatic:
		_elapsed += delta
		seek_warning(_elapsed/_seconds)
		if _elapsed >= _seconds:
			clear()
