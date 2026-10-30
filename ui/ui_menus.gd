extends Control
class_name UIMenus

var manager
var pages: Array[Control] = []
var name_input: LineEdit
var result_title: Label

func bind_manager(m) -> void:
	manager = m

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages.append(_build_main_menu())    # 0
	pages.append(_build_settings())     # 1
	pages.append(_build_pause_menu())   # 2
	pages.append(_build_save_menu())    # 3
	pages.append(_build_result())       # 4
	pages.append(_build_naming())       # 5
	pages.append(_build_credits())      # 6
	pages.append(_build_changelog())   # 7
	pages.append(_build_guide())       # 8 v1.18 玩法指导
	for p in pages: 
		p.visible = false
		add_child(p)

func switch_page(state_id: int) -> void:
	var page_idx := -1
	match state_id:
		manager.State.MAIN_MENU: page_idx = 0
		manager.State.SETTINGS: page_idx = 1
		manager.State.PAUSE: page_idx = 2
		manager.State.SAVE: page_idx = 3
		manager.State.RESULT: page_idx = 4
		manager.State.NAMING: page_idx = 5
		manager.State.CREDITS: page_idx = 6
		manager.State.CHANGELOG: page_idx = 7
		manager.State.GUIDE: page_idx = 8
	# 存档页每次打开都重建：按钮可用态 / 存档摘要保持实时
	if page_idx == 3 and pages.size() > 3:
		var old: Control = pages[3]
		pages.remove_at(3)
		old.queue_free()
		var fresh := _build_save_menu()
		pages.insert(3, fresh)
	for i in pages.size():
		pages[i].visible = (i == page_idx)

func show_result(is_win: bool) -> void:
	result_title.text = "胜利！" if is_win else "失败…"

# ---------------- 主菜单 ----------------
func _build_main_menu() -> Control:
	var root := _page("MainMenu")
	var center := _add_center(root)
	# v1.19 整列下移：150→220 + 间距 30→24，"新游戏"离开标题横幅、"退出"不贴底边
	center.offset_top = 220
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var btn_new := _add_text_button(vbox, "新游戏", 28)
	btn_new.pressed.connect(func(): manager._change_state(manager.State.NAMING))
	if GameState.has_save():
		var btn_cont := _add_text_button(vbox, "继续游戏", 28)
		btn_cont.pressed.connect(func(): manager.continue_game())
	var btn_about := _add_text_button(vbox, "关于我们", 28)
	btn_about.pressed.connect(func(): manager._change_state(manager.State.CREDITS))
	var btn_log := _add_text_button(vbox, "更新日志", 28)
	btn_log.pressed.connect(func(): manager._change_state(manager.State.CHANGELOG))
	# v1.18 玩法指导：插入在原"退出"位置，"退出"自动下移一格（VBox 保持同间距/对齐/字号）
	var btn_guide := _add_text_button(vbox, "玩法指导", 28)
	btn_guide.pressed.connect(func(): manager._change_state(manager.State.GUIDE))
	var btn_quit := _add_text_button(vbox, "退出", 28)
	btn_quit.pressed.connect(func(): get_tree().quit())
	
	var btn_set := _add_text_button(root, "设置", 20)
	btn_set.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_set.offset_left = -160; btn_set.offset_right = -40
	btn_set.offset_top = -90; btn_set.offset_bottom = -30
	btn_set.pressed.connect(func(): manager._change_state(manager.State.SETTINGS))
	return root

