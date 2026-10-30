extends RefCounted
class_name UITextBox

# ================= 原 UITextFormat 功能 =================
static var _cmdysj_font: Font = null
static var _toroman_font: Font = null

static func _get_font(font_path: String) -> Font:
	if "toroman" in font_path:
		if _toroman_font == null: _toroman_font = load(font_path)
		return _toroman_font
	else:
		if _cmdysj_font == null: _cmdysj_font = load(font_path)
		return _cmdysj_font

# 一键应用基础文字样式（适合 Label / Button）
static func apply_basic(control: Control, style: String = "normal", custom_size: int = 20, outline_size: int = 4) -> void:
	var font: Font = _get_font("res://assets/fonts/cmdysj.ttf")
	var is_bold = false
	var final_size = custom_size
	
	if style == "bold" or style == "warning":
		is_bold = true
	elif style == "number":
		font = _get_font("res://assets/fonts/toroman.ttf")
		is_bold = false
	
	if font == null: font = ThemeDB.fallback_font
	
	if is_bold:
		var fv = FontVariation.new()
		fv.base_font = font
		fv.variation_embolden = 0.6
		control.add_theme_font_override("font", fv)
	else:
		control.add_theme_font_override("font", font)
		
	control.add_theme_font_size_override("font_size", final_size)
	
	if outline_size > 0:
		control.add_theme_color_override("font_outline_color", Color.BLACK)
		control.add_theme_constant_override("outline_size", outline_size)

# 一键应用富文本样式（适合 RichTextLabel）
static func apply_rich(text_label: RichTextLabel, style: String = "normal", custom_size: int = 20, outline_size: int = 4) -> void:
	var font: Font = _get_font("res://assets/fonts/cmdysj.ttf")
	var is_bold = false
	var final_size = custom_size
	
	if style == "bold" or style == "title":
		is_bold = true
	elif style == "number":
		font = _get_font("res://assets/fonts/toroman.ttf")
	
	if font == null: font = ThemeDB.fallback_font
	
	if is_bold:
		var fv = FontVariation.new()
		fv.base_font = font
		fv.variation_embolden = 0.8 if style == "title" else 0.6
		text_label.add_theme_font_override("normal_font", fv)
	else:
		text_label.add_theme_font_override("normal_font", font)
		
	text_label.add_theme_font_size_override("normal_font_size", final_size)
	
	if outline_size > 0:
		text_label.add_theme_color_override("font_outline_color", Color.BLACK)
		text_label.add_theme_constant_override("outline_size", outline_size)

