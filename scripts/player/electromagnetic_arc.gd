class_name ElectromagneticArc
extends Node2D
## 命中后按冲击波范围展开浅蓝色折线电弧。

var spec: Dictionary
var radius := 0.0
var _age := 0.0

func _ready() -> void:
	spec = WeaponAttributes.config().rifle.projectile_visuals.electromagnetic
	z_index = 1

func _process(delta: float) -> void:
	_age += delta
	if _age >= float(spec.arc_seconds):
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	if spec.is_empty():
		return
	var progress := clampf(_age / float(spec.arc_seconds), 0.0, 1.0)
	var segments := int(spec.arc_segments)
	var count := int(spec.arc_points)
	var outer := radius * sqrt(progress)
	for segment in segments:
		var points := PackedVector2Array()
		for point in count:
			var angle := TAU * (segment + float(point) / count * float(spec.arc_span)) / segments
			var drift := float(spec.arc_jagged_px) * (-1 if (point + segment) % 2 == 0 else 1)
			points.append((Vector2.from_angle(angle) * maxf(0.0, outer + drift)).round())
		draw_polyline(points, Color(str(spec.arc_color)), 1.0, false)
