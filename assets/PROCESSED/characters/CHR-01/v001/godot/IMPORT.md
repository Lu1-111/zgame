# Godot 4 导入

将本批目录整体复制到工程 res:// 下，保留相对结构；载入 CHR-01_sprite_frames.tres 或 CHR-01_preview.tscn。SpriteFrames 的帧时长单位为 1/fps 秒。纹理 Filter 使用 Nearest、Mipmap 关闭、压缩使用 Lossless。

标准 64×64 帧将节点 root 放在地面，AnimatedSprite2D 设 centered=false，offset=Vector2(-32, -58)。若采用 96×96 的动作，请按 manifest 中该动作的 anchor 同步 offset；图像尺度不变。

所有动作面朝右。未制作左向武器动作，不能自动认定武器镜像正确。碰撞体和受击框来自游戏节点，不从图片包围框推导。动画 FPS 是建议值；无敌时间、攻击判定和死亡 1.5 秒流程由状态机控制。
