extends Control
class_name UIBagPanelEquip

var manager
var equip_slot_cards: Array[int] = [-1, -1, -1]
var equip_slot_labels: Array[Label] = []
var equip_slot_panels: Array[Panel] = []

var attr_popup: Panel
var attr_pop_title: Label
var attr_pop_desc: Label
var attr_pop_attr: Label
var attr_pop_hint: Label
var attr_hint_panel: Panel
var attr_pop_pinned := false

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

	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	bg.add_theme_stylebox_override("panel", manager._make_style(manager.COL_PANEL_BG, Color(0.42, 0.42, 0.45), 1))
	add_child(bg)

	var char_ph := Panel.new()
	char_ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_ph.offset_left = 402.0; char_ph.offset_top = 12.0
	char_ph.offset_right = 652.0; char_ph.offset_bottom = 344.0
	char_ph.add_theme_stylebox_override("panel", manager._make_style(Color(0.30, 0.30, 0.33, 0.6), Color(0.55, 0.57, 0.66, 0.7), 1))
	# v1.19 人物立绘替换占位文字：白柯行以（图缺失时回退原占位文字，保证不空白）
	const HERO_PORTRAIT := "res://assets/textures/portraits/bkxy_portrait.png"
	if ResourceLoader.exists(HERO_PORTRAIT):
		var pic := TextureRect.new()
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.texture = load(HERO_PORTRAIT)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.anchor_right = 1.0; pic.anchor_bottom = 1.0
		pic.offset_left = 8.0; pic.offset_top = 8.0
		pic.offset_right = -8.0; pic.offset_bottom = -8.0
		char_ph.add_child(pic)
	else:
		var char_label := Label.new()
		char_label.text = "人物图片\n（占位）"
		char_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		char_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		char_label.anchor_right = 1.0; char_label.anchor_bottom = 1.0
		char_label.add_theme_color_override("font_color", manager.COL_TEXT_DIM)
		UITextBox.apply_basic(char_label, "normal", 20, 0)
		char_ph.add_child(char_label)
	add_child(char_ph)

	var slot_zone := Panel.new()
	slot_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_zone.anchor_bottom = 1.0
	slot_zone.offset_left = 294.0; slot_zone.offset_top = 356.0
	slot_zone.offset_right = 652.0; slot_zone.offset_bottom = -12.0
	add_child(slot_zone)

	var slot_row := HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 14)
	slot_row.anchor_right = 1.0; slot_row.anchor_bottom = 1.0
	slot_zone.add_child(slot_row)

	for i in 3:
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
		equip_slot_labels.append(l)
		equip_slot_panels.append(slot)

	attr_popup = _build_attr_popup()
	attr_popup.visible = false
	add_child(attr_popup)

	attr_hint_panel = Panel.new()
	attr_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attr_hint_panel.anchor_bottom = 1.0
	attr_hint_panel.offset_left = 12.0; attr_hint_panel.offset_top = 12.0
	attr_hint_panel.offset_right = 282.0; attr_hint_panel.offset_bottom = -12.0
	attr_hint_panel.add_theme_stylebox_override("panel", manager._make_style(manager.COL_PANEL_WHITE, Color(0.42, 0.42, 0.45), 1))
	var hint_lbl := Label.new()
	hint_lbl.text = "（把鼠标移到左侧格子上查看属性）"
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.add_theme_color_override("font_color", manager.COL_TEXT_DARK)
	UITextBox.apply_basic(hint_lbl, "normal", 24, 0)
	hint_lbl.anchor_right = 1.0; hint_lbl.anchor_bottom = 1.0
	hint_lbl.offset_left = 18.0; hint_lbl.offset_top = 30.0
	hint_lbl.offset_right = -18.0; hint_lbl.offset_bottom = -16.0
	attr_hint_panel.add_child(hint_lbl)
	add_child(attr_hint_panel)

