extends RefCounted
## 从 manifest 同步生成的锚点与挂点；预载脚本保证导出包无需运行时 JSON。
const EFFECTS: Dictionary = {
	"physical_hit": {
		"id": "FX-01_physical_hit",
		"anchor": [
			32,
			32
		],
		"attachPoint": "hit",
		"fadeStartNormalized": 0.7,
		"opacityByFrame": [
			1,
			1,
			1,
			1,
			1,
			1
		]
	},
	"magic_hit": {
		"id": "FX-01_magic_hit",
		"anchor": [
			32,
			32
		],
		"attachPoint": "hit",
		"fadeStartNormalized": 0.7,
		"opacityByFrame": [
			1,
			1,
			1,
			1,
			1,
			1
		]
	},
	"guard_spark": {
		"id": "FX-01_guard_spark",
		"anchor": [
			32,
			32
		],
		"attachPoint": "contact",
		"fadeStartNormalized": 0.7,
		"opacityByFrame": [
			1,
			1,
			1,
			1,
			1,
			1
		]
	},
	"perfect_parry": {
		"id": "FX-01_perfect_parry",
		"anchor": [
			32,
			32
		],
		"attachPoint": "contact",
		"fadeStartNormalized": 0.7,
		"opacityByFrame": [
			1,
			1,
			1,
			1,
			1,
			1
		]
	},
	"guard_break": {
		"id": "FX-01_guard_break",
		"anchor": [
			32,
			32
		],
		"attachPoint": "shield_center",
		"fadeStartNormalized": 0.7,
		"opacityByFrame": [
			1,
			1,
			1,
			1,
			1,
			1
		]
	},
	"landing_dust": {
		"id": "FX-02_landing_dust",
		"anchor": [
			32,
			48
		],
		"attachPoint": "feet",
		"fadeStartNormalized": 0.7,
		"opacityByFrame": [
			1,
			1,
			1,
			1,
			1,
			1
		]
	},
	"takeoff_dust": {
		"id": "FX-02_takeoff_dust",
		"anchor": [
			32,
			48
		],
		"attachPoint": "feet",
		"fadeStartNormalized": 0.7,
		"opacityByFrame": [
			1,
			1,
			1,
			1,
			1,
			1
		]
	},
	"double_jump_bubble": {
		"id": "ABL-01_double_jump_bubble",
		"anchor": [
			32,
			48
		],
		"attachPoint": "feet",
		"fadeStartNormalized": 0.7,
		"opacityByFrame": [
			1,
			1,
			1,
			1,
			1,
			1
		]
	},
	"dodge_afterimage": {
		"id": "FX-02_dodge_afterimage",
		"anchor": [
			48,
			64
		],
		"attachPoint": "actor_root",
		"fadeStartNormalized": 0.7,
		"opacityByFrame": [
			0.35,
			0.45,
			0.3,
			0.2,
			0.12,
			0.08
		]
	},
	"hammer_swing_1": {
		"id": "WPN-01_hammer_swing_1",
		"anchor": [
			32,
			32
		],
		"attachPoint": "weapon_swing_pivot",
		"fadeStartNormalized": 0.7,
		"opacityByFrame": [
			1,
			1,
			1,
			1,
			1,
			1
		]
	},
	"hammer_swing_2": {
		"id": "WPN-01_hammer_swing_2",
		"anchor": [
			32,
			32
		],
		"attachPoint": "weapon_swing_pivot",
		"fadeStartNormalized": 0.7,
		"opacityByFrame": [
			1,
			1,
			1,
			1,
			1,
			1
		]
	},
	"hammer_slam_3": {
		"id": "WPN-01_hammer_slam_3",
		"anchor": [
			32,
			48
		],
		"attachPoint": "ground_contact",
		"fadeStartNormalized": 0.7,
		"opacityByFrame": [
			1,
			1,
			1,
			1,
			1,
			1
		]
	}
}
