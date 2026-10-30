extends Control
class_name UIBagPanelWeapon

var manager
var weapon_slot_cards: Array[int] = [-1, -1, -1, -1]
var extra_slot_labels: Array[Label] = []
var extra_slot_panels: Array[Panel] = []

var bag_detail_panel: Panel
var bag_name_label: Label
var bag_type_label: Label
var bag_attr_label: Label
var bag_desc_label: Label
var bag_level_label: Label
var btn_upgrade: Button
var on_slot_changed: Callable

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
	btn_upgrade.text = "升级"
	btn_upgrade.custom_minimum_size = Vector2(96, 44)
	btn_upgrade.disabled = true
	btn_upgrade.modulate = Color(0.5, 0.5, 0.5, 1.0)
	btn_upgrade.anchor_left = 1.0; btn_upgrade.anchor_right = 1.0
	btn_upgrade.anchor_top = 1.0; btn_upgrade.anchor_bottom = 1.0
	btn_upgrade.offset_left = -120.0; btn_upgrade.offset_right = -22.0
	btn_upgrade.offset_bottom = -22.0; btn_upgrade.offset_top = -66.0
	UITextBox.apply_basic(btn_upgrade, "bold", 20, 0)
	bag_detail_panel.add_child(btn_upgrade)

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
		l.text = "武器槽\n（拖入武器卡）"
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
		var idx = weapon_slot_cards[i]
		var slot := extra_slot_panels[i]
		if idx >= 0 and idx < manager._all_cards().size():
			var c = manager._all_cards()[idx]
			var col = manager.COL_CELL_BY_TYPE.get(str(c["type"]), manager.COL_GRID_CELL)
			extra_slot_labels[i].text = "%s\nLv.%d" % [c["name"], int(c.get("level", 1))]
			extra_slot_labels[i].add_theme_color_override("font_color", manager.COL_TEXT_DARK)
			slot.add_theme_stylebox_override("panel", manager._make_style(col.lightened(0.1), manager.COL_ACCENT, 2))
		else:
			extra_slot_labels[i].text = "武器槽\n（拖入武器卡）"
			extra_slot_labels[i].add_theme_color_override("font_color", manager.COL_TEXT_DIM)
			slot.add_theme_stylebox_override("panel", manager._make_style(Color(0.10, 0.10, 0.13, 0.9), Color(0.70, 0.72, 0.80, 0.45), 1))

func _on_slot_drop(slot_i: int, card_index: int) -> void:
	if card_index < 0 or card_index >= manager._all_cards().size(): return
	# 【P1 修复】类型检查由 "物品" 改为 "武器"
	if str(manager._all_cards()[card_index]["type"]) != "武器": return
	if weapon_slot_cards.has(card_index): return
	if weapon_slot_cards[slot_i] >= 0: return
	weapon_slot_cards[slot_i] = card_index
	# 【P1 修复】同步 GameState 装备状态（武器属于装备的一种）
	manager._do_set_equipped(card_index, true)
	refresh_slots()
	manager.persist_card_state()
	if on_slot_changed.is_valid(): on_slot_changed.call()

func _on_slot_click(slot_i: int) -> void:
	# v1.15 单击武器槽：查看卡牌属性（卸下改为双击，防误触）
	if weapon_slot_cards[slot_i] < 0: return
	show_detail(weapon_slot_cards[slot_i])

## v1.15 双击武器槽：卸下（原单击卸下逻辑）
func _on_slot_dbl_click(slot_i: int) -> void:
	if weapon_slot_cards[slot_i] < 0: return
	var idx := weapon_slot_cards[slot_i]
	weapon_slot_cards[slot_i] = -1
	# 【P1 修复】同步卸下
	manager._do_set_equipped(idx, false)
	refresh_slots()
	manager.persist_card_state()
	if on_slot_changed.is_valid(): on_slot_changed.call()

func show_detail(index: int) -> void:
	if index < 0 or index >= manager._all_cards().size():
		bag_name_label.text = "（把鼠标移到左侧格子上查看属性）"
		bag_type_label.text = ""; bag_level_label.text = ""; bag_attr_label.text = ""; bag_desc_label.text = ""
		return
	var c = manager._all_cards()[index]
	bag_name_label.text = str(c["name"]) + ("  ★已装备" if c["is_equipped"] else "")
	bag_type_label.text = "类型：%s" % c["type"]
	bag_desc_label.text = str(c.get("desc", ""))
	var lines: Array[String] = []
	if int(c.get("attack", 0)) != 0: lines.append("攻击力 +%d" % int(c["attack"]))
	if int(c.get("shield", 0)) != 0: lines.append("护盾 +%d" % int(c["shield"]))
	bag_attr_label.text = "\n".join(lines) if not lines.is_empty() else "（无附加属性）"

func _detail_label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	UITextBox.apply_basic(l, "bold" if font_size >= 22 else "normal", font_size, 0)
	parent.add_child(l)
	return l
