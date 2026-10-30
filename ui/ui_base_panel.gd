extends CanvasLayer
class_name UIBasePanel

## 客厅基地面板（锻造台 / 菜地 / 酿造台）
## 静态入口：UIBasePanel.open_panel(mode, owner) / close_panel()

static var _instance: UIBasePanel = null

var _mode := ""
var _owner: Node = null
var _content: VBoxContainer
var _footer: Label
var _title_label: Label

const ALL_MATERIALS := ["木料", "石料", "矿砂", "草叶", "胶质团", "苔核", "晶髓", "青石", "黑铁锭", "赤金锭", "血玉", "沼肥", "沙芦荟", "忆须草"]

static func open_panel(mode: String, owner: Node) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	if tree == null: return
	if _instance == null or not is_instance_valid(_instance):
		_instance = UIBasePanel.new()
		_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		_instance.layer = 120
		tree.root.add_child(_instance)
	_instance._build(mode, owner)
	tree.paused = true

static func close_panel() -> void:
	var tree: SceneTree = Engine.get_main_loop()
	if _instance and is_instance_valid(_instance):
		_instance._close()
	if tree: tree.paused = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ESCAPE, KEY_B]:
			get_viewport().set_input_as_handled()
			close_panel()

func _close() -> void:
	if _owner and _owner.has_method("on_panel_closed"):
		_owner.on_panel_closed()
	_owner = null
	queue_free()
	if _instance == self:
		_instance = null

# ================= 构建 =================
func _build(mode: String, owner: Node) -> void:
	# 清理旧内容
	for c in get_children():
		c.queue_free()
	_mode = mode
	_owner = owner

	var mask := ColorRect.new()
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.color = Color(0, 0, 0, 0.55)
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(mask)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := Panel.new()
	# v1.12-fix 放大面板：菜地一行 = 280px 标签 + 6 个种子按钮 ≈ 860px，原 640 宽必然右侧溢出；
	# 高度同步加大保证底部材料行不越界。CenterContainer 已保证面板在屏幕居中。
	panel.custom_minimum_size = Vector2(1000, 600)
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.13, 0.14, 0.18, 0.97), Color(0.45, 0.42, 0.5, 1.0), 2))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_set_full_rect(vbox)
	vbox.offset_left = 28; vbox.offset_top = 22; vbox.offset_right = -28; vbox.offset_bottom = -20
	panel.add_child(vbox)

	# 标题行
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vbox.add_child(head)
	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	UITextBox.apply_basic(_title_label, "bold", 24)
	head.add_child(_title_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close_btn := Button.new()
	close_btn.text = "✕ 关闭 (Esc)"
	close_btn.custom_minimum_size = Vector2(130, 36)
	close_btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	close_btn.add_theme_stylebox_override("normal", _make_style(Color(0.35, 0.18, 0.18, 1.0), Color(0.6, 0.3, 0.3, 1.0), 1))
	close_btn.pressed.connect(func(): close_panel())
	head.add_child(close_btn)

	# 滚动内容区
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)

	# 底部材料行
	_footer = Label.new()
	_footer.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITextBox.apply_basic(_footer, "normal", 13)
	vbox.add_child(_footer)

	match _mode:
		"forge":
			_title_label.text = "🔨 锻台 — 装备强化"
		"farm":
			_title_label.text = "🌱 菜地 — 种植与收获"
		"brew":
			_title_label.text = "🧪 酿造台 — 药剂合成"
		"save":
			_title_label.text = "🛏️ 卧室 — 存档与休息"
		"ally":
			_title_label.text = "🐾 盟约石碑 — 勇者助战"
		"map":
			_title_label.text = "🗺️ 远征石 — 地图传送"
		"reincarnate":
			_title_label.text = "🌀 轮回之镜 — 周目轮回"

	_refresh()

func _refresh() -> void:
	if _content == null: return
	# 立即从树移除（queue_free 只是延迟释放，旧行会残留一帧）
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	match _mode:
		"forge":
			_build_forge()
		"farm":
			_build_farm()
		"brew":
			_build_brew()
		"save":
			_build_save()
		"ally":
			_build_ally()
		"map":
			_build_map()
		"reincarnate":
			_build_reincarnate()
	_refresh_footer()

