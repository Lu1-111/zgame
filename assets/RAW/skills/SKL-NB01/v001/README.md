# SKL-NB01 · 原始素材与实际提示词

本批采用制作人 2026-10-26 最新六技能清单。主角造型参考 `assets/RAW/characters/CHR-01/v001/CHR-01_master_right_v001.png`。全部原画使用内置 image_gen；没有使用 CLI 或外部模型。

## 入选原稿

| 技能 | 原图 | 实际提示词 |
|---|---|---|
| 新奶流-拔刀 | SKL-N01_quickdraw_right_v001.png | SKL-N01_quickdraw_right_v001.prompt.txt |
| 奶龙大笑 | SKL-N02_laughter_right_v002.png | SKL-N02_laughter_right_v002.prompt.txt |
| 王从天降 | SKL-N03_king_slam_right_v001.png | SKL-N03_king_slam_right_v001.prompt.txt |
| 奶之毅力 | SKL-N04_endurance_right_v001.png | SKL-N04_endurance_right_v001.prompt.txt |
| 虚式-奶 | SKL-N05_void_milk_right_v001.png | SKL-N05_void_milk_right_v001.prompt.txt |
| 奶法之源 | SKL-N06_arcane_source_right_v001.png | SKL-N06_arcane_source_right_v001.prompt.txt |
| 六枚图标图集 | SKL-NB01_icons_v002.png | SKL-NB01_icons_v002.prompt.txt |

大笑 v001、备用角色/特效分张 v003、图标 v001 保留为过程稿，不进入本批正式帧序。图标 v002 修正了通用龙的角、翅膀和鳞片，使其符合 CHR-01 的圆润造型。

原稿 RGBA 保留。原图并非等分网格：切行边界在 `processing_config.json` 中人工复核，角色按连通区域分离相邻帧，附近原始 RGBA 保留；分离后的角色帧不包含孤立表情符号和散落特效。独立特效按透明间隙切列，固定源 root 与缩放比例，不按每帧包围框归一化。具体来源矩形、锚点和原图 SHA-256 写入成品 `manifest.json`。

## 重建

从项目根目录执行，先让 Node 能找到已安装的 sharp 库，再运行：

```bash
node tools/process_skill_nb01.mjs
```

本机 bundled sharp 路径可由工作区依赖工具获得，运行时通过 `NODE_PATH` 指定。脚本只机械分帧、最近邻缩小、透明画布排布和资源打包，不调用生图，也不修改 RAW 源图。

## 对应交付

`assets/PROCESSED/skills/SKL-NB01/v001/`；设计与玩法待定项见 `docs/主角六技能设计与素材-SKL-NB01.md`。全部提示词以各文件中保存的全文为准。
