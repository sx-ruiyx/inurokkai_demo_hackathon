extends Control
class_name UIBagPanelSkill

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # v1.16 背包暂停时消耗条照常刷新（与 GameState 同一时钟）

var manager
var skill_slot_cards: Array[int] = [-1, -1, -1, -1]
var extra_slot_labels: Array[Label] = []
var extra_slot_panels: Array[Panel] = []

var bag_detail_panel: Panel
var bag_name_label: Label
var bag_type_label: Label
var bag_attr_label: Label
var bag_desc_label: Label
var bag_level_label: Label
var _branch_box: VBoxContainer
var _branch_btn_refs: Array = []   # v1.17 [{btn, skill_id, bid}] 供 BP 变化时原地刷新按钮状态
var _last_index: int = -1
var btn_upgrade: Button          # 🌿 技能分支（折叠开关，位于分支按钮列正上方）
var btn_card_upgrade: Button     # v1.15 升级按钮（面板右上角）
var on_slot_changed: Callable

# v1.15 消耗条（BP）：与战斗 HUD BP 条同款组件，同步 GameState，放升级按钮左侧
var cost_bar: HealthBar
var cost_regen_label: Label
var _last_seen_bp: int = -999

func setup(mgr, cb_slot_changed: Callable) -> void:
	manager = mgr
	on_slot_changed = cb_slot_changed
	_build_ui()

func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0; anchor_bottom = 1.0
	offset_left = 464.0; offset_right = -manager.HUD_MARGIN
	offset_top = manager.HUD_MARGIN + 44.0; offset_bottom = -manager.HUD_MARGIN

	bag_detail_panel = Panel.new()
	bag_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag_detail_panel.anchor_right = 1.0; bag_detail_panel.anchor_bottom = 1.0
	bag_detail_panel.offset_top = 0.0; bag_detail_panel.offset_bottom = -186.0
	bag_detail_panel.add_theme_stylebox_override("panel", manager._make_style(manager.COL_PANEL_WHITE, Color(0.55, 0.55, 0.58), 1))
	add_child(bag_detail_panel)

	btn_upgrade = Button.new()
	btn_upgrade.text = "🌿 技能分支"
	btn_upgrade.custom_minimum_size = Vector2(130, 44)
	# v1.15 改为放入 vbox 流式布局（分支按钮列正上方、右对齐），
	# 不再锚定面板右下角 —— 修复与第三行"解锁"按钮重叠成"阴影"的问题
	btn_upgrade.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn_upgrade.visible = false
	UITextBox.apply_basic(btn_upgrade, "bold", 18, 0)
	# 分支区折叠开关（构建时连一次，避免重复连接叠加）
	btn_upgrade.pressed.connect(func():
		if _branch_box != null:
			_branch_box.visible = not _branch_box.visible
	)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.anchor_right = 1.0; vbox.anchor_bottom = 1.0
	vbox.offset_left = 24; vbox.offset_top = 40; vbox.offset_right = -24; vbox.offset_bottom = -16
	bag_detail_panel.add_child(vbox)

	bag_name_label = _detail_label(vbox, "（把鼠标移到左侧格子上查看属性）", 30, manager.COL_TEXT_DARK)
	bag_type_label = _detail_label(vbox, "", 15, Color(0.40, 0.41, 0.45))
	bag_attr_label = _detail_label(vbox, "", 16, Color(0.18, 0.30, 0.52))
	bag_desc_label = _detail_label(vbox, "", 14, Color(0.40, 0.41, 0.45))
	bag_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bag_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bag_level_label = _detail_label(vbox, "", 17, manager.COL_TEXT_DARK)

	# v1.15 技能分支折叠按钮：进入 vbox 流式布局，右对齐，
	# 位于下方分支按钮列（使用中/使用/解锁）正上方，与其上下对齐
	vbox.add_child(btn_upgrade)

	# v1.15 卡牌升级按钮：面板右上角（蓝框位置），与技能分支按钮同尺寸(130×44)、
	# 右边缘同为 -24，两按钮上下对齐成一列
	btn_card_upgrade = Button.new()
	btn_card_upgrade.text = "升级"
	btn_card_upgrade.custom_minimum_size = Vector2(130, 44)
	btn_card_upgrade.anchor_left = 1.0; btn_card_upgrade.anchor_right = 1.0
	btn_card_upgrade.anchor_top = 0.0; btn_card_upgrade.anchor_bottom = 0.0
	btn_card_upgrade.offset_left = -154.0; btn_card_upgrade.offset_right = -24.0
	btn_card_upgrade.offset_top = 28.0; btn_card_upgrade.offset_bottom = 72.0
	btn_card_upgrade.disabled = true
	btn_card_upgrade.visible = false   # v1.15 未选中卡牌前隐藏（选中后显示）
	UITextBox.apply_basic(btn_card_upgrade, "bold", 18, 0)
	btn_card_upgrade.pressed.connect(_on_card_upgrade)
	bag_detail_panel.add_child(btn_card_upgrade)

	_build_cost_bar()

	# v1.5 技能分支区（仅技能卡显示）
	_branch_box = VBoxContainer.new()
	_branch_box.add_theme_constant_override("separation", 6)
	_branch_box.visible = false
	vbox.add_child(_branch_box)

	var slot_row := HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	slot_row.add_theme_constant_override("separation", 14)
	slot_row.anchor_top = 1.0; slot_row.anchor_bottom = 1.0
	slot_row.anchor_right = 1.0
	slot_row.offset_top = -174.0; slot_row.offset_bottom = -12.0
	slot_row.offset_right = -152.0
	add_child(slot_row)

	for i in 4:
		var slot := UIBackpack.DropSlotPanel.new()
		slot.slot_index = i
		slot.custom_minimum_size = Vector2(96, 150)
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.drop_cb = _on_slot_drop
		slot.click_cb = _on_slot_click
		slot.dbl_click_cb = _on_slot_dbl_click
		slot.add_theme_stylebox_override("panel", manager._make_style(Color(0.10, 0.10, 0.13, 0.9), Color(0.70, 0.72, 0.80, 0.45), 1))
		var l := Label.new()
		l.text = "卡槽\n（拖入卡牌）"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.anchor_right = 1.0; l.anchor_bottom = 1.0
		l.add_theme_color_override("font_color", manager.COL_TEXT_DIM)
		UITextBox.apply_basic(l, "normal", 14, 0)
		slot.add_child(l)
		slot_row.add_child(slot)
		extra_slot_labels.append(l)
		extra_slot_panels.append(slot)