func _refresh_footer() -> void:
	if _footer == null: return
	var parts := ["$ %d" % GameState.gold]
	for m in ALL_MATERIALS:
		parts.append("%s×%d" % [m, GameState.count_material(m)])
	_footer.text = "  ".join(PackedStringArray(parts))

# ================= 锻造台 =================
func _build_forge() -> void:
	_add_tip("消耗金币与材料永久强化装备（每级 +1 攻击 / +2 生命 / +2 护盾，上限 +5）。")
	var types := [EquipmentData.Type.WEAPON, EquipmentData.Type.HELMET, EquipmentData.Type.ARMOR, EquipmentData.Type.PANTS, EquipmentData.Type.ACCESSORY]
	for t in types:
		var item = GameState.equipped_items.get(t)
		if item == null:
			_add_row("（空槽位）", "", null)
			continue
		var lv := GameState.get_gear_upgrade_level(item)
		var name_text := "%s  +%d" % [item.item_name, lv]
		var preview := ""
		if lv < GameState.GEAR_UPGRADE_MAX:
			if item.attack_bonus > 0: preview = "强化后 攻击+%d" % (lv + 1)
			elif item.hp_bonus > 0: preview = "强化后 生命+%d" % ((lv + 1) * 2)
			elif item.shield_bonus > 0: preview = "强化后 护盾+%d" % ((lv + 1) * 2)
			else: preview = "强化后 全属性提升"
		else:
			preview = "已满级"
		var cost := GameState.get_gear_upgrade_cost(item)
		var btn_text := "强化（$%d 木料%d 矿砂%d）" % [int(cost["gold"]), int(cost["mats"]["木料"]), int(cost["mats"]["矿砂"])]
		var can := lv < GameState.GEAR_UPGRADE_MAX and GameState.gold >= int(cost["gold"]) \
			and GameState.count_material("木料") >= int(cost["mats"]["木料"]) \
			and GameState.count_material("矿砂") >= int(cost["mats"]["矿砂"])
		var btn := _make_button(btn_text, can)
		btn.pressed.connect(func():
			if GameState.upgrade_gear(item):
				_refresh()
		)
		_add_row(name_text, preview, btn)

	# --- v1.2 图纸打造 ---
	_add_section("📜 图纸打造（一次性获得，自动入库）")
	for recipe in GameState.GEAR_RECIPES:
		var rid := String(recipe["id"])
		var rname := String(recipe["name"])
		var owned := GameState.has_crafted(rid)
		var stat_text := "攻+%d 血+%d 盾+%d" % [int(recipe["atk"]), int(recipe["hp"]), int(recipe["shield"])]
		if float(recipe["crit"]) > 0.0:
			stat_text += " 暴击+%d%%" % int(float(recipe["crit"]) * 100)
		var cost_d: Dictionary = recipe["cost"]
		var mats_d: Dictionary = cost_d["mats"]
		var mat_text := ""
		var can_c := not owned
		for m in mats_d:
			var need := int(mats_d[m])
			mat_text += "%s×%d " % [m, need]
			if GameState.count_material(m) < need: can_c = false
		if GameState.gold < int(cost_d["gold"]): can_c = false
		var btn_text := "已拥有" if owned else "打造（$%d %s）" % [int(cost_d["gold"]), mat_text]
		var cbtn := _make_button(btn_text, can_c)
		if not owned:
			cbtn.pressed.connect(func():
				var made := GameState.craft_gear(rid)
				if made != null:
					GameState.equip_item(made)
					_refresh()
			)
		_add_row("%s — %s" % [rname, stat_text], String(recipe["desc"]), cbtn)

	# --- v1.2 采集工具升级 ---
	_add_section("⛏️ 采集工具（提升野外采集产量）")
	var tool_name := GameState.get_gather_tool_name()
	var tool_mult := GameState.get_gather_multiplier()
	var tool_lv := GameState.gather_tool_tier
	var tool_preview := "当前产量 ×%.1f" % tool_mult
	if tool_lv < GameState.GATHER_TOOLS.size() - 1:
		var up_cost: Dictionary = GameState.GATHER_TOOL_UPGRADE_COSTS[tool_lv]
		var up_mats: Dictionary = up_cost["mats"]
		var up_mat_text := ""
		var up_can := GameState.gold >= int(up_cost["gold"])
		for m in up_mats:
			var need := int(up_mats[m])
			up_mat_text += "%s×%d " % [m, need]
			if GameState.count_material(m) < need: up_can = false
		var next_name := String(GameState.GATHER_TOOLS[tool_lv + 1]["name"])
		var ubtn := _make_button("升级为%s（$%d %s）" % [next_name, int(up_cost["gold"]), up_mat_text], up_can)
		ubtn.pressed.connect(func():
			if GameState.upgrade_gather_tool():
				_refresh()
		)
		_add_row("%s（档位 %d/3）" % [tool_name, tool_lv], tool_preview, ubtn)
	else:
		_add_row("%s（已满档）" % tool_name, tool_preview, null)

