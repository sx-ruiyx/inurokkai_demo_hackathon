extends CanvasLayer

signal line_advanced()
signal choice_made(branch: String, node: String)

const COLOR_DIALOGUE_LIGHT := Color(1.0, 1.0, 1.0) 
const COLOR_DIALOGUE_DARK := Color(0.1, 0.1, 0.12)  
const DEFAULT_DIM_COLOR := Color(0, 0, 0, 0.4) 
const ARROW_TEXTURE_PATH := "res://assets/textures/ui/arrow_down.png" 

var _root: Control
var _box_drawer: UITextBox.DialogueBoxDrawer # 【修改】引用全局类
var _speaker_label: Label
var _text_label: RichTextLabel

# --- Title 组件 ---
var _title_box: Control
var _title_label: RichTextLabel
var _title_hint: Control

# --- Tip 组件 ---
var _tip_box: Control
var _tip_label: Label
var _tip_tween: Tween

var _hint: Control 
var _blocker: ColorRect
var _portrait_layer: Control
var _choice_container: VBoxContainer

var _type_timer: Timer
var _box_tween: Tween 

var current_theme_color: Color = Color.WHITE
var is_light_bg: bool = false 
var instant_in: bool = false 

var _char_names: Dictionary = {}
var _active_portraits: Dictionary = {}
var _current_emotions: Dictionary = {}

var _choice_buttons: Array = []
var _hint_alpha_tween: Tween
var _hint_bob_tween: Tween

var is_typing = false

func _ready() -> void:
	layer = 100
	for child in get_children(): child.queue_free()
	_build_ui()
	_type_timer.timeout.connect(_on_type_timer_timeout)

func register_character(id: String, display_name: String) -> void:
	_char_names[id] = display_name

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_blocker = ColorRect.new()
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blocker.color = DEFAULT_DIM_COLOR
	_root.add_child(_blocker)

	_portrait_layer = Control.new()
	_portrait_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_portrait_layer)

	# --- 底部对话框 ---
	_box_drawer = UITextBox.DialogueBoxDrawer.new() # 【修改】实例化全局类
	_box_drawer.anchor_left = 0.0; _box_drawer.anchor_right = 1.0
	_box_drawer.anchor_top = 1.0; _box_drawer.anchor_bottom = 1.0
	_box_drawer.offset_top = -160; _box_drawer.offset_bottom = 0
	_box_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_box_drawer)

	_speaker_label = Label.new()
	_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITextBox.apply_basic(_speaker_label, "bold", 18)
	_box_drawer.add_child(_speaker_label)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.scroll_active = false
	_text_label.anchor_right = 1.0; _text_label.anchor_bottom = 1.0
	_text_label.offset_left = 40; _text_label.offset_right = -40
	_text_label.offset_top = 65; _text_label.offset_bottom = -20
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITextBox.apply_rich(_text_label, "normal", 20)
	_box_drawer.add_child(_text_label)

	_hint = _create_arrow()
	_hint.anchor_left = 1.0; _hint.anchor_top = 1.0
	_hint.anchor_right = 1.0; _hint.anchor_bottom = 1.0
	_hint.offset_left = -80; _hint.offset_right = -48
	_hint.offset_top = -50; _hint.offset_bottom = -18
	_hint.visible = false
	_box_drawer.add_child(_hint)

	# ================= Title 组件 =================
	_title_box = Control.new()
	_title_box.anchor_left = 0.5; _title_box.anchor_right = 0.5
	_title_box.anchor_top = 0.5; _title_box.anchor_bottom = 0.5
	_title_box.offset_left = -400; _title_box.offset_right = 400
	_title_box.offset_top = -80; _title_box.offset_bottom = 80
	_title_box.visible = false
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title_box)

	var title_bg = UITextBox.create_horizontal_fade_bg()
	_title_box.add_child(title_bg)

	_title_label = RichTextLabel.new()
	_title_label.bbcode_enabled = true
	_title_label.fit_content = true
	_title_label.scroll_active = false
	_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITextBox.apply_rich(_title_label, "title", 36)
	_title_box.add_child(_title_label)

	_title_hint = _create_arrow()
	_title_hint.anchor_left = 0.5; _title_hint.anchor_right = 0.5
	_title_hint.anchor_top = 1.0; _title_hint.anchor_bottom = 1.0
	_title_hint.offset_left = -16; _title_hint.offset_right = 16
	_title_hint.offset_top = 20; _title_hint.offset_bottom = 52
	_title_hint.visible = false
	_title_box.add_child(_title_hint)

	# ================= Tip 组件 =================
	_tip_box = Control.new()
	_tip_box.anchor_left = 0.5; _tip_box.anchor_right = 0.5
	_tip_box.anchor_top = 0.5; _tip_box.anchor_bottom = 0.5
	_tip_box.visible = false
	_tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tip_box)

	var tip_bg = UITextBox.create_horizontal_fade_bg()
	_tip_box.add_child(tip_bg)

	_tip_label = Label.new()
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tip_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	UITextBox.apply_basic(_tip_label, "normal", 20)
	_tip_label.add_theme_color_override("font_color", Color.WHITE) 
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_box.add_child(_tip_label)

	# --- 全屏拦截层 ---
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(_on_overlay_input)
	_root.add_child(overlay)

	# --- 选项层 ---
	_choice_container = VBoxContainer.new()
	_choice_container.anchor_left = 0.5; _choice_container.anchor_right = 1.0 
	_choice_container.anchor_top = 0.2; _choice_container.anchor_bottom = 0.8
	_choice_container.offset_right = -20.0
	_choice_container.add_theme_constant_override("separation", 20)
	_choice_container.alignment = BoxContainer.ALIGNMENT_CENTER 
	_choice_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_choice_container)
	_choice_container.visible = false

	_type_timer = Timer.new()
	_box_drawer.add_child(_type_timer)

