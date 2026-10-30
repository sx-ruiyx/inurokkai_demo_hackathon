extends Node
class_name PlayerHealthComponent

@onready var player = get_parent()

var is_dead: bool = false
var is_invincible: bool = false
var invincible_timer: float = 0.0
var hurt_timer: float = 0.0 

var defense: int = 0 

var color_tween: Tween 
var blink_timer: float = 0.0 

const KNOCKBACK_FORCE = 2500.0   
const MIN_KNOCKBACK = 250.0      
const MAX_KNOCKBACK = 900.0      
const INVINCIBLE_DURATION: float = 1.0 

func _process(delta: float) -> void:
	if is_dead: return
	
	if is_invincible:
		invincible_timer -= delta
		
		blink_timer += delta
		
		var blink_speed = 0.08 
		if invincible_timer < 0.4:
			blink_speed = 0.04 
			
		if blink_timer >= blink_speed:
			blink_timer = 0.0
			if is_equal_approx(player.anim.modulate.a, 1.0):
				player.anim.modulate.a = 0.75
			else:
				player.anim.modulate.a = 1.0
				
		if invincible_timer <= 0:
			is_invincible = false
			player.anim.modulate.a = 1.0 
			
	if hurt_timer > 0:
		hurt_timer -= delta

func take_damage(amount: int, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	if is_dead or is_invincible: return
	
	var final_damage = amount
	var is_dashing = player.movement and player.movement.is_dashing
	
	if is_dashing:
		final_damage = max(1, int(amount * 0.5))
		print("🛡️ [霸体] 冲刺撞击受击: 伤害减半 原", amount, " → 最终", final_damage)
	
	var actual_damage = max(1, final_damage - defense)
	GameState.take_damage(actual_damage)

	# 【v1.1】受击反馈：屏幕震动 + 两边红光 + 头顶伤害数字 + 重置濒死脱战计时
	ScreenShake.shake(5.0 + minf(8.0, float(actual_damage)), 0.28)
	GameState.trigger_hurt_vignette()
	GameState.on_player_hurt()
	var scene := get_tree().current_scene
	if scene:
		DamageNumber.spawn(scene, player.global_position + Vector2(0, -36), actual_damage, "player")
	
	if GameState.hp <= 0:
		die()
		return
		
	if color_tween and color_tween.is_valid(): color_tween.kill()
	color_tween = create_tween()
	color_tween.tween_property(player.anim, "modulate:r", 1.0, 0.1) 
	color_tween.parallel().tween_property(player.anim, "modulate:g", 0.3, 0.1) 
	color_tween.parallel().tween_property(player.anim, "modulate:b", 0.3, 0.1) 
	color_tween.tween_property(player.anim, "modulate:r", 1.0, 0.15)   
	color_tween.parallel().tween_property(player.anim, "modulate:g", 1.0, 0.15)   
	color_tween.parallel().tween_property(player.anim, "modulate:b", 1.0, 0.15)   
	
	if is_dashing:
		is_invincible = true
		invincible_timer = 0.2 
		blink_timer = 0.0 
		player.velocity.x *= 0.5 
		return 
		
	is_invincible = true
	invincible_timer = INVINCIBLE_DURATION 
	blink_timer = 0.0 
	
	if player.movement:
		player.movement.is_dashing = false
		player.movement.is_diving = false
		player.movement.dash_timer = 0.0
		player.movement.dive_timer = 0.0
	
	if attacker_pos != Vector2.ZERO:
		var knockback_dir = sign(player.global_position.x - attacker_pos.x)
		if knockback_dir == 0: knockback_dir = 1 
		var force_ratio = float(actual_damage) / float(GameState.get_max_hp())
		var knockback_vel = clamp(KNOCKBACK_FORCE * force_ratio, MIN_KNOCKBACK, MAX_KNOCKBACK)
		player.velocity.x = knockback_dir * knockback_vel
		player.velocity.y = -450.0 
		hurt_timer = 0.4 

func play_heal_effect() -> void:
	if is_dead: return
	if color_tween and color_tween.is_valid(): color_tween.kill()
	color_tween = create_tween()
	color_tween.tween_property(player.anim, "modulate:r", 0.4, 0.15)
	color_tween.parallel().tween_property(player.anim, "modulate:g", 1.0, 0.15)
	color_tween.parallel().tween_property(player.anim, "modulate:b", 0.4, 0.15)
	color_tween.tween_interval(0.1)
	color_tween.tween_property(player.anim, "modulate:r", 1.0, 0.2)
	color_tween.parallel().tween_property(player.anim, "modulate:g", 1.0, 0.2)
	color_tween.parallel().tween_property(player.anim, "modulate:b", 1.0, 0.2)

func die() -> void:
	if is_dead: return
	is_dead = true
	if color_tween and color_tween.is_valid(): color_tween.kill() 
	
	if DebugConsole: 
		DebugConsole.clear_logs()
		
	# 【新增】播放死亡动画，不再只是变灰
	player.anim.play("dead")
	
	# 死亡瞬间渐变为暗灰（视觉反馈）
	var t = create_tween()
	t.tween_property(player.anim, "modulate", Color(0.5, 0.5, 0.5, 1.0), 0.5)
	
	print("💀 [玩家] 死亡: 播放 dead 动画，准备重生")
	
	# dead 动画共 20 帧，按默认帧率约 2 秒播完。等待 2 秒后重载场景。
	await get_tree().create_timer(2.0).timeout
	
	GameState.hp = GameState.get_max_hp()
	GameState.bp = GameState.get_max_bp()
	GameState.current_shield = GameState.get_max_shield()
	
	if DebugConsole: 
		DebugConsole.clear_logs()
	print("🔄 [系统] 场景重载: 玩家满血复活")
	get_tree().reload_current_scene()
