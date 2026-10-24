extends RefCounted
## test_project_config.gd —— 工程配置用例（QA，T-004）
## 断言 project.godot 的锚点：InputMap 全动作、主场景、物理层名、视口 640×360、物理 60Hz。

## 附录 C / AGENTS.md §5 要求的全部输入动作（move_down/weapon_next 为 M1 新增）
const REQUIRED_ACTIONS := [
	"move_left", "move_right", "move_down", "jump", "dodge", "guard", "attack",
	"skill_1", "skill_2", "skill_3", "skill_4",
	"item_1", "item_2", "item_3", "item_4", "item_5",
	"interact", "inventory", "map", "pause", "weapon_next",
]

## AGENTS.md §6 物理层名（layer_1..layer_9 依次）
const LAYER_NAMES := [
	"world", "player_body", "enemy_body", "player_hitbox",
	"enemy_hitbox", "hurtbox", "interactable", "oneway", "hazard",
]

func run(ctx) -> bool:
	# ---- InputMap：动作齐全且 events 非空 ----
	for action in REQUIRED_ACTIONS:
		if InputMap.has_action(action):
			var ev_count := InputMap.action_get_events(action).size()
			ctx.expect_true(ev_count > 0, "InputMap 动作 '%s' 存在且 events 非空（%d 个事件）" % [action, ev_count])
		else:
			ctx.expect_true(false, "InputMap 动作 '%s' 存在且 events 非空（动作缺失）" % action)

	# ---- ProjectSettings：主场景 ----
	ctx.expect_eq(
		String(ProjectSettings.get_setting("application/run/main_scene", "<缺失>")),
		"res://scenes/main.tscn",
		"application/run/main_scene == res://scenes/main.tscn")

	# ---- ProjectSettings：2D 物理层名 layer_1..layer_9 ----
	for i in LAYER_NAMES.size():
		var key := "layer_names/2d_physics/layer_%d" % (i + 1)
		ctx.expect_eq(
			String(ProjectSettings.get_setting(key, "<缺失>")),
			LAYER_NAMES[i],
			"%s == \"%s\"" % [key, LAYER_NAMES[i]])

	# ---- ProjectSettings：视口与物理帧率 ----
	ctx.expect_eq(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", -1)),
		640,
		"display/window/size/viewport_width == 640")
	ctx.expect_eq(
		int(ProjectSettings.get_setting("display/window/size/viewport_height", -1)),
		360,
		"display/window/size/viewport_height == 360")
	ctx.expect_eq(
		int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", -1)),
		60,
		"physics/common/physics_ticks_per_second == 60（物理 60Hz）")
	return true