# ================= 菜地 =================
func _build_farm() -> void:
	_add_tip("播种消耗 1 份种子材料；肥力缩短生长时间并提高高产概率；击杀怪物加速全场生长。")
	# 解锁新地块行
	if GameState.farm_plots.size() < GameState.MAX_FARM_PLOTS:
		var exp_btn := _make_button("开垦新地块（$%d）" % GameState.FARM_EXPAND_GOLD, GameState.gold >= GameState.FARM_EXPAND_GOLD)
		exp_btn.pressed.connect(func():
			if GameState.unlock_farm_plot():
				_refresh()
		)
		_add_row("地块 %d / %d" % [GameState.farm_plots.size(), GameState.MAX_FARM_PLOTS], "解锁后即可播种", exp_btn)
	for i in GameState.farm_plots.size():
		var state := GameState.get_farm_state(i)
		var fert := GameState.get_farm_fertility(i)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 40)
		var label := Label.new()
		label.custom_minimum_size = Vector2(280, 0)
		label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
		UITextBox.apply_basic(label, "normal", 15)
		row.add_child(label)
		var fert_text := "肥力 %d" % fert
		if state == 0:
			label.text = "地块 %d：空地（%s）" % [i + 1, fert_text]
			for seed in GameState.CROP_DEFS:
				var cdef: Dictionary = GameState.CROP_DEFS[seed]
				var cnt := GameState.count_material(seed)
				var sbtn := _make_button("种%s×1" % seed, cnt > 0)
				sbtn.tooltip_text = "%s：%.0f 秒成熟" % [String(cdef["desc"]), float(cdef["grow"])]
				sbtn.pressed.connect(func():
					if GameState.remove_material(seed, 1):
						GameState.plant_crop(i, seed)
						_refresh()
				)
				row.add_child(sbtn)
		elif state == 1:
			var remain := GameState.get_farm_remain(i)
			label.text = "地块 %d：生长中 %.1fs（%s）" % [i + 1, remain, fert_text]
		else:
			var seed := GameState.get_farm_seed(i)
			label.text = "地块 %d：✅ %s 成熟！（%s）" % [i + 1, seed, fert_text]
			var hbtn := _make_button("收获", true)
			hbtn.pressed.connect(func():
				var y := GameState.harvest_plot(i)
				if y > 0:
					GameState.add_material(seed, y)
				_refresh()
			)
			row.add_child(hbtn)
		# 施肥按钮（沼肥×1）
		if fert < 3:
			var fbtn := _make_button("施肥×1", GameState.count_material("沼肥") > 0)
			fbtn.pressed.connect(func():
				if GameState.fertilize_plot(i):
					_refresh()
			)
			row.add_child(fbtn)
		_content.add_child(row)

	# --- v1.6 厨房：食用作物获得短时增益 ---
	_add_section("🍽️ 厨房（食用作物：回血或短时增益）")
	for crop in GameState.CROP_FOOD_EFFECTS:
		var fx: Dictionary = GameState.CROP_FOOD_EFFECTS[crop]
		var cnt := GameState.count_material(crop)
		var ebtn := _make_button("食用×1", cnt > 0)
		ebtn.pressed.connect(func():
			if GameState.eat_crop(crop):
				_refresh()
		)
		_add_row("%s（持有 %d）" % [crop, cnt], String(fx["desc"]), ebtn)

