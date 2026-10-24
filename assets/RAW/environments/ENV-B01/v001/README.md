# ENV-B01 v001 原始生图

2026-10-24，按《素材设计清单》ENV-01～04制作。使用 imagegen 技能与内置 image_gen，由三个子代理分工，未使用 CLI/API fallback。

- ENV-01：4张，地形、营地背景、透明构件、商人室内。
- ENV-02：3张，地形、透明构件、林地背景。
- ENV-03：2张，地形、洞窟背景与透明构件原画板。
- ENV-04：3张，地形、蜂巢背景与透明构件原画板、专用宽幅女王大厅背景。

每套目录保留 prompt 与来源校验记录；`manifest.json` 是全批原图索引。RAW 保持生图输出像素，不覆盖、不抠图；机械裁片、像素化、接缝校准及完整地图在对应 PROCESSED 批次中。具体提示词以各目录的 `prompts.json`、`*.prompt.txt` 为准。

本批研究和逐房设计见 `docs/地图设计研究-ENV-B01.md`；对应地图入口为 `assets/PROCESSED/environments/ENV-B01/v001/preview.html`。
