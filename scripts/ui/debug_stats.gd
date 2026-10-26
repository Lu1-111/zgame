class_name DebugStats
extends Label
## M1 调试面板：三资源 / 状态 / 冷却实时显示（M2 HUD 实装后移除）。

var player: Node = null


func _process(_delta: float) -> void:
	if player == null:
		return
	text = "HP %d/%d   STA %d/%d   MANA %d/%d   武器: %s\n状态: %s   连击: %d   I人物 · Tab行囊 · 1-5道具 · 滚轮选择/侧键4技能 · E交互" % [
		GameState.hp, GameState.hp_max,
		GameState.sta, GameState.sta_max,
		GameState.mana, GameState.mana_max,
		String(GameState.weapon_id),
		String(player.sm.current_name()),
		player.attack_combo,
	]
