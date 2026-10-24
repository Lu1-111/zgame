# ENM-06 暗影奶灵：PROCESSED v002

来源：`assets/RAW/enemies/ENM-06/v002/`；源表 SHA-256 和逐帧 RAW 路径见 `manifest.json`。

- 64×64 RGBA，右向，Nearest；固定根锚点 `(32, 32)`（`body`）。
- RAW→PROCESSED 只进行硬校验、PNG 写盘、规则 atlas 排布和元数据打包；无重绘、补间、trim、旋转、逐帧缩放或重新居中。
- `frames/<action>/`：逐帧成品；`sheets/`：每动作一行；`ENM-06_atlas_right_v002.png`：不旋转的规则图集。
- `godot/`：按 layer 分离的 SpriteFrames；atlas 相对路径指向本目录。
- `contact_sheet.png`：红线为统一 root 的审查图，不是游戏特效。
- `preview.html`：离线动作播放、逐帧步进和 root 叠加。
- `qa.json`：透明度、裁边、质心、循环接缝和源哈希记录。硬校验全部通过后才写盘。

| 动作 | 层 | 帧数 | fps | 时长(s) | 循环 |
|---|---|---:|---:|---:|---|
| idle | body | 6 | 8 | 0.750 | 是 |
| move | body | 8 | 12 | 0.667 | 是 |
| telegraph | body | 4 | 10 | 0.400 | 否 |
| attack | body | 6 | 14 | 0.429 | 否 |
| recover | body | 3 | 10 | 0.300 | 否 |
| hurt | body | 3 | 12 | 0.250 | 否 |
| death | body | 8 | 10 | 0.800 | 否 |
| immune | body | 6 | 10 | 0.600 | 是 |

预警动作 telegraph 为 4 帧 / 10 fps / 0.400s，达到清单要求的 ≥0.25s；实际游戏停顿和攻击判定仍由配置决定。
