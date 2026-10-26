class_name DamageNumber
extends Node2D
## 每次实际扣血的独立飘字；不依赖攻击特效是否播放成功。
var amount := 0
var magic := false
var _age := 0.0


func _ready() -> void:
	z_index = 30
	queue_redraw()


func _process(delta: float) -> void:
	var cfg: Dictionary = EncounterRules.config().feedback
	_age += delta
	position.y -= float(cfg.number_rise)*delta
	modulate.a = clampf(1.0-_age/float(cfg.number_seconds),0,1)
	if _age >= float(cfg.number_seconds):
		queue_free()


func _draw() -> void:
	var cfg: Dictionary = EncounterRules.config().feedback
	var text := str(amount) if amount > 0 else "抵抗"
	var color := Color(str(cfg.number_magic if magic else cfg.number_physical))
	var origin := Vector2(-16,0)
	draw_string(ThemeDB.fallback_font,origin+Vector2.ONE,text,HORIZONTAL_ALIGNMENT_CENTER,32,int(cfg.number_font_size),Color("#17131b"))
	draw_string(ThemeDB.fallback_font,origin,text,HORIZONTAL_ALIGNMENT_CENTER,32,int(cfg.number_font_size),color)
