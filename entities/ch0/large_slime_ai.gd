extends EntityBase
class_name LargeSlimeAI

## 吞碑者 AI：接近玩家 → 抬手蓄力 → 投掷史莱姆弹（抛物线）→ 间歇
## 夜晚狂暴：移动/出手更快（倍率取 GameState.get_enemy_damage_multiplier）

const THROW_RANGE := 460.0
const APPROACH_RANGE := 280.0
const MOVE_SPEED := 70.0
const THROW_CD := 3.0
const WINDUP := 0.6
const REST_TIME := 1.8
const PHASE2_HP_RATIO := 0.5     # 半血进入二阶段
const ROAR_TIME := 0.9           # 二阶段咆哮硬直

var _state := "idle"
var _state_timer := 0.0
var _throw_count := 0
var _phase2 := false
var _roared := false

func _ready() -> void:
	super._ready()
	_build_frames()

## 着地理清：Boss 场景同为 motion_mode=1（漂浮），is_on_floor() 恒 false，
## 重力速度累积至 MAX_FALL_SPEED 后 move_and_slide 会吞噬 chase 的水平位移（Boss 从不接近玩家）。
## super 之后用射线探脚下，落地即清零 y 速度（只影响本脚本的 4 个 Boss）。
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_dead or not is_inside_tree(): return
	if velocity.y > 0.0:
		var space := get_world_2d().direct_space_state
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 24))
		q.exclude = [self]
		q.collision_mask = 1
		if not space.intersect_ray(q).is_empty():
			velocity.y = 0.0

func _build_frames() -> void:
	if anim.sprite_frames == null:
		anim.sprite_frames = SpriteFrames.new()
	var sf: SpriteFrames = anim.sprite_frames
	if not sf.has_animation("move"):
		sf.add_animation("move")
		sf.set_animation_speed("move", 10.0)
		sf.set_animation_loop("move", true)
		for i in range(1, 10):
			var path := "res://assets/textures/entities/shared/large_slime/move_%03d.png" % i
			if ResourceLoader.exists(path):
				sf.add_frame("move", load(path))
	if not sf.has_animation("throw"):
		sf.add_animation("throw")
		sf.set_animation_speed("throw", 14.0)
		sf.set_animation_loop("throw", false)
		for i in range(1, 15):
			var path := "res://assets/textures/entities/shared/large_slime/throw_%03d.png" % i
			if ResourceLoader.exists(path):
				sf.add_frame("throw", load(path))

func update_ai(delta: float) -> void:
	if is_dead or player == null or not is_instance_valid(player): return
	_check_phase2()
	var dist := global_position.distance_to(player.global_position)
	var night_mult := GameState.get_enemy_damage_multiplier()
	var speed_mult := 1.35 if _phase2 else 1.0
	_state_timer -= delta
	match _state:
		"idle":
			if anim.animation != "idle": anim.play("idle")
			if dist < THROW_RANGE:
				_set_state("chase")
		"chase":
			if dist > THROW_RANGE:
				velocity.x = 0.0
				_set_state("idle")
			elif dist < APPROACH_RANGE:
				velocity.x = 0.0
				_set_state("windup")
			else:
				var dir := signf(player.global_position.x - global_position.x)
				if dir != 0.0:
					velocity.x = dir * MOVE_SPEED * night_mult * speed_mult
					anim.flip_h = dir < 0.0
		"windup":
			velocity.x = 0.0
			if _state_timer <= 0.0:
				_set_state("throw")
		"throw":
			if _state_timer <= 0.0:
				_fire()
				_throw_count += 1
				var volley := 3 if _phase2 else 2      # 二阶段三连弹
				if _throw_count >= volley:
					_throw_count = 0
					_set_state("rest")
				else:
					_set_state("windup", WINDUP * (0.65 if not _phase2 else 0.45))
		"rest":
			velocity.x = 0.0
			if _state_timer <= 0.0:
				_set_state("chase")
		"roar":
			velocity.x = 0.0
			if anim.animation != "throw": anim.play("throw")
			if _state_timer <= 0.0:
				_set_state("chase")

## 半血进入二阶段：血红 + 咆哮硬直 + 全属性提升（一次性）
func _check_phase2() -> void:
	if _phase2 or is_dead or data == null: return
	if current_hp > float(data.max_hp) * PHASE2_HP_RATIO: return
	_phase2 = true
	_roared = true
	modulate = Color(1.0, 0.5, 0.45)
	_set_state("roar", ROAR_TIME)
	ScreenShake.shake(6.0, 0.5)
	GameState.unlock_achievement("phase2")   # v1.10 成就：首次见证狂暴
	print("🔴 [Boss] %s 进入二阶段！半血狂暴：移速+35%%、出手更快、三连弹" % String(data.entity_name))

func _set_state(s: String, dur: float = -1.0) -> void:
	_state = s
	match s:
		"idle":
			anim.play("idle")
			_state_timer = 0.4
		"chase":
			anim.play("move")
			_state_timer = 2.5
		"windup":
			anim.play("throw")
			anim.frame = 0
			var w := WINDUP if dur < 0.0 else dur
			if _phase2: w *= 0.7
			_state_timer = w
		"throw":
			_state_timer = 0.12
		"rest":
			anim.play("idle")
			var rest := REST_TIME / maxf(0.5, night_mult_guard())
			if _phase2: rest *= 0.65
			_state_timer = rest
		"roar":
			anim.play("throw")
			anim.frame = 0
			_state_timer = ROAR_TIME if dur < 0.0 else dur

func night_mult_guard() -> float:
	return maxf(0.75, GameState.get_enemy_damage_multiplier())

func _fire() -> void:
	var ball_scene: PackedScene = load("res://fx/slime_ball.tscn")
	if ball_scene == null: return
	var mult := GameState.get_enemy_damage_multiplier()
	var dmg := maxi(1, int(ceil(float(data.contact_damage) * mult)))
	var dir := signf(player.global_position.x - global_position.x)
	if dir == 0.0: dir = 1.0
	var scene := get_tree().current_scene
	if scene == null: return
	if _phase2:
		# 三连散射：不同抛射高度形成散射弹幕
		for lift in [-300.0, -150.0, -40.0]:
			var b = ball_scene.instantiate()
			b.damage = dmg
			scene.add_child(b)
			b.launch(global_position + Vector2(dir * 70.0, -90.0), dir, lift)
		print("🔴 [Boss] 三连散射！")
	else:
		var ball = ball_scene.instantiate()
		ball.damage = dmg
		scene.add_child(ball)
		ball.launch(global_position + Vector2(dir * 70.0, -90.0), dir)
		print("🟢 [吞碑者] 投掷史莱姆弹！")
