extends Node
class_name PlayerMovementComponent

@onready var player = get_parent()

# ================= 移动手感配置 =================
var speed: float = 300.0
var jump_velocity: float = -400.0
var acceleration: float = 1800.0
var air_acceleration: float = 1000.0
var friction: float = 2000.0
var air_friction: float = 500.0

# ================= 冲刺配置 (v1.12 手感重做) =================
var dash_speed: float = 780.0        # 冲刺峰值速度（原 800）
var dash_time: float = 0.22          # 冲刺时长（原 0.25）
var dash_cooldown: float = 0.45      # 冲刺 CD（原 0.5）
var dash_slide_time: float = 0.12    # 冲刺结束后的动量滑行时长（新增，解决"急停"生硬）
var dash_ramp: float = 0.06          # 起步加速时长（新增，解决"瞬间全速"生硬）
var dive_speed: float = 900.0
var double_tap_time: float = 0.22    # 双击窗口（原 0.2 略严）
var max_dive_time: float = 2.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_dashing = false
var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var last_dash_end_time: float = -999.0
var is_diving = false
var dive_timer = 0.0

# ================= 下坠攻击（S/↓ 落地 AOE）=================
var dive_damage: int = 5                 # 落地对范围内所有敌人造成的伤害
var dive_damage_cooldown: float = 0.5    # 伤害触发冷却
var dive_damage_radius: float = 170.0    # 蓝色圆框范围（圆形，与普攻同形状）≈ 普攻半径
var dive_damage_timer: float = 0.0
var dash_direction = 1.0
var dash_started_on_floor: bool = true   # 地面冲刺贴地；空中冲刺保留重力
var dash_slide_timer = 0.0               # >0 表示冲刺结束后的滑行阶段
var dash_slide_speed = 0.0
var last_tap_time_left = 0.0
var last_tap_time_right = 0.0

# 确保路径对齐 effects 目录
const SHOCKWAVE_SCENE = preload("res://vfx/effects/vfx_shockwave.tscn")

func _physics_process(delta: float) -> void:
	if dash_cooldown_timer > 0: dash_cooldown_timer -= delta
	if dive_damage_timer > 0: dive_damage_timer -= delta

	if not player.can_move or player.health.is_dead or player.health.hurt_timer > 0:
		player.velocity.x = move_toward(player.velocity.x, 0, friction * delta)
		if not player.is_on_floor(): player.velocity.y += gravity * delta
		player.move_and_slide()
		return

	var current_time = Time.get_ticks_msec() / 1000.0

	# 双击方向键冲刺（保留）
	if Input.is_action_just_pressed("move_left"):
		if current_time - last_tap_time_left < double_tap_time and dash_cooldown_timer <= 0 and not is_dashing and dash_slide_timer <= 0.0:
			trigger_dash(-1)
		last_tap_time_left = current_time
	if Input.is_action_just_pressed("move_right"):
		if current_time - last_tap_time_right < double_tap_time and dash_cooldown_timer <= 0 and not is_dashing and dash_slide_timer <= 0.0:
			trigger_dash(1)
		last_tap_time_right = current_time
	# Shift 冲刺（v1.12 新增，方向取当前输入或面朝方向）
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing and dash_slide_timer <= 0.0 and not is_diving:
		var dir := Input.get_axis("move_left", "move_right")
		if dir == 0.0:
			dir = -1.0 if player.anim.flip_h else 1.0
		trigger_dash(signf(dir))

	var direction = Input.get_axis("move_left", "move_right")

	if is_dashing:
		dash_timer -= delta
		# 速度曲线：起步 dash_ramp 内平滑加速到峰值，尾段线性缓降到 55%（避免瞬间全速/瞬间停止）
		var progress := 1.0 - maxf(0.0, dash_timer) / dash_time
		var factor := 1.0
		if progress < dash_ramp / dash_time:
			factor = progress / (dash_ramp / dash_time)
			factor = factor * factor * (3.0 - 2.0 * factor)   # smoothstep
		else:
			factor = lerpf(1.0, 0.55, (progress - dash_ramp / dash_time) / (1.0 - dash_ramp / dash_time))
		player.velocity.x = dash_direction * dash_speed * factor
		# 地面冲刺贴地（y 锁 0）；空中冲刺保留重力，可冲刺接跳跃/下坠
		if dash_started_on_floor:
			player.velocity.y = 0.0
		else:
			player.velocity.y += gravity * delta
		if dash_timer <= 0:
			_end_dash(current_time)
	else:
		if not player.is_on_floor(): player.velocity.y += gravity * delta
		if Input.is_action_just_pressed("jump") and player.is_on_floor(): player.velocity.y = jump_velocity

		if Input.is_action_just_pressed("move_down") and not player.is_on_floor() and not is_diving:
			is_diving = true
			dive_timer = 0.0
			player.velocity.x = 0
			player.velocity.y = dive_speed

		if is_diving:
			dive_timer += delta
			player.velocity.y = dive_speed
			player.velocity.x = 0
			if player.is_on_floor() or dive_timer > max_dive_time:
				is_diving = false
				trigger_shockwave()
				if player.is_on_floor():   # 只有真正落地才结算 AOE（坠坑超时不伤人）
					_apply_dive_damage()

		# 冲刺结束滑行：动量自然衰减（v1.12）
		if dash_slide_timer > 0.0:
			dash_slide_timer -= delta
			player.velocity.x = move_toward(player.velocity.x, 0.0, (dash_slide_speed / dash_slide_time) * delta)

		if not is_diving and dash_slide_timer <= 0.0:
			if player.combat.is_charging:
				# 【v1.1】蓄力时移动减速（可缓慢挪动，增加风险博弈）
				player.velocity.x = move_toward(player.velocity.x, direction * speed * 0.35, acceleration * delta)
			elif player.combat.is_attacking:
				if player.combat.lunge_timer > 0.0:
					# 冲刺取消攻击的前冲：缓慢衰减保留位移（v1.12 连贯性）
					player.velocity.x = move_toward(player.velocity.x, 0.0, friction * 0.5 * delta)
				elif abs(player.velocity.x) > 200.0:
					player.velocity.x = move_toward(player.velocity.x, 0, (friction * 0.15) * delta)
				else:
					player.velocity.x = move_toward(player.velocity.x, 0, friction * delta)
			else:
				if direction != 0:
					var current_accel = acceleration if player.is_on_floor() else air_acceleration
					player.velocity.x = move_toward(player.velocity.x, direction * speed, current_accel * delta)
				else:
					var current_friction = friction if player.is_on_floor() else air_friction
					player.velocity.x = move_toward(player.velocity.x, 0, current_friction * delta)

	player.move_and_slide()

