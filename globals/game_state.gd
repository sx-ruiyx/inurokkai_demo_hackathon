extends Node

# ================= 数据配置区 =================
@export_group("Stat Database")
@export var stat_database: LevelStatData

@export_group("Character Settings")
var current_character_id: String = "bkxy" 
var player_character_data: CharacterData = null

# ================= 场景/关卡流转 =================
var use_custom_spawn_pos: bool = false
var next_spawn_position: Vector2 = Vector2.ZERO
var next_spawn_id: String = ""

var played_intro_scripts: Array[String] = []
## v1.9 图鉴：已解锁的敌人条目（键 = EntityData.entity_name）
var codex_unlocked: Array[String] = []
## v1.10 成就：已解锁成就 id 列表 + 累计击杀数
var achievements_unlocked: Array[String] = []
var kill_count: int = 0

# ================= 运行时状态 =================
var current_level: int = 1
var hp: int = 0
var bp: int = 0
var current_shield: int = 0

var equipped_items: Dictionary = {
	EquipmentData.Type.WEAPON: null,
	EquipmentData.Type.HELMET: null,
	EquipmentData.Type.ARMOR: null,
	EquipmentData.Type.PANTS: null,
	EquipmentData.Type.ACCESSORY: null
}

var base_crit_rate: float = 0.05
var base_crit_damage: float = 1.0

# ================= 全局常量 =================
const MAX_STAT_CAP := 29997          # 各项数值上限（金币/材料/HP/技能点等）
const COMBO_WINDOW := 1.5            # 连击窗口（秒）
const DYING_REGEN_DELAY := 10.0      # 濒死脱战回血等待（秒）
const DAY_LENGTH := 240.0            # 一昼夜时长（秒）

# ================= 经济系统 =================
var gold: int = 0
var materials: Dictionary = {}       # {材料名: 数量}

# ================= 跨关卡卡牌持久化（v1.14） =================
# 存 base_id（文件名）而非索引，与每关重扫顺序无关；换关不重置，新开局由 load_character 清空
var persisted_skill_slots: Array = ["", "", "", ""]   # 快捷技能槽 ×4
var persisted_weapon_slots: Array = ["", "", "", ""]  # 武器快捷栏 ×4
var persisted_equip_slots: Array = ["", "", ""]       # 装备槽 ×3
var persisted_card_levels: Dictionary = {}            # 卡牌等级（base_id -> Lv），跨关卡保留

const MAX_CARD_LEVEL := 9             # 卡牌等级上限（Lv.1/9）
const CARD_LEVEL_DAMAGE_STEP := 0.2   # 每级伤害倍率步进（Lv1 ×1.0 → Lv9 ×2.6）
const UPGRADE_COST_BP_LOW := 1        # Lv1~3 每次升级消耗 BP
const UPGRADE_COST_BP_HIGH := 2       # Lv4~9 每次升级消耗 BP

## v1.15 卡牌升级：等级按 base_id 持久化，跨关卡保留；新开局由 load_character 清空
## 升级消耗 BP：Lv1~3 每次 1 点 / Lv4~9 每次 2 点；每级伤害倍率 +0.2
func get_card_level(base_id: String) -> int:
	return int(persisted_card_levels.get(base_id, 1))

func get_card_max_level() -> int:
	return MAX_CARD_LEVEL

func is_card_max_level(base_id: String) -> bool:
	return get_card_level(base_id) >= MAX_CARD_LEVEL

func get_card_level_multiplier(card_id: String) -> float:
	return 1.0 + float(get_card_level(card_id) - 1) * CARD_LEVEL_DAMAGE_STEP

func get_upgrade_cost_for_card(card_id: String) -> int:
	if get_card_level(card_id) >= 4:
		return UPGRADE_COST_BP_HIGH
	return UPGRADE_COST_BP_LOW

## 升级到底要花什么（UI 直接显示这行字）
func get_upgrade_cost_text(card_id: String = "") -> String:
	var cost := get_upgrade_cost_for_card(card_id)
	return "升级消耗 %d 点 BP（当前 %d/%d）" % [cost, bp, get_max_bp()]

## 不能升级的原因；返回空字符串表示可以升（UI 用它决定按钮灰不灰）
func upgrade_block_reason(card_id: String) -> String:
	if card_id == "": return "选中一张卡牌后才能升级"
	if is_card_max_level(card_id): return "已达最高等级 Lv.%d" % MAX_CARD_LEVEL
	var cost := get_upgrade_cost_for_card(card_id)
	if bp < cost: return "BP 不足（本次需 %d 点，当前 %d）" % [cost, bp]
	return ""

func can_upgrade_card(card_id: String) -> bool:
	return upgrade_block_reason(card_id) == ""

## 升级：扣 BP 费用（Lv1~3 扣 1 / Lv4~9 扣 2）+ 等级 +1，成功返回 true
func upgrade_card(card_id: String) -> bool:
	var reason := upgrade_block_reason(card_id)
	if reason != "":
		print("⚠️ [升级] %s" % reason)
		return false
	var old_lv := get_card_level(card_id)
	var cost := get_upgrade_cost_for_card(card_id)   # 按升级前的等级算费用
	persisted_card_levels[card_id] = old_lv + 1
	bp = maxi(0, bp - cost)                          # 走当前 BP，消耗后照常走 BP 回复
	print("⭐ [升级] 「%s」Lv.%d → Lv.%d，伤害倍率 ×%.1f" % [
		card_id, old_lv, old_lv + 1, get_card_level_multiplier(card_id)])
	return true

# ================= 等级与经验 =================
var exp: int = 0
var skill_points: int = 0            # 技能点（升级获得，用于技能分支）
const MAX_LEVEL := 5
const EXP_TABLE := {1: 100, 2: 260, 3: 520, 4: 950}   # 升到下一级所需经验

# ================= 连击系统 =================
var combo_count: int = 0
var combo_timer: float = 0.0
var combo_box: Control
var combo_label: Label
var combo_tween: Tween

# ================= 受击反馈 =================
var hurt_vignette: ColorRect
var hurt_vignette_tween: Tween

# ================= 濒死状态 =================
var is_dying: bool = false
var out_of_combat_timer: float = 0.0

# ================= 家具基地加成 =================
var furniture_levels := {"bed": 0, "shield_rack": 0, "forge": 0, "card_case": 0, "hourglass": 0}
var furniture_bonus := {"hp": 0, "shield": 0, "atk": 0, "bp": 0, "sp": 0}

# ================= 菜地系统 =================
var farm_plots: Array = []           # [{state:0空/1生长/2成熟, remain:剩余秒, seed:作物名}]
var farm_fertility: Array = []       # 每块地肥力 0~3（施肥提升）

# ================= 药水 Buff =================
var active_buffs: Array = []         # [{type:"atk"/"def", remain:秒}]

# ================= 昼夜系统 =================
var day_time: float = 0.0
var day_night_modulate: CanvasModulate = null

# ================= 装备强化 =================
var gear_upgrades: Dictionary = {}   # {装备资源路径: 强化等级}

# ================= 设置 =================
var settings := {"bgm": 80, "se": 80, "vn_speed": 1.0, "fullscreen": false, "resolution": 0}

# ================= 宝箱与保底 =================
var opened_chests: Array[String] = []
var pity_counter: Dictionary = {}    # 保底计数 {掉落表id: 已roll次数}
# v1.12 教学引导去重 {guide_id: bool}（backpack=背包指南，combat=战斗操作）
var tutorial_seen: Dictionary = {}
# v1.12 采集点冷却 {node_id: 恢复时间戳(unix秒)}——防止重进场景秒刷资源
var harvested_nodes: Dictionary = {}

## 采集点是否仍在冷却（now < 恢复时间戳）
func is_harvest_node_depleted(node_id: String) -> bool:
	if not harvested_nodes.has(node_id): return false
	return float(harvested_nodes[node_id]) > Time.get_unix_time_from_system()

## 记录采集点冷却
func mark_harvest_node(node_id: String, respawn_at: float) -> void:
	harvested_nodes[node_id] = respawn_at

## 冷却到期后清除记录
func clear_harvest_node_if_ready(node_id: String) -> void:
	if harvested_nodes.has(node_id) and not is_harvest_node_depleted(node_id):
		harvested_nodes.erase(node_id)

# ================= 战斗状态管理 =================
var active_combat_entities: int = 0
var combat_ui_layer: CanvasLayer
var ui_root: Control
var combat_box: Control 
var combat_label: Label
var combat_bg: TextureRect
var combat_ui_tween: Tween

var combat_warn_box: Control
var combat_warn_label: Label
var combat_warn_tween: Tween

# ================= BP 自动回复 =================
var bp_regen_interval: float = 4.0
var bp_regen_timer: float = 0.0
var bp_regen_progress: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # v1.16 暂停（背包/暂停菜单）时 BP 照常回复，与战斗界面同一时钟
	load_character(current_character_id)
	_setup_ui()
	_setup_extra_ui()
	_init_farm()
	apply_audio_settings()   # v1.9 确保 BGM/SFX 总线存在并应用音量

func _init_farm() -> void:
	farm_plots.clear()
	farm_fertility.clear()
	for i in 4:
		farm_plots.append({"state": 0, "remain": 0.0, "seed": ""})
		farm_fertility.append(0)

func load_character(char_id: String) -> void:
	var tres_path = "res://data/characters/shared/%s.tres" % char_id
	if ResourceLoader.exists(tres_path):
		player_character_data = load(tres_path)
		current_character_id = char_id
		
		current_level = player_character_data.default_level
		equipped_items[EquipmentData.Type.WEAPON] = player_character_data.default_weapon
		equipped_items[EquipmentData.Type.HELMET] = player_character_data.default_helmet
		equipped_items[EquipmentData.Type.ARMOR] = player_character_data.default_armor
		equipped_items[EquipmentData.Type.PANTS] = player_character_data.default_pants
		equipped_items[EquipmentData.Type.ACCESSORY] = player_character_data.default_accessory
		
		reset_runtime_stats()
		# v1.14 新角色/新开局清空跨关卡卡牌持久化
		persisted_skill_slots = ["", "", "", ""]
		persisted_weapon_slots = ["", "", "", ""]
		persisted_equip_slots = ["", "", ""]
		persisted_card_levels = {}   # v1.15 卡牌等级一并清空
		unlocked_branches.clear()    # v1.16 技能分支解锁状态一并清空
		skill_branches.clear()       # v1.16 当前使用分支回到基础
		print("✅ [系统] 成功加载角色数据: ", player_character_data.char_name)
	else:
		push_error("⚠️ [系统] 找不到角色数据文件: %s" % tres_path)