# ---------------- 设置菜单 ----------------
func _build_settings() -> Control:
	var root := _page("Settings")
	_add_mask(root, manager.COL_MASK)
	var center := _add_center(root)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(560, 560)
	panel.add_theme_stylebox_override("panel", _make_style(manager.COL_PANEL_BG, manager.COL_BORDER, 2))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	_set_full_rect(vbox)
	vbox.offset_left = 36; vbox.offset_top = 26; vbox.offset_right = -36; vbox.offset_bottom = -26
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "设 置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", manager.COL_TEXT)
	UITextBox.apply_basic(title, "bold", 30)
	vbox.add_child(title)

	var gs_settings: Dictionary = GameState.settings

	# BGM 音量
	var bgm_row := _add_slider_row(vbox, "BGM", int(gs_settings.get("bgm", 80)))
	bgm_row.value_changed.connect(func(v: float):
		GameState.settings["bgm"] = int(v)
		GameState.apply_audio_settings()
	)
	# SE 音效音量
	var se_row := _add_slider_row(vbox, "音效", int(gs_settings.get("se", 80)))
	se_row.value_changed.connect(func(v: float):
		GameState.settings["se"] = int(v)
		GameState.apply_audio_settings()
	)
	# VN 打字速度（auto 速度）
	var speed_row := _add_slider_row(vbox, "打字速度", int(float(gs_settings.get("vn_speed", 1.0)) * 100.0))
	speed_row.value_changed.connect(func(v: float):
		GameState.settings["vn_speed"] = v / 100.0
		GameState.apply_vn_speed()
	)
	var speed_tip := Label.new()
	speed_tip.text = "（50% 慢读 · 100% 标准 · 200% 快进）"
	speed_tip.add_theme_color_override("font_color", manager.COL_TEXT_DIM)
	UITextBox.apply_basic(speed_tip, "normal", 12)
	vbox.add_child(speed_tip)

	# 分辨率
	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 12)
	vbox.add_child(res_row)
	var res_name := Label.new()
	res_name.text = "分辨率"
	res_name.custom_minimum_size = Vector2(64, 0)
	res_name.add_theme_color_override("font_color", manager.COL_TEXT_DIM)
	UITextBox.apply_basic(res_name, "normal", 16, 0)
	res_row.add_child(res_name)
	var res_opt := OptionButton.new()
	res_opt.add_item("1152 × 648", 0)
	res_opt.add_item("1280 × 720", 1)
	res_opt.add_item("1600 × 900", 2)
	res_opt.add_item("1920 × 1080", 3)
	res_opt.selected = clampi(int(gs_settings.get("resolution", 0)), 0, 3)
	res_opt.custom_minimum_size = Vector2(200, 0)
	res_row.add_child(res_opt)
	res_opt.item_selected.connect(func(idx: int):
		GameState.settings["resolution"] = idx
		GameState.apply_resolution()
	)

	# 全屏
	var fs_row := HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 12)
	vbox.add_child(fs_row)
	var fs_name := Label.new()
	fs_name.text = "全屏"
	fs_name.custom_minimum_size = Vector2(64, 0)
	fs_name.add_theme_color_override("font_color", manager.COL_TEXT_DIM)
	UITextBox.apply_basic(fs_name, "normal", 16, 0)
	fs_row.add_child(fs_name)
	var fs_check := CheckButton.new()
	fs_check.button_pressed = bool(gs_settings.get("fullscreen", false))
	fs_row.add_child(fs_check)
	fs_check.toggled.connect(func(on: bool):
		GameState.settings["fullscreen"] = on
		GameState.apply_resolution()
	)

	# 键位说明
	var key_tip := Label.new()
	key_tip.text = "A/D 或 ←/→ 移动 · Space 跳跃 · 左键攻击（长按蓄力）\n数字键 1-4 释放技能 · 双击 A/D 冲刺 · 空中 S 下坠冲击\nE 交互 · B 背包 · Esc 暂停"
	key_tip.add_theme_color_override("font_color", manager.COL_TEXT_DIM)
	key_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITextBox.apply_basic(key_tip, "normal", 13)
	vbox.add_child(key_tip)

	var back := _add_button(vbox, "返回", Vector2(200, 52), 20)
	back.pressed.connect(func(): manager._change_state(manager.State.MAIN_MENU))
	return root

