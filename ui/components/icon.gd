extends RefCounted
class_name UIIcon

# 纯代码画红心
class HeartIcon extends Control:
	var col := Color(0.88, 0.28, 0.22)
	func _init(c: Color): col = c; custom_minimum_size = Vector2(20, 20); mouse_filter = MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w = size.x; var h = size.y
		draw_circle(Vector2(w * 0.30, h * 0.32), w * 0.21, col)
		draw_circle(Vector2(w * 0.70, h * 0.32), w * 0.21, col)
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.115, h * 0.40), Vector2(w * 0.885, h * 0.40),
			Vector2(w * 0.70, h * 0.80), Vector2(w * 0.50, h * 0.97),
			Vector2(w * 0.30, h * 0.80)]), col)
		draw_polyline(PackedVector2Array([
			Vector2(w * 0.115, h * 0.40), Vector2(w * 0.30, h * 0.80), Vector2(w * 0.50, h * 0.97),
			Vector2(w * 0.70, h * 0.80), Vector2(w * 0.885, h * 0.40)]), col.darkened(0.35), 1.2)
		draw_circle(Vector2(w * 0.33, h * 0.28), w * 0.07, Color(1, 1, 1, 0.55))

# 纯代码画护盾
class ShieldIcon extends Control:
	var col := Color(0.80, 0.80, 0.82)
	func _init(c: Color): col = c; custom_minimum_size = Vector2(20, 20); mouse_filter = MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w = size.x; var h = size.y
		var pts := PackedVector2Array([
			Vector2(w * 0.10, h * 0.08), Vector2(w * 0.90, h * 0.08),
			Vector2(w * 0.90, h * 0.45), Vector2(w * 0.50, h * 0.95), Vector2(w * 0.10, h * 0.45)])
		draw_colored_polygon(pts, col)
		draw_polyline(pts + PackedVector2Array([pts[0]]), col.darkened(0.4), 1.2)
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.24, h * 0.20), Vector2(w * 0.76, h * 0.20),
			Vector2(w * 0.76, h * 0.42), Vector2(w * 0.50, h * 0.78), Vector2(w * 0.24, h * 0.42)]),
			Color(1, 1, 1, 0.28))
		draw_line(Vector2(w * 0.50, h * 0.16), Vector2(w * 0.50, h * 0.70), col.darkened(0.3), 1.0)

# 纯代码画四角星
class Star4Icon extends Control:
	var col := Color(0.36, 0.78, 0.36)
	func _init(c: Color): col = c; custom_minimum_size = Vector2(20, 20); mouse_filter = MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w = size.x; var h = size.y
		var pts := PackedVector2Array([
			Vector2(w * 0.50, h * 0.02), Vector2(w * 0.60, h * 0.40), Vector2(w * 0.98, h * 0.50),
			Vector2(w * 0.60, h * 0.60), Vector2(w * 0.50, h * 0.98), Vector2(w * 0.40, h * 0.60),
			Vector2(w * 0.02, h * 0.50), Vector2(w * 0.40, h * 0.40)])
		draw_colored_polygon(pts, col)
		draw_polyline(pts + PackedVector2Array([pts[0]]), col.darkened(0.35), 1.2)
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.50, h * 0.34), Vector2(w * 0.55, h * 0.45), Vector2(w * 0.66, h * 0.50),
			Vector2(w * 0.55, h * 0.55), Vector2(w * 0.50, h * 0.66), Vector2(w * 0.45, h * 0.55),
			Vector2(w * 0.34, h * 0.50), Vector2(w * 0.45, h * 0.45)]), Color(1, 1, 1, 0.85))

# ================= 【重构】梯形透视立体键帽 UI 组件 =================
class KeyboardKeyIcon extends Control:
	var key_text: String = "E"
	var font: Font
	var label_node: Label
	
	const THICKNESS = 6.0 # 键帽底部厚度，加粗立体感
	const TOP_RATIO = 0.78 # 顶面宽度与底边长度的比例（上窄下宽）

	func _init(text: String) -> void:
		key_text = text
		font = load("res://assets/fonts/toroman.ttf")
		if font == null: font = ThemeDB.fallback_font
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		label_node = Label.new()
		label_node.text = key_text
		label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# 【修复】将 UITextFormat 改为 UITextBox
		UITextBox.apply_basic(label_node, "bold", 16, 4)
		label_node.add_theme_font_override("font", font)
		
		# 阴影增强立体感
		label_node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		label_node.add_theme_constant_override("shadow_offset_x", 1)
		label_node.add_theme_constant_override("shadow_offset_y", 2)
		
		add_child(label_node)
		_update_size()

	func _update_size() -> void:
		var str_size = font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		var min_width = 36.0
		var final_width = maxf(min_width, str_size.x + 30)
		
		var final_height = 24.0 + THICKNESS 
		custom_minimum_size = Vector2(final_width, final_height)
		size = custom_minimum_size
		
		label_node.size = Vector2(final_width, 24.0)
		label_node.position = Vector2(0, 0)
		
		queue_redraw()

	func _draw() -> void:
		var w = size.x
		var h = size.y
		var top_y = 0
		var bot_y = h - THICKNESS
		
		var top_w = w * TOP_RATIO
		var top_offset = (w - top_w) / 2.0
		
		# 1. 画底部厚度（侧面）
		var bot_face = PackedVector2Array([
			Vector2(0, bot_y),
			Vector2(w, bot_y),
			Vector2(w, h),
			Vector2(0, h)
		])
		draw_colored_polygon(bot_face, Color(0.12, 0.12, 0.15))
		
		# 2. 画侧面底部阴影线（加深接地感）
		draw_line(Vector2(0, h), Vector2(w, h), Color(0, 0, 0, 0.9), 2.0)
		
		# 3. 画键帽顶面（梯形）
		var top_face = PackedVector2Array([
			Vector2(top_offset, top_y),
			Vector2(top_offset + top_w, top_y),
			Vector2(w, bot_y),
			Vector2(0, bot_y)
		])
		draw_colored_polygon(top_face, Color(0.32, 0.32, 0.38))
		
		# 4. 画顶面边框高光
		var outline = top_face + PackedVector2Array([top_face[0]])
		draw_polyline(outline, Color(0.7, 0.7, 0.75), 2.0)
		
		# 5. 画顶面内部下边缘的内阴影，增加细节
		draw_line(Vector2(2, bot_y - 1.5), Vector2(w - 2, bot_y - 1.5), Color(0.1, 0.1, 0.12), 2.0)
