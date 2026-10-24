# Godot 4 导入

将本批目录整体复制到工程 res:// 下，保留相对结构；载入 NPC-02_sprite_frames.tres 或 NPC-02_preview.tscn。SpriteFrames 的帧时长单位为 1/fps 秒。纹理 Filter 使用 Nearest、Mipmap 关闭、压缩使用 Lossless。

标准 64×64 帧将节点 root 放在地面，AnimatedSprite2D 设 centered=false，offset=Vector2(-32, -58)。本批各动作共享 64×64 画布与锚点。

所有动作面朝右；左向镜像需结合手持物语义审核。碰撞体和受击框来自游戏节点，不从图片包围框推导。动画 FPS 是建议值；无敌时间、交互事件和交易结果由状态机控制。
