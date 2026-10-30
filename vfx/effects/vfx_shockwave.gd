extends Area2D

var damage_multiplier: float = 2.0
var has_hit_targets: Array[Node2D] = [] 

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# 视觉表现：0.1 倍放大到 1.5 倍（你可以换成一个圆形的光环动画）
	scale = Vector2(0.1, 0.1) 
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_QUAD)
	
	# 0.3 秒后自动销毁
	await get_tree().create_timer(0.3).timeout
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage") and not has_hit_targets.has(body):
		has_hit_targets.append(body)
		
		# 冲击波伤害（调用全局伤害公式）
		var final_damage = GameState.calculate_damage(damage_multiplier)
		# 传入中心点，让怪物被震飞
		body.take_damage(final_damage, global_position)
		print("💥 [冲击波] 命中目标, 造成伤害: ", final_damage)
