extends CharacterBody2D
class_name Companion

## v1.8 福瑞勇者助战召唤（P1-7）：
## 盟约石碑召唤，持续 60 秒。AI：无敌人时跟随玩家，有敌人时突击攻击。
## 外观为占位色块 + 名签（暂无专属美术，管线就绪后可换 SpriteFrames）。

var data: Dictionary = {}
var life := 60.0
var _attack_cd := 0.0
var _fading := false
var _body_sprite: Sprite2D = null

const FOLLOW_DIST := 110.0     # 跟随保持距离
const AGGRO_RANGE := 280.0     # 索敌范围
const ATTACK_RANGE := 46.0     # 攻击距离
const ATTACK_CD := 0.8
const SPEED := 190.0

func setup(d: Dictionary) -> void:
	data = d
	life = float(d.get("duration", 60.0))
	# 外观（v1.12）：有专属立绘则用立绘（512×768 → scale 0.15 ≈ 77×115，脚底对齐 origin），否则回退占位色块
	var portrait_path := String(d.get("portrait", ""))
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		var spr := Sprite2D.new()
		spr.texture = load(portrait_path)
		spr.scale = Vector2(0.15, 0.15)
		spr.position = Vector2(0.0, -57.5)
		spr.z_index = 1
		add_child(spr)
		_body_sprite = spr
	else:
		var body_color: Color = d.get("color", Color(0.6, 0.6, 0.7))
		var body := ColorRect.new()
		body.size = Vector2(26, 34)
		body.position = Vector2(-13, -34)
		body.color = body_color
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(body)
		var head := ColorRect.new()
		head.size = Vector2(20, 18)
		head.position = Vector2(-10, -54)
		head.color = body_color.lightened(0.25)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(head)
	var label := Label.new()
	label.text = String(d.get("name", "勇者"))
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 12)
	label.position = Vector2(-40, -100)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _physics_process(delta: float) -> void:
	if _fading: return
	life -= delta
	if life <= 0.0:
		_despawn()
		return
	_attack_cd -= delta
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		velocity.x = 0.0
		return
	# 索敌：范围内最近的活敌人
	var target: Node2D = null
	var best := AGGRO_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or bool(e.get("is_dead")): continue
		var d := global_position.distance_to(e.global_position)
		if d < best:
			best = d
			target = e
	if target != null:
		var dir := signf(target.global_position.x - global_position.x)
		velocity.x = dir * SPEED
		if global_position.distance_to(target.global_position) <= ATTACK_RANGE and _attack_cd <= 0.0:
			_attack(target)
	else:
		# 跟随：保持 FOLLOW_DIST
		var dist := global_position.distance_to(player.global_position)
		if dist > FOLLOW_DIST:
			var dir := signf(player.global_position.x - global_position.x)
			velocity.x = dir * SPEED * 0.85
		else:
			velocity.x = 0.0
	if _body_sprite != null and is_instance_valid(_body_sprite) and absf(velocity.x) > 1.0:
		_body_sprite.flip_h = velocity.x < 0.0
	move_and_slide()

func _attack(target: Node2D) -> void:
	_attack_cd = ATTACK_CD
	var dmg := int(data.get("attack", 4))
	if target.has_method("take_damage"):
		target.take_damage(dmg, global_position)
		if OS.is_debug_build(): print("🐾 [助战] %s 攻击 %s，造成 %d 伤害" % [String(data.get("name", "勇者")), String(target.name), dmg])

func _despawn() -> void:
	_fading = true
	velocity = Vector2.ZERO
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.5)
	t.tween_callback(queue_free)
