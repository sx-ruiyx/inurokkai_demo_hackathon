extends Area2D
class_name InteractPanel

# 交互行为类型
enum ActionType { 
	NONE,        ## 什么都不做（只显示提示词或抛出信号）
	PLAY_VN,     ## 播放 VN 剧本
	SHIFT_SCENE  ## 切换场景
}

@export_group("Trigger Config")
## 是否需要按 E 键交互（不勾选则玩家碰到自动触发）
@export var require_interact: bool = true
## 是否只触发一次（触发过就失效）
@export var trigger_once: bool = false
## 显示在玩家头顶的提示词（留空则不显示。支持 [E] 键位转义）
@export var prompt_text: String = "[E] 交互"

@export_group("Action Config")
## 触发什么行为
@export var action_type: ActionType = ActionType.NONE

## 【当行为 = PLAY_VN】填写的剧本路径
@export_file("*.txt") var vn_script_path: String = ""

## 【当行为 = SHIFT_SCENE】填写目标场景路径
@export_file("*.tscn") var target_stage_path: String = ""
## 目标场景的出生点 ID（留空则走默认出生点）
@export var target_spawn_id: String = ""

@export_group("Spawn Override (Advanced)")
## 高级：强制覆盖目标出生坐标（慎用，仅在特殊剧情传送时勾选）
@export var override_spawn_pos: bool = false
@export var target_spawn_pos: Vector2 = Vector2.ZERO

# ================= 信号 =================
signal triggered(body: Node2D)
signal interacted(body: Node2D)

var _player_in_range: Node2D = null
var _prompt_ui: UITextBox.WorldPrompt
var _has_triggered: bool = false
var _is_processing: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if prompt_text != "":
		_prompt_ui = UITextBox.WorldPrompt.new()
		add_child(_prompt_ui)

func _unhandled_input(event: InputEvent) -> void:
	if not require_interact or not _player_in_range or _is_processing: return
	if _has_triggered and trigger_once: return
	
	if DialogueManager.instance()._is_playing or DialogueManager.instance()._is_waiting_choice: return
	if get_tree().paused: return
	
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_E:
		get_viewport().set_input_as_handled()
		_execute_action()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"): return
	_player_in_range = body
	
	if _prompt_ui and (not _has_triggered or not trigger_once):
		_prompt_ui.show_prompt(prompt_text, body)
		
	if not require_interact and (not _has_triggered or not trigger_once):
		_execute_action()
	
	triggered.emit(body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body == _player_in_range:
		_player_in_range = null
		if _prompt_ui:
			_prompt_ui.hide_prompt()

func _execute_action() -> void:
	if _is_processing: return
	
	_has_triggered = true
	interacted.emit(_player_in_range)
	
	if _prompt_ui:
		_prompt_ui.hide_prompt()
		
	match action_type:
		ActionType.NONE:
			pass
			
		ActionType.PLAY_VN:
			if vn_script_path != "" and FileAccess.file_exists(vn_script_path):
				_is_processing = true
				var text = FileAccess.get_file_as_string(vn_script_path)
				await DialogueManager.play_text(text)
				_is_processing = false
				
				if _player_in_range and not (_has_triggered and trigger_once) and _prompt_ui:
					_prompt_ui.show_prompt(prompt_text, _player_in_range)
					
		ActionType.SHIFT_SCENE:
			if target_stage_path == "":
				push_error("⚠️ [Interact] 目标 Stage 为空，请在检查器拖入目标 .tscn！")
				return
				
			_is_processing = true
			print("🚪 [系统] 触发 Stage 切换，前往: ", target_stage_path)
			
			GameState.use_custom_spawn_pos = override_spawn_pos
			if override_spawn_pos:
				GameState.next_spawn_position = target_spawn_pos
				GameState.next_spawn_id = ""
			else:
				GameState.next_spawn_id = target_spawn_id
				
			StageRouter.goto_scene(target_stage_path)