func _create_arrow() -> Control:
	var res: Control
	if ResourceLoader.exists(ARROW_TEXTURE_PATH):
		var tex = TextureRect.new()
		tex.texture = load(ARROW_TEXTURE_PATH)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		res = tex
	else:
		var lbl = Label.new()
		lbl.text = "▼"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UITextBox.apply_basic(lbl, "normal", 20)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		res = lbl
	res.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return res

func execute_character_action(char_id: String, pos_target: int, is_move: bool, emotion: String, _text: String, is_remove: bool) -> void:
	if is_remove:
		if _active_portraits.has(char_id):
			var data = _active_portraits[char_id]
			var node = data["node"]
			if is_instance_valid(node):
				var t = create_tween()
				t.tween_property(node, "modulate:a", 0.0, 0.3)
				t.tween_callback(node.queue_free)
			_active_portraits.erase(char_id)
		return

	if not _active_portraits.has(char_id):
		if pos_target == -1: pos_target = 1
		var rect = TextureRect.new()
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.modulate.a = 0.0
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_portrait_layer.add_child(rect)
		_active_portraits[char_id] = {"node": rect, "pos": pos_target}
		_update_portrait_texture(char_id, rect, emotion if emotion != "" else "base")
		var t = create_tween()
		t.tween_property(rect, "modulate:a", 1.0, 0.3)
	else:
		var data = _active_portraits[char_id]
		var node: TextureRect = data["node"]
		var current_pos = data["pos"]
		if emotion != "":
			_update_portrait_texture(char_id, node, emotion)
		if pos_target != -1 and current_pos != pos_target:
			data["pos"] = pos_target
			var target_x = _get_target_x(pos_target)
			var target_left = target_x - (node.size.x / 2.0)
			if is_move:
				var t = create_tween()
				t.tween_property(node, "position:x", target_left, 0.4).set_trans(Tween.TRANS_SINE)
			else:
				node.position.x = target_left

func _update_portrait_texture(char_id: String, node: TextureRect, emotion: String) -> void:
	_current_emotions[char_id] = emotion
	var paths = [
		"res://assets/textures/characters/ch0/%s/portrait/%s.png" % [char_id, emotion],
		"res://assets/textures/characters/shared/%s/portrait/%s.png" % [char_id, emotion],
		"res://assets/textures/characters/shared/%s/portrait/base.png" % char_id
	]
	var loaded = false
	for p in paths:
		if ResourceLoader.exists(p):
			node.texture = load(p)
			loaded = true
			break
	if not loaded:
		node.visible = false
		return
	else:
		node.visible = true
	
	var img_size = node.texture.get_size()
	var viewport_size = get_viewport().get_visible_rect().size
	var target_h = viewport_size.y
	var scale_factor = target_h / img_size.y
	var draw_w = img_size.x * scale_factor
	var draw_h = img_size.y * scale_factor
	node.size = Vector2(draw_w, draw_h)
	
	var pos_idx = _active_portraits[char_id]["pos"]
	var target_x = _get_target_x(pos_idx)
	var target_y = viewport_size.y + 20.0 
	node.position = Vector2(target_x - draw_w / 2.0, target_y - draw_h)

func _get_target_x(pos_idx: int) -> float:
	var viewport_size = get_viewport().get_visible_rect().size
	if pos_idx == 0: return viewport_size.x * 0.25
	elif pos_idx == 2: return viewport_size.x * 0.75
	else: return viewport_size.x * 0.5

