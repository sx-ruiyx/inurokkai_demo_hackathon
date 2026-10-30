extends Control
class_name HealthBar

# ================= 配置参数 =================
var theme_color: Color = Color(0.88, 0.28, 0.22)
var is_shield: bool = false
var show_delay: bool = false
var show_charge: bool = false

var label_font_size: int = 14
var text_right_margin: float = 10.0
var icon_type: String = ""
var icon_node: Control = null
var num_centered: bool = false   # v1.15 数字在条内水平居中（详情面板消耗条用；HUD 保持默认右偏样式）
var icon_mid: bool = false       # v1.15 右侧标志垂直对齐条中线（默认保持 HUD 原高度）
var flat_style: bool = false     # v1.15 扁平水平矩形样式（深色底衬+圆角填充，替代楔形 3D 样式）
var icon_left: bool = false      # v1.15 标志放条左侧（默认右侧）

var target_ratio: float = 1.0
var ratio: float = 1.0
var delay_ratio: float = 1.0
var charge_ratio: float = 0.0

# ================= 节点引用 =================
var num_label: Label
var bar_drawer: WedgeBarDrawer

# ================= 状态控制 =================
var is_low: bool = false
var flash_timer: float = 0.0
var is_flashing: bool = false
var shake_offset: Vector2 = Vector2.ZERO
var delay_hp_val: float = 100.0

var ratio_tween: Tween
var delay_tween: Tween

func setup(is_shield_bar: bool, color: Color, delay: bool, charge: bool, i_type: String = "", font_size: int = 14, right_margin: float = 10.0):
	is_shield = is_shield_bar
	theme_color = color
	show_delay = delay
	show_charge = charge
	icon_type = i_type
	label_font_size = font_size
	text_right_margin = right_margin

func _ready():
	_build_ui()

func _build_ui():
	bar_drawer = WedgeBarDrawer.new()
	bar_drawer.flat = flat_style
	add_child(bar_drawer)
	
	num_label = Label.new()
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if num_centered else HORIZONTAL_ALIGNMENT_RIGHT
	num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num_label.add_theme_color_override("font_color", Color(1, 1, 1))
	UITextBox.apply_basic(num_label, "number", label_font_size)
	num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(num_label)
	
	if icon_type == "heart":
		icon_node = UIIcon.HeartIcon.new(theme_color)
		add_child(icon_node)
	elif icon_type == "shield":
		icon_node = UIIcon.ShieldIcon.new(theme_color)
		add_child(icon_node)
	elif icon_type == "star":
		icon_node = UIIcon.Star4Icon.new(theme_color)
		add_child(icon_node)

func update_health(new_hp: int, max_hp: int):
	if max_hp <= 0: return
	var old_target = target_ratio
	target_ratio = clampf(float(new_hp) / float(max_hp), 0.0, 1.0)
	
	if target_ratio < old_target and show_delay:
		shake()
		
	if num_label:
		num_label.text = "%d/%d" % [new_hp, max_hp]
		
		var target_is_low = (target_ratio > 0 and target_ratio <= 0.3)
		if target_is_low != is_low:
			is_low = target_is_low
			if not is_low:
				num_label.add_theme_color_override("font_color", Color(1, 1, 1))
				is_flashing = false
				
		var internal_alpha = 0.4 if new_hp <= 0 else 1.0
		if bar_drawer: bar_drawer.modulate.a = internal_alpha
		if num_label: num_label.modulate.a = internal_alpha
		if icon_node: icon_node.modulate.a = internal_alpha
			
	if ratio_tween and ratio_tween.is_valid(): ratio_tween.kill()
	ratio_tween = create_tween()
	ratio_tween.tween_method(func(v): ratio = v, ratio, target_ratio, 0.2).set_trans(Tween.TRANS_SINE)
	
	if show_delay:
		if not delay_tween:
			delay_hp_val = new_hp
			delay_ratio = target_ratio
			return 
			
		if delay_tween.is_valid(): delay_tween.kill()
			
		var current_hp_float = ratio * max_hp
		if new_hp >= current_hp_float or new_hp >= max_hp or new_hp <= 0:
			delay_hp_val = new_hp
			delay_ratio = target_ratio
		else:
			delay_tween = create_tween()
			delay_tween.tween_interval(0.5)
			delay_tween.tween_method(_update_delay_val.bind(max_hp), delay_hp_val, float(new_hp), 0.4).set_trans(Tween.TRANS_SINE)

