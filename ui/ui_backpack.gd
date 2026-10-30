extends Control
class_name UIBackpack

var manager
var bag_tabs: TabContainer
var bag_grids: Array[GridContainer] = []
var bag_cells: Array[Dictionary] = []
var selected_card := -1
var _last_click_index := -1
var _last_click_time := 0
var current_tab: int = 0
var _hover_card_index := -1
var selected_by_tab: Array[int] = [-1, -1, -1, -1, -1]
var codex_list: VBoxContainer
var codex_header: Label
var achievement_list: VBoxContainer   # v1.10 成就页
var achievement_header: Label

var panel_skill: UIBagPanelSkill
var panel_weapon: UIBagPanelWeapon
var panel_equip: UIBagPanelEquip

var skill_slot_cards: Array[int]

const BAG_CELLS_PER_PAGE := 20

#  v1.12 背包指南（教学弹窗）总开关。
#  弹窗内容（标题+①~⑤行+知道了按钮）超出 620×400 面板高度且无裁剪，
#  ②③④⑤行和按钮会溢出到面板下方、飘在卡槽区上。
#  · false = 隐藏：不再弹出指南（本次处理）
#  · true  = 恢复显示（恢复前建议先把 panel.custom_minimum_size 加高或加裁剪）
const ENABLE_BACKPACK_GUIDE := false

func bind_manager(m) -> void:
	manager = m

## v1.12 背包指南（教学弹窗，存档去重）
## v1.15 改为手动打开：顶栏"操作指南"按钮 → _open_backpack_guide()；
##      自动弹出仍由 ENABLE_BACKPACK_GUIDE 控制（默认关）。
##      面板加高 400→560 修复内容溢出；底部新增同款"返回"按钮（与"知道了"等效关闭）。
func _show_backpack_guide() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := Panel.new()
	# v1.18 内容扩充（技能分支/火球两段/治疗分支），560→680 防溢出
	panel.custom_minimum_size = Vector2(620, 680)
	# v1.15 修复：PRESET_CENTER 只改锚点不改偏移，面板会从屏幕中心向右下展开（旧版文字
	# "出现在页面底下"的真正原因）。改为锚点 0.5 + 手动负偏移实现真居中。
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -310.0; panel.offset_right = 310.0
	panel.offset_top = -340.0; panel.offset_bottom = 340.0
	panel.add_theme_stylebox_override("panel", manager._make_style(manager.COL_PANEL_BG, manager.COL_ACCENT, 2))
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 28; vb.offset_right = -28
	vb.offset_top = 24; vb.offset_bottom = -24
	panel.add_child(vb)

	var title := Label.new()
	title.text = "🎒 背包指南"
	title.add_theme_color_override("font_color", manager.COL_ACCENT)
	UITextBox.apply_basic(title, "bold", 26)
	vb.add_child(title)

	var lines := [
		"① 技能卡牌：把卡牌【拖入】右侧技能槽，战斗中按 1/2/3/4 释放（消耗 BP，每 4 秒回复 1 点）",
		"② 武器卡：拖入右侧武器槽整理常用武器（不占按键，1/2/3/4 始终对应技能槽）",
		"③ 装备卡：双击穿上/卸下，攻击·生命·护盾直接加成",
		"④ 图鉴 N 键：击败过的敌人情报；成就 O 键：挑战进度与奖励",
		"⑤ 单击卡牌查看属性并选中；双击装备/使用；卡槽内卡牌：单击看属性、双击取回",
		"⑥ 升级卡牌：右上【升级】按钮消耗 BP（Lv1~3 每次 1 点 / Lv4~9 每次 2 点），每级倍率 +0.2，上限 Lv.9",
		"⑦ 技能分支：技能详情页点【技能分支】展开；Lv.3 解锁第 1 个、Lv.5 解锁第 2 个（各消耗 1 点 BP），点【使用】切换生效分支",
		"⑧ 火球术（两段式）：第一段生成悬浮火球；第二段再按技能键或【鼠标左键点击】朝鼠标方向发射（该次点击不会普攻）",
		"　 · 连珠火弹：一次两发同向，第二发延迟 0.2s，每发 60% 伤害，冷却 80%",
		"　 · 爆炎术：体积与伤害 ×2，冷却 1.5 倍",
		"⑨ 妙手回春（分支）：迅愈——冷却 2/3，一次两段治疗各 60%（间隔 1 秒，共 120%）；铁壁润泽——治疗 80%，护盾值+2/上限+2（8 秒），到期护盾值-2（不足则归零，不扣血）",
	]
	for s in lines:
		var l := Label.new()
		l.text = s
		l.add_theme_color_override("font_color", manager.COL_TEXT)
		UITextBox.apply_basic(l, "normal", 14)   # v1.18 内容扩充后 16→14 防溢出
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(l)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	btn_row.size_flags_vertical = Control.SIZE_SHRINK_END
	vb.add_child(btn_row)

	var ok_btn := Button.new()
	ok_btn.text = "知道了"
	ok_btn.custom_minimum_size = Vector2(180, 44)
	ok_btn.add_theme_stylebox_override("normal", manager._make_style(manager.COL_PANEL_BG, manager.COL_ACCENT, 2))
	ok_btn.add_theme_stylebox_override("hover", manager._make_style(manager.COL_PANEL_BG, manager.COL_TEXT, 2))
	UITextBox.apply_basic(ok_btn, "bold", 18)
	ok_btn.pressed.connect(func():
		GameState.tutorial_seen["backpack"] = true
		dim.queue_free()
		panel.queue_free()
	)
	btn_row.add_child(ok_btn)

	# v1.15 同款返回按钮：样式与顶栏"返回"一致，点击回到进入指南前的界面（关闭覆盖层）
	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(98, 44)
	back_btn.add_theme_color_override("font_color", manager.COL_TEXT)
	back_btn.add_theme_stylebox_override("normal", manager._make_style(manager.COL_PANEL_BG, manager.COL_BORDER, 2))
	back_btn.add_theme_stylebox_override("hover", manager._make_style(manager.COL_PANEL_BG, manager.COL_ACCENT, 2))
	UITextBox.apply_basic(back_btn, "bold", 20)
	back_btn.pressed.connect(func():
		dim.queue_free()
		panel.queue_free()
	)
	btn_row.add_child(back_btn)