func _animate_hint(node: Control, state: bool) -> void:
	if not node: return
	if _hint_alpha_tween and _hint_alpha_tween.is_valid(): _hint_alpha_tween.kill()
	if _hint_bob_tween and _hint_bob_tween.is_valid(): _hint_bob_tween.kill()
	
	if state:
		node.visible = true
		node.modulate.a = 0.0
		_hint_alpha_tween = create_tween()
		_hint_alpha_tween.tween_property(node, "modulate:a", 1.0, 0.3)
		
		var base_top = -50.0
		var base_bottom = -18.0
		if node == _title_hint:
			base_top = 20.0
			base_bottom = 52.0
			
		node.offset_top = base_top
		node.offset_bottom = base_bottom
		
		_hint_bob_tween = create_tween().set_loops()
		_hint_bob_tween.tween_property(node, "offset_top", base_top + 6, 0.6).set_trans(Tween.TRANS_SINE)
		_hint_bob_tween.parallel().tween_property(node, "offset_bottom", base_bottom + 6, 0.6).set_trans(Tween.TRANS_SINE)
		_hint_bob_tween.tween_property(node, "offset_top", base_top, 0.6).set_trans(Tween.TRANS_SINE)
		_hint_bob_tween.parallel().tween_property(node, "offset_bottom", base_bottom, 0.6).set_trans(Tween.TRANS_SINE)
	else:
		_hint_alpha_tween = create_tween()
		_hint_alpha_tween.tween_property(node, "modulate:a", 0.0, 0.2)
		_hint_alpha_tween.tween_callback(func(): node.visible = false)

func set_hint_visible(state: bool) -> void:
	_animate_hint(_hint, state)
	if _title_box.visible:
		_animate_hint(_title_hint, state)

func show_box() -> void:
	_box_drawer.visible = true
	if _box_tween and _box_tween.is_valid():
		_box_tween.kill()
		
	if instant_in:
		_box_drawer.modulate.a = 1.0
	else:
		_box_tween = create_tween()
		_box_tween.tween_property(_box_drawer, "modulate:a", 1.0, 0.3)
	_update_text_colors()

func hide_box() -> void:
	if _box_tween and _box_tween.is_valid():
		_box_tween.kill()
	_box_tween = create_tween()
	_box_tween.tween_property(_box_drawer, "modulate:a", 0.0, 0.3)
	_box_tween.tween_callback(func():
		_box_drawer.visible = false
		_update_text_colors()
	)

func fade_out_and_destroy() -> void:
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(_root, "modulate:a", 0.0, 0.3)
	for data in _active_portraits.values():
		var node = data["node"]
		if is_instance_valid(node):
			t.tween_property(node, "modulate:a", 0.0, 0.3)

func set_whiteout(state: String) -> void:
	var t = create_tween()
	var speed = 0.3 
	if state == "0":
		t.tween_property(_blocker, "color:a", 1.0, speed)
		_blocker.color = Color(0, 0, 0, _blocker.color.a)
		is_light_bg = false
	elif state == "1":
		t.tween_property(_blocker, "color:a", 1.0, speed)
		_blocker.color = Color(1, 1, 1, _blocker.color.a)
		is_light_bg = true
	else:
		t.tween_property(_blocker, "color:a", DEFAULT_DIM_COLOR.a, speed)
		_blocker.color = Color(0, 0, 0, _blocker.color.a)
		is_light_bg = false
	_update_text_colors()

func _update_text_colors() -> void:
	var use_dark = is_light_bg and not _box_drawer.visible
	if use_dark:
		_text_label.add_theme_color_override("default_color", COLOR_DIALOGUE_DARK)
		if _speaker_label: _speaker_label.add_theme_color_override("font_color", COLOR_DIALOGUE_DARK)
		for btn in _choice_buttons:
			if is_instance_valid(btn): btn.update_text_color(COLOR_DIALOGUE_DARK)
	else:
		_text_label.add_theme_color_override("default_color", COLOR_DIALOGUE_LIGHT)
		if _speaker_label: _speaker_label.add_theme_color_override("font_color", Color(1,1,1))
		for btn in _choice_buttons:
			if is_instance_valid(btn): btn.update_text_color(Color.WHITE)
			
	if _hint:
		if use_dark: _hint.modulate = Color(0.1, 0.1, 0.1, _hint.modulate.a) 
		else: _hint.modulate = Color(1, 1, 1, _hint.modulate.a)

