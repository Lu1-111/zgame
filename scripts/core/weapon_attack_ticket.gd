class_name WeaponAttackTicket
extends RefCounted
## 每段普通攻击一张票据；冻结武器与动能增伤，多个目标只增加一次动能。
var weapon: Dictionary = {}
var damage_multiplier := 1.0
var attack_speed := 1.0
var bleeding_multiplier := 1.0
var landed := false
var finished := false