## v1.15 手动打开指南（顶栏"操作指南"按钮入口，不受 ENABLE_BACKPACK_GUIDE 开关限制）
func _open_backpack_guide() -> void:
	_show_backpack_guide()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_backpack()

func open_tab(tab: int) -> void:
	if current_tab != tab and current_tab >= 0 and current_tab <= 4:
		selected_by_tab[current_tab] = selected_card
	current_tab = tab
	selected_card = selected_by_tab[tab] if tab >= 0 and tab <= 4 else -1
	
	if panel_equip: 
		panel_equip.attr_pop_pinned = false
		panel_equip.attr_popup.visible = false
	_hover_card_index = -1
	if bag_tabs: bag_tabs.current_tab = tab
	
	panel_skill.visible = (tab == 0)
	panel_weapon.visible = (tab == 1)
	panel_equip.visible = (tab == 2)
	if tab == 3:
		refresh_codex()
	if tab == 4:
		refresh_achievements()

	if tab == 0:
		panel_skill.show_detail(selected_card)
		panel_skill.refresh_slots()
	elif tab == 1:
		panel_weapon.show_detail(selected_card)
		panel_weapon.refresh_slots()
	else:
		panel_equip.refresh_slots()
		if panel_equip.attr_hint_panel: 
			panel_equip.attr_hint_panel.visible = not panel_equip.attr_popup.visible

