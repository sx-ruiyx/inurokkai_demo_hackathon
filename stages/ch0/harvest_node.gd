extends Area2D
class_name HarvestNode

## v1.2 野外采集点：品质（普通/富集/星灵）× 工具等级倍率 → 产量
## 材料收集（冒险模式）与打怪掉宝（探险模式）共同构成材料经济。
## v1.18：取消工具硬门槛——任何物资徒手也能采，工具只提供产量加成。
## v1.12：采集冷却持久化到存档（防止重进场景秒刷无限采集）；刷新时间大幅延长。

@export var material_name: String = "草叶"
@export var yield_min: int = 1
@export var yield_max: int = 2
@export var respawn_time: float = 90.0       # v1.12：基础刷新 30s → 90s
@export var prompt_text: String = "[E] 采集"
@export_enum("普通:0", "富集:1", "星灵:2") var quality: int = 0   # 品质档位
@export var is_ore: bool = false                                     # 是否矿石类
@export var node_id: String = ""                                     # v1.12：唯一 ID（空则按场景+坐标自动生成）

const QUALITY_NAME := ["普通", "富集", "星灵"]
const QUALITY_MULT := [1.0, 1.5, 2.2]
const QUALITY_COLOR := [
	Color(0.35, 0.55, 0.30),   # 普通·草绿
	Color(0.85, 0.65, 0.20),   # 富集·金黄
	Color(0.55, 0.40, 0.90),   # 星灵·紫
]
# v1.12：品质越高刷新越慢（普通 ×1.0 / 富集 ×2.0 / 星灵 ×3.0）
const QUALITY_RESPAWN_MULT := [1.0, 2.0, 3.0]

var _player_in_range: Node2D = null
var _prompt: UITextBox.WorldPrompt
var _depleted := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visual()
	if prompt_text != "":
		_prompt = UITextBox.WorldPrompt.new()
		add_child(_prompt)
	_apply_saved_cd()

## v1.12：跨场景持久化——读存档恢复冷却状态
func _apply_saved_cd() -> void:
	var id := _resolved_id()
	GameState.clear_harvest_node_if_ready(id)
	if GameState.is_harvest_node_depleted(id):
		_set_depleted(true)
		var remain: float = float(GameState.harvested_nodes[id]) - Time.get_unix_time_from_system()
		if remain > 0.0:
			get_tree().create_timer(maxf(remain, 0.1)).timeout.connect(_on_respawn_cd_done)

func _resolved_id() -> String:
	if node_id != "": return node_id
	var scene_path := ""
	var tree := get_tree()
	if tree and tree.current_scene:
		scene_path = tree.current_scene.scene_file_path
	return "%s@%d,%d" % [scene_path.get_file(), int(round(global_position.x)), int(round(global_position.y))]

func _quality_suffix() -> String:
	if quality <= 0: return ""
	return "·" + QUALITY_NAME[quality]

func _build_visual() -> void:
	var color := Color(0.35, 0.55, 0.30)
	if material_name == "矿砂": color = Color(0.55, 0.55, 0.60)
	elif material_name == "木料": color = Color(0.50, 0.35, 0.22)
	# 品质主色覆盖（星灵/富集一眼可辨）
	color = color.lerp(QUALITY_COLOR[quality], 0.55)
	var rect := ColorRect.new()
	rect.size = Vector2(26 + quality * 4, 26 + quality * 4)
	rect.position = Vector2(-(13 + quality * 2), -(30 + quality * 2))
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	if quality > 0:
		var spark := ColorRect.new()
		spark.size = Vector2(6, 6)
		spark.position = rect.position + Vector2(rect.size.x - 2, -8)
		spark.color = Color(1, 1, 1, 0.9)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(spark)

func _unhandled_input(event: InputEvent) -> void:
	if _depleted or not _player_in_range: return
	var dm = DialogueManager.instance()
	if dm._is_playing or dm._is_waiting_choice: return
	if get_tree().paused: return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_E:
		get_viewport().set_input_as_handled()
		_harvest()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"): return
	_player_in_range = body
	if _prompt and not _depleted:
		_prompt.show_prompt(prompt_text + _quality_suffix(), body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body == _player_in_range:
		_player_in_range = null
		if _prompt:
			_prompt.hide_prompt()

func _harvest() -> void:
	if _depleted: return
	# v1.18：取消工具硬门槛——所有物资任何工具档位都能按 E 直接采集，
	# 工具档位只影响产量倍率（徒手 ×1.0 → 星辉镌 ×2.0）
	var base_amount: int = yield_min + randi() % maxi(1, yield_max - yield_min + 1)
	# 产量 = 基础 × 品质倍率 × 工具倍率
	var amount: int = maxi(1, int(round(float(base_amount) * QUALITY_MULT[quality] * GameState.get_gather_multiplier())))
	GameState.add_material(material_name, amount)
	var scene := get_tree().current_scene
	if scene:
		DamageNumber.spawn(scene, global_position + Vector2(0, -30), amount, "heal")
	print("🌿 [采集] 获得 %s%s ×%d（工具 %s ×%.1f）" % [material_name, _quality_suffix(), amount, GameState.get_gather_tool_name(), GameState.get_gather_multiplier()])
	# v1.12：刷新时间 = 基础 × 品质惩罚；冷却写入存档（重进场景/传送回来都认）
	var respawn: float = respawn_time * QUALITY_RESPAWN_MULT[quality]
	GameState.mark_harvest_node(_resolved_id(), Time.get_unix_time_from_system() + respawn)
	_set_depleted(true)
	get_tree().create_timer(respawn).timeout.connect(_on_respawn_cd_done)

func _set_depleted(v: bool) -> void:
	_depleted = v
	for c in get_children():
		if c is ColorRect:
			(c as ColorRect).visible = not v
	if v:
		if _prompt: _prompt.hide_prompt()
	elif _player_in_range and _prompt:
		_prompt.show_prompt(prompt_text + _quality_suffix(), _player_in_range)

func _on_respawn_cd_done() -> void:
	if not is_instance_valid(self): return
	GameState.clear_harvest_node_if_ready(_resolved_id())
	_set_depleted(false)