func _update_delay_val(val: float, max_hp: int):
	delay_hp_val = val
	delay_ratio = clampf(delay_hp_val / float(max_hp), 0.0, 1.0)

func set_charge_ratio(target: float):
	charge_ratio = clampf(target, 0.0, 1.0)

func shake():
	var t = create_tween()
	t.tween_property(self, "shake_offset", Vector2(-8, 2), 0.03)
	t.tween_property(self, "shake_offset", Vector2(8, -2), 0.03)
	t.tween_property(self, "shake_offset", Vector2(-5, 1), 0.03)
	t.tween_property(self, "shake_offset", Vector2(5, -1), 0.03)
	t.tween_property(self, "shake_offset", Vector2(-2, 0), 0.03)
	t.tween_property(self, "shake_offset", Vector2.ZERO, 0.03)

func _process(delta: float):
	if is_low and is_instance_valid(num_label):
		flash_timer += delta
		if flash_timer >= 1.0:
			flash_timer = 0.0
			is_flashing = not is_flashing
			if is_shield:
				num_label.modulate.a = 0.3 if is_flashing else 1.0
			else:
				num_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3) if is_flashing else Color(1, 1, 1))
	
	if bar_drawer:
		bar_drawer.flat = flat_style
		bar_drawer.update_visuals(theme_color, ratio, delay_ratio, charge_ratio, is_shield, show_delay, show_charge)
		_update_layout()

func get_bar_visual_height() -> float:
	return size.y

func _update_layout():
	if not bar_drawer or not num_label: return
	
	var w = size.x if size.x > 0 else 60.0
	var h = size.y if size.y > 0 else 12.0
	
	bar_drawer.size = Vector2(w, h)
	bar_drawer.position.x = shake_offset.x
	
	# 文字对齐稍微往左收一点，因为右侧被厚度占用了 6px
	if num_centered:
		# v1.15 数字在条中居中（水平铺满条宽 + 垂直对齐视觉条面中线）
		num_label.position = Vector2(shake_offset.x, -h * 0.03)
		num_label.size = Vector2(w, h)
	else:
		num_label.position = Vector2(shake_offset.x + w * 0.3, -h * 0.15)
		num_label.size = Vector2(w * 0.7 - text_right_margin - 6, h)

	if icon_node:
		var icon_size = 10.0
		# v1.15 icon_left = 标志平移到条左侧（间距仍 8px，与右侧时对称）
		var icon_x = -8.0 - icon_size if icon_left else w + 8.0
		# v1.15 icon_mid = 标志中心对齐条视觉中线（主面中心 ≈ 0.525h，控件中线 0.5h 即可视觉居中）
		var icon_y = (h - icon_size) / 2.0 if icon_mid else ((h * 0.4 - icon_size) / 2.0 + 2.0)
		icon_node.position = Vector2(icon_x + shake_offset.x, icon_y)
		icon_node.custom_minimum_size = Vector2(icon_size, icon_size)
		icon_node.size = Vector2(icon_size, icon_size)