# ================= 酿造台 =================
func _build_brew() -> void:
	_add_tip("用探险收集的材料酿造药剂，产出可囤积的药水（战斗中按 Q 快速喝治疗药剂）。")
	# --- 药水库存 ---
	_add_section("🎒 药水库存")
	for pid in GameState.POTION_ITEMS:
		var item: Dictionary = GameState.POTION_ITEMS[pid]
		var cnt := GameState.get_potion_count(pid)
		var ubtn := _make_button("饮用×1", cnt > 0)
		ubtn.pressed.connect(func():
			if GameState.use_potion(pid):
				_refresh()
		)
		var hotkey := String(item.get("hotkey", ""))
		var hk_text := "（按 %s 快速饮用）" % hotkey if hotkey != "" else ""
		_add_row("%s ×%d" % [String(item["name"]), cnt], "%s%s" % [String(item["desc"]), hk_text], ubtn)
	# --- 酿造配方 ---
	_add_section("🧪 酿造配方")
	for recipe_id in GameState.POTION_RECIPES:
		var recipe: Dictionary = GameState.POTION_RECIPES[recipe_id]
		var mats: Dictionary = recipe["mats"]
		var mat_text := ""
		var can := true
		for m in mats:
			var need := int(mats[m])
			var have := GameState.count_material(m)
			mat_text += "%s×%d " % [m, need]
			if have < need: can = false
		var btn := _make_button("酿造", can)
		btn.pressed.connect(func():
			if GameState.brew_potion(recipe_id):
				_refresh()
		)
		var desc_text := "%s — %s（%s）" % [recipe_id, String(recipe.get("desc", "")), mat_text]
		_add_row(desc_text, "", btn)

# ================= 盟约石碑（勇者助战） =================
func _build_ally() -> void:
	_add_tip("与勇者立下盟约：助战 60 秒，自动跟随并攻击敌人（同时只能有一名；切换关卡后盟约结束）。")
	if GameState.has_active_companion():
		var cur_name := "未知"
		var ac = GameState.active_companion
		if ac != null and ac.get("data") != null:
			cur_name = String(ac.data.get("name", "未知"))
		var dbtn := _make_button("解除盟约", true)
		dbtn.custom_minimum_size = Vector2(200, 40)
		dbtn.pressed.connect(func():
			GameState.dismiss_companion()
			_refresh()
		)
		_add_row("当前助战：%s" % cur_name, "提前解除不返还消耗", dbtn)
	else:
		_add_row("当前助战：无", "召唤一名勇者开始助战", null)
	for cid in GameState.COMPANION_DEFS:
		var d: Dictionary = GameState.COMPANION_DEFS[cid]
		var cost: Dictionary = d["cost"]
		var mats: Dictionary = cost["mats"]
		var mat_text := ""
		var can := GameState.gold >= int(cost["gold"])
		for m in mats:
			var need := int(mats[m])
			mat_text += "%s×%d " % [m, need]
			if GameState.count_material(m) < need: can = false
		var sbtn := _make_button("召唤（$%d %s）" % [int(cost["gold"]), mat_text], can)
		sbtn.pressed.connect(func():
			if GameState.summon_companion(cid):
				close_panel()
		)
		_add_row("%s — 攻击 %d / %.0f 秒" % [String(d["name"]), int(d["attack"]), float(d["duration"])], String(d["desc"]), sbtn)

# ================= 远征石（地图传送） =================
func _build_map() -> void:
	_add_tip("远征石记录着你的足迹：可以传送到任何已解锁的关卡。未解锁的关卡需要先推进主线。")
	# 一键传送到最深处
	var idx: int = GameState.get_furthest_stage_index()
	var finfo: Dictionary = GameState.CHAPTER_STAGES[idx]
	var fbtn := _make_button("🌌 传送到最深处", true)
	fbtn.custom_minimum_size = Vector2(220, 40)
	fbtn.pressed.connect(func():
		close_panel()
		GameState.next_spawn_id = ""
		GameState.use_custom_spawn_pos = false
		StageRouter.goto_scene(String(finfo["path"]))
	)
	_add_row("最深处：第 %d 关 · %s" % [idx + 1, String(finfo["name"])], "一键继续征程", fbtn)
	_add_section("🗺️ 关卡列表")
	for i in range(GameState.CHAPTER_STAGES.size()):
		var info: Dictionary = GameState.CHAPTER_STAGES[i]
		var unlocked := GameState.is_stage_index_unlocked(i)
		var cleared := GameState.is_stage_cleared(String(info["id"]))
		var boss := String(info["id"]).ends_with("5")   # ch*_5 均为 Boss 关
		var name_text := ("👑 " if boss else "") + String(info["name"]) + (" ✓" if cleared else "")
		if unlocked:
			var tbtn := _make_button("传送", true)
			var p := String(info["path"])
			tbtn.pressed.connect(func():
				close_panel()
				GameState.next_spawn_id = ""
				GameState.use_custom_spawn_pos = false
				StageRouter.goto_scene(p)
			)
			_add_row(name_text, "已解锁", tbtn)
		else:
			_add_row(name_text, "未解锁 — 推进主线后开放", null)

