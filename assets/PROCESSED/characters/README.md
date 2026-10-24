# NPC-S 可玩素材 PROCESSED v001

来源：`assets/RAW/characters/NPC-S01`～`NPC-S06` 的 `v002/`。6 名 NPC 各 1 张 master、6 帧 idle、8 帧 walk、4 帧 talk；全批 18 套动画、108 帧。

| ID | 角色 | SpriteFrames |
|---|---|---|
| NPC-S01 | 奶兔向导 | `NPC-S01/v001/godot/NPC-S01_sprite_frames.tres` |
| NPC-S02 | 奶牛商人 | `NPC-S02/v001/godot/NPC-S02_sprite_frames.tres` |
| NPC-S03 | 奶鼠工匠 | `NPC-S03/v001/godot/NPC-S03_sprite_frames.tres` |
| NPC-S04 | 奶龙学者 | `NPC-S04/v001/godot/NPC-S04_sprite_frames.tres` |
| NPC-S05 | 奶熊守卫 | `NPC-S05/v001/godot/NPC-S05_sprite_frames.tres` |
| NPC-S06 | 奶鸟信使 | `NPC-S06/v001/godot/NPC-S06_sprite_frames.tres` |

- 64×64 RGBA，正面，root `(32,58)`。
- 场景中使用 `AnimatedSprite2D.centered=false`、`offset=(-32,-58)`。
- idle 6 帧 / 8fps 循环；walk 8 帧 / 12fps 循环；talk 4 帧 / 8fps 非循环。
- 每种目录包含逐帧 PNG、单行 sheet、规则 atlas、SpriteFrames、manifest、QA 和 README。
- `NPC_series_manifest.json` / `NPC_series_qa.json` 为全批索引与验收（当前 `passed=true`）。
- `NPC_series_contact_sheet_v001.png` 为总览。

## Godot 接入

已在 `scenes/levels/test_arena.tscn` 布置 6 个实例，进入试玩场即可看到巡逻；靠近 NPC 显示“E 交谈”，按 E 进入对话，再按 E 推进/关闭。

- 可复用场景：`scenes/npcs/npc.tscn`，实例覆写 `frames`、姓名、台词和巡逻半径。
- 控制脚本：`scripts/world/npc.gd`。
- 对话框：`scenes/ui/npc_dialogue.tscn` + `scripts/ui/npc_dialogue.gd`。
- 交互输入：项目现有 `interact` 动作，默认 E 键。

当前是直线往返巡逻，不含寻路、跳跃、交易或任务状态；左向动作由运行时翻转 sprite 实现，未单独绘制左向帧。
