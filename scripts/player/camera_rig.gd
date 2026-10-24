class_name CameraRig
extends Camera2D
## 平滑跟随摄像机（参考书 §2.5）：lerp 8.0 + 前瞻 40px + 房间边界钳制 + 屏震（0.15s/3px）。
## 作为 Player 子节点使用；房间边界由房间脚本经 set_bounds() 注入（M2 RoomBuilder 接管）。

const FOLLOW_LERP := 8.0     ## 跟随平滑系数
const LOOKAHEAD := 40.0      ## 朝向前瞻像素
const SHAKE_TIME := 0.15
const SHAKE_PX := 3.0

var _bounds := Rect2()
var _has_bounds := false
var _shake_px := SHAKE_PX
var _shake_left := 0.0


## 注入房间边界（像素），摄像机会被钳制在该矩形内。
func set_bounds(r: Rect2) -> void:
	_bounds = r
	_has_bounds = true
	limit_left = int(r.position.x)
	limit_top = int(r.position.y)
	limit_right = int(r.end.x)
	limit_bottom = int(r.end.y)


## 屏震（px 强度，默认 0.15s）。
func shake(px: float = SHAKE_PX, duration: float = SHAKE_TIME) -> void:
	_shake_px = px
	_shake_left = duration


func _physics_process(delta: float) -> void:
	var target := get_parent() as Node2D
	if target != null:
		var face := float(target.get("facing")) if target.get("facing") != null else 0.0
		var want := target.global_position + Vector2(LOOKAHEAD * signf(face), 0.0)
		global_position = global_position.lerp(want, 1.0 - exp(-FOLLOW_LERP * delta))
	if _shake_left > 0.0:
		_shake_left -= delta
		offset = Vector2(randf_range(-_shake_px, _shake_px), randf_range(-_shake_px, _shake_px))
		if _shake_left <= 0.0:
			offset = Vector2.ZERO
