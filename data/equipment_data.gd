extends Resource
class_name EquipmentData

# 类型枚举
enum Type { WEAPON, HELMET, ARMOR, PANTS, ACCESSORY }

@export_group("Basic Info")
@export var equip_type: Type = Type.WEAPON
@export var item_name: String = "Unnamed Equipment"
@export_multiline var description: String = ""

@export_group("Stats Bonus")
@export var attack_bonus: int = 0
@export var hp_bonus: int = 0
@export var shield_bonus: int = 0
@export var crit_rate_bonus: float = 0.0      # 装备提供的暴击率加成（比如填 0.15 代表 +15%）
@export var crit_damage_bonus: float = 0.0    # 装备提供的暴击伤害加成

@export_group("Set Properties")
@export var set_id: String = ""

@export_group("Affixes (v1.10)")
@export var affixes: Array[String] = []   # 词缀 id 列表（见 data/affix_data.gd）
@export var tier: int = 0                 # 品阶 0 普通 / 1 精良 / 2 史诗 / 3 传说
