extends EntityBase

@onready var spawn_position: Vector2 = global_position

## 训练靶子：保持木桩（v1.12 基础怪默认追击 AI 不适用于靶子）
func update_ai(_delta: float) -> void:
	pass

func die() -> void:
	if is_dead: return
	is_dead = true
	
	if OS.is_debug_build(): print("💀 [", data.entity_name, "] 被打碎了, 3秒后重生...")
	
	if is_in_combat:
		is_in_combat = false
		GameState.remove_combat_entity()
	
	contact_hitbox.set_deferred("monitoring", false)
	anim.modulate = Color(0.5, 0.5, 0.5)
	if health_bar: health_bar.visible = false
	
	await get_tree().create_timer(3.0).timeout
	
	current_hp = data.max_hp
	global_position = spawn_position + Vector2(0, -10) 
	
	velocity = Vector2.ZERO 
	anim.modulate = Color(1, 1, 1) 
	contact_hitbox.set_deferred("monitoring", true) 
	is_dead = false
	
	if health_bar: 
		health_bar.visible = true
		_update_health_bar()
	
	anim.modulate = Color(1, 0, 0)
	await get_tree().create_timer(0.2).timeout
	anim.modulate = Color(1, 1, 1)
	
	print("✨ [", data.entity_name, "] 重生完毕!")
