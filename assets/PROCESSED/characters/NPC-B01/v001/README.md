# NPC-01 篝火向导 / NPC-02 商人

本轮共2名角色、7个动作、42张64×64透明帧，固定地面锚点(32,58)。每个动作共用固定倍率和整数接地校准，未逐帧拉伸。

- NPC-01：idle / talk / greet，各6帧。idle为6FPS，talk和greet为8FPS。
- NPC-02：idle / talk / trade_offer / trade_confirm，各6帧，8FPS。
- 各角色包位于相邻 NPC-01/v001 与 NPC-02/v001，含独立帧、动作条、atlas、master、manifest、RAW提示词索引、Godot资源和使用说明。
- preview.html 为自包含离线预览，支持独立播放、暂停、逐帧、动作切换、底色和锚点；旁侧CHR-01用于同尺度对照。contact_sheet.png为42帧总览。

NPC-01早期greet曾出现横向比例变化，已使用独立v002重生成替换talk/greet；RAW保留所有候选。NPC-02 master由同源idle首格机械派生，来源明确记录。

## 实际检查

42帧像素几何检查通过：RGBA透明、64×64、锚点(32,58)、不触及画布边界，alpha≥128的脚底均落在y58。源格裁边时排除alpha=1/255的极低散点，仅用于透明padding几何，保留区RGBA未阈值化，RAW不变。

Godot 4.7.2 独立项目导入退出码0，无ERROR/WARNING；资源脚本加载2个NPC场景、7动作、42张AtlasTexture，尺寸和offset(-32,-58)通过。完整日志与VALIDATION.json保留实测结果。主工程未改动。

本机Chrome不可用，已在Codex内置浏览器实际操作离线预览；动作切换、各自暂停、逐帧、缩略图、底色与锚点显隐通过，控制台0错误/警告。browser_preview.png保存最终画面。

## 接续与使用边界

idle/talk循环；greet/trade_offer/trade_confirm单次，结束后由游戏状态机切回idle第0帧；talk在对话结束时返回idle。当前预览在单次动作末帧保持，方便检查收手姿态。设计口型与手势保留自然变化，未做数码补间。

上述为素材和独立资源验证，未接入主游戏的对话、交易、AI、碰撞或数值逻辑。


## 主工程回归检查

最终素材静止后，主工程 Godot 导入退出码0、无ERROR；单元测试 `passed=310 / total=310`、`RESULT: ALL PASS`；120帧无头启动退出码0、无ERROR。结果见 `PROJECT_CHECKS.json`，完整输出见本目录 `project_import.log`、`project_unit_tests.log`、`project_smoke.log`。这些检查确认现有灰盒工程仍可运行，不代表NPC对话或交易已经接入。
