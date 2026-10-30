extends CanvasLayer

enum State { MAIN_MENU, SETTINGS, GAME_HUD, PAUSE, SAVE, BACKPACK, RESULT, NAMING, CREDITS, CHANGELOG, GUIDE }

const HIDE_MOUSE_IN_HUD := false
const COL_MASK := Color(0.08, 0.09, 0.12, 0.82)
const COL_MASK_LIGHT := Color(0.25, 0.26, 0.30, 0.72)
const COL_MASK_BAG := Color(0.2, 0.2, 0.2, 0.8)
const COL_PANEL_BG := Color(0.14, 0.15, 0.19, 0.96)
const COL_PANEL_WHITE := Color(0.96, 0.96, 0.97, 1.0)
const COL_BORDER := Color(0.40, 0.42, 0.50, 1.0)
const COL_TEXT := Color(0.94, 0.94, 0.96)
const COL_TEXT_DIM := Color(0.62, 0.64, 0.70)
const COL_TEXT_DARK := Color(0.10, 0.10, 0.12)
const COL_ACCENT := Color(1, 0.85, 0.4)
const COL_HP := Color(0.88, 0.28, 0.22)
const COL_SHIELD := Color(0.78, 0.79, 0.83)
const COL_BP := Color(0.36, 0.78, 0.36)
const COL_BURN := Color(0.85, 0.25, 0.20)
const COL_GRID_BOARD := Color(0.22, 0.22, 0.24, 1.0)
const COL_GRID_CELL := Color(0.34, 0.34, 0.37, 1.0)
const COL_CELL_BY_TYPE := {"技能": Color(0.52, 0.74, 0.95), "武器": Color(0.95, 0.62, 0.78), "饰品": Color(0.76, 0.62, 0.95), "装备": Color(0.55, 0.85, 0.62)}

const HUD_MARGIN := 24
const BAR_SIZE := Vector2(240, 20)
const QUICK_SIZE := Vector2(93, 144)
const QUICK_GAP := 19
const CELL_SIZE := Vector2(84, 84)
const DOUBLE_CLICK_MS := 350
const SLOT_CD_TIME := 0.5
const HUD_REFRESH_INTERVAL := 0.05

const FONT_PATH := "res://assets/fonts/cmdysj.ttf"

var current_state: int = State.GAME_HUD
var account_name: String = "玩家"
var game_state: Node = null
var scene_router: Node = null

var _hp: int = 10
var _max_hp: int = 10
var _bp: int = 3
var _max_bp: int = 3
var _shield: int = 1
var _max_shield: int = 1

var _combat_flag := false
var cards: Array[Dictionary] = []      
var _hud_refresh_accum: float = 0.0

var hud_ui: UIHUD
var menu_ui: UIMenus
var bag_ui: UIBackpack

func _ready() -> void:
	layer = 110 
	process_mode = Node.PROCESS_MODE_ALWAYS

	var ui_theme := Theme.new()
	if ResourceLoader.exists(FONT_PATH):
		var custom_font = load(FONT_PATH)
		if custom_font is Font:
			ui_theme.default_font = custom_font
			print("✅ [UI] 全局字体注入成功: %s" % FONT_PATH)
	else:
		print("⚠️ [UI] 字体加载失败，使用系统默认字体: %s" % FONT_PATH)

	hud_ui = UIHUD.new()
	hud_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_ui.theme = ui_theme
	hud_ui.bind_manager(self)
	add_child(hud_ui)

	bag_ui = UIBackpack.new()
	bag_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	bag_ui.theme = ui_theme
	bag_ui.bind_manager(self)
	add_child(bag_ui)

	menu_ui = UIMenus.new()
	menu_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_ui.theme = ui_theme
	menu_ui.bind_manager(self)
	add_child(menu_ui)

	_setup_integration()
	_on_cards_changed()                 
	_change_state(State.GAME_HUD)

func _setup_integration() -> void:
	game_state = get_node_or_null("/root/GameState")
	scene_router = get_node_or_null("/root/SceneRouter")

	_load_cards_from_tres()
	_restore_persisted_cards()   # v1.14 跨关卡恢复卡槽与装备状态
	_pull_game_state()