func _get_current_level_stats() -> Dictionary:
	if not player_character_data or not stat_database:
		return {}
	var target_race = player_character_data.race
	for stat in stat_database.all_stats:
		if stat.get("race") == target_race and int(stat.get("level", 1)) == current_level:
			return stat
	push_warning("⚠️ [系统] 找不到种族 '%s' 等级 %d 的成长数据！" % [target_race, current_level])
	for stat in stat_database.all_stats:
		if stat.get("race") == target_race:
			return stat
	return {}

func get_base_max_hp() -> int:
	var stat = _get_current_level_stats()
	return int(stat.get("hp", 20))

func get_base_attack() -> int:
	var stat = _get_current_level_stats()
	return int(stat.get("atk", 2))

func get_base_shield() -> int:
	var stat = _get_current_level_stats()
	return int(stat.get("shield", 4))

func get_base_max_bp() -> int:
	var stat = _get_current_level_stats()
	return int(stat.get("bp", 3))

func get_theme_color() -> Color:
	return player_character_data.theme_color if player_character_data else Color(0.88, 0.28, 0.22)

func get_total_attack() -> int:
	var total = get_base_attack()
	for item in equipped_items.values():
		if item != null: total += item.attack_bonus
	total += int(furniture_bonus.get("atk", 0))
	total += _get_gear_upgrade_total("attack")
	total += _get_buff_bonus("atk")
	# v1.11 周目加成（cycle 0 时原值不变）
	total = ReincarnationData.scale_player_atk(total, reincarnation_count)
	return total

func get_max_hp() -> int:
	var total = get_base_max_hp()
	var leather_count = 0
	for item in equipped_items.values():
		if item != null:
			total += item.hp_bonus
			if item.set_id == "leather": leather_count += 1
	if leather_count >= 3: total += 5
	total += int(furniture_bonus.get("hp", 0))
	total += _get_buff_bonus("hp")
	# v1.11 周目加成（cycle 0 时原值不变）
	total = ReincarnationData.scale_player_hp(total, reincarnation_count)
	return mini(total, MAX_STAT_CAP)

func get_max_shield() -> int:
	var total = get_base_shield()
	for item in equipped_items.values():
		if item != null: total += item.shield_bonus
	total += int(furniture_bonus.get("shield", 0))
	total += _get_buff_bonus("shield")
	return mini(total, MAX_STAT_CAP)

## v1.18 立即获得护盾值（clamp 到当前上限；铁壁润泽施放时护盾值 +2）
func gain_shield(amount: int) -> void:
	current_shield = clampi(current_shield + amount, 0, get_max_shield())

func get_max_bp() -> int:
	return mini(get_base_max_bp() + int(furniture_bonus.get("bp", 0)), MAX_STAT_CAP)

func get_total_crit_rate() -> float:
	var total = base_crit_rate
	for item in equipped_items.values():
		if item != null: total += item.crit_rate_bonus
	return total

func get_total_crit_damage() -> float:
	var total = base_crit_damage
	for item in equipped_items.values():
		if item != null: total += item.crit_damage_bonus
	return total

func reset_runtime_stats() -> void:
	hp = get_max_hp()
	bp = get_max_bp()
	current_shield = get_max_shield()
	bp_regen_timer = 0.0
	bp_regen_progress = 0.0
	skill_points = mini(int(furniture_bonus.get("sp", 0)), MAX_STAT_CAP)
	combo_count = 0
	combo_timer = 0.0
	is_dying = false
	out_of_combat_timer = 0.0
	set_meta("player_spawned", false)
	played_intro_scripts.clear()
	codex_unlocked.clear()
	achievements_unlocked.clear()
	kill_count = 0
	gear_affixes.clear()
	harvested_nodes.clear()   # v1.12：新档重置采集点冷却
	tutorial_seen.clear()   # v1.12：新档重置教学去重

func _process(delta: float) -> void:
	if bp < get_max_bp():
		bp_regen_timer += delta
		bp_regen_progress = bp_regen_timer / bp_regen_interval
		if bp_regen_timer >= bp_regen_interval:
			bp_regen_timer -= bp_regen_interval
			bp = clampi(bp + 1, 0, get_max_bp())
			print("⚡ [系统] BP充能完毕: 当前BP ", bp, "/", get_max_bp())
	else:
		bp_regen_timer = 0.0
		bp_regen_progress = 0.0

	# v1.16 暂停（背包/暂停菜单）时只推进 BP 回复（与战斗界面同一时钟），
	# 连击/濒死/buff/农场/日夜照旧冻结，防止暂停挂机刷时间
	if get_tree().paused:
		return
	_tick_combo(delta)
	_tick_dying(delta)
	_tick_buffs(delta)
	_tick_farm(delta)
	_tick_daynight(delta)

func equip_item(item: EquipmentData) -> void:
	if item == null: return
	equipped_items[item.equip_type] = item
	print("🛡️ [系统] 已装备: ", item.item_name)

func spend_bp(cost: int) -> bool:
	if bp >= cost:
		bp -= cost
		if bp < get_max_bp() and bp_regen_timer == 0.0: bp_regen_timer = bp_regen_interval * 0.5
		return true
	return false

func heal(amount: int) -> void:
	hp = clampi(hp + amount, 0, get_max_hp())
	print("💚 [玩家] 恢复生命: +", amount, " (当前HP: ", hp, "/", get_max_hp(), ")")

func take_damage(amount: int) -> void:
	if current_shield > 0:
		if amount >= current_shield:
			amount -= current_shield
			current_shield = 0
			print("🛡️ [玩家] 护盾被击破!")
		else:
			current_shield -= amount
			amount = 0
			print("🛡️ [玩家] 护盾抵挡伤害: 剩余护盾 ", current_shield)

	if amount > 0:
		hp = clampi(hp - amount, 0, get_max_hp())
		print("🩸 [玩家] 受到伤害: ", amount, " (剩余HP: ", hp, "/", get_max_hp(), ")")

	if hp <= 0:
		print("💀 [玩家] 死亡!")

func calculate_damage(multiplier: float) -> int:
	var base_damage = get_total_attack() * multiplier
	var final_damage = int(base_damage)
	if randf() < get_total_crit_rate():
		final_damage = int(base_damage * (1.0 + get_total_crit_damage()))
		print("🎯 [战斗] 触发暴击: ", int(base_damage), " → ", final_damage)
	return final_damage

func add_combat_entity() -> void:
	active_combat_entities += 1
	_show_combat_ui(true)

func remove_combat_entity() -> void:
	active_combat_entities = max(0, active_combat_entities - 1)
	if active_combat_entities == 0:
		_show_combat_ui(false)

func _show_combat_ui(in_combat: bool) -> void:
	if combat_ui_tween and combat_ui_tween.is_valid(): combat_ui_tween.kill()
	combat_ui_tween = create_tween()
	if in_combat:
		combat_label.text = "🔴 战斗"
		combat_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		combat_ui_tween.tween_property(combat_box, "modulate:a", 1.0, 0.2)
	else:
		combat_label.text = "🟢 脱战"
		combat_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		combat_ui_tween.tween_property(combat_box, "modulate:a", 1.0, 0.2)
		combat_ui_tween.tween_interval(2.0)
		combat_ui_tween.tween_property(combat_box, "modulate:a", 0.0, 0.5)

func force_refresh_combat_ui() -> void:
	if combat_ui_tween and combat_ui_tween.is_valid(): combat_ui_tween.kill()
	if active_combat_entities > 0:
		combat_label.text = "🔴 战斗"
		combat_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if combat_box: combat_box.modulate.a = 1.0
	else:
		combat_label.text = "🟢 脱战"
		combat_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		if combat_box: combat_box.modulate.a = 0.0

