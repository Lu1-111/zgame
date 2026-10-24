class_name HurtboxComponent
extends Area2D
## 受击框（层6 hurtbox）：被 HitboxComponent/投射物调用 receive_hit。
## 减伤策略（无敌/格挡/破防）由宿主通过 hit_callback 注入；未注入时直通原始伤害
## （供假人靶等无逻辑目标使用）。
## 归属：owner_actor 指向宿主实体（玩家/敌人）。层6 为双方共用层，
## 攻击方必须靠它排除"命中自己"（玩家与敌人的 Hitbox 扫描的都是层6）。

var owner_actor: Node = null
var hit_callback: Callable = Callable()


## 被命中入口：返回最终生效伤害（供命中方做顿帧/飘字）。
func receive_hit(packet: DamagePacket) -> int:
	if packet == null:
		return 0
	if hit_callback.is_valid():
		return int(hit_callback.call(packet))
	return packet.amount
