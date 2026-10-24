extends RefCounted
## 由本批 manifest 生成的展示参数；贴图预载保证导出依赖完整。
const FRAMES: SpriteFrames = preload("ItemSpriteFrames.tres")
const DEFAULTS: Dictionary = {
  "anchor": [
    16,
    24
  ],
  "worldCanvas": [
    32,
    32
  ],
  "iconCanvas": [
    24,
    24
  ],
  "fps": 4,
  "bobAmplitude": 1.0,
  "bobPeriod": 2.0,
  "baseLift": 2.0,
  "pickupDuration": 0.35,
  "pickupRise": 8.0,
  "pickupEasePower": 3.0
}
const ITEMS: Dictionary = {
    &"potion_small": {"anchor": Vector2(16, 24), "icon": preload("res://assets/PROCESSED/items/ITM-B01/v001/icons/ITEM_potion_small_icon_v001.png")},
    &"potion_mana": {"anchor": Vector2(16, 24), "icon": preload("res://assets/PROCESSED/items/ITM-B01/v001/icons/ITEM_potion_mana_icon_v001.png")},
    &"potion_sta": {"anchor": Vector2(16, 24), "icon": preload("res://assets/PROCESSED/items/ITM-B01/v001/icons/ITEM_potion_sta_icon_v001.png")},
    &"milk_bomb": {"anchor": Vector2(16, 24), "icon": preload("res://assets/PROCESSED/items/ITM-B01/v001/icons/ITEM_milk_bomb_icon_v001.png")},
    &"mushroom": {"anchor": Vector2(16, 24), "icon": preload("res://assets/PROCESSED/items/ITM-B01/v001/icons/ITEM_mushroom_icon_v001.png")},
    &"honey_wax": {"anchor": Vector2(16, 24), "icon": preload("res://assets/PROCESSED/items/ITM-B01/v001/icons/ITEM_honey_wax_icon_v001.png")},
    &"milk_crystal": {"anchor": Vector2(16, 24), "icon": preload("res://assets/PROCESSED/items/ITM-B01/v001/icons/ITEM_milk_crystal_icon_v001.png")},
    &"hp_fragment": {"anchor": Vector2(16, 24), "icon": preload("res://assets/PROCESSED/items/ITM-B01/v001/icons/ITEM_hp_fragment_icon_v001.png")},
    &"sta_fragment": {"anchor": Vector2(16, 24), "icon": preload("res://assets/PROCESSED/items/ITM-B01/v001/icons/ITEM_sta_fragment_icon_v001.png")},
    &"mana_fragment": {"anchor": Vector2(16, 24), "icon": preload("res://assets/PROCESSED/items/ITM-B01/v001/icons/ITEM_mana_fragment_icon_v001.png")},
    &"bag_expand": {"anchor": Vector2(16, 24), "icon": preload("res://assets/PROCESSED/items/ITM-B01/v001/icons/ITEM_bag_expand_icon_v001.png")},
    &"map_fragment": {"anchor": Vector2(16, 24), "icon": preload("res://assets/PROCESSED/items/ITM-B01/v001/icons/ITEM_map_fragment_icon_v001.png")},
    &"ability_double_jump": {"anchor": Vector2(16, 24), "icon": preload("res://assets/PROCESSED/items/ITM-B01/v001/icons/ITEM_ability_double_jump_icon_v001.png")},
}
