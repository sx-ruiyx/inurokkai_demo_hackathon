extends Node
class_name DialogueManager

static var _instance = null

var _ui: CanvasLayer = null
var _parsed_script: Dictionary = {}
var _current_branch: String = ""
var _current_node: String = ""
var _instruction_index: int = 0
var _is_playing: bool = false
var _is_waiting_choice: bool = false 
var _cached_player: Node = null

static func instance():
	if _instance == null or not is_instance_valid(_instance):
		var dm = DialogueManager.new()
		Engine.get_main_loop().root.add_child(dm)
		_instance = dm
	return _instance

static func play_text(raw_text: String, instant_in: bool = false) -> void:
	await instance()._play_text(raw_text, instant_in)

static func force_stop() -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance._force_stop_internal()

func _force_stop_internal() -> void:
	_is_playing = false
	_is_waiting_choice = false
	if _ui and is_instance_valid(_ui):
		_ui.queue_free()
		_ui = null
	if _cached_player and is_instance_valid(_cached_player):
		_cached_player.can_move = true
		_cached_player = null

func _ensure_ui() -> CanvasLayer:
	if _ui != null and is_instance_valid(_ui): return _ui
	_ui = load("res://vn/vn_dialogue.gd").new()
	_ui.line_advanced.connect(_on_line_advanced)
	_ui.choice_made.connect(_on_choice_made)
	Engine.get_main_loop().root.add_child(_ui)
	return _ui

func _play_text(raw_text: String, instant_in: bool = false) -> void:
	_parsed_script = DialogueParser.parse_text(raw_text)
	
	if _parsed_script.is_empty():
		push_error("⚠️ [VN_Manager] 剧本解析为空！")
		return
		
	_ensure_ui()
	_ui.instant_in = instant_in 
	_is_playing = true
	_is_waiting_choice = false
	
	_cached_player = get_tree().get_first_node_in_group("player")
	if _cached_player:
		_cached_player.can_move = false
		if _cached_player.combat:
			_cached_player.combat.is_attacking = false
		if _cached_player.movement:
			_cached_player.movement.is_dashing = false
			_cached_player.movement.is_diving = false
	
	# 直接隐藏所有实体血条
	var root = get_tree().current_scene
	if root:
		for n in root.find_children("*", "", true, false):
			if "health_bar" in n and n.health_bar:
				n.health_bar.visible = false
				n.health_bar.modulate.a = 0.0
	
	if _parsed_script.has("characters"):
		for char_id in _parsed_script["characters"]:
			_ui.register_character(char_id, _parsed_script["characters"][char_id])
	
	_current_branch = "0"
	_current_node = "0"
	_instruction_index = 0
	_process_next()

func _process_next() -> void:
	if not _is_playing or not is_instance_valid(_ui): return
	
	if not _parsed_script.has(_current_branch) or not _parsed_script[_current_branch].has(_current_node):
		_end_dialogue()
		return
		
	var instructions: Array = _parsed_script[_current_branch][_current_node]
	if _instruction_index >= instructions.size():
		_end_dialogue()
		return
		
	var cmd = instructions[_instruction_index]
	
	match cmd["type"]:
		"char_action":
			var color = Color.WHITE
			if GameState.player_character_data:
				var c_name = _ui._char_names.get(cmd["char_id"], "")
				if c_name == "白柯行以":
					color = GameState.get_theme_color()
					
			_ui.execute_character_action(
				cmd["char_id"], 
				cmd["pos_target"], 
				cmd["is_move"], 
				cmd["emotion"], 
				cmd["text"], 
				cmd["is_remove"]
			)
			if cmd["text"] != "":
				_instruction_index += 1
				_ui.start_line("say", _ui._char_names.get(cmd["char_id"], ""), cmd["text"], color)
				return
			else:
				_instruction_index += 1
				_process_next()
			
		"narrate":
			_instruction_index += 1
			_ui.start_line("narrate", "", cmd["text"], Color.WHITE)
			return
			
		"title":
			_instruction_index += 1
			_ui.show_title(cmd["text"])
			return 
			
		"tip":
			_instruction_index += 1
			_ui.show_tip(cmd["text"])
			_process_next()
			return
			
		"whiteout":
			_instruction_index += 1
			_ui.set_whiteout(cmd["val"])
			await get_tree().create_timer(0.4).timeout
			if _is_playing and is_instance_valid(_ui): _process_next()
			return
				
		"hide":
			_instruction_index += 1
			if cmd["val"] == 1: _ui.hide_box()
			else: _ui.show_box()
			_process_next()
			return
			
		"pause":
			_instruction_index += 1
			_ui.set_hint_visible(false)
			await get_tree().create_timer(cmd["val"]).timeout
			if _is_playing and is_instance_valid(_ui): 
				_ui.set_hint_visible(true)
				_process_next()
			return
			
		"choice":
			_instruction_index += 1
			_ui.show_choices(cmd["options"])
			_is_playing = false 
			_is_waiting_choice = true
			return
			
		"end":
			_end_dialogue()
			return

func _on_line_advanced() -> void:
	if _is_playing:
		_process_next()
	elif not _is_waiting_choice and _ui and is_instance_valid(_ui):
		_ui.set_whiteout("_")
		_ui.fade_out_and_destroy()
		await get_tree().create_timer(0.3).timeout
		if is_instance_valid(_ui):
			_ui.queue_free()
			_ui = null
			
		if _cached_player and is_instance_valid(_cached_player):
			_cached_player.can_move = true
			
		var root = get_tree().current_scene
		if root:
			for n in root.find_children("*", "", true, false):
				if n.has_method("force_refresh_combat_state"):
					n.force_refresh_combat_state()
		if GameState:
			GameState.force_refresh_combat_ui()

func _on_choice_made(branch: String, node: String) -> void:
	if not _is_waiting_choice: return 
	
	_is_waiting_choice = false
	_current_branch = branch
	_current_node = node
	_instruction_index = 0
	_is_playing = true
	_process_next()

func _end_dialogue() -> void:
	_is_playing = false
	_is_waiting_choice = false 
	
	if _ui and is_instance_valid(_ui):
		if _ui._blocker.color.a > 0.9:
			pass 
		else:
			_ui.fade_out_and_destroy()
			await get_tree().create_timer(0.3).timeout
			if is_instance_valid(_ui):
				_ui.queue_free()
				_ui = null
		
	if _cached_player and is_instance_valid(_cached_player):
		_cached_player.can_move = true
	
	var root = get_tree().current_scene
	if root:
		for n in root.find_children("*", "", true, false):
			if n.has_method("force_refresh_combat_state"):
				n.force_refresh_combat_state()
				
	if GameState:
		GameState.force_refresh_combat_ui()
		
	print("🏁 [VN] 剧本播放完毕")
