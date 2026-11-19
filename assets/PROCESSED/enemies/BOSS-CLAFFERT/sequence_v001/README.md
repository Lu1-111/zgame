# corrumpt 转阶段与虚空湮灭逐帧资源

本包增加演出素材，不覆盖已批准的一、二阶段战斗帧。源图由内置imagegen生成，完整提示词和参考见[PROMPTS.md](PROMPTS.md)。

| 动画 | 规格 | 对齐 | 播放 |
|---|---|---|---|
| opening | 6帧，128×128，共同32色色板，alpha仅0/255 | 根座(64,112)，最终花心(64,64) | 运行时按1.8秒演出进度选帧 |
| void | 4帧，96×96，近黑中心与淡紫旋涡 | 中心(48,48)，不透明圆盘半径34px | 12fps循环 |

opening首帧逐字节复用`v005/frames/phase_1_idle/00.png`，末帧复用`phase2_v001/frames/phase_2_idle/00.png`。中间帧依次绽开并枯萎短根；长触手另复用当前完整逐帧层，逐渐枯暗消失。全部nearest显示，不含骨骼或网格变形。

黑洞从Boss原有花心半径6px扩大到60px（10倍，2026-11-12更新），核心纹理等比缩放；损伤判定使用相同中心和半径。紫色全屏遮罩与上下黑边由Control绘制，确保分辨率变化时仍完整覆盖画面。

重建：`python tools/assets/build_corrumpt_sequences.py`，再运行Godot导入。行为和演出数值见`data/bosses/claffert.json.sequence`，统一破韧公式见`data/boss_rules.json`。验收脚本为`test/integration/test_corrumpt_sequences.gd`，实际画面见`docs/previews/corrumpt_sequences.mp4`。
