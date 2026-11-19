class_name PlayerTuning
extends RefCounted
## 玩家手感参数表（参考书 §3.1，60Hz 物理）。
## player.gd 与 player_states.gd 共用此叶文件，避免二者循环引用。
## 土狼时间与闪避从data/player_movement.json读取，其余常量保留既有值。

# ---- 移动 ----
const MAX_SPEED := 160.0          ## 水平最大速度
const GROUND_ACCEL := 1600.0      ## 地面加速
const GROUND_DECEL := 2200.0      ## 地面减速（停得要"急"）
const AIR_ACCEL := 1200.0         ## 空中加速
const AIR_DECEL := 800.0          ## 空中减速
const GRAVITY_UP := 1800.0        ## 上升重力（落得比升得快）
const GRAVITY_DOWN := 2600.0      ## 下降重力
const MAX_FALL := 700.0           ## 最大下落速度

# ---- 跳跃（2026-10-24 制作人调参：跳高翻倍 56.25→112.4px；偏离 §3.1 原值 450/400）----
## 跳跃初速：按 h = v²/(2g) 反算，112.4px（原 56.25 的 2 倍）→ v = sqrt(2*1800*112.4) ≈ 636
const JUMP_VELOCITY := 636.0      ## 跳跃初速（跳高 112.4px ≈ 7 格，制作人要求 2 倍）
const JUMP_CUT_MULT := 0.45       ## 松键短跳倍率
const DOUBLE_JUMP_VELOCITY := 566.0  ## 二段跳初速（奶泡跃，跳高 89px 同步翻倍）
static var _movement: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/player_movement.json"))
static var COYOTE_TIME: float = float(_movement.jump.coyote_time) ## 离开支撑后的普通跳宽限。
const JUMP_BUFFER := 0.12         ## 跳跃缓冲

# ---- 闪避（2026-10-24 制作人调参：距离调低/速度调快/取消残余惯性；偏离 §3.1 原值 900/0.18）----
static var _dodge: Dictionary = _movement.dodge
static var DODGE_SPEED: float = float(_dodge.speed) ## 2026-11-02：距离×1.5、时长×2；速度×0.75。
static var DODGE_TIME: float = float(_dodge.duration)
static var DODGE_IFRAME_START: float = float(_dodge.iframe_start)
static var DODGE_IFRAME_END: float = float(_dodge.iframe_end)
static var DODGE_COOLDOWN: float = float(_dodge.cooldown)
static var DODGE_STA_COST: int = int(_dodge.stamina_cost)

# ---- 防御 ----
const GUARD_MOVE_MULT := 0.4         ## 防御移速 40%（减伤/反弹比例在 CombatMath）
const GUARD_BREAK_STUN := 0.6        ## 破防硬直

# ---- 受击 ----
const HURT_INVULN := 0.8             ## 受击无敌
const HURT_KNOCKBACK := 180.0        ## 受击击退
const HURT_STUN := 0.2

# ---- 上台辅助（mantle，2026-10-24 制作人规格）----
const MANTLE_MARGIN := 12.0   ## 下落中脚部距单向平台顶面 ≤ 此值时吸附上台

# ---- 体力 ----
const STA_REGEN := 30.0              ## 体力回复 30/s（2026-10-24 制作人调参，原 12/s）
const STA_REGEN_DELAY := 0.8         ## 停手 0.8s 后回复

# ---- 普攻 ----
const ATK_STARTUP := 0.10            ## 起手
const ATK_ACTIVE := 0.12             ## 判定窗
const ATK_RECOVERY := 0.18           ## 后摇（可被闪避/技能/连击取消）
const ATTACK_BUFFER := 0.12
const ATTACK_KB := 240.0             ## 普攻击退
const ATTACK_KB_FINISH := 340.0      ## 连击末段强击退

# ---- 技能 ----
const SKILL_STARTUP := 0.08          ## 起手
const SKILL_RECOVERY := 0.15         ## 后摇（可被闪避/普攻取消）
const SKILL_KB := 160.0

# ---- 其他 ----
const LAND_TIME := 0.05              ## 落地缓冲（可随时被输入打断）
const BODY_MASK := 1 | 128           ## world + oneway
const DROP_THROUGH_TIME := 0.2       ## 下穿单向平台时长
