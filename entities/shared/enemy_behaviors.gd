extends EntityBase
class_name EnemyBehaviors

## v1.9 敌人行为多样化（P1-4）：只增加行为节奏，不改动任何敌人数值（血量/防御/伤害/掉落均来自 EntityData）。
## behavior 取值（场景根节点 @export）：
##   &"charge"  近战突进：站桩锁定 → 抬手蓄力（琥珀色闪烁）→ 朝玩家突进 → 休息
##   &"shoot"   远程直射：与玩家保持 170~430px，蓄力后直线发射能量弹（弹色=自身配色）
##   &"suicide" 自爆：近距离激活后高速冲撞，贴身即引爆（双倍接触伤害）并自毁
##   &"summon"  召唤：与玩家保持 240~420px，每 6 秒召唤一只小怪（场上上限 3）
## 说明：ch0 教学关敌人保持木桩行为不变；Boss 仍走 large_slime_ai.gd。

@export var behavior: StringName = &"charge"

# ---- 行为参数（节奏类参数，不属于敌人数值）----
const CHARGE_TRIGGER := 420.0    # 突进触发距离
const CHARGE_WINDUP := 0.45      # 蓄力时间（可走位躲开）
const CHARGE_DASH := 0.40        # 突进持续时间
const CHARGE_SPEED := 300.0      # 突进速度
const CHARGE_REST := 1.4         # 突进后休息
const SHOOT_MIN := 170.0         # 近于此后退
const SHOOT_MAX := 430.0         # 远于此靠近
const SHOOT_WINDUP := 0.5        # 射击蓄力
const SHOOT_REST := 1.8          # 射击间隔
const KEEP_SPEED := 70.0         # 走位速度
const SUICIDE_RANGE := 420.0     # 自爆激活距离
const SUICIDE_SPEED := 150.0     # 自爆冲撞速度
const SUICIDE_BLAST := 44.0      # 引爆距离
const SUICIDE_BLAST_RADIUS := 64.0   # 爆炸伤害半径
const SUMMON_MIN := 240.0        # 召唤者保持距离
const SUMMON_MAX := 420.0
const SUMMON_CD := 6.0           # 召唤冷却
const SUMMON_MAX_MINIONS := 3    # 场上小怪上限
const MINION_TINT := Color(0.72, 0.6, 1.0)

var _state := "idle"
var _state_timer := 0.0
var _dash_dir := 1.0

func _ready() -> void:
	super._ready()
	if String(behavior) == "summon":
		_state_timer = 2.0        # 首次召唤稍作延迟
	if String(behavior) == "suicide" and contact_hitbox != null:
		# 自爆敌的接触伤害统一走引爆判定，避免与 ContactHitbox 双重伤害
		contact_hitbox.set_deferred("monitoring", false)

## 漂浮运动模式（motion_mode=1）下 is_on_floor() 恒为 false，
## entity_base 的重力累积会把 velocity.y 推到 MAX_FALL_SPEED，
## 身体每帧深陷地面 20px，move_and_slide 的碰撞恢复会吞噬水平位移（敌人无法移动）。
## 这里在 super 之后主动探测脚下：着地即清零下落速度，恢复移动能力。
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_dead or data == null: return
	if velocity.y > 0.0 and test_move(global_transform, Vector2(0, 2.0)):
		velocity.y = 0.0

func update_ai(delta: float) -> void:
	if is_dead or data == null or player == null or not is_instance_valid(player): return
	match String(behavior):
		"charge":
			_do_charge(delta)
		"shoot":
			_do_shoot(delta)
		"suicide":
			_do_suicide(delta)
		"summon":
			_do_summon(delta)

func _face_dir() -> float:
	var d := signf(player.global_position.x - global_position.x)
	return 1.0 if d == 0.0 else d

func _enter_state(s: String, dur: float) -> void:
	_state = s
	_state_timer = dur
	match s:
		"windup":
			modulate = Color(1.0, 0.78, 0.35)   # 蓄力：琥珀
		"dash":
			modulate = Color(1.0, 0.55, 0.5)    # 突进：赤
		_:
			modulate = Color(1, 1, 1)

# ================= 近战突进 =================
func _do_charge(delta: float) -> void:
	var dist := global_position.distance_to(player.global_position)
	_state_timer -= delta
	match _state:
		"idle":
			if dist < CHARGE_TRIGGER:
				_dash_dir = _face_dir()
				anim.flip_h = _dash_dir < 0.0
				_enter_state("windup", CHARGE_WINDUP)
		"windup":
			velocity.x = 0.0
			if _state_timer <= 0.0:
				_dash_dir = _face_dir()          # 出手瞬间锁定方向
				anim.flip_h = _dash_dir < 0.0
				_enter_state("dash", CHARGE_DASH)
		"dash":
			velocity.x = _dash_dir * CHARGE_SPEED
			if _state_timer <= 0.0:
				_enter_state("rest", CHARGE_REST)
		"rest":
			if _state_timer <= 0.0:
				_enter_state("idle", 0.0)