func _build_backpack() -> void:
	var mask := ColorRect.new()
	mask.color = manager.COL_MASK_BAG
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mask)

	# v1.15 顶栏提示文字已改为锚定横幅（见下方 hint），原 top HBox 容器移除

	var hint := Label.new()
	# v1.15 提示拆两行：第一行到快捷键说明为止；被省略号截断的"点住卡牌拖入右侧卡槽"
	# 整句换行到第二行，保证任何窗口宽度下文案完整可读
	hint.text = "单击选中/查看属性 ｜ 双击装备·卸下·使用（卡槽内卡牌双击取回）｜ C 技能页 · B 武器页 · V 装备页 · N 图鉴 · O 成就\n武器/技能页：点住卡牌拖入右侧卡槽"
	hint.add_theme_color_override("font_color", manager.COL_TEXT)
	UITextBox.apply_basic(hint, "normal", 13)
	# 防遮挡：hint 为锚定横幅，右侧给顶栏按钮区留位；单行超宽时自动省略号截断
	hint.anchor_left = 0.0; hint.anchor_right = 1.0
	hint.offset_left = manager.HUD_MARGIN
	hint.offset_right = -(manager.HUD_MARGIN + 272.0)   # 顶栏按钮区左缘再留 20px
	hint.offset_top = manager.HUD_MARGIN - 2.0
	hint.offset_bottom = manager.HUD_MARGIN + 42.0      # 两行高度（下缘不压详情面板顶部 M+44）
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(hint)

	# v1.12 教学：首次打开背包显示指南（存档去重）
	# v1.15 暂时隐藏（ENABLE_BACKPACK_GUIDE = false，见文件顶部开关区说明）
	if ENABLE_BACKPACK_GUIDE and not GameState.tutorial_seen.get("backpack", false):
		_show_backpack_guide()

	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(98, 44)
	back_btn.add_theme_color_override("font_color", manager.COL_TEXT)
	back_btn.add_theme_stylebox_override("normal", manager._make_style(manager.COL_PANEL_BG, manager.COL_BORDER, 2))
	back_btn.add_theme_stylebox_override("hover", manager._make_style(manager.COL_PANEL_BG, manager.COL_ACCENT, 2))
	back_btn.anchor_left = 1.0; back_btn.anchor_right = 1.0
	back_btn.offset_left = -(manager.HUD_MARGIN + 110.0)   # v1.15 右移 10px（原 -(M+120)）
	back_btn.offset_right = -(manager.HUD_MARGIN + 12.0)   # v1.15 右移 10px（原 -(M+22)）
	back_btn.offset_top = manager.HUD_MARGIN + 44.0 - 12.0 - 44.0
	back_btn.offset_bottom = manager.HUD_MARGIN + 44.0 - 12.0
	UITextBox.apply_basic(back_btn, "bold", 20)
	back_btn.pressed.connect(func(): manager._change_state(manager.State.GAME_HUD))
	add_child(back_btn)

	# v1.15 操作指南按钮：返回按钮左侧同排，同款式样、同高对齐；
	# "操作指南"四字比"返回"宽，按需求加长按钮避免拥挤
	var guide_btn := Button.new()
	guide_btn.text = "操作指南"
	guide_btn.custom_minimum_size = Vector2(130, 44)
	guide_btn.add_theme_color_override("font_color", manager.COL_TEXT)
	guide_btn.add_theme_stylebox_override("normal", manager._make_style(manager.COL_PANEL_BG, manager.COL_BORDER, 2))
	guide_btn.add_theme_stylebox_override("hover", manager._make_style(manager.COL_PANEL_BG, manager.COL_ACCENT, 2))
	guide_btn.anchor_left = 1.0; guide_btn.anchor_right = 1.0
	guide_btn.offset_left = -(manager.HUD_MARGIN + 122.0 + 130.0)   # v1.15 随返回按钮右移 10px，间距仍 12
	guide_btn.offset_right = -(manager.HUD_MARGIN + 122.0)
	guide_btn.offset_top = back_btn.offset_top
	guide_btn.offset_bottom = back_btn.offset_bottom
	UITextBox.apply_basic(guide_btn, "bold", 20)
	guide_btn.pressed.connect(_open_backpack_guide)
	add_child(guide_btn)

	var left_panel := Panel.new()
	left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_panel.anchor_bottom = 1.0
	left_panel.offset_left = -12.0
	left_panel.offset_top = manager.HUD_MARGIN + 44.0
	left_panel.offset_right = 448.0
	left_panel.offset_bottom = -manager.HUD_MARGIN
	left_panel.add_theme_stylebox_override("panel", manager._make_style(manager.COL_GRID_BOARD, Color(0.42, 0.42, 0.45), 1))
	add_child(left_panel)

	bag_tabs = TabContainer.new()
	bag_tabs.anchor_right = 1.0; bag_tabs.anchor_bottom = 1.0
	bag_tabs.offset_left = 12; bag_tabs.offset_top = 12; bag_tabs.offset_right = -12; bag_tabs.offset_bottom = -12
	bag_tabs.tabs_visible = false
	left_panel.add_child(bag_tabs)

	var tab_names := ["技能卡牌", "武器卡", "装备卡", "图鉴", "成就"]
	# v1.12 教学：每页签常驻操作说明
	var tab_tips := [
		"🎯 技能页：把左侧技能卡【拖入】右侧 4 个技能槽；战斗中按 1/2/3/4 释放，消耗 BP（蓝条），每 4 秒回复 1 点",
		"🗡️ 武器页：把左侧武器卡【拖入】右侧 4 个武器槽整理常用武器（不占按键，1/2/3/4 始终对应技能槽）",
		"🛡️ 装备页：双击装备卡穿上/卸下；攻击·生命·护盾直接加成，品阶越高词缀越多",
		"📖 图鉴：击败过的敌人都会记录在这里（含掉落）",
		"🏆 成就：完成挑战积累进度；部分成就附带属性奖励",
	]
	for t in 5:
		var margin := MarginContainer.new()
		for m in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
			margin.add_theme_constant_override(m, 6)
		bag_tabs.add_child(margin)
		bag_tabs.set_tab_title(t, tab_names[t])

		# 教学条（常驻页签顶部）
		var tip := Label.new()
		tip.text = tab_tips[t]
		tip.add_theme_color_override("font_color", Color(0.72, 0.85, 1.0))
		UITextBox.apply_basic(tip, "normal", 13)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var page_vb := VBoxContainer.new()
		page_vb.add_theme_constant_override("separation", 4)
		margin.add_child(page_vb)
		page_vb.add_child(tip)

		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		page_vb.add_child(scroll)

		if t == 3:
			# v1.9 图鉴页：顶部进度 + 条目列表（非网格）
			var vb := VBoxContainer.new()
			vb.add_theme_constant_override("separation", 8)
			vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(vb)
			codex_header = Label.new()
			codex_header.add_theme_color_override("font_color", manager.COL_TEXT)
			UITextBox.apply_basic(codex_header, "bold", 18)
			vb.add_child(codex_header)
			codex_list = VBoxContainer.new()
			codex_list.add_theme_constant_override("separation", 8)
			codex_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vb.add_child(codex_list)
			continue

		if t == 4:
			# v1.10 成就页：顶部进度 + 分类成就列表
			var vb2 := VBoxContainer.new()
			vb2.add_theme_constant_override("separation", 8)
			vb2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(vb2)
			achievement_header = Label.new()
			achievement_header.add_theme_color_override("font_color", manager.COL_TEXT)
			UITextBox.apply_basic(achievement_header, "bold", 18)
			vb2.add_child(achievement_header)
			achievement_list = VBoxContainer.new()
			achievement_list.add_theme_constant_override("separation", 8)
			achievement_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vb2.add_child(achievement_list)
			continue

		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		scroll.add_child(grid)
		bag_grids.append(grid)

	panel_skill = UIBagPanelSkill.new()
	panel_skill.setup(manager, _update_cell_highlight)
	add_child(panel_skill)

	panel_weapon = UIBagPanelWeapon.new()
	panel_weapon.setup(manager, _update_cell_highlight)
	panel_weapon.visible = false
	add_child(panel_weapon)

	panel_equip = UIBagPanelEquip.new()
	panel_equip.setup(manager, _update_cell_highlight)
	panel_equip.visible = false
	add_child(panel_equip)

	skill_slot_cards = panel_skill.skill_slot_cards

