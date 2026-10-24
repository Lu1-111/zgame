class_name DebugStats
extends Label
## M1 调试面板：三资源 / 状态 / 冷却实时显示（M2 HUD 实装后移除）。

var player: Node = null


func _process(_delta: float) -> void:
	if player == null:
		return
	text = "HP %d/%d   STA %d/%d   MANA %d/%d   武器: %s\n状态: %s   连击: %d   演示: T切武器 · 1-4用道具 · Q/R/F技能 · E拾取" % [
		GameState.hp, GameState.hp_max,
		GameState.sta, GameState.sta_max,
		GameState.mana, GameState.mana_max,
		String(GameState.weapon_id),
		String(player.sm.current_name()),
		player.attack_combo,
	]
