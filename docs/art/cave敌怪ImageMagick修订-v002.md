# 洞穴敌怪ImageMagick修订

2026-11-17。制作人指出首轮仍有伪像素观感，本轮直接重处理全部新增洞穴敌怪及配套效果，并将全部动作速度改为原来的0.75倍。运行路径仍保留v001，内部修订号为imagemagick_v002，避免现有引用断开。

## 实际转换

使用[ImageMagick官方Windows便携版](https://imagemagick.org/download/)，实际版本ImageMagick 7.1.2-36 Q8 x64；程序和下载校验保存在work/imagemagick，未安装系统服务或修改全局PATH。转换脚本为tools/assets/convert_cave_imagemagick.py，配置为data/art/cave_enemy_imagemagick.json。

- 从RAW原始母版直接按固定源格和数值比例一次Point点采样；没有对旧面积采样成品再次缩放，也没有输出整数放大图充当运行贴图。
- 骨龙与兽类各使用统一16色色板；+dither关闭抖动，不通过面积平均制造过渡色。ImageMagick的[sample/remap/alpha选项](https://imagemagick.org/command-line-options/)承担真实像素处理，Python只负责参数、文件组织、元数据和检查图排版。
- RGB限色前单独保存alpha蒙版，限色后恢复，防止透明区域被映射成不透明色条。硬边alpha仅0/255，运行PNG去除附加元数据。
- 保持全部原生画布、1:1缩放、身体大小和固定锚点。骨龙仍以约42px本体为参照，猎手等保留较大原生体型，武器外伸不会导致身体重新缩放。
- 70张骨龙/箭矢帧、114张兽类/效果帧的RGBA内容全部实际改变。动作保持至少4张独立姿态，兽类每套仍6张独立帧，未用重复静帧冒充转换。

每帧转换记录位于两包pixel_conversion.json，包含原始母版哈希、源格、目标像素数、固定偏移、完整magick参数、工具版本/程序哈希及输出RGBA哈希。数字门禁只是必要条件，仍需对照1×画面、4×检查图与动作形态。

## 速度与时长

27套本体动作和4套箭矢/丝线弹/尖晶石/震荡波，共31套。base_fps保留原始速度，当前fps为其0.75倍；完整时长增加为原4/3。重复构建仍从base_fps计算，不会再次乘0.75。

| 原始fps | 当前fps | 6帧原时长 | 6帧当前时长 |
|---|---|---|---|
| 6 | 4.5 | 1秒 | 1.333秒 |
| 8 | 6 | 0.75秒 | 1秒 |
| 9 | 6.75 | 0.667秒 | 0.889秒 |
| 10 | 7.5 | 0.6秒 | 0.8秒 |
| 12 | 9 | 0.5秒 | 0.667秒 |

SpriteFrames、统一目录、分怪目录和逐动作GIF均同步。GIF以10ms为最小单位，通过逐帧分配舍入误差控制总时长，与资源时长误差不超过10ms。检视AnimatedSprite2D.speed_scale仍为1，不再叠加第二次减速。基础战斗数值仍为null。

## 备份、重建与查看

转换前483文件完整副本：backup/2026-11-17_cave_before_imagemagick，带.gdignore与逐文件SHA256清单。旧面积采样构建器已阻止覆盖当前结果；重建使用：

```text
python tools/assets/convert_cave_imagemagick.py --magick <magick可执行文件> --apply
```

参数和色板先在JSON中明确登记；工具失败、源哈希改变、整批不完整或姿态丢失时停止替换。需要重新登记有效范围时，必须先实际查看，再运行register_pixel_metrics.py；测试不会自动覆盖预期数据。

双击[test/launchers/run_cave_enemies.cmd](../../test/launchers/run_cave_enemies.cmd)查看全部动作。实际引擎截图在docs/previews/cave_enemies_v001；[前后对照](../previews/cave_imagemagick_v002/before_after.png)是4倍nearest检查图；运行帧仍是登记的原生分辨率。

## 验收

```text
cave_imagemagick_final_import exit=0 diagnostics=0
CAVE ENEMY ART: 347 checks / 0 failures / 27 actions / 184 frames
PIXEL PACKAGES: 4 packages / 348 images / 0 failures
PIXEL GATE NEGATIVE CASES: 6 checks / 0 failures
passed=1761 / total=1761
```

引擎计时逐套完整播放31段动画至末帧，记录目标及实测时长到work/qa/cave_enemy_playback_timings.json；避免把资源首次同步加载前的delta算进动作计时。7种敌怪已重新输出实际检视截图。正式beta的内容收集排除backup、RAW、此转换配方与美术储备定义，未执行版本发布。