# ================= 远程直射 =================
func _do_shoot(delta: float) -> void:
	var dist := global_position.distance_to(player.global_position)
	_state_timer -= delta
	match _state:
		"idle":
			if dist < SHOOT_MAX and dist > SHOOT_MIN:
				_enter_state("windup", SHOOT_WINDUP)
			elif dist >= SHOOT_MAX:
				var d := _face_dir()
				velocity.x = d * KEEP_SPEED
				anim.flip_h = d < 0.0
			else:
				var d2 := _face_dir()
				velocity.x = -d2 * KEEP_SPEED   # 太近则后退
		"windup":
			velocity.x = 0.0
			if _state_timer <= 0.0:
				_enter_state("fire", 0.0)
		"fire":
			_fire_straight()
			_enter_state("rest", SHOOT_REST)
		"rest":
			if _state_timer <= 0.0:
				_enter_state("idle", 0.0)

func _fire_straight() -> void:
	var ball_scene: PackedScene = load("res://fx/slime_ball.tscn")
	if ball_scene == null or data == null: return
	var scene := get_tree().current_scene
	if scene == null: return
	var mult := GameState.get_enemy_damage_multiplier()
	var dmg := maxi(1, int(ceil(float(data.contact_damage) * mult)))
	var dir := _face_dir()
	var b = ball_scene.instantiate()
	b.damage = dmg
	scene.add_child(b)
	if anim != null:
		b.modulate = anim.modulate            # 弹丸继承自身配色
	# 出生点错开自身碰撞体（水平 40px 外、垂直 -40），避免落地射线自伤
	b.launch(global_position + Vector2(dir * 40.0, -40.0), dir, 0.0, true)
	print("🔸 [%s] 直线射击！" % String(data.entity_name))

# ================= 自爆 =================
func _do_suicide(delta: float) -> void:
	var dist := global_position.distance_to(player.global_position)
	if dist > SUICIDE_RANGE: return
	var dir := _face_dir()
	velocity.x = dir * SUICIDE_SPEED
	anim.flip_h = dir < 0.0
	if dist <= SUICIDE_BLAST:
		_explode()

func _explode() -> void:
	if is_dead or data == null: return
	var mult := GameState.get_enemy_damage_multiplier()
	var dmg := maxi(1, int(ceil(float(data.contact_damage) * 2.0 * mult)))
	if global_position.distance_to(player.global_position) <= SUICIDE_BLAST_RADIUS \
			and player.has_method("take_damage"):
		player.take_damage(dmg, global_position)
	ScreenShake.shake(4.0, 0.3)
	print("💥 [%s] 自爆！" % String(data.entity_name))
	die()

# ================= 召唤 =================
func _do_summon(delta: float) -> void:
	var dist := global_position.distance_to(player.global_position)
	var dir := _face_dir()
	if dist < SUMMON_MIN:
		velocity.x = -dir * KEEP_SPEED       # 太近则后退
		anim.flip_h = dir < 0.0
	elif dist > SUMMON_MAX:
		velocity.x = dir * KEEP_SPEED        # 太远则靠近
		anim.flip_h = dir < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	_state_timer -= delta
	if _state_timer > 0.0: return
	if dist < SUMMON_MIN or dist > SUMMON_MAX: return   # 脱位时顺延
	if _alive_minions() >= SUMMON_MAX_MINIONS:
		_state_timer = 1.0                    # 满了稍后重试
		return
	_spawn_minion()
	_state_timer = SUMMON_CD

func _spawn_minion() -> void:
	var minion_scene: PackedScene = load("res://entities/ch0/beginner_slime.tscn")
	if minion_scene == null: return
	var scene := get_tree().current_scene
	if scene == null: return
	var m = minion_scene.instantiate()
	m.set_meta("summoned_by", self)
	m.modulate = MINION_TINT
	m.global_position = global_position + Vector2(randf_range(-40.0, 40.0), 0.0)
	scene.add_child(m)
	print("🌀 [%s] 召唤了虚空造物！（场上小怪将计入通关门）" % String(data.entity_name))

func _alive_minions() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e == self: continue
		if e.get_meta("summoned_by", null) == self and not bool(e.get("is_dead")):
			n += 1
	return n
