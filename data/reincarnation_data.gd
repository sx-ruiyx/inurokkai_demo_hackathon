class_name ReincarnationData
extends RefCounted

## v1.11 周目轮回（犬六回：六次轮回为圆满）
## 数值单一数据源：所有周目相关数值都在这里，game_state / entity_base 只读不算。

## 最大周目数（0=初回；第 6 回为圆满，不再开放）
const MAX_CYCLES := 6

## 每周目玩家加成（乘在最终值上；cycle 0 时乘数=1.0，不影响 v1.0 数值）
const PLAYER_ATK_PER_CYCLE := 0.08
const PLAYER_HP_PER_CYCLE := 0.08

## 每周目敌人强化（乘在 EntityData 原始值上；cycle 0 时乘数=1.0）
const ENEMY_HP_PER_CYCLE := 0.12
const ENEMY_DMG_PER_CYCLE := 0.08

const CYCLE_NAMES := ["初回", "二回", "三回", "四回", "五回", "六回·圆满"]

## 周目名（超出范围回退末档）
static func cycle_name(cycle: int) -> String:
	var i: int = clampi(cycle, 0, CYCLE_NAMES.size() - 1)
	return String(CYCLE_NAMES[i])

## 敌人生命缩放系数（cycle 0 → 1.0）
static func enemy_hp_scale(cycle: int) -> float:
	if cycle <= 0: return 1.0
	return 1.0 + ENEMY_HP_PER_CYCLE * float(cycle)

## 敌人伤害缩放系数（cycle 0 → 1.0）
static func enemy_dmg_scale(cycle: int) -> float:
	if cycle <= 0: return 1.0
	return 1.0 + ENEMY_DMG_PER_CYCLE * float(cycle)

## 玩家攻击乘数（cycle 0 → 1.0）
static func player_atk_multiplier(cycle: int) -> float:
	if cycle <= 0: return 1.0
	return 1.0 + PLAYER_ATK_PER_CYCLE * float(cycle)

## 玩家最大生命乘数（cycle 0 → 1.0）
static func player_hp_multiplier(cycle: int) -> float:
	if cycle <= 0: return 1.0
	return 1.0 + PLAYER_HP_PER_CYCLE * float(cycle)

## 按周目缩放敌人数值（向上取整，至少 1）
## 注意：必须用整数百分比运算——float(100)*1.12=112.00000000000001，ceil 会错成 113
static func scale_enemy_hp(base_hp: int, cycle: int) -> int:
	if cycle <= 0: return base_hp
	var pct: int = roundi(ENEMY_HP_PER_CYCLE * 100.0) * cycle
	var scaled := float(base_hp) * float(100 + pct) / 100.0
	return maxi(1, int(ceil(scaled)))

static func scale_enemy_dmg(base_dmg: int, cycle: int) -> int:
	if cycle <= 0: return base_dmg
	var pct: int = roundi(ENEMY_DMG_PER_CYCLE * 100.0) * cycle
	var scaled := float(base_dmg) * float(100 + pct) / 100.0
	return maxi(1, int(round(scaled)))

## 按周目缩放玩家数值（四舍五入；cycle 0 原样返回）
static func scale_player_atk(base_atk: int, cycle: int) -> int:
	if cycle <= 0: return base_atk
	var pct: int = roundi(PLAYER_ATK_PER_CYCLE * 100.0) * cycle
	var scaled := float(base_atk) * float(100 + pct) / 100.0
	return maxi(1, int(round(scaled)))

static func scale_player_hp(base_hp: int, cycle: int) -> int:
	if cycle <= 0: return base_hp
	var pct: int = roundi(PLAYER_HP_PER_CYCLE * 100.0) * cycle
	var scaled := float(base_hp) * float(100 + pct) / 100.0
	return maxi(1, int(round(scaled)))

## 周目加成摘要（面板/提示用）
static func bonus_summary(cycle: int) -> String:
	if cycle <= 0:
		return "初回：无加成，无敌人强化"
	var atk_pct: int = int(round((player_atk_multiplier(cycle) - 1.0) * 100))
	var hp_pct: int = int(round((player_hp_multiplier(cycle) - 1.0) * 100))
	var ehp_pct: int = int(round((enemy_hp_scale(cycle) - 1.0) * 100))
	var edmg_pct: int = int(round((enemy_dmg_scale(cycle) - 1.0) * 100))
	return "%s：攻击 +%d%% / 生命 +%d%%；敌人生命 +%d%% / 伤害 +%d%%" % [
		cycle_name(cycle), atk_pct, hp_pct, ehp_pct, edmg_pct]