## v1.14 跨关卡持久化：按 base_id 恢复三个槽组与装备标志
func _restore_persisted_cards() -> void:
	if game_state == null: return
	if bag_ui == null or bag_ui.panel_skill == null: return
	# 装备标志由槽位归属推导：武器/装备槽里的卡牌 = 已装备
	# （GameState.equipped_items 为 autoload 常驻，数值无需重复 equip_item）
	for i in cards.size():
		var bid := str(cards[i]["base_id"])
		var in_slot: bool = bid in game_state.persisted_weapon_slots \
			or bid in game_state.persisted_equip_slots
		cards[i]["is_equipped"] = in_slot
		# v1.15 恢复跨关卡卡牌等级（无记录则保持扫描默认 Lv.1）
		cards[i]["level"] = game_state.get_card_level(bid)
	_fill_slots(bag_ui.panel_skill.skill_slot_cards, game_state.persisted_skill_slots, "技能")
	_fill_slots(bag_ui.panel_weapon.weapon_slot_cards, game_state.persisted_weapon_slots, "")
	_fill_slots(bag_ui.panel_equip.equip_slot_cards, game_state.persisted_equip_slots, "")
	bag_ui.skill_slot_cards = bag_ui.panel_skill.skill_slot_cards
	bag_ui.panel_skill.refresh_slots()
	bag_ui.panel_weapon.refresh_slots()
	bag_ui.panel_equip.refresh_slots()
	if game_state.persisted_skill_slots.any(func(s): return str(s) != ""):
		print("🔗 [UI] 已恢复跨关卡卡槽配置")

func _fill_slots(slot_arr: Array, id_arr: Array, type_filter: String) -> void:
	for s in mini(slot_arr.size(), id_arr.size()):
		var sid := str(id_arr[s])
		if sid == "": continue
		for i in cards.size():
			if str(cards[i]["base_id"]) != sid: continue
			if type_filter != "" and str(cards[i]["type"]) != type_filter: continue
			slot_arr[s] = i
			break

## v1.14：槽位变化时调用，把当前配置写入 GameState
func persist_card_state() -> void:
	if game_state == null: return
	if bag_ui == null or bag_ui.panel_skill == null: return
	_store_ids(bag_ui.panel_skill.skill_slot_cards, game_state.persisted_skill_slots)
	_store_ids(bag_ui.panel_weapon.weapon_slot_cards, game_state.persisted_weapon_slots)
	_store_ids(bag_ui.panel_equip.equip_slot_cards, game_state.persisted_equip_slots)

func _store_ids(slot_arr: Array, id_arr: Array) -> void:
	for s in mini(slot_arr.size(), id_arr.size()):
		var idx: int = int(slot_arr[s])
		id_arr[s] = str(cards[idx]["base_id"]) if idx >= 0 and idx < cards.size() else ""

func _process(delta: float) -> void:
	var dm = DialogueManager.instance()
	var is_vn_playing = dm._is_playing or dm._is_waiting_choice
	
	# 【核心修复】如果剧本已结束，但 UI 因为防闪烁机制（黑/白屏）保留，HUD 依然不显示
	if not is_vn_playing and dm._ui and is_instance_valid(dm._ui) and dm._ui._blocker.color.a > 0.9:
		is_vn_playing = true
		
	if hud_ui: hud_ui.set_vn_mode(is_vn_playing)
	
	if game_state and game_state.combat_ui_layer:
		game_state.combat_ui_layer.visible = not is_vn_playing

	hud_ui.tick_slot_cooldown(delta)
	
	_hud_refresh_accum += delta
	if _hud_refresh_accum < HUD_REFRESH_INTERVAL: return
	_hud_refresh_accum = 0.0
	
	_pull_game_state()
	if game_state:
		_combat_flag = game_state.active_combat_entities > 0
	hud_ui.refresh_hud()

func _on_cards_changed() -> void:
	_pull_game_state()
	hud_ui.refresh_hud()
	bag_ui.refresh_backpack()
	bag_ui.panel_equip.refresh_slots()

func confirm_naming(text: String, tip: Label) -> void:
	var t := text.strip_edges()
	if t == "":
		tip.text = "请先输入账号昵称，或点右侧「跳过（使用「玩家」）」"
		return
	if t.length() > 12: t = t.substr(0, 12)
	account_name = t
	print("✅ [UI] 账号昵称确认: %s" % account_name)
	_change_state(State.GAME_HUD)

func _change_state(new_state: int) -> void:
	current_state = new_state
	hud_ui.visible = (new_state in [State.GAME_HUD, State.PAUSE, State.SAVE])
	bag_ui.visible = (new_state == State.BACKPACK)
	menu_ui.visible = (new_state != State.GAME_HUD and new_state != State.BACKPACK)

	menu_ui.switch_page(new_state)
	if new_state == State.BACKPACK:
		bag_ui.open_tab(bag_ui.current_tab)

	get_tree().paused = (new_state in [State.PAUSE, State.SAVE, State.BACKPACK, State.RESULT])
	if new_state == State.GAME_HUD and HIDE_MOUSE_IN_HUD: Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else: Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _try_open_backpack(tab: int) -> void:
	if _combat_flag:
		if game_state and game_state.has_method("trigger_combat_warn"):
			game_state.trigger_combat_warn()
		return
	bag_ui.open_tab(tab)
	_change_state(State.BACKPACK)

