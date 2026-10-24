# AGENTS.md — 《奶龙：银河征途》工程公约（所有 Agent 必读）

- 项目：2D 横版类银河恶魔城（Metroidvania）原型，GDScript
- 参考书（最高优先级需求来源）：`docs/开发计划书-奶龙银河征途.md`
- 本期范围：v1.1 范围收窄版（⓪①② 三个区域 / 15 房 / 框架全量），先工程后内容
- 与参考书冲突时：不要擅自裁决，在会话中向制作人提出

## 1. 环境与命令

| 事项 | 值 |
|---|---|
| 引擎 | Godot **4.7.2**（本机路径 `~/.local/bin/godot`；参考书写 4.4，API 按 Godot 4.x 规范，已验证可跑） |
| 平台 | Linux，工程根即本目录 |
| 导入检查 | `~/.local/bin/godot --headless --path . --import`（退出码 0 且无 ERROR） |
| 单元测试 | `~/.local/bin/godot --headless --path . --script res://tests/run_tests.gd`（退出码非 0 = 失败） |
| 冒烟启动 | `~/.local/bin/godot --headless --path . --quit-after 120` |

**提交前必须本地跑通导入检查与单元测试，贴输出。**

## 2. 三条铁律（参考书 §0）

1. 先做能玩的手感，再做内容。
2. 一切数值进表（`data/*.json`），不进代码；代码里禁止魔法数字。
3. 每个里程碑结束必须有一个能双击运行的构建。

## 3. 目录与文件所有权（参考书 §7.1）

| 角色 | 负责 | 禁改 |
|---|---|---|
| Architect | `scripts/autoload/`、`scripts/core/`、`scripts/components/`、存档、房间构建器、`project.godot` | `data/*.json`、美术 |
| Gameplay | `scripts/player/`、`scripts/enemies/`、`scripts/ui/`、战斗逻辑 | `data/`（只读）、`tests/` |
| Level/Balance | `data/world/regions.json`、`data/*.json`、数值 | 所有 `.gd` |
| QA | `tests/`、冒烟、复现报告 | 其他一切 |

并行铁律：**同一时间只有一个 Agent 改 `scenes/`**；数据表独占；合并走 `dev` + 测试门禁。

```
res://
├── AGENTS.md                  ← 本文件
├── docs/                      ← 计划书、框架说明、数据契约
├── project.godot
├── assets/{sprites,audio,fonts}/   本期留空结构（灰盒期无素材）
├── data/                      ★ 数据驱动核心（严格 JSON，无注释）
│   ├── world/regions.json     区域+房间+门+刷怪+宝箱
│   └── items / weapons / skills / talents / enemies .json
├── scenes/                    main.tscn 启动场景；player/enemy/room 空壳
├── scripts/{autoload,core,components,player,enemies,ui,world}/
├── tests/                     自研测试宿主 + 用例
└── tools/                     validate_data.py 等数值/数据脚本
```

## 4. 工程约定

- **视觉**：主角 CHR-01 已接入正式素材（`assets/PROCESSED/characters/CHR-01/`，制作人 2026-10-24 决策；26 动作全朝右，运行时经 `CHR-01_sprite_frames.tres` 注入，缺失自动回退 `_draw()` 灰盒）；敌人经 ENM-B03/ENM-B04 清单接入正式动作素材（制作人 2026-10-24 决策，缺失回退灰盒）；场景仍 `_draw()` 灰盒色块。AudioManager 找不到资源时静默（warning 一次），不得报错。
- **输入只做键鼠**：手柄映射整体推迟（参考书附录 C 手柄列暂不实现）。
- autoload 脚本**禁止声明 `class_name`**（与单例注册名冲突，Godot 4 会报错）。
- GDScript 按 Godot 4.x：`velocity` 属性 + `move_and_slide()` 无参调用；禁止 Godot 3 API。
- `data/*.json` 为严格 JSON（无注释无尾逗号）；schema 见 `docs/数据契约.md`。
- Git：`main` / `dev` / `feat/*`；提交信息 `type(scope): 描述`。
- 新增公共函数写中文注释；无警告运行；不残留调试 `print`。

## 5. autoload 契约（注册顺序即依赖顺序）

| 单例 | 路径 | 职责 |
|---|---|---|
| EventBus | `res://scripts/autoload/event_bus.gd` | 纯全局信号，无逻辑 |
| GameState | `res://scripts/autoload/game_state.gd` | 运行时状态：属性/背包/快捷栏/天赋/进度 + `reset()/to_save_dict()/load_from_dict()` |
| DataDB | `res://scripts/autoload/data_db.gd` | 启动即 `load_all()` 载入 `data/*.json`，按 id 查询（`get_room/get_enemy/get_item/get_weapon/get_skill/get_talent/get_region`）；文件缺失 warning 不中断 |
| SaveSystem | `res://scripts/autoload/save_system.gd` | 双槽轮换 + `.bak` + CRC；接口 `save_game/load_game/has_save/delete_save`；禁止战斗中自动存档 |
| SceneRouter | `res://scripts/autoload/scene_router.gd` | 房间切换、0.25s 黑场转场、出生点、转场自动存档（M2 实装） |
| AudioManager | `res://scripts/autoload/audio_manager.gd` | `play_sfx/play_bgm/stop_bgm`；资源缺失静默容错 |

关键默认值（QA 用例锚点）：HP 80/80、体力 100/100、奶力 60/60、Lv1、EXP 0、奶币 0、初始武器 `hammer_01`、初始房间 `camp_01`、初始检查点 `cp_camp_01`。

## 6. 已知事项 / 待制作人决策

- **E 键冲突**：附录 C 中 `skill_2` 与 `interact` 都映射 E，现按参考书原样保留，待决策。
- **IP 命名**：对外工程名用「奶宝：银河征途」（参考书 §1.6 建议），文档内沿用参考书称呼；正式上线前必须全部换成原创命名。
- **单向门数据约定**：`one_way: true` 表示该门只能作为单向通道的**落点**，不可从此侧主动进入。
- **物理层**（project.godot 已注册）：1 world / 2 player_body / 3 enemy_body / 4 player_hitbox / 5 enemy_hitbox / 6 hurtbox / 7 interactable / 8 oneway / 9 hazard。
- **渲染层级（z_index）约定**：背景/远景 `-30 ~ -10`；地形 TileMapLayer `0`；装饰、道具、建筑 `1`；**角色与敌人一律 `20`**。新增装饰必须 `z_index ≤ 1`，禁止盖住角色。`build_camp.gd` / `build_forest.gd` 已按此实现。
- **素材跨机器同步**：`.import` 里的 ctex 缓存路径与本机绑定；从别的机器拷素材后要删掉对应 `.import` 再 `--import`，否则报 `No loader found for resource`。