func show_title(text: String) -> void:
	if _type_timer: _type_timer.stop()
	_box_drawer.visible = false
	_title_box.visible = true
	_animate_hint(_title_hint, false)
	
	_title_label.text = text
	_title_label.visible_characters = 0
	
	is_typing = true
	_type_timer.wait_time = 0.05
	
	await get_tree().process_frame
	await get_tree().process_frame
	_type_timer.start()

func show_tip(text: String) -> void:
	_tip_label.text = text
	_tip_box.visible = false
	await get_tree().process_frame
	
	var text_w = _tip_label.get_combined_minimum_size().x
	if text_w < 100: text_w = 100
	var box_w = text_w + 160 
	var target_top = -35.0
	var target_bottom = 35.0
	
	_tip_box.offset_left = -box_w / 2.0
	_tip_box.offset_right = box_w / 2.0
	_tip_box.offset_top = target_top - 20
	_tip_box.offset_bottom = target_bottom - 20
	
	_tip_box.visible = true
	_tip_box.modulate.a = 0.0
	
	if _tip_tween and _tip_tween.is_valid(): _tip_tween.kill()
	_tip_tween = create_tween()
	_tip_tween.set_parallel(true)
	_tip_tween.tween_property(_tip_box, "modulate:a", 1.0, 0.2)
	_tip_tween.tween_property(_tip_box, "offset_top", target_top, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tip_tween.tween_property(_tip_box, "offset_bottom", target_bottom, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tip_tween.chain().tween_interval(1.5)
	_tip_tween.chain().tween_property(_tip_box, "modulate:a", 0.0, 0.3)
	_tip_tween.chain().tween_callback(func(): _tip_box.visible = false)

func start_line(type: String, speaker: String, text: String, color: Color) -> void:
	if _type_timer: _type_timer.stop()
	_title_box.visible = false
	is_typing = false
	
	current_theme_color = color
	_animate_hint(_hint, false)
	
	show_box()
	_box_drawer.custom_theme_color = current_theme_color
	
	if type == "say":
		_speaker_label.text = speaker
		_speaker_label.visible = true
		_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var font = _speaker_label.get_theme_font("font")
		if font == null: font = ThemeDB.fallback_font
		var font_size = _speaker_label.get_theme_font_size("font_size")
		var text_size = font.get_string_size(speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		
		_box_drawer.name_width = text_size.x + 60
		_speaker_label.position = Vector2(15, 0)
		_speaker_label.size = Vector2(_box_drawer.name_width, 36)
	else:
		_speaker_label.visible = false
		_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box_drawer.name_width = 0
		
	_update_text_colors()
	_box_drawer.queue_redraw()
	
	_text_label.text = text
	_text_label.visible_characters = 0
	
	var total = _text_label.get_total_character_count()
	if total <= 0:
		_finish_line()
		return
		
	is_typing = true
	_type_timer.wait_time = 0.05
	_type_timer.start()

func _on_type_timer_timeout() -> void:
	if _title_box.visible:
		_title_label.visible_characters += 1
		if _title_label.visible_characters >= _title_label.get_total_character_count():
			_finish_line()
	else:
		_text_label.visible_characters += 1
		if _text_label.visible_characters >= _text_label.get_total_character_count():
			_finish_line()

func _finish_line() -> void:
	if _type_timer: _type_timer.stop()
	if _title_box.visible:
		_title_label.visible_characters = -1
	else:
		_text_label.visible_characters = -1
	is_typing = false
	set_hint_visible(true)

func _on_overlay_input(event: InputEvent) -> void:
	if _choice_container.visible: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled() 
		
		if is_typing:
			_finish_line() 
		else:
			if _title_box.visible or _box_drawer.visible:
				line_advanced.emit() 

func show_choices(options: Array) -> void:
	set_hint_visible(false) 
	_choice_buttons.clear()
	for child in _choice_container.get_children(): child.queue_free()
	
	var now = Time.get_ticks_msec()
	for opt in options:
		# 【修改】使用全局的 UITextBox.ChoiceButton
		var btn = UITextBox.ChoiceButton.new(current_theme_color)
		btn.custom_minimum_size = Vector2(0, 60)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_END 
		btn.set_custom_text(opt["text"])
		
		btn.pressed.connect(func():
			if Time.get_ticks_msec() - now < 200: return 
			if not _choice_container.visible: return 
			_choice_container.visible = false
			choice_made.emit(opt["goto"]["b"], opt["goto"]["n"])
		)
		_choice_container.add_child(btn)
		_choice_buttons.append(btn)
		
	_update_text_colors()
	_choice_container.visible = true
	_choice_container.modulate.a = 0.0
	
	var t = create_tween()
	t.tween_property(_choice_container, "modulate:a", 1.0, 0.2)
