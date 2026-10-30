extends Area2D
class_name TreasureChest

## 野外宝箱：一次性开启，掉落金币（世界拾取物）+ 材料 + 小概率稀有材料。
## chest_id 用于 GameState.opened_chests 去重（重进场景不重复刷）。

@export var chest_id: String = "chest_default"
@export var gold_min: int = 15
@export var gold_max: int = 40
@export var material_pool: Array[String] = []
@export var rare_material: String = "晶髓"
@export var rare_chance: float = 0.25
@export var prompt_text: String = "[E] 开启宝箱"

var _player_in_range: Node2D = null
var _prompt: UITextBox.WorldPrompt
var _opened := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visual()
	if GameState.is_chest_opened(chest_id):
		_opened = true
		for c in get_children():
			if c is ColorRect: (c as ColorRect).color = Color(0.25, 0.22, 0.18)
	else:
		_prompt = UITextBox.WorldPrompt.new()
		add_child(_prompt)

func _build_visual() -> void:
	var body_rect := ColorRect.new()
	body_rect.size = Vector2(44, 30)
	body_rect.position = Vector2(-22, -30)
	body_rect.color = Color(0.55, 0.40, 0.22)
	body_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body_rect)
	var lid := ColorRect.new()
	lid.size = Vector2(46, 10)
	lid.position = Vector2(-23, -40)
	lid.color = Color(0.72, 0.52, 0.28)
	lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lid)

func _unhandled_input(event: InputEvent) -> void:
	if _opened or not _player_in_range: return
	var dm = DialogueManager.instance()
	if dm._is_playing or dm._is_waiting_choice: return
	if get_tree().paused: return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_E:
		get_viewport().set_input_as_handled()
		_open()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"): return
	_player_in_range = body
	if _prompt and not _opened:
		_prompt.show_prompt(prompt_text, body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body == _player_in_range:
		_player_in_range = null
		if _prompt:
			_prompt.hide_prompt()

func _open() -> void:
	if _opened: return
	_opened = true
	GameState.mark_chest_opened(chest_id)
	if _prompt: _prompt.hide_prompt()
	# 开箱视觉：盖子弹开 + 箱体变暗
	for c in get_children():
		if c is ColorRect:
			var r := c as ColorRect
			if r.size.y < 14:
				var t := r.create_tween()
				t.tween_property(r, "position:y", r.position.y - 14, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			else:
				r.color = Color(0.32, 0.28, 0.20)
	# 掉落
	var scene := get_tree().current_scene
	var gold := gold_min + randi() % maxi(1, gold_max - gold_min + 1)
	if GameState.is_night():
		gold = int(ceil(float(gold) * 1.5))
	var coin_scene: PackedScene = load("res://fx/gold_coin.tscn")
	if scene and coin_scene:
		var coin = coin_scene.instantiate()
		coin.amount = gold
		coin.global_position = global_position + Vector2(0, -20)
		scene.add_child(coin)
	var got := ""
	if material_pool.size() > 0:
		var mat: String = material_pool[randi() % material_pool.size()]
		var cnt := 1 + randi() % 2
		GameState.add_material(mat, cnt)
		got += " %s×%d" % [mat, cnt]
	if randf() < rare_chance:
		GameState.add_material(rare_material, 1)
		got += " %s×1（稀有！）" % rare_material
	ScreenShake.shake(3.0, 0.2)
	print("🎁 [宝箱] 开启 %s：$%d%s" % [chest_id, gold, got])
