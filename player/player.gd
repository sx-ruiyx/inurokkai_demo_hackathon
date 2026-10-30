extends CharacterBody2D

var can_move: bool = true
var attack_offset_x: float = 0.0   # v1.13 普攻改蓝色圆框（圆心=玩家中心），不再前后偏移

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox 
@onready var movement: PlayerMovementComponent = $MovementComponent
@onready var combat: PlayerCombatComponent = $CombatComponent
@onready var skills: PlayerSkillComponent = $SkillComponent      
@onready var health: PlayerHealthComponent = $HealthComponent    

var was_slashing: bool = false 
const HANG_VELOCITY_THRESHOLD = 80.0 

var was_on_floor: bool = true
var is_jumping_anim: bool = false
var is_landing_anim: bool = false

func _ready() -> void:
	if not has_node("MovementComponent") or not has_node("CombatComponent") or not has_node("AnimatedSprite2D"):
		push_error("⚠️ [玩家] 致命错误：缺少核心组件！请检查生成逻辑。")
		return
		
	attack_hitbox.monitoring = false
	attack_hitbox.body_entered.connect(combat._on_attack_hitbox_body_entered)
	_setup_weapon_hitbox()
	anim.animation_finished.connect(_on_anim_finished)

func _on_anim_finished() -> void:
	if anim.animation == "jump":
		is_jumping_anim = false
	elif anim.animation == "land":
		is_landing_anim = false

func _setup_weapon_hitbox() -> void:
	# v1.12 判定重做（原圆形半径 32、世界中心 (70,0)，竖直只到 +32，离脚底 (+82) 差 50px，
	# 贴脚/地面敌人常打不到）：
	#   主判定 120×150  世界 (80,-15)  → x[20,140]  y[-90,60]   身前大范围
	#   下刺   100×100  世界 (70, 90)  → x[20,120]  y[40,140]  脚底以下 58px，专治贴脚与一层高差
	#   背刺    44×120  世界 (-28,-10) → x[-50,-6]  y[-70,50]   身后判定
	# 朝左时 player.gd _physics_process 设 scale.x=-1 自动镜像三个形状
	attack_hitbox.position.x = attack_offset_x

func _physics_process(_delta):
	if health and health.is_dead:
		if anim.animation != "dead": anim.play("dead")
		return

	var direction = 0
	if can_move:
		direction = Input.get_axis("move_left", "move_right")

	if direction != 0:
		anim.flip_h = direction < 0
		if anim.flip_h:
			attack_hitbox.position.x = -attack_offset_x
			attack_hitbox.scale.x = -1
		else:
			attack_hitbox.position.x = attack_offset_x
			attack_hitbox.scale.x = 1

	var on_floor = is_on_floor()
	if was_on_floor and not on_floor and velocity.y < 0:
		anim.play("jump")
		is_jumping_anim = true
		is_landing_anim = false
	elif not was_on_floor and on_floor:
		anim.play("land")
		is_landing_anim = true
		is_jumping_anim = false
	was_on_floor = on_floor

	if combat.is_attacking: 
		is_jumping_anim = false
		is_landing_anim = false
		if anim.animation != "slash": anim.play("slash")
	elif movement.is_dashing: 
		is_jumping_anim = false
		is_landing_anim = false
		if anim.animation != "dash": anim.play("dash")
	elif movement.is_diving: 
		is_jumping_anim = false
		is_landing_anim = false
		if anim.animation != "dive": anim.play("dive")
	elif is_jumping_anim or is_landing_anim:
		pass 
	elif not on_floor: 
		if velocity.y < -HANG_VELOCITY_THRESHOLD:
			if anim.animation != "hang": anim.play("hang") # 上升期也用 hang 替代
		elif velocity.y > HANG_VELOCITY_THRESHOLD:
			if anim.animation != "fall": anim.play("fall")
		else:
			if anim.animation != "hang": anim.play("hang")
	elif abs(velocity.x) > 10.0: 
		if anim.animation != "walk": anim.play("walk")
	else: 
		if anim.animation != "idle": anim.play("idle")
		
	if combat.is_attacking and not was_slashing:
		_spawn_slash_effect()
	was_slashing = combat.is_attacking 

func _spawn_slash_effect() -> void:
	var vfx = SlashVFX.new()
	# 剑光落在主判定中心附近（朝左镜像）
	var fx := 1.0 if not anim.flip_h else -1.0
	vfx.global_position = global_position + Vector2(70.0 * fx, -15.0)
	vfx.z_index = 10 
	get_parent().add_child(vfx)
	
	var base_scale_x = -1.0 if anim.flip_h else 1.0
	var base_scale = Vector2(base_scale_x, 1.0)
	
	var t = create_tween()
	t.set_parallel(true)
	vfx.scale = base_scale * 0.5
	vfx.modulate.a = 1.0
	t.tween_property(vfx, "scale", base_scale * 1.5, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(vfx, "modulate:a", 0.0, 0.2)
	t.chain().tween_callback(vfx.queue_free)

func _unhandled_input(event: InputEvent) -> void:
	if not can_move or health.is_dead or health.hurt_timer > 0:
		return
	# v1.12：J 键攻击。按下=蓄力/缓存连击，松开=结算
	if Input.is_action_just_pressed("attack"):
		combat.start_charge()
	if Input.is_action_just_released("attack"):
		combat.release_charge()
	# v1.13：鼠标左键同样触发普攻（与 J 键同一套蓄力/结算管线）
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# v1.18 两段式火球：身前有悬浮火球时，鼠标左键点击 = 直接释放火球
		# （朝鼠标方向，方向判定与第二段相同），该次点击不进入普攻蓄力/结算管线
		if skills.is_holding_fireball():
			if event.pressed:
				skills._launch_held_fireball()
			return
		if event.pressed:
			combat.start_charge()
		else:
			combat.release_charge()

func take_damage(amount: int, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	if health: health.take_damage(amount, attacker_pos)

class SlashVFX extends Node2D:
	func _draw() -> void:
		var size_val = 60.0 
		var rect_outer = Rect2(-size_val / 2.0, -size_val / 2.0, size_val, size_val)
		draw_rect(rect_outer, Color.WHITE, false, 6.0) 
		var inner_size = size_val - 16.0
		var rect_inner = Rect2(-inner_size / 2.0, -inner_size / 2.0, inner_size, inner_size)
		draw_rect(rect_inner, Color(0.8, 0.95, 1.0), false, 2.0) 
		var core_size = 8.0
		var rect_core = Rect2(-core_size / 2.0, -core_size / 2.0, core_size, core_size)
		draw_rect(rect_core, Color(1, 1, 1, 0.8), true)
