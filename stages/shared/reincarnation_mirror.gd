extends Area2D
class_name ReincarnationMirror

## v1.11 轮回之镜（木屋）：通关 15 关后按 E 打开轮回面板。
## 面板内二次确认后由 GameState.do_reincarnate() 执行轮回（周目+1、关卡进度重置）。

@export var prompt_text: String = "[E] 轮回之镜 · 开启新的轮回"

var _player_in_range: Node2D = null
var _is_open := false
var _prompt: UITextBox.WorldPrompt

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visual()
	_prompt = UITextBox.WorldPrompt.new()
	add_child(_prompt)

func _build_visual() -> void:
	# 镜面
	var frame := ColorRect.new()
	frame.size = Vector2(34, 52)
	frame.position = Vector2(-17, -62)
	frame.color = Color(0.45, 0.40, 0.60)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var glass := ColorRect.new()
	glass.size = Vector2(26, 44)
	glass.position = Vector2(-13, -58)
	glass.color = Color(0.72, 0.68, 0.90, 0.95)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glass)
	var glow := ColorRect.new()
	glow.size = Vector2(8, 8)
	glow.position = Vector2(-4, -50)
	glow.color = Color(0.95, 0.90, 1.0, 0.9)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or _is_open: return
	var dm = DialogueManager.instance()
	if dm._is_playing or dm._is_waiting_choice: return
	if get_tree().paused: return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_E:
		get_viewport().set_input_as_handled()
		_open()

func _open() -> void:
	if _is_open: return
	_is_open = true
	if _prompt: _prompt.hide_prompt()
	UIBasePanel.open_panel("reincarnate", self)

func on_panel_closed() -> void:
	_is_open = false

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"): return
	_player_in_range = body
	if _prompt:
		var text := prompt_text
		if not GameState.is_reincarnation_unlocked():
			text = "轮回之镜黯淡无光（需通关全部 15 关）"
		elif GameState.reincarnation_count >= ReincarnationData.MAX_CYCLES:
			text = "轮回之镜已圆融（%d 回圆满）" % ReincarnationData.MAX_CYCLES
		else:
			text = "%s（当前：%s）" % [prompt_text, ReincarnationData.cycle_name(GameState.reincarnation_count)]
		_prompt.show_prompt(text, body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body == _player_in_range:
		_player_in_range = null
		if _prompt:
			_prompt.hide_prompt()