func refresh_backpack() -> void:
	if bag_grids.is_empty(): return
	bag_cells.clear()
	for g in 3:
		var grid := bag_grids[g]
		for child in grid.get_children(): child.queue_free()
		var count := 0
		var all_c = manager._all_cards()
		for idx in range(all_c.size()):
			var c = all_c[idx]
			# 【P1 修复】类型分组对齐：
			#   tab 0 = 技能；tab 1 = 武器；tab 2 = 装备 / 饰品
			var type_g := 2
			if c["type"] == "技能": type_g = 0
			elif c["type"] == "武器": type_g = 1
			if type_g != g: continue
			# 技能/武器页：已放入槽位的卡不在卡池重复显示
			# 装备页：已装备的卡保留在卡池（便于查看/卸下）
			if g != 2 and c["is_equipped"]: continue

			var cell := _make_card_cell(idx, g)
			cell.custom_minimum_size = manager.QUICK_SIZE
			grid.add_child(cell)
			bag_cells.append({"btn": cell, "index": idx})
			count += 1

		for f in range(BAG_CELLS_PER_PAGE - count):
			var empty := Panel.new()
			empty.custom_minimum_size = manager.QUICK_SIZE
			empty.add_theme_stylebox_override("panel", manager._make_style(manager.COL_GRID_CELL, Color(0.46, 0.46, 0.50), 1))
			var q := Label.new()
			q.text = "?"
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			q.anchor_right = 1.0; q.anchor_bottom = 1.0
			q.add_theme_color_override("font_color", Color(1, 1, 1))
			UITextBox.apply_basic(q, "normal", 18, 0)
			empty.add_child(q)
			grid.add_child(empty)

	_update_cell_highlight()
	if codex_list != null:
		refresh_codex()
	if achievement_list != null:
		refresh_achievements()
	panel_skill.show_detail(selected_card)
	panel_skill.refresh_slots()
	panel_weapon.show_detail(selected_card)
	panel_weapon.refresh_slots()
	panel_equip.refresh_slots()