# ---------------- 暂停菜单 ----------------
func _build_pause_menu() -> Control:
	var root := _page("PauseMenu")
	_add_mask(root, Color(0, 0, 0, 0.6))
	var center := _add_center(root)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(800, 400)
	# v1.18 美化：面板加清晰描边（白底 + 深色 2px 边框 + 12px 圆角，带投影）
	panel.add_theme_stylebox_override("panel", _make_style(manager.COL_PANEL_WHITE, Color(0.22, 0.24, 0.30), 2, 12))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	_set_full_rect(vbox)
	vbox.offset_left = 32; vbox.offset_right = -32   # v1.18 左右内边距
	panel.add_child(vbox)
	vbox.add_child(_spacer(22))
	# v1.18 标题装框：深色圆角小面板 + 金色描边 + 白字（与整体 UI 同风格，不再裸文字）
	var title_box := PanelContainer.new()
	var tb_style := _make_style(manager.COL_PANEL_BG, manager.COL_ACCENT, 2, 10)
	tb_style.content_margin_left = 40.0; tb_style.content_margin_right = 40.0
	tb_style.content_margin_top = 8.0; tb_style.content_margin_bottom = 10.0
	title_box.add_theme_stylebox_override("panel", tb_style)
	title_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title := Label.new()
	title.text = "暂 停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	UITextBox.apply_basic(title, "bold", 32, 0)
	title_box.add_child(title)
	vbox.add_child(title_box)
	var mid_gap := Control.new()
	mid_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(mid_gap)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 36)
	vbox.add_child(row)
	# v1.18 底部留白：按钮与文字整体上移，不再贴着面板下边缘
	vbox.add_child(_spacer(34))

	var btn_quit := _icon_square_button("↩", "退出")
	btn_quit["btn"].pressed.connect(func():
		get_tree().paused = false
		StageRouter.goto_scene("res://stages/shared/title_main.tscn")
	)
	row.add_child(btn_quit["box"])

	var btn_resume := _icon_square_button("▶", "继续")
	btn_resume["btn"].pressed.connect(func(): manager._change_state(manager.State.GAME_HUD))
	row.add_child(btn_resume["box"])

	var btn_save := _icon_square_button("⤓", "存档")
	btn_save["btn"].pressed.connect(func(): manager._change_state(manager.State.SAVE))
	row.add_child(btn_save["box"])
	return root

# ---------------- 存档菜单 ----------------
func _build_save_menu() -> Control:
	var root := _page("SaveMenu")
	_add_mask(root, manager.COL_MASK_LIGHT)
	var center := _add_center(root)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(520, 420)
	panel.add_theme_stylebox_override("panel", _make_style(manager.COL_PANEL_BG, manager.COL_BORDER, 2))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	_set_full_rect(vbox)
	vbox.offset_left = 40; vbox.offset_top = 30; vbox.offset_right = -40; vbox.offset_bottom = -30
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "存 档"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", manager.COL_TEXT)
	UITextBox.apply_basic(title, "bold", 30)
	vbox.add_child(title)
	# 槽位 1：真实存档（v1.4 接入 GameState 存档系统）
	var slot1 := Button.new()
	slot1.custom_minimum_size = Vector2(360, 56)
	slot1.add_theme_font_size_override("font_size", 18)
	slot1.disabled = true
	if GameState.has_save():
		slot1.text = "存档 1：" + GameState.get_save_summary()
	else:
		slot1.text = "存档槽位 1（空）"
	vbox.add_child(slot1)
	_add_button(vbox, "存档槽位 2（空）", Vector2(360, 56), 18).disabled = true
	_add_button(vbox, "存档槽位 3（空）", Vector2(360, 56), 18).disabled = true
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	vbox.add_child(row)
	var btn_save := _add_button(row, "保存", Vector2(110, 48), 18)
	btn_save.pressed.connect(func():
		if GameState.save_game():
			manager._change_state(manager.State.PAUSE)
	)
	var btn_load := _add_button(row, "读取", Vector2(110, 48), 18)
	btn_load.disabled = not GameState.has_save()
	btn_load.pressed.connect(func():
		if GameState.load_game():
			manager._change_state(manager.State.GAME_HUD)
	)
	var btn_del := _add_button(row, "删除", Vector2(110, 48), 18)
	btn_del.disabled = not GameState.has_save()
	btn_del.pressed.connect(func():
		GameState.delete_save()
		manager._change_state(manager.State.PAUSE)
	)
	var back := _add_button(vbox, "返回", Vector2(200, 48), 18)
	back.pressed.connect(func(): manager._change_state(manager.State.PAUSE))
	return root

# ---------------- 结算菜单 ----------------
func _build_result() -> Control:
	var root := _page("ResultScreen")
	_add_mask(root, Color(0, 0, 0, 0.75))
	var center := _add_center(root)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	center.add_child(vbox)
	result_title = Label.new()
	result_title.text = "胜利！"
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_color_override("font_color", manager.COL_ACCENT)
	UITextBox.apply_basic(result_title, "bold", 56)
	vbox.add_child(result_title)
	var back := _add_button(vbox, "返回主菜单", Vector2(260, 60), 22)
	back.pressed.connect(func(): 
		get_tree().paused = false
		StageRouter.goto_scene("res://stages/shared/title_main.tscn")
	)
	return root

