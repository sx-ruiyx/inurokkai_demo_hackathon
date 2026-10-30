extends Area2D
class_name ExpeditionStone

## v1.3 远征石（挂在木屋）：按 E 打开地图传送面板（v1.10 扩展为全关卡传送）。
## 进度来源：GameState.cleared_stages（由各关通关门 StageGoal 写入）。

@export var prompt_text: String = "[E] 远征传送 · 打开地图"

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
	var stone := ColorRect.new()
	stone.size = Vector2(30, 44)
	stone.position = Vector2(-15, -50)
	stone.color = Color(0.38, 0.42, 0.78)
	stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stone)
	var glow := ColorRect.new()
	glow.size = Vector2(10, 10)
	glow.position = Vector2(-5, -42)
	glow.color = Color(0.75, 0.85, 1.0, 0.95)
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
	UIBasePanel.open_panel("map", self)

func on_panel_closed() -> void:
	_is_open = false

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"): return
	_player_in_range = body
	if _prompt:
		var idx: int = GameState.get_furthest_stage_index()
		var info: Dictionary = GameState.CHAPTER_STAGES[idx]
		_prompt.show_prompt("%s（最深处：第 %d 关 · %s）" % [prompt_text, idx + 1, String(info["name"])], body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body == _player_in_range:
		_player_in_range = null
		if _prompt:
			_prompt.hide_prompt()