# ================= 轮回之镜（周目轮回） =================
func _build_reincarnate() -> void:
	_add_tip("犬六回，回回皆是新生。通关全部 15 关后，可在此开启新的轮回：关卡进度重置，等级、装备、材料、图鉴与成就全部保留。")
	var cleared := 0
	for info in GameState.CHAPTER_STAGES:
		if GameState.is_stage_cleared(String(info["id"])):
			cleared += 1
	_add_row("当前周目：%s（第 %d 回）" % [ReincarnationData.cycle_name(GameState.reincarnation_count), GameState.reincarnation_count + 1],
		ReincarnationData.bonus_summary(GameState.reincarnation_count), null)
	_add_row("主线进度：%d / 15 关" % cleared,
		"轮回需要先通关全部 15 关" if cleared < 15 else "已满足轮回条件", null)

	if not GameState.is_reincarnation_unlocked():
		_add_section("🔒 轮回未解锁")
		var lock := Label.new()
		lock.text = "镜面沉寂如水——通往%s的路还未走完。" % ReincarnationData.cycle_name(GameState.reincarnation_count + 1)
		lock.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITextBox.apply_basic(lock, "normal", 14)
		_content.add_child(lock)
		return

	if GameState.reincarnation_count >= ReincarnationData.MAX_CYCLES:
		_add_section("🌕 六回圆满")
		var done := Label.new()
		done.text = "六回圆满，轮回之镜的光芒已归于平静。所有的故事都已讲完。"
		done.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
		done.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITextBox.apply_basic(done, "normal", 14)
		_content.add_child(done)
		return

	_add_section("🌀 开启新的轮回")
	# 注意：GDScript lambda 按值捕获局部变量，确认状态必须放引用类型（Dictionary）里
	var arm := {"on": false}
	var btn := _make_button("🌀 确认轮回", true)
	btn.custom_minimum_size = Vector2(220, 40)
	var warn := Label.new()
	warn.text = "轮回后：关卡进度重置（可重新挑战）；等级/装备/材料/图鉴/成就保留。"
	warn.add_theme_color_override("font_color", Color(0.95, 0.75, 0.6))
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITextBox.apply_basic(warn, "normal", 13)
	_content.add_child(warn)
	btn.pressed.connect(func():
		if not arm["on"]:
			arm["on"] = true
			btn.text = "⚠️ 再次点击确认（不可逆）"
			btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
			warn.text = "再次点击将立刻进入%s：敌人将更强，你也将更强。" % ReincarnationData.cycle_name(GameState.reincarnation_count + 1)
			return
		var nc := GameState.do_reincarnate()
		if nc >= 0:
			close_panel()
	)
	_add_row("进入 %s" % ReincarnationData.cycle_name(GameState.reincarnation_count + 1),
		"敌人生命 +%d%% / 伤害 +%d%%；你获得攻击/生命加成" % [
			int(round((ReincarnationData.enemy_hp_scale(1) - 1.0) * 100)),
			int(round((ReincarnationData.enemy_dmg_scale(1) - 1.0) * 100))], btn)