func _unhandled_input(event: InputEvent) -> void:
	var dm = DialogueManager.instance()
	if dm._is_playing or dm._is_waiting_choice:
		return
		
	if event is not InputEventKey: return
	var key := event as InputEventKey
	if not key.pressed or key.echo: return

	match key.physical_keycode:
		KEY_C: _try_open_backpack(0)
		KEY_B: _try_open_backpack(1)
		KEY_V: _try_open_backpack(2)
		KEY_N: _try_open_backpack(3)   # v1.9 图鉴
		KEY_O: _try_open_backpack(4)   # v1.10 成就
		KEY_ESCAPE:
			if current_state == State.BACKPACK: _change_state(State.GAME_HUD)
			elif current_state == State.SAVE: _change_state(State.PAUSE)
		KEY_1: hud_ui.use_card_slot(0)
		KEY_2: hud_ui.use_card_slot(1)
		KEY_3: hud_ui.use_card_slot(2)
		KEY_4: hud_ui.use_card_slot(3)

func _pull_game_state() -> void:
	if game_state == null: return
	if game_state.get("hp") != null: _hp = int(game_state.get("hp"))
	if game_state.has_method("get_max_hp"): _max_hp = int(game_state.get_max_hp())
	if game_state.get("bp") != null: _bp = int(game_state.get("bp"))
	if game_state.get("max_bp") != null: _max_bp = int(game_state.get_max_bp())
	if game_state.get("current_shield") != null: _shield = int(game_state.get("current_shield"))
	if game_state.has_method("get_max_shield"): _max_shield = int(game_state.get_max_shield())

func _load_cards_from_tres() -> void:
	cards.clear()
	var total := 0
	total += _scan_dir("res://data/equipment")
	total += _scan_dir("res://data/skills")
	print("🗂️ [UI] 卡牌扫描完成，共 %d 张" % total)
	if total == 0:
		push_warning("⚠️ [UI] 未扫描到任何卡牌！检查：\n"
			+ "  1) res://data/equipment 与 res://data/skills 下是否有 .tres/.res；\n"
			+ "  2) 导出预设是否用 Export Selected Resources 排除了 data/**；\n"
			+ "  默认 Export All Resources in the Project 会包含全部 .tres。")

func _scan_dir(path: String) -> int:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("⚠️ [UI] 无法打开目录: %s" % path)
		return 0
	return _scan_tres_dir(dir, path)

func _scan_tres_dir(dir: DirAccess, path: String) -> int:
	var count := 0
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		var full := path + "/" + f
		if dir.current_is_dir() and not f.begins_with("."):
			var sub := DirAccess.open(full)
			if sub != null: count += _scan_tres_dir(sub, full)
		elif f.ends_with(".tres") or f.ends_with(".res"):
			if not ResourceLoader.exists(full):
				push_warning("⚠️ [UI] 资源不存在: %s" % full)
				f = dir.get_next()
				continue
			var res: Resource = load(full)
			if res == null:
				push_warning("⚠️ [UI] 资源加载失败: %s" % full)
			elif res is EquipmentData:
				var tname := "装备"
				if res.equip_type == EquipmentData.Type.WEAPON: tname = "武器"
				elif res.equip_type == EquipmentData.Type.ACCESSORY: tname = "饰品"
				cards.append({
					"base_id": f.get_basename(), "name": str(res.item_name),
					"type": tname, "level": 1, "desc": str(res.description),
					"attack": int(res.attack_bonus), "shield": int(res.shield_bonus),
					"is_equipped": false, "res": res
				})
				count += 1
			elif res is SkillData:
				cards.append({
					"base_id": f.get_basename(), "name": str(res.card_name),
					"type": "技能", "level": 1, "desc": str(res.description),
					"is_equipped": false, "res": res
				})
				count += 1
		f = dir.get_next()
	dir.list_dir_end()
	return count

func _all_cards() -> Array:
	return cards

func _equipped_cards() -> Array:
	var result: Array = []
	for c in _all_cards():
		if bool(c.get("is_equipped", false)): result.append(c)
	return result

func _do_set_equipped(index: int, equipped: bool) -> void:
	if index < 0 or index >= cards.size(): return
	var c: Dictionary = cards[index]
	c["is_equipped"] = equipped
	if game_state != null and c.get("res") is EquipmentData:
		var item: EquipmentData = c["res"]
		if equipped: game_state.equip_item(item)
		else: game_state.equipped_items[item.equip_type] = null
	_on_cards_changed()

func _make_style(bg: Color, border: Color, bw: int, radius: int = 6) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg; st.border_color = border
	st.set_border_width_all(bw); st.set_corner_radius_all(radius)
	st.shadow_color = Color(0, 0, 0, 0.18); st.shadow_size = 5; st.shadow_offset = Vector2(0, 2)
	return st
