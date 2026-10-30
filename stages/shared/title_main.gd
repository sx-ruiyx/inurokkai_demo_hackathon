extends Node2D

# ================= 为袁的 UIMenus 提供依赖 =================
const COL_MASK := Color(0.08, 0.09, 0.12, 0.82)
const COL_MASK_LIGHT := Color(0.25, 0.26, 0.30, 0.72)
const COL_PANEL_BG := Color(0.14, 0.15, 0.19, 0.96)
const COL_PANEL_WHITE := Color(0.96, 0.96, 0.97, 1.0)
const COL_BORDER := Color(0.40, 0.42, 0.50, 1.0)
const COL_TEXT := Color(0.94, 0.94, 0.96)
const COL_TEXT_DIM := Color(0.62, 0.64, 0.70)
const COL_TEXT_DARK := Color(0.10, 0.10, 0.12)
const COL_ACCENT := Color(1, 0.85, 0.4)

const FONT_PATH := "res://assets/fonts/cmdysj.ttf"

enum State { MAIN_MENU, SETTINGS, GAME_HUD, PAUSE, SAVE, BACKPACK, RESULT, NAMING, CREDITS, CHANGELOG, GUIDE }

# ================= 相机平动参数 =================
const PAN_DISTANCE = 150.0  
const PAN_TIME = 12.0       

# ================= 场景与音频配置 =================
@export_group("Stage Flow")
@export_file("*.tscn") var first_stage_path: String = "res://stages/ch0/01_wooden_house.tscn"

@export_group("Scene Environment")
@export var bgm_audio: AudioStream
@export var bgm_volume_db: float = -10.0

var _ui_menus: UIMenus
var _bgm_player: AudioStreamPlayer
var _title_root: Control
var _current_state: int = State.MAIN_MENU

func _ready() -> void:
	print("✅ [MainTitle] 启动，相机平动，强制生成 UI")
	_start_camera_pan()
	_play_bgm()
	_setup_ui()
	_setup_title_art()
	_spawn_walking_character()

# ================= 标题画面：角色自动散步 (v1.1) =================
var _walker: AnimatedSprite2D
var _walker_dir: float = 1.0
var _walker_state: String = "idle"
var _walker_timer: float = 0.0
const WALKER_SPEED := 90.0
const WALKER_MIN_X := 396.0
const WALKER_MAX_X := 756.0

func _spawn_walking_character() -> void:
	_walker = AnimatedSprite2D.new()
	# v1.12 修复陷地：草地贴图视觉表面 y=928，精灵 64×128 缩放 1.5，脚底偏移 (117-64)*1.5=79.5
	# 原 936.0 导致脚底实际落在 y≈1015（陷进地面约 87px）
	_walker.position = Vector2(576.0, 848.5)
	_walker.scale = Vector2(1.5, 1.5)
	_walker.z_index = 5
	var frames := SpriteFrames.new()
	for a in ["idle", "walk"]:
		frames.add_animation(a)
		frames.set_animation_speed(a, 12.0)
		frames.set_animation_loop(a, true)
		for i in range(1, 21):
			var path := "res://assets/textures/characters/shared/bkxy/sprite/%s_%03d.png" % [a, i]
			if ResourceLoader.exists(path):
				frames.add_frame(a, load(path))
	_walker.sprite_frames = frames
	_walker.play("idle")
	add_child(_walker)
	_pick_walker_action()

func _pick_walker_action() -> void:
	if _walker == null: return
	if _walker_state == "idle":
		_walker_dir = 1.0 if randf() < 0.5 else -1.0
		_walker_state = "walk"
		_walker_timer = randf_range(1.5, 4.0)
		_walker.play("walk")
	else:
		_walker_state = "idle"
		_walker_timer = randf_range(1.5, 3.5)
		_walker.play("idle")
	_walker.flip_h = _walker_dir < 0.0

