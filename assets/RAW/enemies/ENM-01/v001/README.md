# ENM-01 苔甲虫：RAW 原生像素帧

生成日期：2026-10-24。生成方式：`work/enm_pipeline/generate_raw.py` 确定性原生像素绘制；不是对已有关键帧自动补间。

- 画布：64×64，右向，真 Alpha PNG，Nearest。
- 固定根锚点：`(32, 58)`（`ground`）。所有动作共用根点，不按帧包围框重新居中。
- 原始逐帧：`frames/`；每动作一行源表：`sheets/`；对应 `.layout.json` 记录帧序与锚点。
- 动作数：7；帧图总数：27（含独立层/子体，如适用）。
- 播放建议：idle 6 fps、move 10 fps、telegraph 8 fps（3 帧，0.375 秒）、attack 12 fps、recover 8 fps、hurt 10 fps、death 8 fps；专属动作见 manifest。

RAW 是保留源，不覆盖旧版本。`PROCESSED` 仅执行像素校验、复制、规则 atlas 排布和元数据打包；实际入选来源由 processed manifest 记录。