# ---------------- 起名菜单 (1:1 复刻 VN 样式) ----------------
func _build_naming() -> Control:
	var root := _page("Naming")
	_add_mask(root, Color(0, 0, 0, 0.3))
	
	var box = UITextBox.DialogueBoxDrawer.new()
	box.anchor_left = 0.0; box.anchor_right = 1.0
	box.anchor_top = 1.0; box.anchor_bottom = 1.0
	box.offset_top = -160
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_theme_color = manager.COL_ACCENT
	root.add_child(box)
	
	var name_label = Label.new()
	name_label.text = "我……是谁？"
	name_label.position = Vector2(15, 0) 
	name_label.size = Vector2(200, 36)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITextBox.apply_basic(name_label, "bold", 18)
	name_label.add_theme_color_override("font_color", Color(1,1,1))
	box.add_child(name_label)
	box.name_width = 220
	
	name_input = LineEdit.new()
	name_input.placeholder_text = "输入勇者的名字……"
	name_input.anchor_right = 1.0; name_input.anchor_bottom = 1.0
	name_input.offset_left = 40; name_input.offset_right = -40
	name_input.offset_top = 65; name_input.offset_bottom = -20
	name_input.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	name_input.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	name_input.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UITextBox.apply_basic(name_input, "normal", 22)
	name_input.add_theme_color_override("font_color", Color(1, 1, 1))
	name_input.add_theme_color_override("font_placeholder_color", Color(0.5, 0.5, 0.5))
	box.add_child(name_input)
	
	var choice_container = VBoxContainer.new()
	choice_container.anchor_left = 0.5; choice_container.anchor_right = 1.0
	choice_container.anchor_top = 0.2; choice_container.anchor_bottom = 0.8
	choice_container.offset_right = -20.0
	choice_container.add_theme_constant_override("separation", 20)
	choice_container.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(choice_container)
	
	var btn_ok = UITextBox.ChoiceButton.new(manager.COL_ACCENT)
	btn_ok.set_custom_text("确认")
	btn_ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn_ok.pressed.connect(func(): 
		if name_input.text.strip_edges() == "":
			name_input.placeholder_text = "⚠️ 不能为空。"
			name_input.add_theme_color_override("font_placeholder_color", Color(0.89, 0.278, 0.239))
			return
		manager.confirm_naming(name_input.text, null))
	choice_container.add_child(btn_ok)
	
	var btn_skip = UITextBox.ChoiceButton.new(manager.COL_ACCENT)
	btn_skip.set_custom_text("「白柯」。（跳过）")
	btn_skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn_skip.pressed.connect(func():
		name_input.text = ""
		manager._change_state(manager.State.GAME_HUD))
	choice_container.add_child(btn_skip)
	
	var btn_back = UITextBox.ChoiceButton.new(manager.COL_ACCENT)
	btn_back.set_custom_text("返回")
	btn_back.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn_back.pressed.connect(func(): manager._change_state(manager.State.MAIN_MENU))
	choice_container.add_child(btn_back)
	
	name_input.text_changed.connect(func(_txt):
		name_input.placeholder_text = "输入一个名字……"
		name_input.add_theme_color_override("font_placeholder_color", Color(0.5, 0.5, 0.5))
	)
	
	return root