func trigger_combat_warn() -> void:
	if combat_warn_tween and combat_warn_tween.is_valid(): combat_warn_tween.kill()
	var target_top = combat_warn_box.offset_top
	var target_bottom = combat_warn_box.offset_bottom
	combat_warn_box.modulate.a = 0.0
	combat_warn_box.offset_top = target_top - 20
	combat_warn_box.offset_bottom = target_bottom - 20
	combat_warn_tween = create_tween()
	combat_warn_tween.set_parallel(true)
	combat_warn_tween.tween_property(combat_warn_box, "modulate:a", 1.0, 0.2)
	combat_warn_tween.tween_property(combat_warn_box, "offset_top", target_top, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	combat_warn_tween.tween_property(combat_warn_box, "offset_bottom", target_bottom, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	combat_warn_tween.chain().tween_interval(1.0)
	combat_warn_tween.chain().tween_property(combat_warn_box, "modulate:a", 0.0, 0.3)

func reset_combat_state() -> void:
	active_combat_entities = 0
	if combat_box: combat_box.modulate.a = 0.0
	if combat_warn_box: combat_warn_box.modulate.a = 0.0
	if combat_ui_tween and combat_ui_tween.is_valid(): combat_ui_tween.kill()
	if combat_warn_tween and combat_warn_tween.is_valid(): combat_warn_tween.kill()

func _setup_ui() -> void:
	combat_ui_layer = CanvasLayer.new()
	combat_ui_layer.layer = 100
	add_child(combat_ui_layer)

	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_ui_layer.add_child(ui_root)

	combat_box = Control.new()
	combat_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	combat_box.position = Vector2(-100, 0) 
	combat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_box.modulate.a = 0.0 
	ui_root.add_child(combat_box)

	combat_bg = UITextBox.create_vertical_fade_bg(200, 40, true)
	combat_box.add_child(combat_bg)

	combat_label = Label.new()
	combat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combat_label.position = Vector2.ZERO
	combat_label.size = Vector2(200, 40) 
	UITextBox.apply_basic(combat_label, "bold", 14)
	combat_box.add_child(combat_label)

	combat_warn_box = Control.new()
	combat_warn_box.anchor_left = 0.5
	combat_warn_box.anchor_right = 0.5
	combat_warn_box.anchor_top = 0.0
	combat_warn_box.anchor_bottom = 0.0
	combat_warn_box.offset_left = -150.0
	combat_warn_box.offset_right = 150.0
	combat_warn_box.offset_top = 50.0
	combat_warn_box.offset_bottom = 86.0 
	combat_warn_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_warn_box.modulate.a = 0.0
	ui_root.add_child(combat_warn_box)

	var warn_bg = UITextBox.create_horizontal_fade_bg()
	combat_warn_box.add_child(warn_bg)

	combat_warn_label = Label.new()
	combat_warn_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	combat_warn_label.text = "⚠ 战斗中无法打开背包！"
	combat_warn_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	combat_warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_warn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITextBox.apply_basic(combat_warn_label, "warning", 14)
	combat_warn_box.add_child(combat_warn_label)

# ============================================================
# ================= 新增系统（v1.1 增量） ====================
# ============================================================

# ---------- 连击框 + 受击红光 UI ----------
func _setup_extra_ui() -> void:
	# 右上角连击爆炸框
	combo_box = Control.new()
	combo_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	combo_box.offset_left = -260.0
	combo_box.offset_right = -20.0
	combo_box.offset_top = 16.0
	combo_box.offset_bottom = 96.0
	combo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_box.modulate.a = 0.0
	ui_root.add_child(combo_box)

	var combo_bg := Panel.new()
	combo_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.09, 0.72)
	sb.border_color = Color(1.0, 0.72, 0.25, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	combo_bg.add_theme_stylebox_override("panel", sb)
	combo_box.add_child(combo_bg)

	combo_label = Label.new()
	combo_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	combo_label.add_theme_constant_override("outline_size", 5)
	UITextBox.apply_basic(combo_label, "bold", 30)
	combo_box.add_child(combo_label)

	# 受击两边红光
	hurt_vignette = ColorRect.new()
	hurt_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_vignette.color = Color(0.85, 0.08, 0.08, 0.0)
	hurt_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hurt_vignette)

	var bar_l := ColorRect.new()
	bar_l.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_l.anchor_right = 0.0
	bar_l.offset_right = 46.0
	bar_l.color = Color(0.95, 0.1, 0.1, 0.0)
	bar_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_vignette.add_child(bar_l)
	var bar_r := ColorRect.new()
	bar_r.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_r.anchor_left = 1.0
	bar_r.offset_left = -46.0
	bar_r.color = Color(0.95, 0.1, 0.1, 0.0)
	bar_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_vignette.add_child(bar_r)
	hurt_vignette.set_meta("bar_l", bar_l)
	hurt_vignette.set_meta("bar_r", bar_r)

func trigger_hurt_vignette() -> void:
	if hurt_vignette == null: return
	if hurt_vignette_tween and hurt_vignette_tween.is_valid(): hurt_vignette_tween.kill()
	var bar_l = hurt_vignette.get_meta("bar_l")
	var bar_r = hurt_vignette.get_meta("bar_r")
	hurt_vignette_tween = create_tween()
	hurt_vignette_tween.set_parallel(true)
	hurt_vignette_tween.tween_property(hurt_vignette, "color:a", 0.16, 0.06)
	hurt_vignette_tween.tween_property(bar_l, "color:a", 0.5, 0.06)
	hurt_vignette_tween.tween_property(bar_r, "color:a", 0.5, 0.06)
	hurt_vignette_tween.chain().tween_interval(0.1)
	hurt_vignette_tween.set_parallel(true)
	hurt_vignette_tween.tween_property(hurt_vignette, "color:a", 0.0, 0.45)
	hurt_vignette_tween.tween_property(bar_l, "color:a", 0.0, 0.45)
	hurt_vignette_tween.tween_property(bar_r, "color:a", 0.0, 0.45)

# ---------- 连击 ----------
func register_hit() -> void:
	combo_count = mini(combo_count + 1, MAX_STAT_CAP)
	combo_timer = COMBO_WINDOW
	if combo_count < 2: return
	if combo_label:
		combo_label.text = "%d HITS" % combo_count
		if combo_count >= 20:
			combo_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
		elif combo_count >= 10:
			combo_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.25))
		else:
			combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	if combo_box:
		combo_box.modulate.a = 1.0
		combo_box.pivot_offset = combo_box.size * 0.5
		if combo_tween and combo_tween.is_valid(): combo_tween.kill()
		combo_tween = create_tween()
		combo_tween.tween_property(combo_box, "scale", Vector2(1.25, 1.25), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		combo_tween.tween_property(combo_box, "scale", Vector2(1.0, 1.0), 0.12)

func _tick_combo(delta: float) -> void:
	if combo_count <= 0: return
	combo_timer -= delta
	if combo_timer <= 0.0:
		combo_count = 0
		combo_timer = 0.0
		if combo_box and combo_box.modulate.a > 0.01:
			if combo_tween and combo_tween.is_valid(): combo_tween.kill()
			combo_tween = create_tween()
			combo_tween.tween_property(combo_box, "modulate:a", 0.0, 0.3)

# ---------- 濒死状态 ----------
func on_player_hurt() -> void:
	out_of_combat_timer = 0.0

func _tick_dying(delta: float) -> void:
	if hp <= 1 and not is_dying:
		is_dying = true
		out_of_combat_timer = 0.0
		print("🩸 [系统] 濒死状态！脱战 %.0f 秒后恢复 1 点生命" % DYING_REGEN_DELAY)
	elif hp > 1:
		is_dying = false
		return
	if not is_dying: return
	if active_combat_entities > 0:
		out_of_combat_timer = 0.0
		return
	out_of_combat_timer += delta
	if out_of_combat_timer >= DYING_REGEN_DELAY:
		out_of_combat_timer = 0.0
		heal(1)
		if hp > 1: is_dying = false

# ---------- 经济：金币 / 材料 ----------
func add_gold(amount: int) -> void:
	if amount <= 0: return
	gold = mini(gold + amount, MAX_STAT_CAP)

func spend_gold(amount: int) -> bool:
	if gold < amount: return false
	gold -= amount
	return true

func add_material(name: String, count: int = 1) -> void:
	if count <= 0: return
	materials[name] = mini(int(materials.get(name, 0)) + count, MAX_STAT_CAP)

func remove_material(name: String, count: int = 1) -> bool:
	if count_material(name) < count: return false
	materials[name] = int(materials.get(name, 0)) - count
	if int(materials[name]) <= 0: materials.erase(name)
	return true

func count_material(name: String) -> int:
	return int(materials.get(name, 0))

# ---------- 经验与等级（5 级封顶） ----------
func exp_to_next() -> int:
	if current_level >= MAX_LEVEL: return 0
	return int(EXP_TABLE.get(current_level, 0))

func add_exp(amount: int) -> void:
	if amount <= 0 or current_level >= MAX_LEVEL: return
	exp += amount
	while current_level < MAX_LEVEL and exp >= exp_to_next():
		exp -= exp_to_next()
		_level_up()

func _level_up() -> void:
	current_level = mini(current_level + 1, MAX_LEVEL)
	skill_points = mini(skill_points + 1 + int(furniture_bonus.get("sp", 0)), MAX_STAT_CAP)
	hp = get_max_hp()
	bp = get_max_bp()
	current_shield = get_max_shield()
	print("🎉 [系统] 升级！Lv.%d（获得技能点，当前 %d）" % [current_level, skill_points])

# ---------- 家具基地 ----------
const FURNITURE_PER_LEVEL := {
	"bed": {"hp": 6},
	"shield_rack": {"shield": 2},
	"forge": {"atk": 1},
	"card_case": {"bp": 1},
	"hourglass": {"sp": 3},
}

const FURNITURE_NAMES := {
	"bed": "床榻",
	"shield_rack": "盾架",
	"forge": "锻台",
	"card_case": "卡匣",
	"hourglass": "沙漏",
}

func get_furniture_level(kind: String) -> int:
	return int(furniture_levels.get(kind, 0))

func get_furniture_upgrade_cost(kind: String) -> Dictionary:
	var lv := get_furniture_level(kind)
	var cost := {"gold": 60 + lv * 70, "mats": {"木料": 1 + lv, "石料": lv}}
	if kind == "forge": cost["mats"]["矿砂"] = 1 + lv
	if kind == "hourglass": cost["mats"]["晶髓"] = 1 + lv
	return cost

func upgrade_furniture(kind: String) -> bool:
	if not FURNITURE_PER_LEVEL.has(kind): return false
	var lv := get_furniture_level(kind)
	if lv >= 5: return false
	var cost := get_furniture_upgrade_cost(kind)
	if not spend_gold(int(cost["gold"])): return false
	var mats: Dictionary = cost["mats"]
	for m in mats:
		if not remove_material(m, int(mats[m])):
			# 回滚金币
			add_gold(int(cost["gold"]))
			return false
	furniture_levels[kind] = lv + 1
	_recalc_furniture_bonus()
	hp = get_max_hp()
	bp = get_max_bp()
	current_shield = get_max_shield()
	print("🛠️ [基地] %s 升级到 Lv.%d" % [String(FURNITURE_NAMES.get(kind, kind)), lv + 1])
	return true

func _recalc_furniture_bonus() -> void:
	for k in furniture_bonus: furniture_bonus[k] = 0
	for kind in furniture_levels:
		var per: Dictionary = FURNITURE_PER_LEVEL.get(kind, {})
		var lv := int(furniture_levels[kind])
		for stat in per:
			furniture_bonus[stat] = int(furniture_bonus.get(stat, 0)) + int(per[stat]) * lv

# ---------- 菜地 ----------

## v1.2 作物表：不同种子不同时长/产物/档位
const CROP_GROW_TIME := 45.0             # 未知种子兜底时长
const CROP_DEFS := {
	"草叶": {"grow": 20.0, "yield_min": 1, "yield_max": 3, "tier": 1, "desc": "速生基础草木"},
	"苔核": {"grow": 45.0, "yield_min": 1, "yield_max": 2, "tier": 1, "desc": "沼泽苔球，酿造常用"},
	"晶髓": {"grow": 90.0, "yield_min": 1, "yield_max": 1, "tier": 2, "desc": "砂地结晶，高级锻造核心"},
	"沙芦荟": {"grow": 35.0, "yield_min": 1, "yield_max": 2, "tier": 1, "desc": "沙漠作物，灼伤恢复"},
	"忆须草": {"grow": 60.0, "yield_min": 1, "yield_max": 2, "tier": 2, "desc": "回廊草须，炼金催化剂"},
}

func get_crop_def(seed_name: String) -> Dictionary:
	return CROP_DEFS.get(seed_name, {"grow": CROP_GROW_TIME, "yield_min": 1, "yield_max": 2, "tier": 1, "desc": "未知种子"})

## v1.6 食物效果表：吃 1 份作物 → 立即回血或短时增益
const CROP_FOOD_EFFECTS := {
	"草叶": {"type": "heal", "value": 3, "duration": 0.0, "desc": "立即恢复 3 点生命"},
	"沙芦荟": {"type": "heal", "value": 5, "duration": 0.0, "desc": "立即恢复 5 点生命"},
	"苔核": {"type": "atk", "value": 2, "duration": 60.0, "desc": "60 秒内攻击 +2"},
	"忆须草": {"type": "atk", "value": 3, "duration": 90.0, "desc": "90 秒内攻击 +3"},
	"晶髓": {"type": "shield", "value": 3, "duration": 60.0, "desc": "60 秒内护盾 +3"},
}

func get_food_effect(crop_name: String) -> Dictionary:
	return CROP_FOOD_EFFECTS.get(crop_name, {})

## 食用作物：消耗 1 份，获得回血/短时增益（食材与弹药耗材通用的取舍）
func eat_crop(crop_name: String) -> bool:
	var fx := get_food_effect(crop_name)
	if fx.is_empty():
		print("🍽️ [食物] %s 不能食用" % crop_name)
		return false
	if count_material(crop_name) <= 0:
		print("🍽️ [食物] 没有 %s 了" % crop_name)
		return false
	remove_material(crop_name, 1)
	match String(fx["type"]):
		"heal":
			heal(int(fx["value"]))
		"atk", "shield":
			add_buff(String(fx["type"]), float(fx["duration"]), int(fx["value"]))
	print("🍽️ [食物] 食用 %s：%s" % [crop_name, String(fx["desc"])])
	return true

func get_farm_plot_count() -> int:
	return farm_plots.size()

## 解锁新地块（田契升级）：返回是否成功解锁
func unlock_farm_plot() -> bool:
	if farm_plots.size() >= MAX_FARM_PLOTS: return false
	if not spend_gold(FARM_EXPAND_GOLD): return false
	farm_plots.append({"state": 0, "remain": 0.0, "seed": ""})
	farm_fertility.append(0)
	print("🌾 [农场] 解锁新地块，当前 %d 块" % farm_plots.size())
	return true

const MAX_FARM_PLOTS := 8
const FARM_EXPAND_GOLD := 400

## 施肥：提升土地肥力（0~3），缩短生长时间并提高高产概率
func fertilize_plot(idx: int) -> bool:
	if idx < 0 or idx >= farm_plots.size(): return false
	if int(farm_fertility[idx]) >= 3: return false
	if not remove_material("沼肥", 1): return false
	farm_fertility[idx] = int(farm_fertility[idx]) + 1
	print("💩 [农场] 地块 %d 肥力提升至 %d" % [idx, int(farm_fertility[idx])])
	return true

func get_farm_fertility(idx: int) -> int:
	if idx < 0 or idx >= farm_plots.size(): return -1
	return int(farm_fertility[idx])

func plant_crop(idx: int, seed_name: String) -> bool:
	if idx < 0 or idx >= farm_plots.size(): return false
	var plot: Dictionary = farm_plots[idx]
	if int(plot["state"]) != 0: return false
	var cdef: Dictionary = get_crop_def(seed_name)
	var fert := int(farm_fertility[idx])
	var grow_time: float = float(cdef["grow"]) * (1.0 - 0.12 * fert)
	farm_plots[idx] = {"state": 1, "remain": grow_time, "seed": seed_name}
	print("🌱 [农场] 地块 %d 播种 %s（%.0f 秒成熟，肥力 %d）" % [idx, seed_name, grow_time, fert])
	return true

func harvest_plot(idx: int) -> int:
	if idx < 0 or idx >= farm_plots.size(): return 0
	var plot: Dictionary = farm_plots[idx]
	if int(plot["state"]) != 2: return 0
	var seed_name := String(plot["seed"])
	var cdef: Dictionary = get_crop_def(seed_name)
	var yield_count: int = int(cdef["yield_min"]) + randi() % maxi(1, int(cdef["yield_max"]) - int(cdef["yield_min"]) + 1)
	# 肥力高产概率：基础 5% + 每级肥力 15%
	var fert := int(farm_fertility[idx])
	if randf() < 0.05 + 0.15 * fert:
		yield_count *= 2
		print("✨ [农场] 地块 %d 大丰收！产量翻倍" % idx)
	farm_plots[idx] = {"state": 0, "remain": 0.0, "seed": ""}
	if seed_name != "":
		add_material(seed_name, yield_count)
	return yield_count

func get_farm_seed(idx: int) -> String:
	if idx < 0 or idx >= farm_plots.size(): return ""
	return String(farm_plots[idx]["seed"])

func get_farm_state(idx: int) -> int:
	if idx < 0 or idx >= farm_plots.size(): return -1
	return int(farm_plots[idx]["state"])

func get_farm_remain(idx: int) -> float:
	if idx < 0 or idx >= farm_plots.size(): return -1.0
	return float(farm_plots[idx]["remain"])

func _tick_farm(delta: float) -> void:
	for i in farm_plots.size():
		var plot: Dictionary = farm_plots[i]
		if int(plot["state"]) == 1:
			var remain := float(plot["remain"]) - delta
			if remain <= 0.0:
				farm_plots[i] = {"state": 2, "remain": 0.0, "seed": String(plot["seed"])}
			else:
				farm_plots[i] = {"state": 1, "remain": remain, "seed": String(plot["seed"])}

## 击杀怪物时调用：刷新（加速）所有生长中的植物
func refresh_farm_growth(seconds: float) -> void:
	for i in farm_plots.size():
		var plot: Dictionary = farm_plots[i]
		if int(plot["state"]) == 1:
			var remain := float(plot["remain"]) - seconds
			if remain <= 0.0:
				farm_plots[i] = {"state": 2, "remain": 0.0, "seed": String(plot["seed"])}
			else:
				farm_plots[i] = {"state": 1, "remain": remain, "seed": String(plot["seed"])}

# ---------- 药水 Buff / 酿造 ----------
const POTION_RECIPES := {
	"攻击灵药": {"mats": {"草叶": 3, "胶质团": 2}, "buff": {"type": "atk", "duration": 120.0, "potence": 3}, "desc": "120 秒内攻击 +3"},
	"坚壳灵药": {"mats": {"石料": 3, "苔核": 2}, "buff": {"type": "shield", "duration": 120.0, "potence": 4}, "desc": "120 秒内护盾 +4"},
	"治疗药剂": {"mats": {"草叶": 2, "胶质团": 1}, "heal": 8, "desc": "立即恢复 8 点生命"},
	"苔核浓缩液": {"mats": {"苔核": 4, "晶髓": 1}, "buff": {"type": "atk", "duration": 180.0, "potence": 5}, "desc": "180 秒内攻击 +5（高级）"},
}

## v1.18 drain_on_expire=true：buff 到期时护盾值同步扣回 potence（铁壁润泽：
## 到期上限 -2、护盾值 -2；不足则归零，current_shield 为 int 不会为负、不扣血）
## 同类 buff 叠加时保留 max 时长/potence，drain 标志取"或"
func add_buff(buff_type: String, duration: float, potence: int, drain_on_expire: bool = false) -> void:
	for b in active_buffs:
		if String(b["type"]) == buff_type:
			b["remain"] = maxf(float(b["remain"]), duration)
			b["potence"] = maxi(int(b["potence"]), potence)
			b["drain"] = bool(b.get("drain", false)) or drain_on_expire
			return
	active_buffs.append({"type": buff_type, "remain": duration, "potence": potence, "drain": drain_on_expire})

func _tick_buffs(delta: float) -> void:
	if active_buffs.is_empty(): return
	var i := active_buffs.size() - 1
	while i >= 0:
		var b: Dictionary = active_buffs[i]
		b["remain"] = float(b["remain"]) - delta
		if float(b["remain"]) <= 0.0:
			# v1.18 带回吸标志的护盾 buff 到期：护盾值 -potence（最低 0，不扣血）
			if bool(b.get("drain", false)) and String(b["type"]) == "shield":
				current_shield = maxi(0, current_shield - int(b["potence"]))
			active_buffs.remove_at(i)
		i -= 1

func _get_buff_bonus(kind: String) -> int:
	var total := 0
	for b in active_buffs:
		if String(b["type"]) == kind:
			total += int(b["potence"])
	return total

## v1.7 药水道具化：酿造产出可囤积的药水，随时饮用（Q 键快速喝治疗药）
## 效果沿用 POTION_RECIPES 的 heal / buff 数值，只是从"酿造即生效"改为"入库后自选时机使用"
const POTION_ITEMS := {
	"potion_heal": {"name": "治疗药剂", "recipe": "治疗药剂", "desc": "立即恢复 8 点生命", "hotkey": "Q"},
	"potion_atk": {"name": "攻击灵药", "recipe": "攻击灵药", "desc": "120 秒内攻击 +3", "hotkey": ""},
	"potion_shield": {"name": "坚壳灵药", "recipe": "坚壳灵药", "desc": "120 秒内护盾 +4", "hotkey": ""},
	"potion_atk2": {"name": "苔核浓缩液", "recipe": "苔核浓缩液", "desc": "180 秒内攻击 +5", "hotkey": ""},
}

var potions: Dictionary = {}            # {potion_id: 持有数量}

func get_potion_count(potion_id: String) -> int:
	return int(potions.get(potion_id, 0))

## 酿造：消耗材料 → 药水入库（返回获得的瓶数；0 = 失败）
func brew_potion(recipe_id: String) -> bool:
	if not POTION_RECIPES.has(recipe_id): return false
	var recipe: Dictionary = POTION_RECIPES[recipe_id]
	var mats: Dictionary = recipe["mats"]
	for m in mats:
		if count_material(m) < int(mats[m]): return false
	for m in mats:
		remove_material(m, int(mats[m]))
	# 找到对应药水 id
	var potion_id := ""
	for pid in POTION_ITEMS:
		if String(POTION_ITEMS[pid]["recipe"]) == recipe_id:
			potion_id = String(pid)
			break
	if potion_id == "":
		# 未登记道具的配方：保持旧行为（立即生效）
		if recipe.has("heal"):
			heal(int(recipe["heal"]))
		if recipe.has("buff"):
			var buff: Dictionary = recipe["buff"]
			add_buff(String(buff["type"]), float(buff["duration"]), int(buff["potence"]))
		print("🧪 [酿造] %s 立即生效" % recipe_id)
		unlock_achievement("potion")
		return true
	potions[potion_id] = get_potion_count(potion_id) + 1
	print("🧪 [酿造] %s 入库（持有 %d）" % [String(POTION_ITEMS[potion_id]["name"]), get_potion_count(potion_id)])
	unlock_achievement("potion")
	return true

## 饮用药水：消耗 1 瓶，应用效果
func use_potion(potion_id: String) -> bool:
	if not POTION_ITEMS.has(potion_id): return false
	if get_potion_count(potion_id) <= 0: return false
	var recipe_id := String(POTION_ITEMS[potion_id]["recipe"])
	var recipe: Dictionary = POTION_RECIPES[recipe_id]
	potions[potion_id] = get_potion_count(potion_id) - 1
	if potions[potion_id] <= 0:
		potions.erase(potion_id)
	if recipe.has("heal"):
		heal(int(recipe["heal"]))
	if recipe.has("buff"):
		var buff: Dictionary = recipe["buff"]
		add_buff(String(buff["type"]), float(buff["duration"]), int(buff["potence"]))
	print("🧪 [药水] 饮用 %s（剩 %d）" % [String(POTION_ITEMS[potion_id]["name"]), get_potion_count(potion_id)])
	return true

## Q 键快速饮用：优先治疗药，没有则提示
func quick_heal() -> bool:
	if get_potion_count("potion_heal") > 0:
		return use_potion("potion_heal")
	print("🧪 [药水] 没有治疗药剂了（去酿造台合成）")
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q:
		var dm = DialogueManager.instance()
		if dm and (dm._is_playing or dm._is_waiting_choice): return
		if get_tree().paused: return
		get_viewport().set_input_as_handled()
		quick_heal()

# ---------- 装备强化（锻造台） ----------
const GEAR_UPGRADE_MAX := 5

func get_gear_upgrade_level(item) -> int:
	if item == null: return 0
	return int(gear_upgrades.get(_gear_key(item), 0))

func _get_gear_upgrade_total(stat: String) -> int:
	var total := 0
	for item in equipped_items.values():
		if item == null: continue
		var lv := int(gear_upgrades.get(_gear_key(item), 0))
		if stat == "attack":
			total += lv
		elif stat == "hp":
			total += lv * 2
		elif stat == "shield":
			total += lv * 2
	return total

func get_gear_upgrade_cost(item) -> Dictionary:
	var lv := get_gear_upgrade_level(item)
	return {"gold": 80 + lv * 90, "mats": {"木料": 1 + lv, "矿砂": 1 + lv}}

func upgrade_gear(item) -> bool:
	if item == null: return false
	var lv := get_gear_upgrade_level(item)
	if lv >= GEAR_UPGRADE_MAX: return false
	var cost := get_gear_upgrade_cost(item)
	if not spend_gold(int(cost["gold"])): return false
	var mats: Dictionary = cost["mats"]
	for m in mats:
		if not remove_material(m, int(mats[m])):
			add_gold(int(cost["gold"]))
			return false
	gear_upgrades[_gear_key(item)] = lv + 1
	hp = get_max_hp()
	current_shield = get_max_shield()
	print("🔨 [锻造] %s 强化至 +%d" % [item.item_name, lv + 1])
	return true

# ---------- 伪随机掉落 + 保底 ----------
## entries: [{"id": 材料名, "weight": 权重, "rare": 是否稀有}]
## pity_limit: 连续 N 次未中稀有时第 N 次必中稀有
func roll_drop(table_id: String, entries: Array, pity_limit: int = 30) -> Dictionary:
	if entries.is_empty(): return {}
	var rolls := int(pity_counter.get(table_id, 0)) + 1
	var total_weight := 0.0
	for e in entries:
		total_weight += float(e.get("weight", 1.0))
	var roll := randf() * total_weight
	var acc := 0.0
	var picked: Dictionary = entries[0]
	for e in entries:
		acc += float(e.get("weight", 1.0))
		if roll <= acc:
			picked = e
			break
	if bool(picked.get("rare", false)):
		pity_counter[table_id] = 0
	elif rolls >= pity_limit:
		for e in entries:
			if bool(e.get("rare", false)):
				picked = e
				break
		pity_counter[table_id] = 0
		print("🎯 [保底] 掉落表 %s 触发保底！" % table_id)
	else:
		pity_counter[table_id] = rolls
	return picked

# ---------- 宝箱记录 ----------
func is_chest_opened(chest_id: String) -> bool:
	return opened_chests.has(chest_id)

func mark_chest_opened(chest_id: String) -> void:
	if not opened_chests.has(chest_id):
		opened_chests.append(chest_id)

# ---------- 昼夜系统 ----------
func is_night() -> bool:
	return day_time > DAY_LENGTH * 0.68

func get_day_phase() -> String:
	if day_time < DAY_LENGTH * 0.55: return "白天"
	if day_time < DAY_LENGTH * 0.68: return "黄昏"
	return "夜晚"

func get_enemy_damage_multiplier() -> float:
	return 1.25 if is_night() else 1.0

# ---------- 设置应用 ----------
## v1.9 音频总线：BGM / SFX 两条子总线挂在 Master 下，滑条各管各的。
func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index("BGM") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "BGM")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")

