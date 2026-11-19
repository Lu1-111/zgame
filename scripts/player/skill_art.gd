class_name SkillArt
extends Node2D
## 独立技能特效，只播放合作者原始逐帧；生命周期由技能逻辑驱动。
var animation := ""
var duration := 0.0
var elapsed := 0.0
var facing := 1
var loop := false
var persistent := false
var frame_override := -1

## 创建有明确时限的特效；局部挂接和世界放置使用同一入口。
static func spawn(parent: Node, id: String, point: Vector2, seconds: float, direction: int = 1, repeat: bool = false) -> SkillArt:
	var art := SkillArt.new()
	art.animation = id
	art.duration = seconds
	art.facing = direction
	art.loop = repeat
	art.position = point
	art.z_index = 1
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(art)
	return art

func _physics_process(delta: float) -> void:
	elapsed += delta
	if not persistent and elapsed >= duration:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var cfg := SkillLibrary.animation(animation)
	if cfg.is_empty():
		return
	var index := frame_override if frame_override >= 0 else floori(elapsed*float(cfg.fps))
	index = posmod(index,cfg.frames.size()) if loop else mini(index,cfg.frames.size()-1)
	var root: Array = cfg.root
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
	draw_texture(SkillLibrary.texture(str(cfg.frames[index])),-Vector2(root[0],root[1]))