func _process(delta: float) -> void:
	if _walker == null or not is_instance_valid(_walker): return
	if _walker_state == "walk":
		_walker.position.x += _walker_dir * WALKER_SPEED * delta
		if _walker.position.x <= WALKER_MIN_X:
			_walker.position.x = WALKER_MIN_X
			_walker_dir = 1.0
			_walker.flip_h = false
			_walker_timer = randf_range(1.5, 4.0)
		elif _walker.position.x >= WALKER_MAX_X:
			_walker.position.x = WALKER_MAX_X
			_walker_dir = -1.0
			_walker.flip_h = true
			_walker_timer = randf_range(1.5, 4.0)
	_walker_timer -= delta
	if _walker_timer <= 0.0:
		_pick_walker_action()

func _play_bgm() -> void:
	if bgm_audio:
		_bgm_player = AudioStreamPlayer.new()
		var stream = bgm_audio.duplicate()
		if stream is AudioStreamOggVorbis: stream.loop = true
		elif stream is AudioStreamMP3: stream.loop = true
		elif stream is AudioStreamWAV: stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_bgm_player.stream = stream
		_bgm_player.bus = "BGM"   # v1.9 音频总线
		_bgm_player.volume_db = bgm_volume_db
		_bgm_player.autoplay = true
		add_child(_bgm_player)