func refresh_slots() -> void:
	for i in 4:
		var idx = skill_slot_cards[i]
		var slot := extra_slot_panels[i]
		if idx >= 0 and idx < manager._all_cards().size():
			var c = manager._all_cards()[idx]
			var col = manager.COL_CELL_BY_TYPE.get(str(c["type"]), manager.COL_GRID_CELL)
			extra_slot_labels[i].text = "%s\nLv.%d" % [c["name"], int(c.get("level", 1))]
			extra_slot_labels[i].add_theme_color_override("font_color", manager.COL_TEXT_DARK)
			slot.add_theme_stylebox_override("panel", manager._make_style(col.lightened(0.1), manager.COL_ACCENT, 2))
		else:
			extra_slot_labels[i].text = "卡槽\n（拖入卡牌）"
			extra_slot_labels[i].add_theme_color_override("font_color", manager.COL_TEXT_DIM)
			slot.add_theme_stylebox_override("panel", manager._make_style(Color(0.10, 0.10, 0.13, 0.9), Color(0.70, 0.72, 0.80, 0.45), 1))

func _on_slot_drop(slot_i: int, card_index: int) -> void:
	if card_index < 0 or card_index >= manager._all_cards().size(): return
	if str(manager._all_cards()[card_index]["type"]) != "技能": return
	if skill_slot_cards.has(card_index): return
	if skill_slot_cards[slot_i] >= 0: return
	skill_slot_cards[slot_i] = card_index
	refresh_slots()
	manager.persist_card_state()
	if on_slot_changed.is_valid(): on_slot_changed.call()

