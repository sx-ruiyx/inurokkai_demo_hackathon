extends Node
class_name PlayerCombatComponent

@onready var player = get_parent()

# ================= 战斗手感配置 (v1.12 重设计) =================
# 攻击键 = J（鼠标左键已移除）；轻击为三段连击，蓄力斩保留
var attack_cd: float = 0.30            # 连击段间冷却（原 0.5，过慢）
var attack_duration: float = 0.16      # 单段判定持续时间（原 0.2）
var heavy_attack_multiplier: float = 1.6   # 冲刺/取消重击倍率（原 1.5）
var miss_penalty: float = 0.08         # 挥空惩罚（原 1.0，过于惩罚导致手感断裂）
var heavy_attack_window: float = 0.30  # 冲刺结束后接重击的窗口（原 0.15 太短）
var combo_window: float = 0.40         # 连击窗口：一段结束后多久内再按可续段
var lunge_time: float = 0.15           # 冲刺取消为攻击时的前冲保留时间

# ================= 蓄力攻击配置 (v1.1 保留) =================
const CHARGE_THRESHOLD := 0.45      # 长按超过该秒数视为蓄力
const CHARGE_MULTIPLIER := 2.2      # 蓄力斩倍率
const CHARGE_CD := 0.90             # 蓄力斩独立冷却
const CHARGE_HITBOX_SCALE := Vector2(1.6, 1.3)

# 三段连击倍率（第三段略高，奖励打满）
const COMBO_MULT := [1.0, 1.05, 1.25]

var is_attacking = false
var attack_cooldown_timer = 0.0
var current_attack_multiplier: float = 1.0
var has_hit_something: bool = false

# 连击状态
var combo_index: int = 0
var combo_timer: float = 0.0
var buffered_attack: bool = false   # 攻击中按下的缓存输入（下一段立即接上）

# 冲刺取消前冲（攻击连贯性）
var lunge_timer: float = 0.0

var is_charging = false
var charge_time: float = 0.0
var charge_tween: Tween
var _charge_base_scale := Vector2.ONE

func _physics_process(delta: float) -> void:
	if attack_cooldown_timer > 0: attack_cooldown_timer -= delta
	if lunge_timer > 0: lunge_timer -= delta
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_index = 0   # 连击窗口过期，回到第一段
	# 连击缓存：CD 就绪且当前无动作时立即接上下一段（真正不断连）
	if buffered_attack and not is_attacking and not is_charging and attack_cooldown_timer <= 0.0:
		buffered_attack = false
		_perform_attack(COMBO_MULT[combo_index], false, false)
	if is_charging:
		charge_time += delta
		# 蓄力满时的视觉提示（ modulate 达到峰值后轻微脉动 ）
		if charge_time >= CHARGE_THRESHOLD and player.anim.scale.x < _charge_base_scale.x * 1.10:
			if charge_tween and charge_tween.is_valid(): charge_tween.kill()
			charge_tween = create_tween().set_loops()
			charge_tween.tween_property(player.anim, "scale", _charge_base_scale * 1.10, 0.18)
			charge_tween.tween_property(player.anim, "scale", _charge_base_scale * 1.06, 0.18)

# ================= 入口：按下开始蓄力，松开结算 =================
func start_charge() -> void:
	if player.movement.is_diving or is_charging:
		return
	if is_attacking or attack_cooldown_timer > 0:
		# 攻击中/段间冷却中按下 → 缓存下一段轻击（连击不断连）
		buffered_attack = true
		return
	is_charging = true
	charge_time = 0.0
	_charge_base_scale = player.anim.scale
	if charge_tween and charge_tween.is_valid(): charge_tween.kill()
	player.anim.modulate = Color(1.15, 1.1, 0.95)
	charge_tween = create_tween()
	charge_tween.tween_property(player.anim, "modulate", Color(1.5, 1.35, 1.0), 0.45)
	charge_tween.parallel().tween_property(player.anim, "scale", _charge_base_scale * 1.06, 0.45)

func release_charge() -> void:
	if not is_charging: return
	is_charging = false
	var charged := charge_time >= CHARGE_THRESHOLD
	var held := charge_time
	charge_time = 0.0
	_reset_charge_visual()
	if attack_cooldown_timer > 0: return
	if charged:
		if OS.is_debug_build(): print("⚡ [玩家] 蓄力斩！(按住 %.2fs)" % held)
		_perform_attack(CHARGE_MULTIPLIER, true, true)
	else:
		_perform_attack(COMBO_MULT[combo_index], false, false)

func cancel_charge() -> void:
	if not is_charging: return
	is_charging = false
	charge_time = 0.0
	_reset_charge_visual()

func _reset_charge_visual() -> void:
	if charge_tween and charge_tween.is_valid(): charge_tween.kill()
	charge_tween = create_tween()
	charge_tween.tween_property(player.anim, "modulate", Color(1, 1, 1), 0.12)
	charge_tween.parallel().tween_property(player.anim, "scale", _charge_base_scale, 0.12)

# ================= 兼容旧入口：直接普通攻击（连击下一段） =================
func perform_attack() -> void:
	var is_heavy = player.movement.is_dashing or (Time.get_ticks_msec() / 1000.0 - player.movement.last_dash_end_time <= heavy_attack_window)
	if is_heavy:
		_perform_attack(heavy_attack_multiplier, false, false)
	else:
		_perform_attack(COMBO_MULT[combo_index], false, false)

func _perform_attack(mult: float, is_charged: bool, reset_combo: bool) -> void:
	is_attacking = true
	has_hit_something = false
	current_attack_multiplier = mult
	buffered_attack = false
	# 冷却：蓄力斩独立长 CD；连击段间固定短 CD
	if is_charged:
		attack_cooldown_timer = CHARGE_CD
	else:
		attack_cooldown_timer = attack_cd
	player.attack_hitbox.monitoring = true

	# 冲刺中攻击 → 取消冲刺并保留前冲（v1.12 连贯性）
	if player.movement.is_dashing:
		player.movement.cancel_dash_for_attack()
		lunge_timer = lunge_time
	elif player.movement.dash_slide_timer > 0.0:
		lunge_timer = lunge_time * 0.6   # 滑行中攻击：保留少量前冲

	# 【修改】挥剑音效路径加上 free_ 前缀
	_play_sfx("res://assets/audio/sfx/sfx_free_sword_swing.wav")

	if is_charged:
		player.attack_hitbox.scale = CHARGE_HITBOX_SCALE

	await get_tree().create_timer(attack_duration).timeout

	player.attack_hitbox.monitoring = false
	if is_charged:
		player.attack_hitbox.scale = Vector2.ONE
	is_attacking = false

	# 连击推进：轻击续段；蓄力/重击重置
	if not is_charged:
		if reset_combo:
			combo_index = 0
		else:
			combo_index = (combo_index + 1) % COMBO_MULT.size()
		combo_timer = combo_window
	else:
		combo_index = 0
		combo_timer = 0.0

	if not has_hit_something:
		attack_cooldown_timer += miss_penalty

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if not is_attacking: return
	if body.has_method("take_damage"):
		has_hit_something = true
		var final_damage = GameState.calculate_damage(current_attack_multiplier)
		body.take_damage(final_damage, player.global_position)
		player.attack_hitbox.set_deferred("monitoring", false)

func _play_sfx(path: String) -> void:
	if ResourceLoader.exists(path):
		var sfx = AudioStreamPlayer.new()
		sfx.stream = load(path)
		sfx.bus = "SFX"   # v1.9 音频总线
		player.add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)
