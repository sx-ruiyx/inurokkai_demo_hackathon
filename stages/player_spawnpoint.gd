extends Marker2D

@export_group("Spawn Config")
@export var spawn_id: String = ""
@export var is_default: bool = false

@export_group("Player Scale Config")
@export var spawn_scale: float = 1.0

func _ready() -> void:
	await get_tree().process_frame
	
	if GameState.get_meta("player_spawned", false):
		return 

	var all_spawns := get_tree().get_nodes_in_group("spawn_point")
	if all_spawns.is_empty():
		all_spawns = get_tree().current_scene.find_children("*", "Marker2D", true, false)
		all_spawns = all_spawns.filter(func(n): return n.has_method("_spawn_player"))

	var target_sp = null

	if GameState.use_custom_spawn_pos:
		target_sp = self
		global_position = GameState.next_spawn_position
	elif GameState.next_spawn_id != "":
		for sp in all_spawns:
			if sp.get("spawn_id") == GameState.next_spawn_id:
				target_sp = sp
				break
		# 【核心修复】这里不要清空 GameState.next_spawn_id！等自己真正生成时再清空。
	
	# 只有在没有指定有效 ID 时，才走默认逻辑
	if target_sp == null:
		if all_spawns.size() == 1:
			target_sp = all_spawns[0]
		else:
			for sp in all_spawns:
				if sp.get("is_default"):
					target_sp = sp
					break
			if target_sp == null:
				target_sp = all_spawns[0]

	if target_sp == self:
		GameState.set_meta("player_spawned", true)
		# 【核心修复】只有当目标点是自己时，才把全局 ID 消耗掉
		GameState.next_spawn_id = ""
		GameState.use_custom_spawn_pos = false
		_spawn_player()
	else:
		print("⏭️ [SpawnPoint] ", name, " 跳过。")

func _spawn_player() -> void:
	if not GameState.player_character_data:
		push_error("⚠️ [系统] 玩家角色数据未初始化！")
		return

	var scene = GameState.player_character_data.character_scene
	if scene == null: return

	var body = scene.instantiate()
	body.global_position = global_position
	body.add_to_group("player")

	if not is_equal_approx(spawn_scale, 1.0):
		body.scale = Vector2(spawn_scale, spawn_scale)

	if not body.has_node("Camera2D"):
		var cam = Camera2D.new()
		cam.name = "Camera2D"
		body.add_child(cam)
		
	var cam = body.get_node("Camera2D")
	if not is_equal_approx(spawn_scale, 1.0):
		cam.zoom = Vector2(1.0 / spawn_scale, 1.0 / spawn_scale)

	if not body.has_node("MovementComponent"):
		var mov = load("res://player/player_move.gd").new()
		mov.name = "MovementComponent"
		body.add_child(mov)

	if not body.has_node("CombatComponent"):
		var combat = load("res://player/player_combat.gd").new()
		combat.name = "CombatComponent"
		body.add_child(combat)

	if not body.has_node("SkillComponent"):
		var skills = load("res://player/player_skills.gd").new()
		skills.name = "SkillComponent"
		body.add_child(skills)

	if not body.has_node("HealthComponent"):
		var health = load("res://player/player_health.gd").new()
		health.name = "HealthComponent"
		body.add_child(health)

	var player_script = load("res://player/player.gd")
	var current_script = body.get_script()
	if current_script == null:
		body.set_script(player_script)
	elif current_script != player_script:
		body.set_script(player_script)

	get_parent().add_child.call_deferred(body)
	print("✅ [SpawnPoint] 动态组装玩家成功。出生点: ", name, " | 坐标: ", body.global_position)
