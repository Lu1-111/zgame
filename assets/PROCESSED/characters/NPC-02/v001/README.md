# NPC-02 营地商人 · 奶牛

本目录是独立素材包，尚未接入游戏。RAW 原始造型与动作图位于 assets/RAW/characters/NPC-02/v001/；sourceMaster、逐帧来源、固定尺度与整数平移详见 manifest.json。完整提示词保存在对应 RAW 目录，本目录 RAW_PROMPT_INDEX.md 列出原始记录。

## 规格与播放

- 4 个动作、24 张 64×64 RGBA 独立帧；面向右。固定地面 root (32,58)。
- 每个动作共用固定倍率；不同原始行先按中位站高校准到含角约42像素，再做整数平移。未逐帧拉伸。裁边几何使用 alpha>1，裁掉范围外的 alpha=1/255 散点；保留区的 RGBA 未作阈值化，RAW 不变。
- Nearest 采样；脚底按 alpha≥128 接地点校准，保留呼吸与手势变化。透明画布不代表碰撞框。
- idle 与 talk 循环；trade_offer / trade_confirm 播放一次，在 animation_finished 后返回 idle 第0帧。talk 在对话结束后回 idle。
- 各动作首尾收手姿态用于接续；尚需在真实对话/交易状态机里验证事件时机。

## 文件

frames/ 为独立帧，sheets/ 为每动作六帧横条；NPC-02_atlas_right_v001.png 是规则总图集；NPC-02_master_right_v001.png 是独立造型。preview.html 可离线播放。godot/ 提供 SpriteFrames、预览场景与偏移同步脚本。资源以相对路径引用，复制时保留整包结构。

Godot 使用 centered=false / offset=(-32,-58)，节点原点放在地面。PNG 保留透明通道，Nearest、无 mipmap。未制作左向独立动作；镜像后需检查手持物位置。

## 验证范围

VALIDATION.json 是像素级尺寸、透明、边界与地面锚点检查；qa.json 是帧间变化与循环缝的量化诊断。视觉动画审核与 Godot 独立载入记录见组合包 NPC-B01/v001。上述检查不等于主游戏对话、交易或碰撞已接入。

商人 master 由同一动作表的 idle 首格机械截取派生，详见 manifest.sourceMaster.derivedFrom；不是独立生图。