func _on_slot_click(slot_i: int) -> void:
	# v1.15 单击卡槽：查看卡牌属性（卸下改为双击，防误触）
	if skill_slot_cards[slot_i] < 0: return
	show_detail(skill_slot_cards[slot_i])

## v1.15 双击卡槽：卸下卡牌（原单击卸下逻辑）
func _on_slot_dbl_click(slot_i: int) -> void:
	if skill_slot_cards[slot_i] < 0: return
	skill_slot_cards[slot_i] = -1
	refresh_slots()
	manager.persist_card_state()
	if on_slot_changed.is_valid(): on_slot_changed.call()

func show_detail(index: int) -> void:
	_last_index = index
	_branch_btn_refs.clear()   # v1.17 旧按钮即将释放，引用表同步清空
	_branch_box.visible = false
	for c in _branch_box.get_children():
		_branch_box.remove_child(c)
		c.queue_free()
	btn_upgrade.visible = false
	_refresh_card_upgrade_btn()
	if index < 0 or index >= manager._all_cards().size():
		bag_name_label.text = "（把鼠标移到左侧格子上查看属性）"
		bag_type_label.text = ""; bag_level_label.text = ""; bag_attr_label.text = ""; bag_desc_label.text = ""
		# v1.15 未选中：隐藏消耗条与升级按钮（占位文字已说明操作）
		if cost_bar: cost_bar.visible = false
		btn_card_upgrade.visible = false
		return
	var c = manager._all_cards()[index]
	# v1.15 选中卡牌：显示消耗条与升级按钮
	if cost_bar: cost_bar.visible = true
	btn_card_upgrade.visible = true
	bag_name_label.text = str(c["name"]) + ("  ★已装备" if c["is_equipped"] else "")
	bag_type_label.text = "类型：%s" % c["type"]
	bag_desc_label.text = str(c.get("desc", ""))
	var lines: Array[String] = []
	if int(c.get("attack", 0)) != 0: lines.append("攻击力 +%d" % int(c["attack"]))
	if int(c.get("shield", 0)) != 0: lines.append("护盾 +%d" % int(c["shield"]))
	bag_attr_label.text = "\n".join(lines) if not lines.is_empty() else "（无附加属性）"
	bag_level_label.text = "当前等级：Lv.%d/%d" % [int(c.get("level", 1)), GameState.get_card_max_level()]
	# 技能卡：显示数值 + 分支界面
	if str(c["type"]) == "技能":
		_show_skill_detail(c)
		return
	var res = c.get("res")
	if res is EquipmentData:
		var txt := "攻击 +%d  生命 +%d  护盾 +%d" % [res.attack_bonus, res.hp_bonus, res.shield_bonus]
		# v1.10 词缀：品阶前缀 + 词缀清单（加成已计入上面的数值）
		if res.tier > 0 or (res.affixes != null and res.affixes.size() > 0):
			txt = "[%s] %s" % [AffixData.tier_name(res.tier), txt]
		if res.affixes != null and res.affixes.size() > 0:
			var names := ""
			for a in res.affixes:
				names += "✦ %s\n" % AffixData.affix_label(String(a))
			txt += "\n" + names.strip_edges()
		bag_attr_label.text = txt