# ================= 卧室（存档） =================
func _build_save() -> void:
	_add_tip("本游戏没有自动存档：只有点击下方「保存进度」或「小憩」时，进度（等级、金币、材料、装备、通关记录、菜地与设置）才会写入存档文件。")
	_add_section("💾 进度存档")
	var info := Label.new()
	info.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITextBox.apply_basic(info, "normal", 14)
	if GameState.has_save():
		info.text = "当前进度：%s\n存档文件：%s" % [GameState.get_save_summary(), GameState.SAVE_PATH]
	else:
		info.text = "尚未有过存档。保存后即使关闭游戏，进度也不会丢失。"
	_content.add_child(info)

	var save_btn := _make_button("💾 保存进度", true)
	save_btn.custom_minimum_size = Vector2(220, 40)
	save_btn.pressed.connect(func():
		if GameState.save_game():
			_refresh()
	)
	_add_row("保存当前进度", "覆盖旧存档", save_btn)

	if GameState.has_save():
		var load_btn := _make_button("📂 读取进度", true)
		load_btn.custom_minimum_size = Vector2(220, 40)
		load_btn.pressed.connect(func():
			if GameState.load_game():
				_refresh()
		)
		_add_row("读取上次保存", "当前未保存的进度会丢失", load_btn)
		var del_btn := _make_button("🗑️ 删除存档", true)
		del_btn.custom_minimum_size = Vector2(220, 40)
		del_btn.add_theme_color_override("font_color", Color(0.95, 0.6, 0.6))
		del_btn.pressed.connect(func():
			GameState.delete_save()
			_refresh()
		)
		_add_row("删除存档", "清空后从序章重新开始", del_btn)

	_add_section("🌙 休息")
	var rest_tip := Label.new()
	rest_tip.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
	rest_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITextBox.apply_basic(rest_tip, "normal", 13)
	rest_tip.text = "小憩片刻：保存进度并把时间推到清晨，怪物掉落的夜间加成会重置。"
	_content.add_child(rest_tip)
	var rest_btn := _make_button("🌅 小憩（保存并进入清晨）", true)
	rest_btn.custom_minimum_size = Vector2(260, 40)
	rest_btn.pressed.connect(func():
		GameState.save_game()
		GameState.day_time = 0.0
		GameState.hp = GameState.get_max_hp()
		GameState.bp = GameState.get_max_bp()
		GameState.current_shield = GameState.get_max_shield()
		_refresh()
	)
	_add_row("小憩", "保存 + 满血 + 时间推到清晨", rest_btn)

# ================= 通用组件 =================
func _add_tip(text: String) -> void:
	var tip := Label.new()
	tip.text = text
	tip.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITextBox.apply_basic(tip, "normal", 13)
	_content.add_child(tip)

func _add_section(text: String) -> void:
	var sec := Label.new()
	sec.text = "── %s ──" % text
	sec.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	sec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITextBox.apply_basic(sec, "bold", 16)
	_content.add_child(sec)

func _add_row(name_text: String, preview: String, btn: Button) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 40)
	var name_l := Label.new()
	name_l.text = name_text
	name_l.custom_minimum_size = Vector2(230, 0)
	name_l.add_theme_color_override("font_color", Color(0.92, 0.94, 0.97))
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITextBox.apply_basic(name_l, "normal", 15)
	row.add_child(name_l)
	var prev_l := Label.new()
	prev_l.text = preview
	prev_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev_l.add_theme_color_override("font_color", Color(0.55, 0.75, 0.55))
	prev_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITextBox.apply_basic(prev_l, "normal", 13)
	row.add_child(prev_l)
	if btn:
		btn.custom_minimum_size = Vector2(190, 34)
		row.add_child(btn)
	_content.add_child(row)

func _make_button(text: String, enabled: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.disabled = not enabled
	if enabled:
		btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
		btn.add_theme_stylebox_override("normal", _make_style(Color(0.30, 0.26, 0.16, 1.0), Color(0.75, 0.62, 0.30, 1.0), 1))
	else:
		btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.52))
		btn.add_theme_stylebox_override("normal", _make_style(Color(0.20, 0.20, 0.23, 1.0), Color(0.35, 0.35, 0.38, 1.0), 1))
	btn.add_theme_stylebox_override("hover", _make_style(Color(0.42, 0.36, 0.20, 1.0), Color(1.0, 0.85, 0.4, 1.0), 1))
	return btn

func _make_style(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(bw)
	st.set_corner_radius_all(6)
	return st

func _set_full_rect(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
