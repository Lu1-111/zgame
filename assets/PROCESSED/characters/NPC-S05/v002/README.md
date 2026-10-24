# NPC-S05 奶熊守卫

本轮v002精修版，保留v001供对照。右向3/4、64×64透明画布，固定世界地面root(32,58)，centered=false，offset(-32,-58)，Nearest采样。master、idle6 / walk8 / talk4，共18帧。

每个动作共用固定倍率，未按每帧包围框拉伸；walk保留前后腿交替与设计起伏，不能把抬脚高度逐帧归零。来源、裁切、锚点、倍率详见processing_manifest.json。

manifest.json保留旧系列id/name/role/direction/root/atlas/animations对象等字段；SpriteFrames动画名保持idle/walk/talk，资源路径godot/NPC-S05_sprite_frames.tres。仅walk时由游戏节点位移，图片本身原地循环。flip_h可使角色面朝左，职业道具镜像需结合交互语义审核。

idle/walk循环，talk单次。对话结束回idle首帧；现有4帧talk以中立起止帧与口型/手势衔接。未通过图片推导碰撞或交易逻辑。全部逐帧与动作条在frames/、sheets/。组合预览与验收见NPC-SERIES/v002。
