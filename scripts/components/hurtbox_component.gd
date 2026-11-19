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
	var effective := packet
	var ticket := packet.weapon_ticket
	if ticket!=null:
		effective=packet.copy_for_target()
		var multiplier := ticket.damage_multiplier
		var bonus := WeaponAttributes.effect(ticket.weapon,"broken_bonus")
		if not bonus.is_empty() and WeaponAttributes.target_is_broken(owner_actor):multiplier*=1.0+float(bonus.ratio)
		effective.amount=roundi(float(packet.amount)*multiplier)
	var before: Variant=owner_actor.get("hp") if is_instance_valid(owner_actor) else null
	var can_notify := is_instance_valid(packet.origin_actor) and packet.origin_actor.has_method("target_poise_broken")
	var was_broken := WeaponAttributes.target_is_broken(owner_actor) if can_notify else false
	var result: int=int(hit_callback.call(effective)) if hit_callback.is_valid() else effective.amount
	if can_notify and not was_broken and WeaponAttributes.target_is_broken(owner_actor):
		packet.origin_actor.target_poise_broken()
	var actual := result
	if before is int and is_instance_valid(owner_actor):actual=clampi(int(before)-int(owner_actor.get("hp")),0,result)
	if ticket != null and actual > 0 and is_instance_valid(owner_actor) and owner_actor.has_method("apply_status"):
		for effect: Dictionary in ticket.weapon.get("special_effects", []):
			if str(effect.kind) == "status" and bool(effect.get("implemented", false)):
				var amplifier := ticket.bleeding_multiplier if str(effect.id) == "bleeding" else 1.0
				owner_actor.apply_status(str(effect.id), float(effect.duration), amplifier)
	if ticket!=null and actual>0 and is_instance_valid(packet.origin_actor) and packet.origin_actor.has_method("weapon_attack_landed"):
		packet.origin_actor.weapon_attack_landed(ticket,actual)
	return result