# ---------------- 关于我们（制作组名单） ----------------
func _build_credits() -> Control:
	var root := _page("Credits")
	_add_mask(root, manager.COL_MASK)
	var center := _add_center(root)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(640, 560)
	panel.add_theme_stylebox_override("panel", _make_style(manager.COL_PANEL_BG, manager.COL_BORDER, 2))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_set_full_rect(vbox)
	vbox.offset_left = 40; vbox.offset_top = 28; vbox.offset_right = -40; vbox.offset_bottom = -28
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "关 于 我 们"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", manager.COL_TEXT)
	UITextBox.apply_basic(title, "bold", 30)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "异世界福瑞勇者 · 犬六回"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", manager.COL_TEXT_DIM)
	UITextBox.apply_basic(sub, "normal", 14)
	vbox.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 18)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var credits := [
		["贺子成", "主策划 · 主程序 · 文案\nUI/VN 架构重构与美化 · 美术方向指导 · 宣发"],
		["江俊皓", "创意/数值策划 · 主美术 · 宣发"],
		["蔡圣钦", "VN 程序（前期基础框架）· 测试"],
		["袁鸿韬", "UI 程序（前期基础界面）· 测试"],
		["潘怀翰", "测试 · 线下摆摊与宣发策划"],
	]
	for entry in credits:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		list.add_child(row)
		var name_l := Label.new()
		name_l.text = str(entry[0])
		name_l.add_theme_color_override("font_color", manager.COL_ACCENT)
		UITextBox.apply_basic(name_l, "bold", 20)
		row.add_child(name_l)
		var role_l := Label.new()
		role_l.text = str(entry[1])
		role_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		role_l.add_theme_color_override("font_color", manager.COL_TEXT)
		UITextBox.apply_basic(role_l, "normal", 15)
		row.add_child(role_l)

	var btn_back := _add_text_button(vbox, "返 回", 20)
	btn_back.pressed.connect(func(): manager._change_state(manager.State.MAIN_MENU))
	return root

# ---------------- 玩法指导（v1.18，主菜单入口；金色主题，格式与"关于我们"同款框式） ----------------
func _build_guide() -> Control:
	var root := _page("Guide")
	_add_mask(root, manager.COL_MASK)
	var center := _add_center(root)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(760, 640)
	panel.add_theme_stylebox_override("panel", _make_style(manager.COL_PANEL_BG, manager.COL_ACCENT, 2))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_set_full_rect(vbox)
	vbox.offset_left = 42; vbox.offset_top = 24; vbox.offset_right = -42; vbox.offset_bottom = -20
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "玩 法 指 导"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", manager.COL_ACCENT)
	UITextBox.apply_basic(title, "bold", 30)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "进入游戏前，先花一分钟了解这个世界的规则"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", manager.COL_TEXT_DIM)
	UITextBox.apply_basic(sub, "normal", 14)
	vbox.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	# [分区标题, [正文行...]]
	var sections := [
		["◆ 游戏概述", [
			"你将扮演转生到异世界的狼人勇者「白柯行以」，从木屋基地出发，穿越森林、密林、沙海与霜峰，揭开「回响之冠」的秘密。",
			"游戏融合横版动作战斗与卡牌构筑：击败敌人获取卡牌与材料，组装专属的技能、武器与装备，逐关深入并迎接双结局。",
		]],
		["◆ 基础操作", [
			"A/D 或 ←/→ 移动 · Space 跳跃 · 双击 A/D（或 Shift）冲刺 · 空中按 S / ↓ 下坠冲击",
			"J 或鼠标左键普攻：三段连击，长按蓄力斩，冲刺中攻击触发重击",
			"E 交互 · Esc 暂停 · C 技能页 / B 武器页 / V 装备页 / N 图鉴 / O 成就",
		]],
		["◆ 战斗与资源", [
			"技能槽：把技能卡拖入右侧 4 个槽位，战斗中按 1/2/3/4 释放；每个槽施放后有 0.5 秒公共冷却",
			"BP（蓝条）：释放技能消耗 BP，每 4 秒自动回复 1 点，上限随成长提升；蓝条见底时先用普攻过渡",
			"善用冲刺取消与蓄力斩打断敌人节奏，下坠冲击适合突入敌阵收尾",
		]],
		["◆ 卡牌成长", [
			"单击卡牌查看属性并选中，双击装备/使用；卡槽内卡牌单击看属性、双击取回",
			"装备卡双击穿戴，攻击·生命·护盾直接加成；武器槽（B 键）用于整理常用武器卡，不占按键",
			"升级：右上【升级】按钮消耗 BP（Lv1~3 每次 1 点 / Lv4~9 每次 2 点），每级倍率 +0.2，上限 Lv.9",
		]],
		["◆ 技能分支", [
			"技能详情页点【技能分支】展开；Lv.3 解锁第 1 个、Lv.5 解锁第 2 个（各消耗 1 点 BP），点【使用】切换生效分支",
			"火球术（两段式）：第一段生成悬浮火球；第二段再按技能键或鼠标左键点击，朝鼠标方向发射（该次点击不会普攻）",
			"　· 连珠火弹：一次两发同向，第二发延迟 0.2 秒，每发 60% 伤害，冷却 80%",
			"　· 爆炎术：体积与伤害翻倍，冷却 1.5 倍",
			"妙手回春：迅愈——冷却缩短至 2/3，一次两段治疗各 60%（间隔 1 秒，共 120%）；铁壁润泽——治疗 80%，8 秒内护盾值与上限各 +2，到期护盾值 -2（不足则归零，不扣血）",
		]],
		["◆ 基地与生活", [
			"木屋基地可摆放家具（床、盾架、锻造台、卡盒、沙漏），提供永久属性加成",
			"采集材料后可烹饪食物、酿造药水、锻造装备；装备品阶越高，词缀越多",
		]],
		["◆ 图鉴 · 成就 · 存档", [
			"图鉴（N）：记录击败过的敌人情报；成就（O）：挑战进度与奖励一览",
			"本作为手动存档：暂停菜单 → 存档；读档后从基地继续冒险",
			"通关后开启周目，继承加成，以更强的姿态再战一次",
		]],
	]
	for sec in sections:
		var head := Label.new()
		head.text = str(sec[0])
		head.add_theme_color_override("font_color", manager.COL_ACCENT)
		UITextBox.apply_basic(head, "bold", 17)
		list.add_child(head)
		for line in sec[1]:
			var l := Label.new()
			l.text = str(line)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.add_theme_color_override("font_color", manager.COL_TEXT)
			UITextBox.apply_basic(l, "normal", 14)
			list.add_child(l)

	var btn_back := _add_text_button(vbox, "返 回", 20)
	btn_back.pressed.connect(func(): manager._change_state(manager.State.MAIN_MENU))
	return root