## v1.5 技能详情：基础数值 + 分支解锁/装备
func _show_skill_detail(c: Dictionary) -> void:
	var res = c.get("res")
	if not (res is SkillData):
		bag_attr_label.text = "（技能数据异常）"
		return
	var skill_id := String(res.skill_id)
	if skill_id == "":
		skill_id = str(c.get("base_id", ""))
	var mods: Dictionary = GameState.get_branch_mods(skill_id)
	var cur_bid := String(GameState.skill_branches.get(skill_id, "base"))
	var cur_name := "基础"
	for b in GameState.get_branches_of(skill_id):
		if String(b["id"]) == cur_bid: cur_name = String(b["name"])
	# 基础数值行
	var base_text := "BP 消耗 %d   冷却 %.1fs" % [int(res.cost_bp), float(res.cooldown)]
	if float(res.damage_multiplier) > 0.0:
		base_text += "   伤害 ×%.1f" % float(res.damage_multiplier)
	if float(res.heal_percent) > 0.0 or int(res.heal_flat) > 0:
		base_text += "   治疗 %d%%+%d" % [int(float(res.heal_percent) * 100), int(res.heal_flat)]
	bag_attr_label.text = base_text
	# v1.17 治疗技能（妙手回春）的等级倍率显示"回血倍率"，攻击技能仍为"伤害倍率"
	var is_heal_skill := float(res.heal_percent) > 0.0 or int(res.heal_flat) > 0
	var mult_word := "回血倍率" if is_heal_skill else "伤害倍率"
	bag_level_label.text = "当前分支：%s    Lv.%d/%d ｜ %s ×%.1f" % [
		cur_name, GameState.get_card_level(skill_id),
		GameState.get_card_max_level(), mult_word, GameState.get_card_level_multiplier(skill_id)]

	# 分支列表
	_branch_box.visible = true
	btn_upgrade.visible = true
	var sp_label := Label.new()
	sp_label.text = "── 技能分支（Lv.3 解锁第 1 个 · Lv.5 解锁第 2 个，每次消耗 1 点 BP）──"
	sp_label.add_theme_color_override("font_color", manager.COL_ACCENT)
	sp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITextBox.apply_basic(sp_label, "bold", 14, 0)
	_branch_box.add_child(sp_label)
	for b in GameState.get_branches_of(skill_id):
		var bid := String(b["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 34)
		var name_l := Label.new()
		var unlocked := GameState.is_branch_unlocked(skill_id, bid)
		var selected := cur_bid == bid
		name_l.text = "%s%s" % [String(b["name"]), " ✓" if selected else ""]
		name_l.custom_minimum_size = Vector2(150, 0)
		name_l.add_theme_color_override("font_color", manager.COL_TEXT_DARK if unlocked else manager.COL_TEXT_DIM)
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UITextBox.apply_basic(name_l, "bold" if selected else "normal", 14, 0)
		row.add_child(name_l)
		var desc_l := Label.new()
		desc_l.text = String(b["desc"])
		desc_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_l.add_theme_color_override("font_color", manager.COL_TEXT_DIM)
		desc_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITextBox.apply_basic(desc_l, "normal", 12, 0)
		row.add_child(desc_l)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(110, 30)
		_apply_branch_btn_state(btn, skill_id, bid)
		# v1.17 登记引用：BP/等级变化时 _process 原地刷新按钮状态（不重建盒子，
		# 防止连点时按钮被释放吞掉点击 —— 修复"连点升级后 BP 回满仍灰着无法解锁"）
		_branch_btn_refs.append({"btn": btn, "skill_id": skill_id, "bid": bid})
		# v1.17 点击时读实时状态（不依赖闭包捕获），防原地刷新后状态与捕获值不一致
		btn.pressed.connect(func():
			if String(GameState.skill_branches.get(skill_id, "base")) == bid:
				return
			if GameState.is_branch_unlocked(skill_id, bid):
				GameState.select_branch(skill_id, bid)
			else:
				GameState.unlock_branch(skill_id, bid)
			show_detail(_last_index)
		)
		UITextBox.apply_basic(btn, "normal", 13, 0)
		row.add_child(btn)
		_branch_box.add_child(row)

## v1.17 分支按钮三态统一入口：构建与运行期刷新共用，保证状态永远与 GameState 一致
## 1) 使用中（当前分支）：灰、禁用  2) 已解锁未选中：亮绿"使用"  3) 未解锁：达标亮绿/否则灰"解锁（1 点）"
func _apply_branch_btn_state(btn: Button, skill_id: String, bid: String) -> void:
	if not is_instance_valid(btn):
		return
	var cur_bid := String(GameState.skill_branches.get(skill_id, "base"))
	var unlocked := GameState.is_branch_unlocked(skill_id, bid)
	if cur_bid == bid:
		# 使用中：灰底、禁用（当前生效分支）
		btn.text = "使用中"
		btn.disabled = true
		btn.tooltip_text = "当前生效分支"
		_style_branch_btn(btn, false)
	elif unlocked:
		# 已解锁未选中：亮起"使用"，点击切换为该分支
		btn.text = "使用"
		btn.disabled = false
		btn.tooltip_text = "切换为「%s」" % _branch_name(skill_id, bid)
		_style_branch_btn(btn, true)
	else:
		# 未解锁：达到等级且 BP 足够则亮起，否则灰
		var reason := GameState.branch_unlock_block_reason(skill_id, bid)
		var can_unlock := reason == ""
		btn.text = "解锁（1 点）"
		btn.disabled = not can_unlock
		_style_branch_btn_btn_safe(btn, can_unlock)
		btn.tooltip_text = reason if not can_unlock else "解锁「%s」（消耗 1 点 BP）" % _branch_name(skill_id, bid)

func _branch_name(skill_id: String, bid: String) -> String:
	for b in GameState.get_branches_of(skill_id):
		if String(b["id"]) == bid: return String(b["name"])
	return bid

## 防御：btn 可能已被 queue_free（引用表滞后一帧），跳过即可
func _style_branch_btn_btn_safe(btn: Button, lit: bool) -> void:
	_style_branch_btn(btn, lit)

## v1.16 分支按钮样式：lit=true 亮绿（可点），false 暗灰（禁用/使用中）
## 注意：disabled 按钮画的是 "disabled" 样式盒而非 "normal"，两者都要覆盖，
## 否则默认浅灰 disabled 底 + 浅灰字 = 文字"消失"（v1.16 修复）
func _style_branch_btn(btn: Button, lit: bool) -> void:
	if lit:
		btn.add_theme_stylebox_override("normal",
			manager._make_style(Color(0.20, 0.60, 0.28), Color(0.45, 0.95, 0.55), 2))
		btn.add_theme_stylebox_override("hover",
			manager._make_style(Color(0.27, 0.72, 0.36), Color(0.65, 1.0, 0.7), 2))
		btn.add_theme_stylebox_override("pressed",
			manager._make_style(Color(0.14, 0.46, 0.22), Color(0.45, 0.95, 0.55), 2))
		btn.add_theme_color_override("font_color", Color(0.92, 1.0, 0.92))
		btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		btn.add_theme_color_override("font_disabled_color", Color(0.92, 1.0, 0.92))
	else:
		var gray: StyleBoxFlat = manager._make_style(Color(0.30, 0.30, 0.33), Color(0.45, 0.45, 0.48), 1)
		btn.add_theme_stylebox_override("normal", gray)
		btn.add_theme_stylebox_override("hover", gray)
		btn.add_theme_stylebox_override("pressed", gray)
		btn.add_theme_stylebox_override("disabled", gray)   # v1.16 关键：禁用态同样用暗灰底
		btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		btn.add_theme_color_override("font_disabled_color", Color(0.85, 0.85, 0.85))

## v1.15 消耗条（BP）：与战斗 HUD BP 条同款 HealthBar（绿色 + star 标志 + 充能），
## 放升级按钮左侧（红框位置）；样式按需求改动：数字条内居中、右侧标志下调到条中线
func _build_cost_bar() -> void:
	cost_bar = HealthBar.new()
	cost_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_bar.setup(false, manager.COL_BP, false, true, "star", 14, 10.0)
	cost_bar.num_centered = true   # 数字在条中居中
	cost_bar.icon_mid = true       # 标志垂直对齐条中线
	cost_bar.flat_style = true     # v1.15 扁平水平矩形样式（参考图状态）
	cost_bar.icon_left = true      # v1.15 star 标志平移到条左侧
	cost_bar.custom_minimum_size = manager.BAR_SIZE * 0.5   # 120×20，同 HUD BP 条
	cost_bar.anchor_left = 1.0; cost_bar.anchor_right = 1.0
	cost_bar.anchor_top = 0.0; cost_bar.anchor_bottom = 0.0
	cost_bar.offset_left = -292.0; cost_bar.offset_right = -172.0   # 升级按钮（-154）左侧，间隔 18
	cost_bar.offset_top = 40.0; cost_bar.offset_bottom = 60.0       # 垂直中心 50 = 升级按钮中心
	bag_detail_panel.add_child(cost_bar)
	cost_bar.visible = false   # v1.15 未选中卡牌前隐藏（选中后显示）

	# BP 回复倒计时（与 HUD 同款功能）
	cost_regen_label = Label.new()
	# v1.16 数字居中，倒计时放条内右侧（不再与数字重叠）；白字黑描边保证在绿条上可读
	cost_regen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_regen_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_regen_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	UITextBox.apply_basic(cost_regen_label, "number", 11)
	cost_regen_label.visible = false
	cost_regen_label.position = Vector2(cost_bar.size.x - 54.0, 0)
	cost_regen_label.size = Vector2(48, cost_bar.size.y)
	cost_bar.add_child(cost_regen_label)
	_refresh_cost_bar()

func _refresh_cost_bar() -> void:
	if cost_bar == null or manager == null or manager.game_state == null: return
	var gs = manager.game_state
	var cur: int = int(gs.get("bp"))
	var mx: int = int(gs.get_max_bp())
	cost_bar.update_health(cur, mx)
	if cur < mx:
		var prog: float = float(gs.get("bp_regen_progress"))
		cost_bar.set_charge_ratio((float(cur) + clampf(prog, 0.0, 1.0)) / float(mx))
		if cost_regen_label:
			cost_regen_label.visible = true
			var time_left: float = float(gs.get("bp_regen_interval")) - float(gs.get("bp_regen_timer"))
			cost_regen_label.text = "(-%.1fs)" % maxf(0.0, time_left)
	else:
		cost_bar.set_charge_ratio(0.0)
		if cost_regen_label: cost_regen_label.visible = false

## v1.15 消耗条每帧刷新（与 HUD BP 条同数据源 GameState.bp/bp_regen_progress，
## 回复进度实时走动、升级扣费立即反映）；升级按钮只在 BP 整数变化时刷新
func _process(_delta: float) -> void:
	if manager == null or manager.game_state == null: return
	_refresh_cost_bar()
	var cur_bp: int = int(manager.game_state.get("bp"))
	if _last_seen_bp != cur_bp:
		_last_seen_bp = cur_bp
		_refresh_card_upgrade_btn()
		# v1.17 BP 整数变化时同步刷新分支按钮（解锁/升级都扣 BP），
		# 修复连点升级把 BP 烧空后、BP 回满按钮仍停留在灰色禁用态的 bug
		_refresh_branch_btns()

## v1.17 原地刷新分支按钮三态（不重建 _branch_box，鼠标下的按钮不会被释放）
func _refresh_branch_btns() -> void:
	for r in _branch_btn_refs:
		if r is Dictionary and is_instance_valid(r.get("btn")):
			_apply_branch_btn_state(r["btn"], String(r["skill_id"]), String(r["bid"]))

## v1.15 升级按钮状态：由 GameState.upgrade_block_reason 决定（满级 / BP 不足 / 未选中）
func _refresh_card_upgrade_btn() -> void:
	if btn_card_upgrade == null: return
	if _last_index < 0 or _last_index >= manager._all_cards().size():
		_apply_upgrade_btn_style(false)
		btn_card_upgrade.disabled = true
		btn_card_upgrade.text = "升级"
		btn_card_upgrade.tooltip_text = "先在左侧选中一张卡牌"
		return
	var c = manager._all_cards()[_last_index]
	var bid := str(c.get("base_id", ""))
	var reason: String = GameState.upgrade_block_reason(bid)
	if reason == "":
		btn_card_upgrade.disabled = false
		btn_card_upgrade.text = "升级"
		btn_card_upgrade.tooltip_text = GameState.get_upgrade_cost_text(bid)
		_apply_upgrade_btn_style(true)
	else:
		btn_card_upgrade.disabled = true
		btn_card_upgrade.text = "已满级" if GameState.is_card_max_level(bid) else "升级"
		btn_card_upgrade.tooltip_text = reason
		_apply_upgrade_btn_style(false)

## 可用 = 醒目绿色按钮；不可用 = 暗灰（旧最终版同款配色）
func _apply_upgrade_btn_style(can: bool) -> void:
	if can:
		btn_card_upgrade.add_theme_stylebox_override("normal",
			manager._make_style(Color(0.20, 0.60, 0.28), Color(0.45, 0.95, 0.55), 2))
		btn_card_upgrade.add_theme_stylebox_override("hover",
			manager._make_style(Color(0.27, 0.72, 0.36), Color(0.65, 1.0, 0.7), 2))
		btn_card_upgrade.add_theme_stylebox_override("pressed",
			manager._make_style(Color(0.14, 0.46, 0.22), Color(0.45, 0.95, 0.55), 2))
		btn_card_upgrade.add_theme_color_override("font_color", Color(0.92, 1.0, 0.92))
	else:
		var gray: StyleBoxFlat = manager._make_style(Color(0.30, 0.30, 0.33), Color(0.45, 0.45, 0.48), 1)
		btn_card_upgrade.add_theme_stylebox_override("normal", gray)
		btn_card_upgrade.add_theme_stylebox_override("hover", gray)
		btn_card_upgrade.add_theme_stylebox_override("pressed", gray)
		btn_card_upgrade.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

## v1.15 升级：扣 BP（Lv1~3 扣 1 / Lv4~5 扣 2）+ 等级 +1，等级按 base_id 跨关卡保留
func _on_card_upgrade() -> void:
	if _last_index < 0 or _last_index >= manager._all_cards().size(): return
	var idx := _last_index
	var c = manager._all_cards()[idx]
	var bid := str(c.get("base_id", ""))
	if bid == "" or not GameState.upgrade_card(bid): return
	c["level"] = GameState.get_card_level(bid)
	# 刷新背包格子 / 卡槽 / HUD 快捷栏上的 Lv 显示，最后恢复当前详情
	if manager.bag_ui != null: manager.bag_ui.refresh_backpack()
	if manager.hud_ui != null: manager.hud_ui._refresh_quickbar()
	show_detail(idx)
	_play_upgrade_feedback()

## 升级成功反馈：等级文字闪绿 + "Lv+1" 上飘小字（旧最终版同款）
func _play_upgrade_feedback() -> void:
	if bag_level_label:
		bag_level_label.add_theme_color_override("font_color", Color(0.20, 0.78, 0.32))
		var t := create_tween()
		t.tween_interval(0.7)
		t.tween_callback(func(): bag_level_label.add_theme_color_override(
			"font_color", manager.COL_TEXT_DARK))
	if bag_detail_panel and manager and manager.has_method("_make_style"):
		var tip := Label.new()
		tip.text = "Lv +1 ⭐"
		tip.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
		tip.add_theme_color_override("font_outline_color", Color(0.3, 0.15, 0.0))
		tip.add_theme_constant_override("outline_size", 6)
		UITextBox.apply_basic(tip, "bold", 22, 0)
		tip.position = Vector2(bag_detail_panel.size.x - 180.0, 8.0)
		bag_detail_panel.add_child(tip)
		var tw := tip.create_tween()
		tw.set_parallel(true)
		tw.tween_property(tip, "position:y", tip.position.y - 46.0, 0.9) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(tip, "modulate:a", 0.0, 0.35).set_delay(0.6)
		tw.chain().tween_callback(tip.queue_free)

func _detail_label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	UITextBox.apply_basic(l, "bold" if font_size >= 22 else "normal", font_size, 0)
	parent.add_child(l)
	return l
