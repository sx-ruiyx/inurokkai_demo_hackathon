extends Area2D

var speed: float = 600.0
var direction: float = 1.0
var velocity_y: float = 0.0          # 垂直分量（连珠火弹多弹散射用）
var damage_multiplier: float = 6.5
var visual_scale: float = 1.0        # 爆炎术巨大化
var lifetime: float = 0.0            # v1.14：0 = 无限寿命，只有命中才消失
var has_hit: bool = false
var exploding: bool = false          # 爆炸动画播放中（停止移动、关闭碰撞）
# v1.14 两段式施法：第一段悬浮在玩家身前随移动，第二段朝鼠标发射
var held: bool = false
var aim_vector: Vector2 = Vector2.ZERO   # 非零时按此方向飞行（鼠标瞄准）

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _life_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if not is_equal_approx(visual_scale, 1.0):
		scale = Vector2(visual_scale, visual_scale)
	sprite.play("fly")   # v1.13：飞行燃烧动画（原为断剑静图）
	if held:
		# 悬浮阶段不与任何东西碰撞，避免贴身误炸
		set_deferred("monitoring", false)
		$CollisionShape2D.set_deferred("disabled", true)

func _physics_process(delta: float) -> void:
	if exploding: return   # 爆炸中定住原地播动画
	if held: return        # 悬浮中：作为玩家子节点随其移动，不自行位移、不计寿命
	if not aim_vector.is_zero_approx():
		position += aim_vector * speed * delta
	else:
		position.x += speed * direction * delta
		if not is_zero_approx(velocity_y):
			position.y += velocity_y * delta
	# 寿命只在发射后累计（悬浮不倒计时）；lifetime <= 0 表示无限
	if lifetime > 0.0:
		_life_timer += delta
		if _life_timer >= lifetime:
			queue_free()

## v1.14：第二段——脱离玩家、朝目标点（鼠标）发射
func launch_towards(target_global: Vector2) -> void:
	if exploding: return
	held = false
	# 从玩家身上解挂到场景层，保持世界坐标（发射点 = 火球当前所在位置）
	var cur := get_parent()
	var scene := get_tree().current_scene
	if cur and scene and cur != scene:
		var keep_global := global_position
		cur.remove_child(self)
		scene.add_child(self)
		global_position = keep_global
	_apply_launch(target_global)

func _apply_launch(target_global: Vector2) -> void:
	var av := target_global - global_position
	aim_vector = av.normalized() if av.length() > 1.0 else Vector2.RIGHT
	if sprite != null:
		sprite.flip_h = aim_vector.x < -0.01
	# 恢复碰撞
	set_deferred("monitoring", true)
	$CollisionShape2D.set_deferred("disabled", false)

## v1.16 连珠火弹第二发：按第一发的方向发射（不再朝目标点重算）
func launch_in_direction(dir: Vector2) -> void:
	if exploding: return
	held = false
	var cur := get_parent()
	var scene := get_tree().current_scene
	if cur and scene and cur != scene:
		var keep_global := global_position
		cur.remove_child(self)
		scene.add_child(self)
		global_position = keep_global
	# 注意：dir 通常是单位向量（长度恰为 1.0），不能像 _apply_launch 那样用 >1.0 判空
	aim_vector = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	if sprite != null:
		sprite.flip_h = aim_vector.x < -0.01
	set_deferred("monitoring", true)
	$CollisionShape2D.set_deferred("disabled", false)

func _on_body_entered(body: Node2D) -> void:
	if has_hit: return
	if body.has_method("take_damage"):
		has_hit = true
		var final_damage = GameState.calculate_damage(damage_multiplier)

		body.take_damage(final_damage, global_position)
		print("🔥 [火球] 命中目标, 造成伤害: ", final_damage)

		if body.has_method("apply_burn"):
			body.apply_burn(3, 2)

		_explode()

## v1.13：命中后播放爆炸动画再消失（伤害/灼烧逻辑不变）
func _explode() -> void:
	exploding = true
	set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)
	sprite.play("explosion")
	await sprite.animation_finished
	if is_instance_valid(self):
		queue_free()