# ---------------- 更新日志（v1.12 绿色主题） ----------------
func _build_changelog() -> Control:
	var root := _page("Changelog")
	_add_mask(root, manager.COL_MASK)
	var center := _add_center(root)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(700, 620)
	var green_bg := Color(0.07, 0.15, 0.11, 0.97)
	var green_border := Color(0.25, 0.75, 0.42, 1.0)
	var green_title := Color(0.45, 0.95, 0.60)
	var green_dot := Color(0.30, 0.85, 0.50)
	panel.add_theme_stylebox_override("panel", _make_style(green_bg, green_border, 2))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_set_full_rect(vbox)
	vbox.offset_left = 42; vbox.offset_top = 26; vbox.offset_right = -42; vbox.offset_bottom = -26
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "更 新 日 志"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", green_title)
	UITextBox.apply_basic(title, "bold", 30)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var versions := [
		["v1.12", "2026-10-29 · 本次更新", [
			"战斗重做：J 键攻击（鼠标左键已停用），三段连击 + 攻击缓存，节奏更快更流畅",
			"新增 Shift 冲刺：平滑加速、滑行收尾；冲刺中按 J 可直接取消，打出前冲斩",
			"修复基础怪物（史莱姆等）呆站不战斗的问题：现在会主动追击、受伤硬直、阵亡掉落",
			"采集物刷新 30 秒 → 90 秒（品质越高越久），传送走再回来也不会瞬间复活",
			"修复 17 个关卡与标题界面的地面碰撞错位：走路不再陷进地里",
			"背包 / 技能教学引导：首次打开有指南，首次进关显示操作面板（12 秒淡出）",
			"新增「关于我们」制作组名单页",
			"助战勇者换上专属立绘：雪枭霰 / 岩羊磐 / 赤狐焰璃 / 水獭汐",
			"存档说明：本作仅手动存档（保存进度 / 小憩），无自动存档",
		]],
		["v1.11", "周目轮回", [
			"通关全部 15 关后开启新轮回：最多 6 周目，每周目敌人更强、你也更强",
		]],
		["v1.10", "成就 · 词缀 · 地图", [
			"成就系统（16+ 隐藏）、装备随机词缀、远征石地图传送",
		]],
		["v1.9", "AI · 图鉴 · 音频 · 隐藏关", [
			"敌人 AI 多样化、关卡指引、怪物图鉴、音频总线、2 个隐藏关卡",
		]],
		["v1.8", "队友助战", [
			"盟约石碑召唤福瑞勇者助战 60 秒，自动跟随并攻击敌人",
		]],
		["v1.4 - v1.7", "基础系统", [
			"手动存档、技能分支与双结局、Boss 二阶段、食物烹饪、药水酿造",
		]],
	]
	for v in versions:
		var head := Label.new()
		head.text = "%s    %s" % [str(v[0]), str(v[1])]
		head.add_theme_color_override("font_color", green_title)
		UITextBox.apply_basic(head, "bold", 20)
		list.add_child(head)
		for item in v[2]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			list.add_child(row)
			var dot := Label.new()
			dot.text = "●"
			dot.add_theme_color_override("font_color", green_dot)
			UITextBox.apply_basic(dot, "normal", 13)
			row.add_child(dot)
			var text_l := Label.new()
			text_l.text = str(item)
			text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text_l.add_theme_color_override("font_color", manager.COL_TEXT)
			UITextBox.apply_basic(text_l, "normal", 14)
			row.add_child(text_l)

	var btn_back := _add_text_button(vbox, "返 回", 20)
	btn_back.pressed.connect(func(): manager._change_state(manager.State.MAIN_MENU))
	return root