func refresh_slots() -> void:
	for i in 3:
		var idx = equip_slot_cards[i]
		var slot := equip_slot_panels[i]
		if idx >= 0 and idx < manager._all_cards().size():
			var c = manager._all_cards()[idx]
			var col = manager.COL_CELL_BY_TYPE.get(str(c["type"]), manager.COL_GRID_CELL)
			equip_slot_labels[i].text = "%s ★\nLv.%d" % [c["name"], int(c.get("level", 1))]
			equip_slot_labels[i].add_theme_color_override("font_color", manager.COL_TEXT_DARK)
			slot.add_theme_stylebox_override("panel", manager._make_style(col.lightened(0.1), manager.COL_ACCENT, 2))
		else:
			equip_slot_labels[i].text = "卡槽\n（拖入卡牌）"
			equip_slot_labels[i].add_theme_color_override("font_color", manager.COL_TEXT_DIM)
			slot.add_theme_stylebox_override("panel", manager._make_style(Color(0.10, 0.10, 0.13, 0.9), Color(0.70, 0.72, 0.80, 0.45), 1))

func _on_slot_drop(slot_i: int, card_index: int) -> void:
	if card_index < 0 or card_index >= manager._all_cards().size(): return
	if equip_slot_cards.has(card_index): return
	if equip_slot_cards[slot_i] >= 0: return
	equip_slot_cards[slot_i] = card_index
	manager._do_set_equipped(card_index, true)
	refresh_slots()
	manager.persist_card_state()
	if on_slot_changed.is_valid(): on_slot_changed.call()

func _on_slot_click(slot_i: int) -> void:
	# v1.15 单击装备槽：查看卡牌属性（卸下改为双击，防误触）
	if equip_slot_cards[slot_i] < 0: return
	show_popup(equip_slot_cards[slot_i], true)

## v1.15 双击装备槽：卸下（原单击卸下逻辑）
func _on_slot_dbl_click(slot_i: int) -> void:
	if equip_slot_cards[slot_i] < 0: return
	var idx := equip_slot_cards[slot_i]
	equip_slot_cards[slot_i] = -1
	manager._do_set_equipped(idx, false)
	refresh_slots()
	manager.persist_card_state()
	show_popup(idx, true)
	if on_slot_changed.is_valid(): on_slot_changed.call()

func show_popup(index: int, pinned: bool) -> void:
	if index < 0 or index >= manager._all_cards().size(): return
	var c = manager._all_cards()[index]
	attr_pop_title.text = str(c["name"])
	attr_pop_desc.text = str(c.get("desc", "（暂无描述）"))
	var lines: Array[String] = []
	if int(c.get("attack", 0)) != 0: lines.append("攻击力 +%d" % int(c["attack"]))
	if int(c.get("shield", 0)) != 0: lines.append("护盾 +%d" % int(c["shield"]))
	attr_pop_attr.text = "\n".join(lines) if not lines.is_empty() else "（无附加属性）"
	attr_pop_pinned = pinned
	attr_pop_hint.text = "（已固定，点其他卡牌切换）" if pinned else ""
	attr_popup.visible = true
	attr_hint_panel.visible = false

func hide_popup() -> void:
	if not attr_pop_pinned:
		attr_popup.visible = false
		attr_hint_panel.visible = true

func _build_attr_popup() -> Panel:
	var pop := Panel.new()
	pop.anchor_bottom = 1.0
	pop.offset_left = 12.0; pop.offset_top = 12.0
	pop.offset_right = 282.0; pop.offset_bottom = -12.0
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.add_theme_stylebox_override("panel", manager._make_style(manager.COL_PANEL_WHITE, Color(0.42, 0.42, 0.45), 1))

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0; vbox.anchor_bottom = 1.0
	vbox.offset_left = 14; vbox.offset_top = 20
	vbox.offset_right = -14; vbox.offset_bottom = -12
	pop.add_child(vbox)

	attr_pop_title = _detail_label(vbox, "", 22, manager.COL_TEXT_DARK)
	attr_pop_desc = _detail_label(vbox, "", 13, Color(0.40, 0.41, 0.45))
	attr_pop_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attr_pop_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	attr_pop_attr = _detail_label(vbox, "", 15, Color(0.18, 0.30, 0.52))
	attr_pop_hint = _detail_label(vbox, "", 12, Color(0.55, 0.56, 0.60))
	return pop

func _detail_label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	UITextBox.apply_basic(l, "bold" if font_size >= 22 else "normal", font_size, 0)
	parent.add_child(l)
	return l
