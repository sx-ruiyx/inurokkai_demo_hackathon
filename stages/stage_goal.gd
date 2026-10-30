extends Area2D
class_name StageGoal

## v1.3 通关门（三章十五关流转核心）：
## - 需清怪的门：清空本场景全部敌人后解封（红柱→绿柱）
## - 不需清怪的门：进场即解封
## - 解封即调用 GameState.mark_stage_cleared 记录进度（远征石按此快速传送）
## - 玩家按 E 传送到下一小关

@export var stage_id: String = ""
@export var next_stage_path: String = ""
@export var require_clear: bool = true
@export var prompt_text: String = "[E] 前往下一区域"
## v1.5 终章剧本：配置后，按 E 先播放该 VN（一次性，记入 played_intro_scripts），结束后再传送
@export_file("*.txt") var finale_script_path: String = ""

var _unlocked := false
var _player_in_range: Node2D = null
var _enemy_total := 0
var _prompt: UITextBox.WorldPrompt
var _bar: ColorRect

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visual()
	_prompt = UITextBox.WorldPrompt.new()
	add_child(_prompt)
	if require_clear:
		_watch_enemies()
	else:
		_unlock()

func _build_visual() -> void:
	_bar = ColorRect.new()
	_bar.size = Vector2(26, 130)
	_bar.position = Vector2(-13, -140)
	_bar.color = Color(0.85, 0.32, 0.25, 0.85)   # 封印·红
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	var cap := ColorRect.new()
	cap.size = Vector2(34, 12)
	cap.position = Vector2(-17, -152)
	cap.color = Color(0.92, 0.88, 0.80, 0.95)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cap)

func _watch_enemies() -> void:
	# 等 2 秒让生成器把敌人放进 enemies 组，避免误判空场
	await get_tree().create_timer(2.0).timeout
	_enemy_total = _enemies_alive()
	while is_inside_tree():
		var alive := _enemies_alive()
		if alive == 0:
			break
		# v1.9 关卡内指引：封印期间向门口玩家实时播报清敌进度
		if _player_in_range:
			_prompt.show_prompt("清空敌人 %d / %d" % [alive, _enemy_total], _player_in_range)
		await get_tree().create_timer(0.6).timeout
	if not is_inside_tree(): return
	_unlock()

func _enemies_alive() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not bool(e.get("is_dead")):
			n += 1
	return n

func _unlock() -> void:
	if _unlocked: return
	_unlocked = true
	if stage_id != "":
		GameState.mark_stage_cleared(stage_id)
	if _bar:
		_bar.color = Color(0.32, 0.85, 0.45, 0.95)
	if _player_in_range:
		_prompt.show_prompt(prompt_text, _player_in_range)

func _unhandled_input(event: InputEvent) -> void:
	if not _unlocked or not _player_in_range: return
	var dm = DialogueManager.instance()
	if dm._is_playing or dm._is_waiting_choice: return
	if get_tree().paused: return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_E:
		get_viewport().set_input_as_handled()
		if next_stage_path == "":
			push_warning("⚠️ [StageGoal] 未配置 next_stage_path！")
			return
		GameState.next_spawn_id = ""
		GameState.use_custom_spawn_pos = false
		# v1.5 终章：先播结局 VN（一次性），落幕后再传送。
		# 注意：DialogueManager.play_text 是"即返回"协程（内部遇定时器就让出），
		# 不能靠 await 它等待播完——必须轮询 _is_playing / _is_waiting_choice。
		if finale_script_path != "" and FileAccess.file_exists(finale_script_path) \
				and not (finale_script_path in GameState.played_intro_scripts):
			GameState.played_intro_scripts.append(finale_script_path)
			DialogueManager.play_text(FileAccess.get_file_as_string(finale_script_path), true)
			while dm._is_playing or dm._is_waiting_choice:
				await get_tree().create_timer(0.3).timeout
			await get_tree().create_timer(0.6).timeout   # 等落幕淡出
			StageRouter.goto_scene(next_stage_path)
			return
		StageRouter.goto_scene(next_stage_path)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"): return
	_player_in_range = body
	if _unlocked:
		_prompt.show_prompt(prompt_text, body)
	elif _enemy_total > 0:
		_prompt.show_prompt("清空敌人 %d / %d" % [_enemies_alive(), _enemy_total], body)
	else:
		_prompt.show_prompt("封印未解 · 清空敌人后开启", body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body == _player_in_range:
		_player_in_range = null
		_prompt.hide_prompt()