# ---------------- 通用小工具函数 ----------------
func _add_slider_row(parent: Control, title: String, initial: int) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size = Vector2(64, 0)
	name_label.add_theme_color_override("font_color", manager.COL_TEXT_DIM)
	UITextBox.apply_basic(name_label, "normal", 16, 0)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = 0; slider.max_value = 100; slider.step = 1; slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.text = "%d%%" % initial
	value_label.custom_minimum_size = Vector2(56, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", manager.COL_TEXT)
	UITextBox.apply_basic(value_label, "number", 16)
	row.add_child(value_label)
	slider.value_changed.connect(func(v: float): value_label.text = "%d%%" % int(v))
	return slider

func _page(node_name: String) -> Control:
	var c := Control.new()
	c.name = node_name
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _add_mask(parent: Control, color: Color) -> void:
	var mask := ColorRect.new()
	mask.color = color
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(mask)

func _add_center(parent: Control) -> CenterContainer:
	var center := CenterContainer.new()
	_set_full_rect(center)
	parent.add_child(center)
	return center

func _add_button(parent: Control, text: String, btn_size: Vector2, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = btn_size
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_color_override("font_color", manager.COL_TEXT)
	btn.add_theme_stylebox_override("normal", _make_style(manager.COL_PANEL_BG, manager.COL_BORDER, 2))
	btn.add_theme_stylebox_override("hover", _make_style(manager.COL_PANEL_BG, manager.COL_ACCENT, 2))
	UITextBox.apply_basic(btn, "bold", font_size)
	parent.add_child(btn)
	return btn

func _add_text_button(parent: Control, text: String, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_color_override("font_color", manager.COL_TEXT)
	btn.add_theme_color_override("font_hover_color", manager.COL_ACCENT)
	btn.add_theme_color_override("font_pressed_color", manager.COL_ACCENT)
	btn.add_theme_color_override("font_focus_color", manager.COL_TEXT)
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	UITextBox.apply_basic(btn, "bold", font_size)
	btn.custom_minimum_size = Vector2(200, 50)
	parent.add_child(btn)
	return btn

func _icon_square_button(icon: String, label: String) -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var btn := Button.new()
	btn.text = icon
	btn.custom_minimum_size = Vector2(96, 96)
	btn.add_theme_color_override("font_color", manager.COL_TEXT_DARK)
	btn.add_theme_stylebox_override("normal", _make_style(Color(0.90, 0.90, 0.92), Color(0.45, 0.45, 0.50), 1))
	UITextBox.apply_basic(btn, "bold", 44, 0)
	box.add_child(btn)
	var lbl := Label.new()
	lbl.text = label
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", manager.COL_TEXT_DARK)
	UITextBox.apply_basic(lbl, "bold", 20, 0)
	box.add_child(lbl)
	return {"box": box, "btn": btn}

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _set_full_rect(c: Control) -> void:
	c.anchor_right = 1.0; c.anchor_bottom = 1.0

func _make_style(bg: Color, border: Color, bw: int, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg; style.border_color = border
	style.set_border_width_all(bw); style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.18); style.shadow_size = 5; style.shadow_offset = Vector2(0, 2)
	return style
