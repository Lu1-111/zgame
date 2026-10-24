# ITM-B01 道具原始生图 v001

2026-10-24，按《素材设计清单》§7 和当前 `data/items.json` 制作。三个美术子代理通过内置 image_gen 分工生成：消耗品、材料/特殊物品、碎片/能力奖励；未使用 CLI/API fallback。

- `consumables/`：小型奶瓶、奶力药剂、体力药剂、奶弹。
- `materials_special/`：奶菇、蜜蜡、奶晶、背包扩容卷、地图碎片。
- `fragments_ability/`：生命/体力/奶力碎片，以及独立的奶泡跃奖励。

共 12 项物品 + 1 项能力奖励、13 张原始 sheet、52 个候选帧。每项有原图、完整 `.prompt.txt` 和实测 `.layout.json`；各分组有生成来源、SHA256 与诊断。总索引为 `manifest.json`。

所有原图为内置工具实际输出的 **1254×1254 RGBA**、2×2 格、单格627×627；提示词请求的1024×1024没有被生成器严格采用。原始字节和 Alpha 均保留。图中存在低透明度散点；多数道具在不同格内的排版位置不同。layout 的 nominal root 只是生成建议，成品使用实测语义锚点，不能直接等格播放 RAW。

PROCESSED 对应 `assets/PROCESSED/items/ITM-B01/v001/`。该目录记录实际源矩形、配准平移、整组统一缩放、目标锚点和成品哈希。RAW 存在不代表通过游戏内验收。
