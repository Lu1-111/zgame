# ENM-02 飞奶蛾：PROCESSED v001

来源：`assets/RAW/enemies/ENM-02/v001/`；源表 SHA-256 和逐帧 RAW 路径见 `manifest.json`。

- 64×64 RGBA，右向，Nearest；固定根锚点 `(32, 32)`（`body`）。
- RAW→PROCESSED 只进行硬校验、PNG 写盘、规则 atlas 排布和元数据打包；无重绘、补间、trim、旋转、逐帧缩放或重新居中。
- `frames/<action>/`：逐帧成品；`sheets/`：每动作一行；`ENM-02_atlas_right_v001.png`：不旋转的规则图集。
- `godot/`：按 layer 分离的 SpriteFrames；atlas 相对路径指向本目录。
- `contact_sheet.png`：红线为统一 root 的审查图，不是游戏特效。
- `preview.html`：离线动作播放、逐帧步进和 root 叠加。
- `qa.json`：透明度、裁边、质心、循环接缝和源哈希记录。硬校验全部通过后才写盘。

| 动作 | 层 | 帧数 | fps | 时长(s) | 循环 |
|---|---|---:|---:|---:|---|
| idle | body | 4 | 6 | 0.667 | 是 |
| move | body | 6 | 10 | 0.600 | 是 |
| telegraph | body | 3 | 8 | 0.375 | 否 |
| attack | body | 4 | 12 | 0.333 | 否 |
| recover | body | 2 | 8 | 0.250 | 否 |
| hurt | body | 2 | 10 | 0.200 | 否 |
| death | body | 6 | 8 | 0.750 | 否 |

预警动作 telegraph 为 3 帧 / 8 fps / 0.375s，达到清单要求的 ≥0.25s；实际游戏停顿和攻击判定仍由配置决定。
