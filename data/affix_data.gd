class_name AffixData
extends RefCounted

## 装备词缀池（v1.10 P3）：词缀加成在装备生成时直接写进 EquipmentData 的 bonus 字段，
## 属性聚合链路（get_total_attack 等）零改动即可生效。
## apply 字段：attack/hp/shield 为整数加成；crit_rate/crit_dmg 为小数加成。

const AFFIXES := {
	"atk_small":   {"name": "锋锐",     "desc": "攻击 +3",        "rarity": "common", "apply": {"attack": 3}},
	"atk_big":     {"name": "锐不可当", "desc": "攻击 +6",        "rarity": "rare",   "apply": {"attack": 6}},
	"hp_small":    {"name": "坚韧",     "desc": "生命 +8",        "rarity": "common", "apply": {"hp": 8}},
	"hp_big":      {"name": "厚甲",     "desc": "生命 +16",       "rarity": "rare",   "apply": {"hp": 16}},
	"shield_small":{"name": "守护",     "desc": "护盾 +2",        "rarity": "common", "apply": {"shield": 2}},
	"shield_big":  {"name": "铁壁",     "desc": "护盾 +4",        "rarity": "rare",   "apply": {"shield": 4}},
	"crit_rate":   {"name": "精准",     "desc": "暴击率 +8%",     "rarity": "common", "apply": {"crit_rate": 0.08}},
	"crit_dmg":    {"name": "狂怒",     "desc": "暴击伤害 +20%",  "rarity": "rare",   "apply": {"crit_dmg": 0.2}},
}

## 品阶表：roll 概率 55/30/12/3；史诗/传说保底至少 1 条稀有词缀
const TIERS := [
	{"name": "普通", "count": 0},
	{"name": "精良", "count": 1},
	{"name": "史诗", "count": 2},
	{"name": "传说", "count": 3},
]

static func tier_name(tier: int) -> String:
	if tier < 0 or tier >= TIERS.size(): return "普通"
	return String(TIERS[tier]["name"])

static func tier_color(tier: int) -> Color:
	match tier:
		0: return Color(0.62, 0.62, 0.65)
		1: return Color(0.35, 0.75, 0.45)
		2: return Color(0.55, 0.55, 0.95)
		3: return Color(0.95, 0.72, 0.30)
	return Color(0.62, 0.62, 0.65)

## 把词缀加成写进装备（幂等由调用方保证：每件装备只应用一次）
static func apply_to(item: EquipmentData, affix_id: String) -> void:
	if item == null: return
	var a: Dictionary = AFFIXES.get(affix_id, {})
	if a.is_empty(): return
	var ap: Dictionary = a["apply"]
	if ap.has("attack"): item.attack_bonus += int(ap["attack"])
	if ap.has("hp"): item.hp_bonus += int(ap["hp"])
	if ap.has("shield"): item.shield_bonus += int(ap["shield"])
	if ap.has("crit_rate"): item.crit_rate_bonus += float(ap["crit_rate"])
	if ap.has("crit_dmg"): item.crit_damage_bonus += float(ap["crit_dmg"])

## 按品阶随机词缀（史诗/传说保底 1 rare；同件不重复）
static func roll_affixes(tier: int) -> Array[String]:
	var out: Array[String] = []
	if tier <= 0 or tier >= TIERS.size(): return out
	var count := int(TIERS[tier]["count"])
	var pool: Array = AFFIXES.keys()
	pool.shuffle()
	var rare_first: Array = []
	for id in pool:
		if String(AFFIXES[id]["rarity"]) == "rare":
			rare_first.append(id)
	for id in pool:
		if String(AFFIXES[id]["rarity"]) != "rare":
			rare_first.append(id)
	for id in rare_first:
		if out.size() >= count: break
		if not (String(id) in out):
			out.append(String(id))
	return out

static func roll_tier() -> int:
	var r := randf()
	if r < 0.55: return 0
	if r < 0.85: return 1
	if r < 0.97: return 2
	return 3

static func affix_label(affix_id: String) -> String:
	var a: Dictionary = AFFIXES.get(affix_id, {})
	if a.is_empty(): return ""
	return "%s（%s）" % [String(a["name"]), String(a["desc"])]