## v1.9 图鉴页刷新：已解锁显示名称+章节+描述，未解锁显示 ？？？
func refresh_codex() -> void:
	if codex_list == null: return
	for child in codex_list.get_children():
		child.queue_free()
	var prog: Dictionary = GameState.codex_progress()
	if codex_header:
		codex_header.text = "已解锁 %d / %d" % [int(prog["unlocked"]), int(prog["total"])]
	for name in CodexData.ENTRIES:
		var entry: Dictionary = CodexData.ENTRIES[name]
		var unlocked := GameState.is_codex_unlocked(String(name))
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", manager._make_style(
			manager.COL_PANEL_BG if unlocked else manager.COL_GRID_CELL,
			manager.COL_BORDER, 1))
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		row.add_child(vb)
		var title := Label.new()
		title.text = ("%s  ·  %s" % [String(name), String(entry.get("ch", ""))]) if unlocked \
			else "？？？  ·  尚未解锁"
		title.add_theme_color_override("font_color",
			manager.COL_ACCENT if unlocked else Color(0.55, 0.55, 0.58))
		UITextBox.apply_basic(title, "bold", 17)
		vb.add_child(title)
		var desc := Label.new()
		desc.text = String(entry.get("desc", "")) if unlocked else "击败该敌人后解锁图鉴条目。"
		desc.add_theme_color_override("font_color",
			manager.COL_TEXT if unlocked else Color(0.5, 0.5, 0.53))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITextBox.apply_basic(desc, "normal", 14)
		vb.add_child(desc)
		codex_list.add_child(row)

## v1.10 成就页刷新：按分类展示，已解锁显示名称+描述，未解锁显示 ？？？
func refresh_achievements() -> void:
	if achievement_list == null: return
	for child in achievement_list.get_children():
		child.queue_free()
	var prog: Dictionary = GameState.achievement_progress()
	if achievement_header:
		achievement_header.text = "已达成 %d / %d" % [int(prog["unlocked"]), int(prog["total"])]
	var cats := ["战斗", "探索", "收集", "成长"]
	for cat in cats:
		var cat_label := Label.new()
		cat_label.text = "—— %s ——" % cat
		cat_label.add_theme_color_override("font_color", manager.COL_ACCENT)
		cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITextBox.apply_basic(cat_label, "bold", 16)
		achievement_list.add_child(cat_label)
		for aid in AchievementData.ENTRIES:
			var entry: Dictionary = AchievementData.ENTRIES[aid]
			if String(entry.get("cat", "")) != cat: continue
			var unlocked := GameState.is_achievement_unlocked(String(aid))
			var row := PanelContainer.new()
			row.add_theme_stylebox_override("panel", manager._make_style(
				manager.COL_PANEL_BG if unlocked else manager.COL_GRID_CELL,
				manager.COL_BORDER, 1))
			var vb := VBoxContainer.new()
			vb.add_theme_constant_override("separation", 2)
			row.add_child(vb)
			var title := Label.new()
			title.text = ("🏆 %s" % String(entry.get("name", ""))) if unlocked else "🏆 ？？？  ·  未达成"
			title.add_theme_color_override("font_color",
				manager.COL_ACCENT if unlocked else Color(0.55, 0.55, 0.58))
			UITextBox.apply_basic(title, "bold", 17)
			vb.add_child(title)
			var desc := Label.new()
			desc.text = String(entry.get("desc", "")) if unlocked else "条件保密，达成后揭晓。"
			desc.add_theme_color_override("font_color",
				manager.COL_TEXT if unlocked else Color(0.5, 0.5, 0.53))
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UITextBox.apply_basic(desc, "normal", 14)
			vb.add_child(desc)
			achievement_list.add_child(row)