# ================= 绘制器：完美严丝合缝的3D积木 =================
class WedgeBarDrawer extends Control:
	var draw_theme_color: Color = Color.RED
	var hp_ratio: float = 1.0
	var delay_ratio: float = 1.0
	var charge_ratio: float = 0.0
	var is_shield: bool = false
	var show_delay: bool = true
	var show_charge: bool = false
	var flat: bool = false   # v1.15 扁平水平矩形样式（详情面板消耗条用；HUD 保持楔形）
	
	func _init():
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	
	func update_visuals(col: Color, hp: float, dly: float, chg: float, is_sh: bool, shw_dly: bool, shw_chg: bool):
		draw_theme_color = col
		hp_ratio = clampf(hp, 0.0, 1.0)
		delay_ratio = clampf(dly, 0.0, 1.0)
		charge_ratio = clampf(chg, 0.0, 1.0)
		is_shield = is_sh
		show_delay = shw_dly
		show_charge = shw_chg
		queue_redraw()

	func _draw():
		var w = size.x
		var h = size.y
		if w <= 0 or h <= 0: return

		# ====== v1.15 扁平水平矩形样式（参考旧版详情面板消耗条）======
		if flat:
			# 深色底衬 + 深色描边（圆角矩形）
			var track := StyleBoxFlat.new()
			track.bg_color = Color(0.16, 0.18, 0.16, 0.55)
			track.set_corner_radius_all(3)
			track.set_border_width_all(2)
			track.border_color = draw_theme_color.darkened(0.5)
			draw_style_box(track, Rect2(Vector2.ZERO, size))
			# 亮色填充（按比例，内缩 2px 让描边包住填充）
			if hp_ratio > 0:
				var fill := StyleBoxFlat.new()
				fill.bg_color = draw_theme_color
				fill.set_corner_radius_all(2)
				var fw = maxf(0.0, (w - 4.0) * hp_ratio)
				draw_style_box(fill, Rect2(2, 2, fw, h - 4.0))
			# 充能亮层（BP 回复进度）
			if show_charge and charge_ratio > hp_ratio:
				var chg := StyleBoxFlat.new()
				chg.bg_color = draw_theme_color.lightened(0.3)
				chg.bg_color.a = 0.4
				chg.set_corner_radius_all(2)
				var cw = maxf(0.0, (w - 4.0) * charge_ratio)
				draw_style_box(chg, Rect2(2, 2, cw, h - 4.0))
			return

		var T = Vector2(6, 6) # 向右下的厚度
		
		# 主面的四个基准角
		var p_tl = Vector2(0, h * 0.35)
		var p_bl = Vector2(0, h * 0.7)
		var p_tr = Vector2(w - T.x, 0)
		var p_br = Vector2(w - T.x, h * 0.35)
		
		# 主面的各比例插值点
		var p_tc = p_tl.lerp(p_tr, hp_ratio)
		var p_bc = p_bl.lerp(p_br, hp_ratio)
		
		var p_td = p_tl.lerp(p_tr, delay_ratio)
		var p_bd = p_bl.lerp(p_br, delay_ratio)
		
		var p_tch = p_tl.lerp(p_tr, charge_ratio)
		var p_bch = p_bl.lerp(p_br, charge_ratio)
		
		var dark = draw_theme_color.darkened(0.7)

		# ====== 1. 绘制底部暗面 ======
		var poly_bot = PackedVector2Array([p_bl, p_br, p_br + T, p_bl + T])
		draw_colored_polygon(poly_bot, dark.darkened(0.3))

		# ====== 2. 绘制右侧暗面 ======
		var poly_right = PackedVector2Array([p_tr, p_br, p_br + T, p_tr + T])
		draw_colored_polygon(poly_right, dark.darkened(0.5))

		# ====== 3. 绘制主面背景 ======
		var poly_bg = PackedVector2Array([p_tl, p_tr, p_br, p_bl])
		draw_colored_polygon(poly_bg, Color(0.15, 0.15, 0.18))
		
		# ====== 4. 延迟扣血 ======
		if show_delay and delay_ratio > hp_ratio and delay_ratio > 0:
			draw_colored_polygon(PackedVector2Array([p_tc, p_td, p_bd, p_bc]), Color(0.85, 0.6, 0.2))
			
		# ====== 5. 充能 ======
		if show_charge and charge_ratio > hp_ratio:
			var c = draw_theme_color.lightened(0.3)
			c.a = 0.4
			draw_colored_polygon(PackedVector2Array([p_tc, p_tch, p_bch, p_bc]), c)
			
		# ====== 6. 实际血量 ======
		if hp_ratio > 0:
			draw_colored_polygon(PackedVector2Array([p_tl, p_tc, p_bc, p_bl]), draw_theme_color)
			
		# ====== 7. 外轮廓高光描边 (杜绝接缝) ======
		var outline = PackedVector2Array([
			p_tl, p_tr, 
			p_tr + T, p_br + T, 
			p_bl + T, p_bl, 
			p_tl
		])
		draw_polyline(outline, draw_theme_color.lightened(0.2), 1.5)
		
		# 把主面左侧那条线补上，防止它看起来像个奇怪的三角
		draw_line(p_bl, p_tl, draw_theme_color.lightened(0.2), 1.5)
