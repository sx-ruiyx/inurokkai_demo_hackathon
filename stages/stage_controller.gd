extends Node2D

# ================= 场景配置 =================
@export_group("Camera Settings")
@export var limit_left: int = 0
@export var limit_right: int = 4000
@export var limit_top: int = 0
@export var limit_bottom: int = 1056

@export_group("Scene Environment")
@export var bgm_audio: AudioStream
@export var bgm_volume_db: float = -10.0

@export_group("Gameplay Config")
@export var bp_regen_interval: float = 4.0

@export_group("Story Config")
@export_file("*.txt") var intro_script_path: String = ""
## 勾选后，哪怕之前播过，这次进场景也会强制再播一遍（方便开发调试）
@export var force_play_intro: bool = false 

@export_group("Stage Flow")
@export_file("*.tscn") var next_stage_path: String = ""

func _ready() -> void:
	print("🚀 [系统] StageController 启动: ", name)
	GameState.set_meta("player_spawned", false)
	GameState.reset_combat_state() 
	
	_apply_camera_settings()
	_play_bgm()
	_apply_gameplay_config()
	
	if intro_script_path != "" and FileAccess.file_exists(intro_script_path):
		var has_played = intro_script_path in GameState.played_intro_scripts
		
		if force_play_intro or not has_played:
			await get_tree().create_timer(0.2).timeout
			var text = FileAccess.get_file_as_string(intro_script_path)
			if not has_played:
				GameState.played_intro_scripts.append(intro_script_path)
			await DialogueManager.play_text(text, true)
		else:
			print("⏭️ [系统] 剧本已播放过，跳过 Intro: ", intro_script_path)

func goto_next_stage() -> void:
	if next_stage_path == "":
		push_warning("⚠️ [系统] 当前 Stage 没有配置下一关路径 (next_stage_path)！")
		return
	StageRouter.goto_scene(next_stage_path)

func _apply_camera_settings() -> void:
	var player = get_tree().get_first_node_in_group("player")
	
	# 【修复】加入重试次数和节点存活检查，防止死循环崩溃
	var retries = 0
	while not player and retries < 10:
		retries += 1
		await get_tree().process_frame
		
		if not is_inside_tree(): return
		player = get_tree().get_first_node_in_group("player")
		
	if not player:
		print("⚠️ [StageController] 警告: 找不到玩家，无法应用相机边界设置！")
		return
		
	# 【修复】变量名改为 player_cam，避免和前面的 cam 冲突
	var player_cam = player.get_node_or_null("Camera2D")
	if player_cam:
		player_cam.position_smoothing_enabled = false
		player_cam.limit_left = limit_left
		player_cam.limit_right = limit_right
		player_cam.limit_top = limit_top
		player_cam.limit_bottom = limit_bottom
		player_cam.zoom = Vector2.ONE 
		player_cam.global_position = player.global_position

func _play_bgm() -> void:
	if bgm_audio:
		var bgm_player = AudioStreamPlayer.new()
		var stream = bgm_audio.duplicate()
		if stream is AudioStreamOggVorbis: stream.loop = true
		elif stream is AudioStreamMP3: stream.loop = true
		elif stream is AudioStreamWAV: stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		bgm_player.stream = stream
		bgm_player.bus = "BGM"   # v1.9 音频总线
		bgm_player.volume_db = bgm_volume_db
		bgm_player.autoplay = true
		add_child(bgm_player)

func _apply_gameplay_config() -> void:
	GameState.bp_regen_interval = maxf(0.1, bp_regen_interval)