func apply_audio_settings() -> void:
	_ensure_audio_buses()
	var bgm_linear := clampf(float(settings.get("bgm", 80)) / 100.0, 0.001, 1.0)
	var se_linear := clampf(float(settings.get("se", 80)) / 100.0, 0.001, 1.0)
	var bgm_idx := AudioServer.get_bus_index("BGM")
	var se_idx := AudioServer.get_bus_index("SFX")
	if bgm_idx >= 0:
		AudioServer.set_bus_volume_db(bgm_idx, linear_to_db(bgm_linear))
	if se_idx >= 0:
		AudioServer.set_bus_volume_db(se_idx, linear_to_db(se_linear))
	apply_vn_speed()

func apply_vn_speed() -> void:
	var speed := clampf(float(settings.get("vn_speed", 1.0)), 0.25, 3.0)
	settings["vn_speed"] = speed
	# 注意：不能在这里调用 DialogueManager.instance()——autoload 初始化期创建并挂到
	# root 的节点会被清掉，之后 get_tree() 返回 null（VN 播放即报空引用）。
	# 仅在实例已存在（游戏内已播过 VN）时才应用速度。
	var dm = DialogueManager._instance
	if dm != null and is_instance_valid(dm) and dm._ui and dm._ui._type_timer:
		dm._ui._type_timer.wait_time = 0.05 / speed