func _make_card_cell(index: int, _group: int = 0) -> Button:
	var c = manager._all_cards()[index]
	var btn := DragCardButton.new()
	var star = " ★" if c["is_equipped"] else ""
	btn.text = "%s%s\nLv.%d" % [c["name"], star, c["level"]]
	btn.add_theme_color_override("font_color", manager.COL_TEXT_DARK)
	UITextBox.apply_basic(btn, "bold", 18, 0)
	
	var cell_color = manager.COL_CELL_BY_TYPE.get(str(c["type"]), manager.COL_GRID_CELL)
	btn.cell_color = cell_color
	btn.card_index = index
	btn.add_theme_stylebox_override("normal", manager._make_style(cell_color, cell_color.darkened(0.25), 1))
	btn.add_theme_stylebox_override("hover", manager._make_style(cell_color.lightened(0.15), manager.COL_ACCENT, 2))
	btn.drag_cb = _get_card_drag_data
	btn.mouse_entered.connect(func(): _on_cell_hover(index))
	btn.mouse_exited.connect(func(): _on_cell_unhover(index))
	btn.pressed.connect(func(): _on_cell_clicked(index))
	return btn

func _on_cell_hover(index: int) -> void:
	_hover_card_index = index
	if current_tab == 2 and not panel_equip.attr_pop_pinned:
		panel_equip.show_popup(index, false)

func _on_cell_unhover(index: int) -> void:
	if _hover_card_index == index: _hover_card_index = -1
	if current_tab == 2:
		panel_equip.hide_popup()

func _on_cell_clicked(index: int) -> void:
	var now := Time.get_ticks_msec()
	if index == _last_click_index and now - _last_click_time <= manager.DOUBLE_CLICK_MS:
		_on_cell_double_clicked(index)
		_last_click_index = -1; _last_click_time = 0
	else:
		_last_click_index = index; _last_click_time = now
		selected_card = index
		if current_tab == 2:
			panel_equip.show_popup(index, true)
		elif current_tab == 1:
			panel_weapon.show_detail(index)
		else:
			panel_skill.show_detail(index)
		_update_cell_highlight()

func _on_cell_double_clicked(index: int) -> void:
	var c = manager._all_cards()[index]

	if c["type"] == "武器":
		# 武器 → 武器页 4 槽（快捷栏），同步 GameState 装备状态
		if panel_weapon.weapon_slot_cards.has(index):
			panel_weapon._on_slot_dbl_click(panel_weapon.weapon_slot_cards.find(index))
			return
		var empty_i := -1
		for i in 4:
			if panel_weapon.weapon_slot_cards[i] < 0: empty_i = i; break
		if empty_i < 0:
			print("⚠️ [背包] 武器快捷栏已满，无法再放置「%s」" % c["name"])
			return
		manager._do_set_equipped(index, true)
		panel_weapon.weapon_slot_cards[empty_i] = index
		panel_weapon.refresh_slots()
		manager.persist_card_state()
		_update_cell_highlight()

	elif c["type"] in ["饰品", "装备"]:
		# 装备/饰品 → 装备页 3 槽（原逻辑）
		if panel_equip.equip_slot_cards.has(index):
			panel_equip._on_slot_dbl_click(panel_equip.equip_slot_cards.find(index))
			return
		if bool(c.get("is_equipped", false)):
			manager._do_set_equipped(index, false)
			return
		var empty_i := -1
		for i in 3:
			if panel_equip.equip_slot_cards[i] < 0: empty_i = i; break
		if empty_i < 0:
			print("⚠️ [背包] 装备失败: 卡槽已满，无法再装备「%s」" % c["name"])
			return
		manager._do_set_equipped(index, true)
		panel_equip.equip_slot_cards[empty_i] = index
		panel_equip.refresh_slots()
		manager.persist_card_state()
		_update_cell_highlight()

	elif c["type"] == "技能":
		# 技能 → 技能页 4 槽（原逻辑）
		if panel_skill.skill_slot_cards.has(index):
			panel_skill._on_slot_dbl_click(panel_skill.skill_slot_cards.find(index))
			return
		var empty_i := -1
		for i in 4:
			if panel_skill.skill_slot_cards[i] < 0: empty_i = i; break
		if empty_i < 0:
			print("⚠️ [背包] 放置失败: 卡槽已满，无法再放置「%s」" % c["name"])
			return
		panel_skill.skill_slot_cards[empty_i] = index
		panel_skill.refresh_slots()
		manager.persist_card_state()
		_update_cell_highlight()

