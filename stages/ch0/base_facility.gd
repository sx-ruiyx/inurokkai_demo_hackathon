extends Area2D
class_name BaseFacility

## 客厅基地设施交互节点（锻造台 / 菜地 / 酿造台）
## 玩家靠近按 E 打开对应面板；自包含，不依赖其他场景脚本。

@export_enum("forge", "farm", "brew", "save", "ally") var facility_type: String = "forge"
@export var prompt_text: String = "[E] 使用"

var _player_in_range: Node2D = null
var _prompt: UITextBox.WorldPrompt
var _name_label: Label
var _is_open := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visual()
	if prompt_text != "":
		_prompt = UITextBox.WorldPrompt.new()
		add_child(_prompt)

func _build_visual() -> void:
	# 占位视觉：色块台子 + 名称牌（无美术素材时的临时外观）
	match facility_type:
		"forge":
			_add_block(Vector2(72, 40), Vector2(0, -20), Color(0.42, 0.40, 0.44))
			_add_block(Vector2(20, 26), Vector2(-14, -50), Color(0.65, 0.42, 0.22))
			_add_name_label("锻造台")
		"farm":
			_add_block(Vector2(180, 22), Vector2(0, -6), Color(0.36, 0.26, 0.16))
			for i in 4:
				_add_block(Vector2(30, 12), Vector2(-60 + i * 40, -18), Color(0.30, 0.42, 0.20))
			_add_name_label("菜地")
		"brew":
			_add_block(Vector2(64, 44), Vector2(0, -22), Color(0.22, 0.45, 0.35))
			_add_block(Vector2(16, 22), Vector2(0, -52), Color(0.55, 0.75, 0.45))
			_add_name_label("酿造台")
		"save":
			_add_block(Vector2(150, 26), Vector2(0, -13), Color(0.45, 0.30, 0.22))
			_add_block(Vector2(150, 20), Vector2(0, -33), Color(0.62, 0.45, 0.32))
			_add_block(Vector2(40, 18), Vector2(-55, -52), Color(0.85, 0.82, 0.75))
			_add_name_label("卧室（存档）")
		"ally":
			_add_block(Vector2(46, 90), Vector2(0, -45), Color(0.42, 0.44, 0.50))
			_add_block(Vector2(30, 24), Vector2(0, -78), Color(0.55, 0.58, 0.65))
			_add_name_label("盟约石碑")

func _add_block(size: Vector2, offset: Vector2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.size = size
	rect.position = offset - size * 0.5
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)

func _add_name_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.92, 0.90, 0.85))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", 12)
	label.position = Vector2(-30, -84)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label = label
	add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or _is_open: return
	var dm = DialogueManager.instance()
	if dm._is_playing or dm._is_waiting_choice: return
	if get_tree().paused: return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_E:
		get_viewport().set_input_as_handled()
		_open()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"): return
	_player_in_range = body
	if _prompt:
		# 提示已经包含设施名，暂时收起同名名牌，避免两组文字叠在一起
		if _name_label: _name_label.visible = false
		_prompt.show_prompt(prompt_text, body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body == _player_in_range:
		_player_in_range = null
		if _prompt:
			_prompt.hide_prompt()
		if _name_label: _name_label.visible = true

func _open() -> void:
	if _is_open: return
	_is_open = true
	if _prompt: _prompt.hide_prompt()
	UIBasePanel.open_panel(facility_type, self)

func on_panel_closed() -> void:
	_is_open = false
	if _name_label: _name_label.visible = true
