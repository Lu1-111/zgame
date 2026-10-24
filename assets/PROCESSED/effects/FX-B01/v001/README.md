# FX-B01 特效组件 v001

本包包含一批透明单帧 PNG、逐动作横排 sheet、整批 atlas、Godot 4 SpriteFrames 和可复用播放组件。已完成逐帧、语义锚点与运行时检查；验收记录见 `VALIDATION.json`，原始诊断见 `qa.json`。

## 预览与文件

直接打开 `preview.html`，无需网络。总览持续回放每一组，方便看消散连续性；单组检视支持重播、暂停、前后步进、倍速、底色、root 十字线、镜像和逐帧条。640×360 同屏视图以实际像素比例显示，可加载本地参考角色 PNG、设置角色锚点和特效偏移。预览辅助线不在 PNG 内。

- `frames/<id>/`：固定画布、透明 RGBA，未做逐帧归一化。
- `sheets/`：每组所有帧从左至右排列。
- `FX-B01_v001_atlas.png`：整批规则 atlas，无 trim/rotate。
- `manifest.json`：动作 FPS、loop、attachPoint、每帧源矩形/锚点/尺度/平移/时长/校验和。
- `analysis.json` / `qa.json`：源格真 alpha、空帧、边界、面积、质心与相邻帧变化诊断。
- `godot/EffectPlayer.tscn`：可重复触发的一次性视觉组件。

## Godot 4 使用

将整个目录保留原结构放到 `res://` 下，实例化 `godot/EffectPlayer.tscn`。在节点进入场景树并完成 ready 后调用：

```gdscript
# action_name 使用 manifest.effects[].name 中的实际值。
effect.position = hit_position_in_parent
effect.play_effect(action_name, facing_left, 1.0)

# 或附着到已有 Marker2D：
effect.play_attached($FootMarker, action_name, facing_left, 1.0)
```

每次触发会归零帧进度；一次性动画播完自动隐藏，并发出 `effect_completed(effect_name)`。节点保留，可复用。`stop_effect()` 可打断并隐藏。循环动作需要调用方主动停止。`hide_on_finish` 可关闭自动隐藏；检查未淡出的末帧时还需将 `fadeStartNormalized` 设为 1。

一次性特效默认从归一化生命周期 70% 起平滑淡出，在最后两帧附近消散到透明。PNG 仍保留全部原像素，逐帧缩略条不叠加淡出；大图、总览与同屏播放器同步模拟组件淡出。运行时按 SpriteFrames 的实际每帧 duration 与 AnimatedSprite2D.frame_progress 计算进度，暂停会冻结淡出，变速及重播均同步，未使用独立 Tween。重播和 stop 会把 VisualRoot 的生命周期 alpha 恢复为 1。manifest/catalog 的 `fadeStartNormalized` 可配置，设为 1 禁用；循环动作默认禁用尾段淡出。

残影等效果还可设置 `opacityByFrame` 作为 Sprite 透明度包络，帧内平滑过渡，叠加 VisualRoot 的尾段淡出。默认各帧为 1；重播会恢复首帧配置值，stop 将两个节点都重置为 1。该包络只影响运行时和播放预览，原帧缩略图与 PNG 不变。

AnimatedSprite2D 采用 `centered=false`、`offset=-manifest anchor`。镜像通过 VisualRoot 的横向负比例围绕 root 完成，禁止额外启用 Sprite 的 `flip_h`。若父节点本身已镜像，调用方需避免重复镜像；附着节点会跟随父节点变换。此组件不移动角色或敌人。

纹理使用 Nearest、Lossless、mipmap 关闭、alpha border 修补关闭。相邻 `.png.import` 提供首次导入参数，Godot 会补齐自己的导入缓存。首次导入后可检查纹理导入面板；组件显式设置 Nearest。

默认锚点与挂点同步生成在 `godot/EffectCatalog.gd`，由组件 preload 引用，Godot 导出会跟随脚本依赖打包，运行时不依赖 JSON。`manifest.json` 保留完整追溯与工具配置。若主动设置组件的 `manifest_path` 用 JSON 覆写，必须在 Godot 导出预设的非资源文件包含规则中加入对应 `*.json`，否则导出包可能缺失该文件。

## 锚点与时间

本批播放预览采用正式 `CHR-01_canonical_right_v001.png`，角色 root 为 `(32,58)`，manifest 记录站立可见高度 40px。残影以整组 `40/350 = 0.11428571428571428` 的 Nearest 尺度与该规格对齐；逐帧源锚点、96×80 画布和 `(48,64)` 输出 root 保持不变。RAW 中约 44px 的描述保留为原始设计记录，成品实际尺度以本批 manifest 为准。

中心型冲击通常是 `(32,32)`，脚底/落地点型通常是 `(32,48)`；最终以每动作 manifest 为准。源每格按统一尺度缩放、整数平移，人工源锚点覆写仍保留在追溯信息中。面积和质心变化不等同于锚点漂移；扩张与消散会自然改变它们。

当前默认 12 FPS、6 帧，即 0.5 秒。单帧 `duration` 单位为 `1/fps` 秒，支持不等时长；运行时还可用 `speed_multiplier` 和 `playback_rate` 调整展示速度。重生成资源需编辑处理配置或 batch 的 `fps`、`frameDurations`，再构建。

建议由已有游戏事件触发：物理命中在确认命中时放到 contact marker；落地尘在落地事件放到 foot marker；起跳/二段跳/闪避在对应状态进入时触发；锤挥击残影附着武器或手部 marker，锤地冲击附着地面接触点。实际 attachPoint 名称保留在 manifest 中，需映射到游戏已有节点。

视觉播放时长不能替代伤害判定、连击窗口、受击无敌或角色动画状态。该包未接入主游戏场景，未修改游戏平衡数值。

## 本版验收与来源

12 组、72 帧。11 组为 64×64；闪避残影为 96×80、root (48,64)，为保留左拖尾与全部原始 alpha 而增加透明画布。残影使用整组统一尺度校准至现有 CHR-01 canonical 的约 40px 站立高度；预览内嵌正式角色参考，root 为 (32,58)。

RAW 与完整提示词位于 `assets/RAW/effects/FX-B01/v001/` 的 impact、motion、hammer 目录，均由内置 image_gen 生成；每个效果独立调用，保留旧版候选。`manifest.json` 保存每帧 RAW 相对路径、sha256、源矩形、源锚点、固定缩放与整数位移。

已通过 Godot 4.7.2 独立组件工程导入及全部 12 组播放检查。检查范围含重播归零、自动隐藏、附着挂点、围绕 root 镜像、暂停、不同播放速度与帧时长、尾段淡出及残影透明度包络。主游戏动作事件和武器挂点尚需按实际场景接入。

原始低 alpha 边缘散点完整保留；成品没有非零 alpha 触及画布边界。落地尘破碎过程中约 1px 的基线变化已检查为可接受。
