# corrumpt 演出素材生成记录

模式：内置 imagegen，透明背景；未使用 CLI/API fallback。

## 绽开与枯萎

参考：`v005/frames/phase_1_idle/00.png`、`phase2_v001/frames/phase_2_idle/00.png`，调用前已逐张查看。

原始生成文件：`C:/Users/29845/.codex/generated_images/01a172b4-1738-7372-85ad-4ff413e2eadb/exec-8bcab77f-a12b-419c-8925-0e401e372dee.png`，项目副本：`sources/opening.png`。

完整提示词：

Asset type: exact character-consistent pixel-art transition animation spritesheet for existing purple corrupted plant boss in TWO reference images. First reference is the closed heart-like purple bud with olive roots, second is its rootless frontal three-layer blade-petal flower. Generate EXACTLY SIX CELLS in a3-column by2-row regular grid. Each cell a logical128x128 transparent canvas, common center x64, grounded root anchor(64,112); body remains about84 native pixels high. Sequence left-to-right top-to-bottom:1 same closed bud as reference1,2 outer bud seams open slightly, roots darken;3 bud opens halfway showing dark center, short basal roots droop and wither;4 purple petals unfold, roots shrivel thinner;5 nearly open frontal flower, dead roots falling to small fragments;6 same front-facing rootless sharp-bladed flower as reference2, flower center at(64,64). Match the original silhouette, restricted muted purple/olive/black32-color palette and chunky native pixel density EXACTLY. No new giant leaves, no new eyes or limbs, no over-rendered texture, no antialiasing or smooth gradients. Keep original body scale consistent from bud to flower; sharp, hand-placed pixel clusters. Do not draw the long external attack tentacles, they are separate layers. All parts fully inside their own cells, consistent generous transparent gutters. Actual transparent background; no text, labels, frames, scenery, floor, UI or camera perspective changes. This is a full-body frame animation, NOT bones or cut-out pieces.

## 虚空核心

原始生成文件：`C:/Users/29845/.codex/generated_images/01a172b4-1738-7372-85ad-4ff413e2eadb/exec-362efdb2-1eff-4a3a-a0af-d7a617848159.png`，项目副本：`sources/void.png`。

完整提示词：

Asset type: transparent pixel-art VFX spritesheet for the dark central void in an existing purple blade-flower boss. Exactly4 equally-sized square cells in a single horizontal row, same centered alignment, each logical96x96. A truly black circular void core, no face or eyes, encircled by a very thin jagged dark-purple/lavender rotating accretion rim; small restrained wisps curve around the rim, no long rays. All4 frames have EXACTLY same black disk radius34 logical pixels and outside footprint about84x84; only the thin swirling rim subtly circulates between frames. Pixel style must match a hand drawn muted32-color dark-fantasy game, crisp native pixels, no smooth gradients, no antialiasing, no photorealistic bloom. The opaque center must be near-black, not transparent; everything OUTSIDE the swirling disk is true transparent alpha. This overlay will start small in the center of the flower and grow to6 times its initial diameter. Do not depict a flower, roots, boss body, character, UI, text, labels, background or outer rectangle. Keep generous transparent gutter and exact centers in each cell. Limited black and desaturated violet/lilac palette.

## 确定性转换

`tools/assets/build_corrumpt_sequences.py`使用ImageMagick裁格、等比采样、限色、硬透明与统一画布装配；Pillow只读取尺寸与透明边界。绽开首帧和末帧直接复制已批准的正式Boss帧，保持原画和锚点。黑洞生成图中心存在透明缺口，转换时补上半径34px的不透明近黑圆盘，避免黑洞内部透出背景。
