extends Resource
class_name EntityData

@export_group("Basic Info")
@export var entity_name: String = "Unnamed Entity"
@export var max_hp: int = 50
@export var defense: int = 0

@export_group("Combat Stats")
@export var contact_damage: int = 2

@export_group("Physics")
## 击退倍率：普通怪1.0，Boss设0.2（基本打不退），羽毛怪设2.0（飞很远）
@export var knockback_multiplier: float = 1.0

@export_group("Drops")
## 击杀经验奖励
@export var exp_reward: int = 20
## 金币掉落范围（含两端；夜晚 +50%）
@export var drop_gold_min: int = 1
@export var drop_gold_max: int = 3
## 材料掉落池（每次必掉 1 种，伪随机 + 保底）
@export var drop_materials: Array[String] = [] 