func trigger_dash(dir: float):
	is_dashing = true
	dash_timer = dash_time
	dash_cooldown_timer = dash_cooldown
	dash_direction = dir
	dash_slide_timer = 0.0
	dash_started_on_floor = player.is_on_floor()

func _end_dash(current_time: float) -> void:
	is_dashing = false
	last_dash_end_time = current_time
	# 进入滑行：保留当前速度的 60%，在 dash_slide_time 内衰减到 0
	dash_slide_speed = abs(player.velocity.x) * 0.6
	dash_slide_timer = dash_slide_time

## 冲刺被攻击取消时调用：结束冲刺并保留前冲速度（v1.12 冲刺攻击连贯性）
func cancel_dash_for_attack() -> void:
	is_dashing = false
	dash_cooldown_timer = dash_cooldown * 0.5   # 冲刺转攻击只付一半 CD（鼓励进攻）
	last_dash_end_time = Time.get_ticks_msec() / 1000.0
	dash_slide_speed = abs(player.velocity.x) * 0.8
	dash_slide_timer = dash_slide_time

func trigger_shockwave() -> void:
	var shockwave = SHOCKWAVE_SCENE.instantiate()
	shockwave.global_position = player.global_position + Vector2(0, 20)
	player.get_parent().add_child.call_deferred(shockwave)
	var camera = player.get_node_or_null("Camera2D")
	if camera:
		var tween = player.create_tween()
		var original_pos = camera.position
		tween.tween_property(camera, "position", original_pos + Vector2(8, -8), 0.05)
		tween.tween_property(camera, "position", original_pos + Vector2(-8, 8), 0.05)
		tween.tween_property(camera, "position", original_pos, 0.05)

## 【下坠攻击】落地 AOE：对半径 dive_damage_radius（圆形，同普攻蓝圈范围）内
## 的所有敌人造成 dive_damage 点伤害，冷却 dive_damage_cooldown 秒
func _apply_dive_damage() -> void:
	if dive_damage_timer > 0: return
	dive_damage_timer = dive_damage_cooldown

	var DamageNumberScript = preload("res://fx/damage_number.gd")
	var hit_count := 0
	for node in player.get_tree().get_nodes_in_group("enemies"):
		if node is Node2D and is_instance_valid(node) and node.has_method("take_damage"):
			if node.global_position.distance_to(player.global_position) <= dive_damage_radius:
				node.take_damage(dive_damage, player.global_position)
				DamageNumberScript.spawn(player.get_parent(), node.global_position + Vector2(0, -46), dive_damage, "enemy")
				hit_count += 1
	if hit_count > 0:
		print("💥 [下坠] 落地冲击命中 %d 个敌人，各 %d 点伤害" % [hit_count, dive_damage])
