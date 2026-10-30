extends Resource
class_name SkillData

@export_group("Basic Info")
@export var card_name: String = "Unnamed Skill"
## 技能唯一 ID，供 PlayerSkillComponent.cast_skill() 分发。
## 留空时回退到资源文件名（如 fireball.tres → "fireball"）。
## 新增技能：填一个短 id，并在 player_skills.gd 的 cast_skill() match 里加分支。
@export var skill_id: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D # 技能卡面图标

@export_group("Battle Stats")
@export var cost_bp: int = 1
@export var cooldown: float = 1.0

@export_group("Skill Values")
# 伤害倍率（火球术填 6.5）
@export var damage_multiplier: float = 0.0
# 治疗固定值（妙手回春填 1）
@export var heal_flat: int = 0
# 治疗百分比（妙手回春填 0.1）
@export var heal_percent: float = 0.0
