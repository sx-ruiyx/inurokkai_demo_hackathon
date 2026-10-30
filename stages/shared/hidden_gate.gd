extends Area2D
class_name HiddenGate

## v1.9 隐藏关卡入口（P2-10）：
## - require_stages 全部通关后才显现并可交互（否则不可见、不监测）
## - 按 E 传送到隐藏关卡目标出生点

@export var prompt_text: String = "[E] 踏入神秘入口"
@export_file("*.tscn") var target_stage_path: String = ""
@export var target_spawn_id: String = ""
@export_group("Unlock Condition")
## 需要全部通关才会显现（留空则一直显现）
@export var require_stages: Array[String] = []

var _player_in_range: Node2D = null
var _prompt: UITextBox.WorldPrompt
var _unlocked := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_unlocked = require_stages.is_empty() or GameState.are_stages_cleared(require_stages)
	visible = _unlocked
	monitoring = _unlocked
	if _unlocked:
		_prompt = UITextBox.WorldPrompt.new()
		add_child(_prompt)

func _unhandled_input(event: InputEvent) -> void:
	if not _unlocked or not _player_in_range: return
	if DialogueManager.instance()._is_playing or DialogueManager.instance()._is_waiting_choice: return
	if get_tree().paused: return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_E:
		get_viewport().set_input_as_handled()
		GameState.next_spawn_id = target_spawn_id
		GameState.use_custom_spawn_pos = false
		GameState.unlock_achievement("hidden")   # v1.10 成就：首次踏入秘境
		StageRouter.goto_scene(target_stage_path)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"): return
	_player_in_range = body
	if _prompt:
		_prompt.show_prompt(prompt_text, body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body == _player_in_range:
		_player_in_range = null
		if _prompt:
			_prompt.hide_prompt()
