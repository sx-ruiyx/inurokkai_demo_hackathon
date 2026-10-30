extends Resource
class_name CharacterData

@export var char_name: String = "白柯"
@export var race: String = "兽人" 
@export var theme_color: Color = Color(0.88, 0.28, 0.22)
@export var default_level: int = 1

@export_group("Scene Settings")
## 直接把这个角色对应的 .tscn 拖进来（不同体型/动画的角色建不同的 tscn）
@export var character_scene: PackedScene 

@export_group("默认装备")
@export var default_weapon: EquipmentData
@export var default_helmet: EquipmentData
@export var default_armor: EquipmentData
@export var default_pants: EquipmentData
@export var default_accessory: EquipmentData