func _update_cell_highlight() -> void:
	for cell in bag_cells:
		var btn = cell["btn"]
		var idx = cell["index"]
		var c = manager._all_cards()[idx]
		var cell_color = manager.COL_CELL_BY_TYPE.get(str(c["type"]), manager.COL_GRID_CELL)
		var in_slot := panel_equip.equip_slot_cards.has(idx) or panel_skill.skill_slot_cards.has(idx) or panel_weapon.weapon_slot_cards.has(idx)
		
		if in_slot:
			btn.modulate = Color(0.5, 0.5, 0.5, 1.0)
			btn.add_theme_stylebox_override("normal", manager._make_style(cell_color.darkened(0.4), cell_color.darkened(0.5), 1))
		else:
			btn.modulate = Color.WHITE
			if idx == selected_card:
				btn.add_theme_stylebox_override("normal", manager._make_style(cell_color.lightened(0.1), manager.COL_ACCENT, 2))
			else:
				btn.add_theme_stylebox_override("normal", manager._make_style(cell_color, cell_color.darkened(0.25), 1))

func _get_card_drag_data(card_index: int) -> Variant:
	if panel_equip.equip_slot_cards.has(card_index) or panel_skill.skill_slot_cards.has(card_index) or panel_weapon.weapon_slot_cards.has(card_index):
		return null
	var c = manager._all_cards()[card_index]
	var preview := Panel.new()
	preview.custom_minimum_size = manager.QUICK_SIZE
	preview.size = manager.QUICK_SIZE
	var col = manager.COL_CELL_BY_TYPE.get(str(c["type"]), manager.COL_GRID_CELL)
	preview.add_theme_stylebox_override("panel", manager._make_style(col, manager.COL_ACCENT, 2))
	var l := Label.new()
	l.text = str(c["name"])
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.anchor_right = 1.0; l.anchor_bottom = 1.0
	l.add_theme_color_override("font_color", manager.COL_TEXT_DARK)
	UITextBox.apply_basic(l, "bold", 14, 0)
	preview.add_child(l)
	set_drag_preview(preview)
	return {"index": card_index}

class DragCardButton extends Button:
	var drag_cb: Callable
	var card_index := -1
	var cell_color := Color(0.34, 0.34, 0.37)
	func _get_drag_data(_at: Vector2) -> Variant:
		if drag_cb.is_null() or card_index < 0: return null
		return drag_cb.call(card_index)

class DropSlotPanel extends Panel:
	const DOUBLE_CLICK_MS := 350   # 与 manager.DOUBLE_CLICK_MS 一致
	var slot_index := -1
	var drop_cb: Callable
	var click_cb: Callable         # v1.15 单击：查看卡牌属性
	var dbl_click_cb: Callable     # v1.15 双击：卸下（原单击卸下，防误触改为双击）
	var _last_click_ms := 0
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("index")
	func _drop_data(_at: Vector2, data: Variant) -> void:
		if drop_cb.is_valid(): drop_cb.call(slot_index, int(data["index"]))
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				accept_event()
				var now := Time.get_ticks_msec()
				if now - _last_click_ms <= DOUBLE_CLICK_MS:
					_last_click_ms = 0
					if dbl_click_cb.is_valid(): dbl_click_cb.call(slot_index)
				else:
					_last_click_ms = now
					if click_cb.is_valid(): click_cb.call(slot_index)
