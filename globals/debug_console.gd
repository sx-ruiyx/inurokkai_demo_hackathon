extends Node

var ui_label: RichTextLabel
var bg_rect: TextureRect
var logs: Array[String] = []
var root_control: Control

var _emoji_regex: RegEx
var _num_regex: RegEx 

class CustomLogger extends Logger:
	var parent_node: Node
	func _init(p_node: Node):
		parent_node = p_node

	func _log_message(message: String, _error: bool) -> void:
		if parent_node and parent_node.has_method("add_log"):
			parent_node.add_log(message)

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if parent_node and parent_node.has_method("add_log"):
			parent_node.add_log("[ERROR] %s" % _code)

func _ready() -> void:
	_emoji_regex = RegEx.new()
	_emoji_regex.compile("\\[([^\\]]+)\\]")
	
	_num_regex = RegEx.new()
	_num_regex.compile("\\b(\\d+(?:/\\d+)?)\\b")

	OS.add_logger(CustomLogger.new(self))

	var canvas = CanvasLayer.new()
	canvas.layer = 128
	add_child(canvas)

	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.visible = false 
	canvas.add_child(root_control)

	var width = 240
	var height = 120

	# 【核心修复】直接调用统一组件，彻底告别手搓
	bg_rect = UITextBox.create_edge_fade_bg(Color(0, 0, 0), 0.85)
	bg_rect.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bg_rect.offset_left = 0
	bg_rect.offset_right = width
	bg_rect.offset_bottom = -100
	bg_rect.offset_top = -100 - height
	root_control.add_child(bg_rect)

	ui_label = RichTextLabel.new()
	ui_label.bbcode_enabled = true
	ui_label.scroll_following = false 
	ui_label.scroll_active = true
	ui_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	ui_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ui_label.offset_left = 10
	ui_label.offset_right = width - 10
	ui_label.offset_bottom = -100 - 4 
	ui_label.offset_top = -100 - (height - 4)

	# ================= 【终极锁死字体和字号】 =================
	var debug_theme = Theme.new()
	var font = load("res://assets/fonts/cmdysj.ttf")
	if font:
		debug_theme.default_font = font
		ui_label.add_theme_font_override("normal_font", font)
		ui_label.add_theme_font_override("bold_font", font)
		ui_label.add_theme_font_override("italics_font", font)
		ui_label.add_theme_font_override("bold_italics_font", font)
		ui_label.add_theme_font_override("mono_font", font)
		
	debug_theme.default_font_size = 8
	ui_label.add_theme_font_size_override("normal_font_size", 8)
	ui_label.add_theme_font_size_override("bold_font_size", 8)
	ui_label.add_theme_font_size_override("italics_font_size", 8)
	ui_label.add_theme_font_size_override("bold_italics_font_size", 8)
	ui_label.add_theme_font_size_override("mono_font_size", 8)
	ui_label.add_theme_font_size_override("default_font_size", 8)
	
	ui_label.theme = debug_theme
	ui_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	ui_label.add_theme_constant_override("line_separation", 0)
	ui_label.add_theme_color_override("default_color", Color(0.9, 0.9, 0.9, 1.0))
	
	root_control.add_child(ui_label)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_QUOTELEFT:
			root_control.visible = not root_control.visible
			get_viewport().set_input_as_handled()

func add_log(msg: String) -> void:
	var formatted_msg = msg
	if _emoji_regex != null:
		formatted_msg = _emoji_regex.sub(formatted_msg, "[b][color=#FFD700][$1][/color][/b]", true)

	if _num_regex != null:
		formatted_msg = _num_regex.sub(formatted_msg, "[b]$1[/b]", true)

	logs.append(formatted_msg)

	if logs.size() > 50:
		logs.pop_front()

	if ui_label:
		ui_label.text = "\n".join(logs) + "\n"
		_scroll_to_bottom.call_deferred()

func _scroll_to_bottom() -> void:
	if ui_label and is_instance_valid(ui_label):
		var sb = ui_label.get_v_scroll_bar()
		if sb:
			if sb.max_value > 0 and sb.max_value != sb.value:
				sb.value = sb.max_value

func clear_logs() -> void:
	logs.clear()
	if ui_label:
		ui_label.text = ""