func _start_camera_pan() -> void:
	var cam = get_node_or_null("Camera2D")
	if not cam: return
	var start_x = cam.position.x
	var tween = create_tween().set_loops()
	tween.tween_property(cam, "position:x", start_x + PAN_DISTANCE, PAN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cam, "position:x", start_x - PAN_DISTANCE, PAN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _setup_ui() -> void:
	var canvas = get_node_or_null("CanvasLayer")
	if not canvas:
		canvas = CanvasLayer.new()
		canvas.name = "CanvasLayer"
		canvas.layer = 110 
		add_child(canvas)
	for child in canvas.get_children(): child.queue_free()

	var ui_theme := Theme.new()
	if ResourceLoader.exists(FONT_PATH):
		var custom_font = load(FONT_PATH)
		if custom_font is Font: ui_theme.default_font = custom_font

	_ui_menus = UIMenus.new()
	_ui_menus.theme = ui_theme
	_ui_menus.bind_manager(self) 
	canvas.add_child(_ui_menus)
	_ui_menus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_menus.switch_page(State.MAIN_MENU)

func _setup_title_art() -> void:
	var canvas = get_node_or_null("CanvasLayer")
	if not canvas: return
	
	var title_layer = CanvasLayer.new()
	title_layer.layer = 105 
	add_child(title_layer)
	
	_title_root = Control.new()
	_title_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.add_child(_title_root)

	var main_tex_path := "res://assets/textures/ui/false_title_cn.png" 
	var sub_tex_path := "res://assets/textures/ui/false_subtitle_jp.png"

	# ==========================================
	# 【核心参数】在这里调整主副标题大小和位置
	# ==========================================
	var main_scale = 1.25  # 主标题缩放
	var main_y_offset = 32 # 主标题 Y 轴微调 (正数下移，负数上移)
	
	var sub_scale = 0.75   # 副标题缩放
	var sub_y_offset = -32  # 副标题 Y 轴微调
	# ==========================================

	if ResourceLoader.exists(main_tex_path):
		var main_tex = load(main_tex_path)
		var main_shadow := _create_title_tex(main_tex, -40, 120, main_scale, main_y_offset)
		main_shadow.offset_left += 6; main_shadow.offset_right += 6
		main_shadow.offset_top += 6; main_shadow.offset_bottom += 6
		main_shadow.modulate = Color(0, 0, 0, 0.4) 
		_title_root.add_child(main_shadow)
		_title_root.add_child(_create_title_tex(main_tex, -40, 120, main_scale, main_y_offset))

	if ResourceLoader.exists(sub_tex_path):
		var sub_tex = load(sub_tex_path)
		var sub_shadow := _create_title_tex(sub_tex, 170, 230, sub_scale, sub_y_offset)
		sub_shadow.offset_left += 4; sub_shadow.offset_right += 4
		sub_shadow.offset_top += 4; sub_shadow.offset_bottom += 4
		sub_shadow.modulate = Color(0, 0, 0, 0.4)
		_title_root.add_child(sub_shadow)
		_title_root.add_child(_create_title_tex(sub_tex, 170, 230, sub_scale, sub_y_offset))

	# 【v1.11 美术集成】主角立绘：右侧淡入装饰（layer 105 在 UI 菜单 110 之下）
	# v1.19 冻结：立绘会遮挡主标题文字，暂不显示（ENABLE_TITLE_PORTRAIT=false 保留代码，
	# 图片 assets/textures/portraits/hero_portrait.png 原样保留，后续恢复改回 true 即可）
	const ENABLE_TITLE_PORTRAIT := false
	var portrait_path := "res://assets/textures/portraits/hero_portrait.png"
	if ENABLE_TITLE_PORTRAIT and ResourceLoader.exists(portrait_path):
		var portrait := TextureRect.new()
		portrait.texture = load(portrait_path)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.anchor_left = 1.0; portrait.anchor_right = 1.0
		portrait.anchor_top = 0.5; portrait.anchor_bottom = 0.5
		portrait.offset_left = -520.0; portrait.offset_right = -8.0
		portrait.offset_top = -300.0; portrait.offset_bottom = 212.0
		portrait.modulate = Color(1, 1, 1, 0.0)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_title_root.add_child(portrait)
		var tw := create_tween()
		tw.tween_property(portrait, "modulate:a", 0.92, 2.0).set_trans(Tween.TRANS_SINE)

	_start_title_float_tween(_title_root)

func _create_title_tex(tex: Texture2D, top_offset: float, bottom_offset: float, _scale: float, y_shift: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.anchor_left = 0.5; rect.anchor_right = 0.5
	rect.offset_left = -700; rect.offset_right = 700
	rect.offset_top = 40 + top_offset + y_shift
	rect.offset_bottom = 40 + bottom_offset + y_shift
	rect.scale = Vector2(_scale, _scale)
	rect.pivot_offset = Vector2(700, (bottom_offset - top_offset) / 2.0) # 保证缩放时中心点不动
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _start_title_float_tween(node: Control) -> void:
	var base_pos := node.position
	_float_title_loop(node, base_pos)

func _float_title_loop(node: Control, base_pos: Vector2) -> void:
	if not is_instance_valid(node): return
	var angle = randf() * TAU
	var distance = randf_range(10.0, 20.0)
	var target_pos = base_pos + Vector2(cos(angle), sin(angle)) * distance
	var time_d = randf_range(3.0, 5.0)
	var t := create_tween()
	t.tween_property(node, "position", target_pos, time_d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func(): _float_title_loop(node, base_pos))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if _current_state == State.NAMING or _current_state == State.SETTINGS or _current_state == State.CHANGELOG or _current_state == State.GUIDE:
				_change_state(State.MAIN_MENU)
				get_viewport().set_input_as_handled()

func _change_state(new_state: int) -> void:
	_current_state = new_state
	
	if new_state in [State.NAMING, State.SETTINGS, State.CREDITS, State.CHANGELOG, State.GUIDE]:
		if _title_root: _title_root.visible = false
		_ui_menus.switch_page(new_state)
	elif new_state == State.GAME_HUD:
		_ui_menus.modulate.a = 0.5 
		if first_stage_path == "":
			push_error("⚠️ [MainTitle] 没有配置首个 Stage！")
			return
		if _bgm_player:
			var t = create_tween()
			t.tween_property(_bgm_player, "volume_db", -80.0, 0.5)
			await t.finished
			
		if has_node("/root/SceneRouter"): 
			StageRouter.goto_scene(first_stage_path)
		else:
			get_tree().change_scene_to_file(first_stage_path)
	elif new_state == State.MAIN_MENU:
		if _title_root: _title_root.visible = true
		_ui_menus.switch_page(State.MAIN_MENU)

func confirm_naming(text: String, _tip: Label) -> void:
	if text.strip_edges() == "":
		return
	_change_state(State.GAME_HUD)

## v1.4 继续游戏：读档后从木屋基地开始（用远征石可传送到最深关卡）
func continue_game() -> void:
	if not GameState.load_game():
		print("⚠️ [MainTitle] 继续游戏失败：没有可用存档")
		return
	_change_state(State.GAME_HUD)
