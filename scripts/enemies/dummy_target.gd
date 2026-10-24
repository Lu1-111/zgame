extends Node2D
## M1 假人靶：无 AI 静态目标，用于验证命中管线（Hitbox→Hurtbox→结算→顿帧/屏震/扣血）。
## 不真死：归零后 1.5s 复位，方便连续试刀。

const HP_MAX := 100
const SIZE := 28.0  ## 靶体边长（px）

var hp := HP_MAX
var _flash := 0.0

@onready var _label: Label = $HpLabel


func _ready() -> void:
	$Hurtbox.hit_callback = _on_hit
	$Hurtbox.owner_actor = self
	_update_label()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
	queue_redraw()


## 受击回调（HurtboxComponent 直通约定）：返回最终伤害供命中方做顿帧。
func _on_hit(packet: DamagePacket) -> int:
	var dmg := int(packet.amount)
	hp = maxi(0, hp - dmg)
	_flash = 0.15
	_update_label()
	if hp <= 0:
		get_tree().create_timer(1.5).timeout.connect(_revive)
	return dmg


func _revive() -> void:
	hp = HP_MAX
	_update_label()


func _update_label() -> void:
	_label.text = str(hp)


func _draw() -> void:
	var body := Rect2(-SIZE / 2.0, -SIZE / 2.0, SIZE, SIZE)
	var base := Color(0.72, 0.44, 0.44) if _flash > 0.0 else Color(0.45, 0.45, 0.5)
	draw_rect(body, base, true)
	draw_rect(body, Color(0.2, 0.2, 0.24), false, 1.5)