# 世界坐标悬浮提示词组件
class WorldPrompt extends HBoxContainer:
	# 【互斥】同一时刻只允许一个悬浮提示可见，防止相邻交互点（如取走钟/盟约石碑）的提示叠在同一点
	static var _active_prompt = null

	var _current_target: Node2D
	var _prompt_tween: Tween

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		modulate.a = 0.0 
		scale = Vector2.ONE
		z_index = 100
		add_theme_constant_override("separation", 14)
		alignment = BoxContainer.ALIGNMENT_CENTER

	func show_prompt(text: String, target: Node2D) -> void:
		# 顶掉上一个还在显示的提示，避免两条文字重叠成一团
		if _active_prompt != null and is_instance_valid(_active_prompt) and _active_prompt != self and _active_prompt.visible:
			_active_prompt.hide_prompt()
		_active_prompt = self

		_current_target = target
		_build_content(text)
		
		if _prompt_tween and _prompt_tween.is_valid(): _prompt_tween.kill()
		
		visible = true
		_prompt_tween = create_tween().set_parallel(true)
		_prompt_tween.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_prompt_tween.tween_property(self, "position:y", position.y - 10.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func hide_prompt() -> void:
		if not visible: return
		
		if _prompt_tween and _prompt_tween.is_valid(): _prompt_tween.kill()
		
		_prompt_tween = create_tween().set_parallel(true)
		_prompt_tween.tween_property(self, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_prompt_tween.tween_property(self, "position:y", position.y + 10.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		_prompt_tween.chain().tween_callback(func():
			visible = false
			_current_target = null
			if _active_prompt == self: _active_prompt = null
		)

	func _build_content(text: String) -> void:
		for child in get_children():
			child.queue_free()
			
		var regex = RegEx.new()
		regex.compile("\\[([^\\]]+)\\]")
		
		var last_end = 0
		for m in regex.search_all(text):
			var start = m.get_start()
			if start > last_end:
				_add_label(text.substr(last_end, start - last_end))
				
			var key_str = m.get_string(1)
			var key_icon = UIIcon.KeyboardKeyIcon.new(key_str)
			add_child(key_icon)
			
			last_end = m.get_end()
			
		if last_end < text.length():
			_add_label(text.substr(last_end))

	func _add_label(txt: String) -> void:
		var lbl := Label.new()
		lbl.text = txt
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		UITextBox.apply_basic(lbl, "bold", 16, 4)
		add_child(lbl)

	func _process(_delta: float) -> void:
		if visible and is_instance_valid(_current_target):
			reset_size() 
			var target_y = _current_target.global_position.y
			if _current_target.has_node("AnimatedSprite2D"):
				var spr = _current_target.get_node("AnimatedSprite2D") as AnimatedSprite2D
				if spr.sprite_frames:
					var tex = spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
					if tex:
						var spr_h = tex.get_height() * abs(spr.global_scale.y)
						target_y -= spr_h / 2.0
			target_y -= 30.0 
			var target_x = _current_target.global_position.x - (size.x / 2.0)
			
			global_position = Vector2(target_x, target_y - size.y)


# ================= 原 UITextBox 绘制功能 =================
# 1. 水平渐变框
static func create_horizontal_fade_bg(
	bg_color: Color = Color(0.05, 0.05, 0.08), 
	mid_alpha: float = 0.85
) -> TextureRect:
	var bg = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE

	var grad = Gradient.new()
	grad.colors = [
		Color(bg_color.r, bg_color.g, bg_color.b, 0.0), 
		Color(bg_color.r, bg_color.g, bg_color.b, mid_alpha), 
		Color(bg_color.r, bg_color.g, bg_color.b, mid_alpha), 
		Color(bg_color.r, bg_color.g, bg_color.b, 0.0)
	]
	grad.offsets = [0.0, 0.3, 0.7, 1.0]

	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	bg.texture = tex
	return bg

# 2. 垂直渐变框
static func create_vertical_fade_bg(
	w: float, 
	h: float, 
	fade_down: bool = true,
	bg_color: Color = Color(0.05, 0.05, 0.08),
	start_alpha: float = 0.8
) -> TextureRect:
	var bg = TextureRect.new()
	bg.custom_minimum_size = Vector2(w, h)
	bg.size = Vector2(w, h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var grad = Gradient.new()
	grad.colors = [
		Color(bg_color.r, bg_color.g, bg_color.b, start_alpha), 
		Color(bg_color.r, bg_color.g, bg_color.b, 0.0)
	]
	grad.offsets = [0.0, 1.0]

	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1) if fade_down else Vector2(0, 0.5)
	bg.texture = tex
	return bg

# 3. 边缘渐变框
static func create_edge_fade_bg(
	bg_color: Color = Color(0, 0, 0),
	start_alpha: float = 0.85
) -> TextureRect:
	var bg = TextureRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE

	var grad = Gradient.new()
	grad.colors = [
		Color(bg_color.r, bg_color.g, bg_color.b, start_alpha), 
		Color(bg_color.r, bg_color.g, bg_color.b, 0.0)
	]
	grad.offsets = [0.0, 1.0]

	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0) 
	bg.texture = tex
	return bg

# 纯代码绘制 VN 对话框底板（带切角名字牌）
class DialogueBoxDrawer extends Control:
	var custom_theme_color: Color = Color.WHITE:
		set(v): custom_theme_color = v; queue_redraw()
	var name_width: float = 0.0:
		set(v): name_width = v; queue_redraw()

	func _draw() -> void:
		var w = size.x; var h = size.y
		var y_start = 24.0
		var pts = PackedVector2Array([Vector2(0, y_start), Vector2(w, y_start), Vector2(w, h), Vector2(0, h)])
		var colors = PackedColorArray([Color(0,0,0,1.0), Color(0,0,0,1.0), Color(0,0,0,0.6), Color(0,0,0,0.6)])
		draw_polygon(pts, colors)
		draw_line(Vector2(0, 24), Vector2(w, 24), custom_theme_color, 4.0)

		if name_width > 0:
			var name_h = 36.0; var name_w = name_width
			var pt_top_left = Vector2(0, name_h * 0.1); var pt_bot_left = Vector2(0, name_h * 0.9)
			var pt_tip_top = Vector2(name_w, name_h * 0.3); var pt_tip_bot = Vector2(name_w, name_h * 0.7)
			var thickness = Vector2(0, name_h * 0.35) 
			
			var poly_bottom = PackedVector2Array([pt_bot_left, pt_tip_bot, pt_tip_bot + thickness * 0.2, pt_bot_left + thickness])
			draw_colored_polygon(poly_bottom, custom_theme_color.darkened(0.4))
			draw_polyline(PackedVector2Array([pt_bot_left, pt_tip_bot, pt_tip_bot + thickness * 0.2, pt_bot_left + thickness, pt_bot_left]), custom_theme_color, 2.0)

			var poly_main = PackedVector2Array([pt_top_left, pt_tip_top, pt_tip_bot, pt_bot_left])
			draw_colored_polygon(poly_main, Color(0, 0, 0, 0.95))
			draw_polyline(PackedVector2Array([pt_top_left, pt_tip_top, pt_tip_bot, pt_bot_left, pt_top_left]), custom_theme_color, 3.0)
			draw_line(pt_top_left, pt_tip_top, custom_theme_color.lightened(0.4), 4.0)

# 纯代码绘制梯形斜角选项按钮
class ChoiceButton extends Button:
	var theme_color: Color
	var text_color: Color = Color.WHITE
	var display_label: Label
	
	func _init(color: Color):
		theme_color = color
		custom_minimum_size = Vector2(0, 60)
		add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		add_theme_color_override("font_color", Color(0,0,0,0)) 
		add_theme_color_override("font_hover_color", Color(0,0,0,0)) 
		add_theme_color_override("font_pressed_color", Color(0,0,0,0)) 
		add_theme_color_override("font_focus_color", Color(0,0,0,0)) 
		mouse_filter = Control.MOUSE_FILTER_STOP
		
		display_label = Label.new()
		display_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		display_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		display_label.offset_right = -30
		display_label.offset_left = 30
		display_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		display_label.clip_text = true
		UITextBox.apply_basic(display_label, "bold", 22)
		add_child(display_label)
	
	func set_custom_text(t: String):
		super.set_text(t)
		if display_label: 
			display_label.text = t
			var font = UITextBox._get_font("res://assets/fonts/cmdysj.ttf")
			if font == null: font = ThemeDB.fallback_font
			var text_size = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
			custom_minimum_size = Vector2(text_size.x + 80, 60)
		
	func update_text_color(c: Color):
		text_color = c
		if display_label: 
			display_label.add_theme_color_override("font_color", c)
		queue_redraw()
		
	func _draw() -> void:
		var w = size.x; var h = size.y
		var pt_tip_top = Vector2(0, h * 0.3)
		var pt_tip_bot = Vector2(0, h * 0.7)
		var pt_top_right = Vector2(w, h * 0.1)
		var pt_bot_right = Vector2(w, h * 0.9)
		var thickness = Vector2(0, h * 0.3)
		
		var is_dark_text = text_color.get_luminance() < 0.5
		var bg_base = Color(0.95, 0.95, 0.96) if is_dark_text else Color(0.05, 0.05, 0.08)
		var bg_edge = Color(bg_base.r, bg_base.g, bg_base.b, 0.2)
		var bg_mid = Color(bg_base.r, bg_base.g, bg_base.b, 0.95)
		
		var poly_bottom = PackedVector2Array([pt_tip_bot, pt_bot_right, pt_bot_right + thickness, pt_tip_bot + thickness * 0.2])
		draw_colored_polygon(poly_bottom, theme_color.darkened(0.5))
		draw_polyline(PackedVector2Array([pt_tip_bot, pt_bot_right, pt_bot_right + thickness, pt_tip_bot + thickness * 0.2, pt_tip_bot]), theme_color.darkened(0.7), 2.0)
		
		var poly_main = PackedVector2Array([pt_tip_top, pt_top_right, pt_bot_right, pt_tip_bot])
		var colors = PackedColorArray([bg_edge, bg_mid, bg_mid, bg_edge])
		draw_polygon(poly_main, colors)
		
		draw_polyline(PackedVector2Array([pt_tip_top, pt_top_right, pt_bot_right, pt_tip_bot, pt_tip_top]), theme_color, 3.0)
		draw_line(pt_tip_top, pt_top_right, theme_color.lightened(0.4), 4.0)