const RESOLUTIONS := [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

func apply_resolution() -> void:
	var idx := clampi(int(settings.get("resolution", 0)), 0, RESOLUTIONS.size() - 1)
	var size: Vector2i = RESOLUTIONS[idx]
	if bool(settings.get("fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(size)
		var screen_size := DisplayServer.screen_get_size()
		DisplayServer.window_set_position((screen_size - size) / 2)

func _tick_daynight(delta: float) -> void:
	day_time += delta
	if day_time >= DAY_LENGTH:
		day_time -= DAY_LENGTH
	var scene := get_tree().current_scene
	if scene == null: return
	if day_night_modulate == null or not is_instance_valid(day_night_modulate):
		day_night_modulate = scene.get_node_or_null("DayNightModulate") as CanvasModulate
		if day_night_modulate == null:
			day_night_modulate = CanvasModulate.new()
			day_night_modulate.name = "DayNightModulate"
			scene.add_child(day_night_modulate)
	var target := Color(1, 1, 1)
	if is_night():
		target = Color(0.42, 0.48, 0.68)
	elif day_time > DAY_LENGTH * 0.55:
		target = Color(1.0, 0.86, 0.68)
	day_night_modulate.color = day_night_modulate.color.lerp(target, delta * 0.8)

# ================= v1.2 采集工具等级 =================

## 工具档位：影响野外采集产量倍率（v1.18 起不再限制采集资格）
const GATHER_TOOLS := [
	{"name": "徒手", "mult": 1.0, "can_ore": false},
	{"name": "铁镌", "mult": 1.3, "can_ore": true},
	{"name": "精金镌", "mult": 1.6, "can_ore": true},
	{"name": "星辉镌", "mult": 2.0, "can_ore": true},
]
const GATHER_TOOL_UPGRADE_COSTS := [
	{"gold": 150, "mats": {"木料": 6, "矿砂": 6}},
	{"gold": 600, "mats": {"黑铁锭": 4, "晶髓": 2}},
	{"gold": 2000, "mats": {"赤金锭": 4, "血玉": 1}},
]

var gather_tool_tier: int = 0            # 当前采集工具档位 0~3

func get_gather_tool_name() -> String:
	return String(GATHER_TOOLS[clampi(gather_tool_tier, 0, GATHER_TOOLS.size() - 1)]["name"])

func get_gather_multiplier() -> float:
	return float(GATHER_TOOLS[clampi(gather_tool_tier, 0, GATHER_TOOLS.size() - 1)]["mult"])

func can_gather_ore() -> bool:
	return bool(GATHER_TOOLS[clampi(gather_tool_tier, 0, GATHER_TOOLS.size() - 1)]["can_ore"])

func upgrade_gather_tool() -> bool:
	if gather_tool_tier >= GATHER_TOOLS.size() - 1: return false
	var cost: Dictionary = GATHER_TOOL_UPGRADE_COSTS[gather_tool_tier]
	if not spend_gold(int(cost["gold"])): return false
	var mats: Dictionary = cost["mats"]
	for m in mats:
		if not remove_material(m, int(mats[m])):
			add_gold(int(cost["gold"]))
			return false
	gather_tool_tier += 1
	print("⛏️ [采集] 工具升级为 %s（产量 ×%.1f）" % [get_gather_tool_name(), get_gather_multiplier()])
	return true

# ================= v1.2 图纸打造（动态装备） =================

## 打造配方：材料 + 金币 → 动态生成 EquipmentData（不入扫描目录，仅打造后拥有）
const GEAR_RECIPES := [
	{"id": "qingshi_blade", "name": "青石锋刃", "type": "weapon", "atk": 6, "hp": 0, "shield": 0, "crit": 0.0,
	 "cost": {"gold": 300, "mats": {"青石": 8, "木料": 4}}, "desc": "青石锻制的轻刃，锋线稳定"},
	{"id": "heitie_cuirass", "name": "黑铁胸甲", "type": "armor", "atk": 0, "hp": 14, "shield": 5, "crit": 0.0,
	 "cost": {"gold": 500, "mats": {"黑铁锭": 6, "矿砂": 10}}, "desc": "沉厚的黑铁甲叶，扛得住撞击"},
	{"id": "chijin_amulet", "name": "赤金护符", "type": "accessory", "atk": 2, "hp": 4, "shield": 0, "crit": 0.06,
	 "cost": {"gold": 800, "mats": {"赤金锭": 4, "苔核": 6}}, "desc": "赤金镂花，耳语般提升气运"},
	{"id": "xueyu_edge", "name": "血玉锋刃", "type": "weapon", "atk": 14, "hp": 0, "shield": 2, "crit": 0.05,
	 "cost": {"gold": 1800, "mats": {"血玉": 3, "晶髓": 6, "黑铁锭": 4}}, "desc": "血玉芯刃，渴战"},
	{"id": "huixiang_vestment", "name": "回响法衣", "type": "armor", "atk": 4, "hp": 20, "shield": 8, "crit": 0.0,
	 "cost": {"gold": 3500, "mats": {"忆须草": 10, "血玉": 2, "赤金锭": 6}}, "desc": "前世遗物的织纹，仍带余温"},
]

var owned_gear: Dictionary = {}         # recipe_id -> EquipmentData（打造获得）
var gear_affixes: Dictionary = {}       # recipe_id -> {"affixes": [...], "tier": int}（v1.10 词缀持久化）

func get_owned_gear_list() -> Array:
	var out: Array = []
	for id in owned_gear:
		out.append(owned_gear[id])
	return out

func has_crafted(recipe_id: String) -> bool:
	return owned_gear.has(recipe_id)

func craft_gear(recipe_id: String) -> EquipmentData:
	if owned_gear.has(recipe_id):
		print("🔨 [锻造] %s 已拥有，无需重复打造" % recipe_id)
		return null
	var recipe: Dictionary = {}
	for r in GEAR_RECIPES:
		if String(r["id"]) == recipe_id:
			recipe = r
			break
	if recipe.is_empty(): return null
	var cost: Dictionary = recipe["cost"]
	if not spend_gold(int(cost["gold"])): return null
	var mats: Dictionary = cost["mats"]
	for m in mats:
		if not remove_material(m, int(mats[m])):
			add_gold(int(cost["gold"]))
			return null
	# v1.10 词缀：按品阶随机附加（记录于 gear_affixes，读档恢复）
	var tier := AffixData.roll_tier()
	var affixes := AffixData.roll_affixes(tier)
	gear_affixes[recipe_id] = {"affixes": affixes, "tier": tier}
	var item := _create_gear_from_recipe(recipe_id, affixes, tier)
	if item == null: return null
	owned_gear[recipe_id] = item
	print("🔨 [锻造] 打造成功：%s（攻+%d 血+%d 盾+%d）[%s]" % [item.item_name, item.attack_bonus, item.hp_bonus, item.shield_bonus, AffixData.tier_name(tier)])
	if affixes.size() > 0:
		var names := ""
		for a in affixes: names += String(AffixData.AFFIXES[String(a)]["name"]) + " "
		print("   ✦ 词缀：%s" % names.strip_edges())
	unlock_achievement("crafter")
	return item

## 按配方生成装备资源（不消耗材料；打造与读档共用）
## affix_ids/tier：打造时传入随机词缀，读档时传入存档的词缀（v1.10）
func _create_gear_from_recipe(recipe_id: String, affix_ids: Array = [], tier := 0) -> EquipmentData:
	var recipe: Dictionary = {}
	for r in GEAR_RECIPES:
		if String(r["id"]) == recipe_id:
			recipe = r
			break
	if recipe.is_empty(): return null
	var item := EquipmentData.new()
	item.item_name = String(recipe["name"])
	match String(recipe["type"]):
		"weapon": item.equip_type = EquipmentData.Type.WEAPON
		"armor": item.equip_type = EquipmentData.Type.ARMOR
		"accessory": item.equip_type = EquipmentData.Type.ACCESSORY
	item.attack_bonus = int(recipe["atk"])
	item.hp_bonus = int(recipe["hp"])
	item.shield_bonus = int(recipe["shield"])
	item.crit_rate_bonus = float(recipe["crit"])
	item.description = String(recipe["desc"])
	# 合成稳定标识键：gear_upgrades 字典按此索引。
	# 不能改用 resource_path（运行时资源注册假路径会撞 Godot 资源缓存）
	item.set_meta("gear_key", "crafted://" + recipe_id)
	# v1.10 词缀：加成直接写进 bonus 字段（属性聚合链路零改动）
	item.tier = tier
	for aid in affix_ids:
		item.affixes.append(String(aid))
		AffixData.apply_to(item, String(aid))
	return item

## 装备的字典索引键：打造装备用合成键，磁盘装备用资源路径
func _gear_key(item) -> String:
	if item == null: return ""
	var mk: String = item.get_meta("gear_key", "")
	if mk != "": return mk
	return String(item.resource_path)

# ================= v1.2 关卡进度 =================

## 已通关关卡 id 集合（如 "1-3"）；关卡出口按此决定是否开放
var cleared_stages: Dictionary = {}

func is_stage_cleared(stage_id: String) -> bool:
	return cleared_stages.has(stage_id)

## v1.9 隐藏关卡：检查一组关卡是否全部通关
func are_stages_cleared(ids: Array) -> bool:
	for id in ids:
		if not is_stage_cleared(String(id)):
			return false
	return true

func mark_stage_cleared(stage_id: String) -> void:
	if cleared_stages.has(stage_id): return
	cleared_stages[stage_id] = true
	print("🏁 [关卡] %s 已通关" % stage_id)
	_check_stage_achievements()

# ================= v1.3 三章十五关进度表 =================

## 主线关卡顺序表（远征石 / 通关门都按这张表流转）
## 第 i 关解锁条件：第 i-1 关已通关（cleared_stages 记录）
const CHAPTER_STAGES := [
	{"id": "ch1_1", "name": "1-1 森林初遇", "path": "res://stages/ch0/02_forest_entrance.tscn"},
	{"id": "ch1_2", "name": "1-2 密林深处", "path": "res://stages/ch1/03_forest_deep.tscn"},
	{"id": "ch1_3", "name": "1-3 荆棘巢穴", "path": "res://stages/ch1/04_forest_nest.tscn"},
	{"id": "ch1_4", "name": "1-4 碑林遗迹", "path": "res://stages/ch1/05_forest_relic.tscn"},
	{"id": "ch1_5", "name": "1-5 森林之心", "path": "res://stages/ch1/06_forest_heart.tscn"},
	{"id": "ch2_1", "name": "2-1 沙海之门", "path": "res://stages/ch2/07_sand_gate.tscn"},
	{"id": "ch2_2", "name": "2-2 流沙谷", "path": "res://stages/ch2/08_sand_valley.tscn"},
	{"id": "ch2_3", "name": "2-3 风蚀残丘", "path": "res://stages/ch2/09_sand_dunes.tscn"},
	{"id": "ch2_4", "name": "2-4 绿洲废墟", "path": "res://stages/ch2/10_sand_oasis.tscn"},
	{"id": "ch2_5", "name": "2-5 沙暴之核", "path": "res://stages/ch2/11_sand_boss.tscn"},
	{"id": "ch3_1", "name": "3-1 霜峰山道", "path": "res://stages/ch3/12_peak_ascent.tscn"},
	{"id": "ch3_2", "name": "3-2 风雪回廊", "path": "res://stages/ch3/13_peak_storm.tscn"},
	{"id": "ch3_3", "name": "3-3 空山神龛", "path": "res://stages/ch3/14_peak_shrine.tscn"},
	{"id": "ch3_4", "name": "3-4 虚空裂隙", "path": "res://stages/ch3/15_peak_hollow.tscn"},
	{"id": "ch3_5", "name": "3-5 回响之冠", "path": "res://stages/ch3/16_peak_boss.tscn"},
]

func get_stage_count() -> int:
	return CHAPTER_STAGES.size()

func is_stage_index_unlocked(idx: int) -> bool:
	if idx <= 0: return true
	if idx >= CHAPTER_STAGES.size(): return false
	return is_stage_cleared(String(CHAPTER_STAGES[idx - 1]["id"]))

## 最深已解锁关卡下标（第 0 关永远解锁）
func get_furthest_stage_index() -> int:
	var furthest := 0
	for i in range(1, CHAPTER_STAGES.size()):
		if is_stage_index_unlocked(i):
			furthest = i
		else:
			break
	return furthest

# ================= v1.11 周目轮回 =================

## 当前周目（0=初回；通关 15 关后可在木屋"轮回之镜"开启下一周目）
var reincarnation_count: int = 0

## 轮回解锁条件：15 个主线关卡全部通关
func is_reincarnation_unlocked() -> bool:
	for info in CHAPTER_STAGES:
		if not is_stage_cleared(String(info["id"])):
			return false
	return true

## 是否还能继续轮回（未满圈）
func can_reincarnate() -> bool:
	return is_reincarnation_unlocked() and reincarnation_count < ReincarnationData.MAX_CYCLES

## 执行轮回：周目 +1，重置关卡进度；保留等级/装备/材料/图鉴/成就/设置（meta 进度）。
## 返回新周目数；条件不满足返回 -1。
func do_reincarnate() -> int:
	if not can_reincarnate():
		print("🌀 [轮回] 条件不满足（需 15 关全通且未满 %d 回）" % ReincarnationData.MAX_CYCLES)
		return -1
	reincarnation_count = mini(reincarnation_count + 1, ReincarnationData.MAX_CYCLES)
	cleared_stages.clear()
	played_intro_scripts.clear()   # 犬六回：每一回重新经历故事
	_check_stage_achievements()
	hp = get_max_hp()
	bp = get_max_bp()
	current_shield = 0
	print("🌀 [轮回] 进入%s（第 %d 回）— 关卡进度已重置，成长与收集保留" % [
		ReincarnationData.cycle_name(reincarnation_count), reincarnation_count + 1])
	return reincarnation_count

# ================= v1.4 存档系统 =================

const SAVE_PATH := "user://inurokkai_save.json"
const SAVE_VERSION := 1

signal game_loaded   # 读档完成后广播（UI 可订阅刷新）

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## 序列化已装备装备：磁盘资源存路径，打造装备存配方 id
func _serialize_equipped() -> Dictionary:
	var out := {}
	for t in equipped_items:
		var item = equipped_items[t]
		if item == null: continue
		var mk: String = item.get_meta("gear_key", "")
		if mk != "":
			out[str(int(t))] = {"gear": mk.substr(len("crafted://"))}
		else:
			var rp := String(item.resource_path)
			if rp != "" and ResourceLoader.exists(rp):
				out[str(int(t))] = {"res": rp}
	return out

func build_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"character": current_character_id,
		"level": current_level,
		"exp": exp,
		"skill_points": skill_points,
		"gold": gold,
		"hp": hp,
		"bp": bp,
		"shield": current_shield,
		"materials": materials.duplicate(),
		"furniture": furniture_levels.duplicate(),
		"farm_plots": farm_plots.duplicate(true),
		"farm_fertility": farm_fertility.duplicate(),
		"gear_upgrades": gear_upgrades.duplicate(),
		"gather_tool_tier": gather_tool_tier,
		"owned_gear": owned_gear.keys(),
		"gear_affixes": gear_affixes.duplicate(true),
		"equipped": _serialize_equipped(),
		"unlocked_branches": unlocked_branches.duplicate(),
		"skill_branches": skill_branches.duplicate(),
		"potions": potions.duplicate(),
		"cleared_stages": cleared_stages.duplicate(),
		"opened_chests": opened_chests.duplicate(),
		"pity_counter": pity_counter.duplicate(),
		"harvested_nodes": harvested_nodes.duplicate(),
		"tutorial_seen": tutorial_seen.duplicate(),
		"settings": settings.duplicate(),
		"played_intro": played_intro_scripts.duplicate(),
		"codex": codex_unlocked.duplicate(),
		"achievements": achievements_unlocked.duplicate(),
		"kill_count": kill_count,
		"reincarnation": reincarnation_count,
		"day_time": day_time,
	}

func save_game() -> bool:
	var data := build_save_data()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("💾 [存档] 无法写入存档文件: " + SAVE_PATH)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("💾 [存档] 已保存：Lv.%d / $%d / 通关 %d 关 / %s" % [current_level, gold, cleared_stages.size(), String(data["saved_at"])])
	return true

func load_game() -> bool:
	if not has_save():
		print("💾 [存档] 没有找到存档")
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null: return false
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("💾 [存档] 存档损坏（非 JSON 对象）")
		return false
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_error("💾 [存档] 存档版本不兼容")
		return false
	# ---- 基础成长 ----
	current_level = clampi(int(data.get("level", 1)), 1, MAX_LEVEL)
	exp = maxi(0, int(data.get("exp", 0)))
	skill_points = clampi(int(data.get("skill_points", 0)), 0, MAX_STAT_CAP)
	gold = clampi(int(data.get("gold", 0)), 0, MAX_STAT_CAP)
	# ---- 材料 ----
	materials.clear()
	var mats: Dictionary = data.get("materials", {})
	for m in mats:
		materials[String(m)] = clampi(int(mats[m]), 0, MAX_STAT_CAP)
	# ---- 家具 ----
	furniture_levels = (data.get("furniture", {}) as Dictionary).duplicate()
	_recalc_furniture_bonus()
	# ---- 菜地 ----
	farm_plots.clear()
	for p in (data.get("farm_plots", []) as Array):
		var d: Dictionary = p
		farm_plots.append({
			"state": clampi(int(d.get("state", 0)), 0, 2),
			"remain": maxf(0.0, float(d.get("remain", 0.0))),
			"seed": String(d.get("seed", "")),
		})
	farm_fertility.clear()
	for v in (data.get("farm_fertility", []) as Array):
		farm_fertility.append(clampi(int(v), 0, 3))
	# ---- 装备 ----
	gear_upgrades = (data.get("gear_upgrades", {}) as Dictionary).duplicate()
	gear_affixes = (data.get("gear_affixes", {}) as Dictionary).duplicate(true)
	owned_gear.clear()
	for rid in (data.get("owned_gear", []) as Array):
		var ga: Dictionary = gear_affixes.get(String(rid), {})
		var item := _create_gear_from_recipe(String(rid),
			ga.get("affixes", []) as Array, int(ga.get("tier", 0)))
		if item != null:
			owned_gear[String(rid)] = item
	equipped_items.clear()
	var eq: Dictionary = data.get("equipped", {})
	for t_str in eq:
		var entry: Dictionary = eq[t_str]
		var t := int(String(t_str))
		if entry.has("res"):
			var res = load(String(entry["res"]))
			if res is EquipmentData:
				equipped_items[t] = res
		elif entry.has("gear"):
			var gid := String(entry["gear"])
			if owned_gear.has(gid):
				equipped_items[t] = owned_gear[gid]
	# ---- 采集/进度/设置 ----
	gather_tool_tier = clampi(int(data.get("gather_tool_tier", 0)), 0, GATHER_TOOLS.size() - 1)
	cleared_stages = (data.get("cleared_stages", {}) as Dictionary).duplicate()
	opened_chests.assign((data.get("opened_chests", []) as Array))
	pity_counter = (data.get("pity_counter", {}) as Dictionary).duplicate()
	harvested_nodes = (data.get("harvested_nodes", {}) as Dictionary).duplicate()
	tutorial_seen = (data.get("tutorial_seen", {}) as Dictionary).duplicate()
	settings.merge((data.get("settings", {}) as Dictionary).duplicate(), true)
	played_intro_scripts.assign((data.get("played_intro", []) as Array))
	codex_unlocked.assign((data.get("codex", []) as Array))
	achievements_unlocked.assign((data.get("achievements", []) as Array))
	kill_count = int(data.get("kill_count", 0))
	reincarnation_count = clampi(int(data.get("reincarnation", 0)), 0, ReincarnationData.MAX_CYCLES)
	day_time = clampf(float(data.get("day_time", 0.0)), 0.0, DAY_LENGTH)
	# ---- 技能分支 ----
	unlocked_branches.assign((data.get("unlocked_branches", []) as Array))
	skill_branches = (data.get("skill_branches", {}) as Dictionary).duplicate()
	# ---- 药水库存 ----
	potions = (data.get("potions", {}) as Dictionary).duplicate()
	# ---- 当前血量按存档恢复 ----
	hp = clampi(int(data.get("hp", get_max_hp())), 1, get_max_hp())
	bp = clampi(int(data.get("bp", get_max_bp())), 0, get_max_bp())
	current_shield = clampi(int(data.get("shield", get_max_shield())), 0, get_max_shield())
	combo_count = 0
	is_dying = false
	# ---- 应用设置 ----
	apply_audio_settings()
	apply_resolution()
	apply_vn_speed()
	game_loaded.emit()
	print("💾 [存档] 读取成功：Lv.%d / $%d / 通关 %d 关" % [current_level, gold, cleared_stages.size()])
	return true

func delete_save() -> bool:
	if not has_save(): return false
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if err != OK:
		DirAccess.remove_absolute(SAVE_PATH)
	print("💾 [存档] 存档已删除")
	return true

## 存档摘要（UI 展示用）
func get_save_summary() -> String:
	var data := build_save_data()
	return "Lv.%d  $%d  通关 %d/15 关  %s" % [
		int(data["level"]), int(data["gold"]), cleared_stages.size(), String(data["saved_at"])
	]

# ================= v1.8 福瑞勇者助战 =================

## 盟约石碑召唤：助战 60 秒（切换关卡后消失），同时只能存在一名
const COMPANION_DEFS := {
	"xuexiao": {"name": "雪枭霰", "attack": 4, "duration": 60.0, "color": Color(0.75, 0.85, 0.95),
		"cost": {"gold": 200, "mats": {"霜华": 2}}, "desc": "霜峰巡夜的雪枭，翎羽如刃",
		"portrait": "res://assets/textures/characters/ally/ally_xuexiao.png"},
	"yanpan": {"name": "岩羊磐", "attack": 6, "duration": 60.0, "color": Color(0.55, 0.5, 0.45),
		"cost": {"gold": 350, "mats": {"黑铁锭": 2}}, "desc": "山道上的岩羊，犄角能撞碎甲壳",
		"portrait": "res://assets/textures/characters/ally/ally_yanpan.png"},
	"yanli": {"name": "赤狐焰璃", "attack": 8, "duration": 60.0, "color": Color(0.9, 0.45, 0.25),
		"cost": {"gold": 600, "mats": {"赤金锭": 2, "晶髓": 2}}, "desc": "沙漠里的赤狐，尾焰过处草木焦枯",
		"portrait": "res://assets/textures/characters/ally/ally_yanli.png"},
	"shuixi": {"name": "水獭汐", "attack": 5, "duration": 60.0, "color": Color(0.4, 0.65, 0.8),
		"cost": {"gold": 450, "mats": {"血玉": 1}}, "desc": "绿洲的水獭，浪里来去无踪",
		"portrait": "res://assets/textures/characters/ally/ally_shuixi.png"},
}

var active_companion: Node = null

func get_companion_def(cid: String) -> Dictionary:
	return COMPANION_DEFS.get(cid, {})

## 召唤助战勇者（替换当前助战；返回是否成功）
func summon_companion(cid: String) -> bool:
	var d := get_companion_def(cid)
	if d.is_empty(): return false
	var cost: Dictionary = d["cost"]
	if gold < int(cost["gold"]): return false
	var mats: Dictionary = cost["mats"]
	for m in mats:
		if count_material(m) < int(mats[m]): return false
	var cur := get_tree().current_scene
	if cur == null: return false
	var player := get_tree().get_first_node_in_group("player")
	# 扣费
	spend_gold(int(cost["gold"]))
	for m in mats:
		remove_material(m, int(mats[m]))
	# 替换旧助战
	dismiss_companion()
	var c = load("res://entities/companion/companion.gd").new()
	c.setup(d)
	c.position = player.global_position + Vector2(-60, 0) if player != null else Vector2.ZERO
	cur.add_child(c)
	active_companion = c
	print("🐾 [助战] %s 降临！（%.0f 秒）" % [String(d["name"]), float(d["duration"])])
	unlock_achievement("companion")
	return true

func dismiss_companion() -> void:
	if active_companion != null and is_instance_valid(active_companion):
		active_companion.queue_free()
	active_companion = null

func has_active_companion() -> bool:
	return active_companion != null and is_instance_valid(active_companion)

# ================= v1.9 图鉴 =================

## 解锁敌人图鉴条目；返回是否为首次解锁（已解锁过返回 false）
func unlock_codex(entity_name: String) -> bool:
	if entity_name == "" or entity_name in codex_unlocked:
		return false
	codex_unlocked.append(entity_name)
	if codex_unlocked.size() >= 5: unlock_achievement("codex_5")
	if codex_unlocked.size() >= CodexData.total(): unlock_achievement("codex_all")
	return true

func is_codex_unlocked(entity_name: String) -> bool:
	return entity_name in codex_unlocked

func codex_progress() -> Dictionary:
	return {"unlocked": codex_unlocked.size(), "total": CodexData.total()}

# ================= v1.10 成就系统 =================

## 解锁成就（幂等）；返回是否首次解锁
func unlock_achievement(id: String) -> bool:
	if id == "" or id in achievements_unlocked:
		return false
	if not AchievementData.ENTRIES.has(id):
		return false
	achievements_unlocked.append(id)
	print("🏆 [成就] 「%s」已解锁" % String(AchievementData.ENTRIES[id]["name"]))
	return true

func is_achievement_unlocked(id: String) -> bool:
	return id in achievements_unlocked

func achievement_progress() -> Dictionary:
	return {"unlocked": achievements_unlocked.size(), "total": AchievementData.total()}

## 敌人死亡时调用：累计击杀 + 战斗类成就判断
func register_kill(entity_name: String) -> void:
	kill_count += 1
	unlock_achievement("first_blood")
	if kill_count >= 10: unlock_achievement("kill_10")
	if kill_count >= 50: unlock_achievement("kill_50")
	match entity_name:
		"吞碑者": unlock_achievement("boss_1")
		"荆棘之母": unlock_achievement("boss_2")
		"沙暴之核": unlock_achievement("boss_3")
		"回响之冠": unlock_achievement("boss_4")

## 章节通关成就判断（mark_stage_cleared 调用）
func _check_stage_achievements() -> void:
	var ch1 := ["ch1_1", "ch1_2", "ch1_3", "ch1_4", "ch1_5"]
	var ch2 := ["ch2_1", "ch2_2", "ch2_3", "ch2_4", "ch2_5"]
	var ch3 := ["ch3_1", "ch3_2", "ch3_3", "ch3_4", "ch3_5"]
	if are_stages_cleared(ch1): unlock_achievement("chapter1")
	if are_stages_cleared(ch2): unlock_achievement("chapter2")
	if are_stages_cleared(ch3): unlock_achievement("chapter3")
	if are_stages_cleared(ch1 + ch2 + ch3): unlock_achievement("all_clear")

# ================= v1.5 技能分支 =================

## 每个技能：1 个免费基础分支 + 2 个分支（卡牌等级解锁：Lv.3 首个 / Lv.5 第二个；解锁消耗 1 点 BP）
## mods 字段：damage_mult（伤害倍率修正）/ cooldown_mult / shots（弹数）/
## fireball_scale（火球体积）/ heal_mult / heal_flat_add / heals（治疗段数，迅愈=2）/
## heal_delay（治疗段间隔秒数，迅愈=1.0）/ shield_buff（治疗附带护盾）
const BRANCH_UNLOCK_COST_BP := 1     # 解锁一个分支消耗的 BP
const SKILL_BRANCHES := {
	"fireball": [
		{"id": "base", "name": "基础火球", "desc": "标准单体法术。", "cost": 0, "req_level": 0, "mods": {}},
		{"id": "lianzhu", "name": "连珠火弹", "desc": "一次射出两发同向火球，重叠出现在身前；每发伤害 60%，第二发延迟 0.2 秒射出，冷却降至 80%。", "cost": 1, "req_level": 3,
		 "mods": {"damage_mult": 0.6, "cooldown_mult": 0.8, "shots": 2, "shot_delay": 0.2}},
		{"id": "baoyan", "name": "爆炎术", "desc": "火球体积为基础火球的两倍，每一发伤害翻倍，冷却延长至 1.5 倍；施法与发射操作与基础火球相同。", "cost": 1, "req_level": 5,
		 "mods": {"damage_mult": 2.0, "cooldown_mult": 1.5, "fireball_scale": 2.0}},
	],
	"heal": [
		{"id": "base", "name": "基础治疗", "desc": "标准恢复法术。", "cost": 0, "req_level": 0, "mods": {}},
		{"id": "xunyu", "name": "迅愈", "desc": "冷却缩短至基础治疗的三分之二；每次施放释放两次治疗（间隔 1 秒），每次回复基础治疗的 60%（总计 120%）。", "cost": 1, "req_level": 3,
		 "mods": {"heal_mult": 0.6, "cooldown_mult": 2.0 / 3.0, "heals": 2, "heal_delay": 1.0}},
		{"id": "tiebi", "name": "铁壁润泽", "desc": "治疗量降为基础治疗的 80%；施放后 8 秒内护盾上限 +2 并立即获得 2 点护盾。效果结束时护盾上限 -2、护盾值 -2（不足 2 点则直接归零，不会扣血）。", "cost": 1, "req_level": 5,
		 "mods": {"heal_mult": 0.8, "shield_buff": {"duration": 8.0, "potence": 2, "shield_gain": 2, "drain_on_expire": true}}},
	],
}

var unlocked_branches: Array = []              # ["fireball:lianzhu", ...] 已解锁
var skill_branches: Dictionary = {}            # {skill_id: branch_id} 当前装备的分支（缺省 = base）

func get_branches_of(skill_id: String) -> Array:
	return SKILL_BRANCHES.get(skill_id, [])

func get_branch(skill_id: String, branch_id: String) -> Dictionary:
	for b in get_branches_of(skill_id):
		if String(b["id"]) == branch_id: return b
	return {}

## 当前装备分支的修正字典（cast 时读取；基础分支返回空字典）
func get_branch_mods(skill_id: String) -> Dictionary:
	var bid := String(skill_branches.get(skill_id, "base"))
	if bid == "" or bid == "base": return {}
	var b := get_branch(skill_id, bid)
	if b.is_empty(): return {}
	return b["mods"]

func is_branch_unlocked(skill_id: String, branch_id: String) -> bool:
	if branch_id == "base": return true
	return unlocked_branches.has("%s:%s" % [skill_id, branch_id])

## 分支解锁所需卡牌等级（基础分支为 0）
func get_branch_req_level(skill_id: String, branch_id: String) -> int:
	var b := get_branch(skill_id, branch_id)
	return int(b.get("req_level", 0))

## 不能解锁的原因；空字符串 = 可以解锁（UI 据此决定按钮亮/灰）
func branch_unlock_block_reason(skill_id: String, branch_id: String) -> String:
	if is_branch_unlocked(skill_id, branch_id): return "该分支已解锁"
	var b := get_branch(skill_id, branch_id)
	if b.is_empty(): return "分支数据缺失"
	var req := get_branch_req_level(skill_id, branch_id)
	if get_card_level(skill_id) < req:
		return "卡牌需 Lv.%d 才能解锁（当前 Lv.%d）" % [req, get_card_level(skill_id)]
	if bp < BRANCH_UNLOCK_COST_BP:
		return "BP 不足（解锁需 %d 点，当前 %d）" % [BRANCH_UNLOCK_COST_BP, bp]
	return ""

## v1.16 解锁分支：卡牌等级达标 + 消耗 1 点 BP；解锁后不自动选中（由玩家点"使用"切换）
func unlock_branch(skill_id: String, branch_id: String) -> bool:
	var reason := branch_unlock_block_reason(skill_id, branch_id)
	if reason != "":
		print("⚠️ [技能分支] %s" % reason)
		return false
	bp = maxi(0, bp - BRANCH_UNLOCK_COST_BP)
	unlocked_branches.append("%s:%s" % [skill_id, branch_id])
	print("🌿 [技能分支] 解锁 %s / %s（消耗 %d BP，剩余 %d）" % [skill_id, branch_id, BRANCH_UNLOCK_COST_BP, bp])
	unlock_achievement("skill")
	return true

func select_branch(skill_id: String, branch_id: String) -> bool:
	if not is_branch_unlocked(skill_id, branch_id): return false
	if get_branch(skill_id, branch_id).is_empty(): return false
	skill_branches[skill_id] = branch_id
	return true
