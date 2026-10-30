extends CharacterBody2D
class_name EntityBase

@export var data: EntityData

const COMBAT_ENTER_RANGE: float = 500.0
const COMBAT_EXIT_RANGE: float = 600.0
const HEALTH_BAR_OFFSET_Y: float = -10.0

const GRAVITY = 980.0
const FRICTION = 1500.0
const KNOCKBACK_FORCE = 1500.0
const MIN_KNOCKBACK = 150.0
const MAX_KNOCKBACK = 800.0
const MAX_FALL_SPEED = 1200.0

var current_hp: int
var eff_max_hp: int   ## v1.11 周目缩放后的实际上限（初回= data.max_hp）
var is_dead: bool = false
var hurt_timer: float = 0.0
var damage_tween: Tween
var bar_tween: Tween

var _warned_hurtbox_group := false
var _probe_timer: float = 0.0       # v1.12：前方地面检测节流
var _no_ground_ahead: bool = false  # v1.12：前方无地（停步防坠落）

@onready var anim = $AnimatedSprite2D
@onready var contact_hitbox = $ContactHitbox
var health_bar: HealthBar
var player: Node2D
var is_in_combat: bool = false

func _ready() -> void:
	if data == null:
		push_error("⚠️ [系统] 致命错误: 实体没有配置 EntityData 数据!")
		return
	current_hp = data.max_hp
	# v1.11 周目轮回：按周目缩放敌人生命（初回不变）
	eff_max_hp = ReincarnationData.scale_enemy_hp(data.max_hp, GameState.reincarnation_count)
	current_hp = eff_max_hp
	add_to_group("enemies")   # v1.3：供 StageGoal 统计存活敌人（通关门判定）

	anim.play("idle")

	if contact_hitbox:
		contact_hitbox.area_entered.connect(_on_contact_hitbox_area_entered)

	health_bar = HealthBar.new()
	# 【修改】怪物血条统一使用 10 号字和 heart 图标
	health_bar.setup(false, Color(0.88, 0.28, 0.22), true, false, "heart", 10, 10.0)
	health_bar.z_index = 10
	add_child(health_bar)

	var multiplier = 1.0
	if eff_max_hp > 100:
		multiplier = log(float(eff_max_hp) / 100.0) / log(2.0) + 1.0
	
	health_bar.custom_minimum_size = Vector2(60 * multiplier, 12 * (1.0 + (multiplier - 1.0) * 0.2))
	
	health_bar.visible = false
	health_bar.modulate.a = 0.0

	anim.frame_changed.connect(_update_health_bar_position)
	anim.animation_changed.connect(_update_health_bar_position)

	_update_health_bar_position()
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if data == null: return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	if is_on_floor():
		if velocity.y > 0: velocity.y = 0
	else:
		velocity.y += GRAVITY * delta
		velocity.y = min(velocity.y, MAX_FALL_SPEED)

	velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
	if hurt_timer > 0: hurt_timer -= delta

	if player and is_instance_valid(player) and not is_dead:
		var dist = global_position.distance_to(player.global_position)
		if dist < COMBAT_ENTER_RANGE and not is_in_combat:
			is_in_combat = true
			GameState.add_combat_entity()
			_fade_bar(true)
		elif dist > COMBAT_EXIT_RANGE and is_in_combat:
			is_in_combat = false
			GameState.remove_combat_entity()
			_fade_bar(false)

	if is_in_combat and health_bar and not health_bar.visible:
		var dm = DialogueManager.instance()
		if not dm._is_playing and not dm._is_waiting_choice:
			_fade_bar(true)

	update_ai(delta)
	move_and_slide()

func force_refresh_combat_state() -> void:
	if is_dead: return
	player = get_tree().get_first_node_in_group("player")
	if not player: return
	
	var dist = global_position.distance_to(player.global_position)
	if dist < COMBAT_ENTER_RANGE:
		if not is_in_combat:
			is_in_combat = true
			GameState.add_combat_entity()
		if bar_tween and bar_tween.is_valid(): bar_tween.kill()
		health_bar.visible = true
		health_bar.modulate.a = 1.0
	else:
		if is_in_combat:
			is_in_combat = false
			GameState.remove_combat_entity()
		if bar_tween and bar_tween.is_valid(): bar_tween.kill()
		health_bar.visible = false
		health_bar.modulate.a = 0.0

func _fade_bar(is_show: bool) -> void:
	if not health_bar: return
	if bar_tween and bar_tween.is_valid(): bar_tween.kill()
	
	health_bar.visible = true 
	bar_tween = create_tween()
	bar_tween.tween_property(health_bar, "modulate:a", 1.0 if is_show else 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	if not is_show:
		bar_tween.tween_callback(func(): health_bar.visible = false)

# ================= 默认敌人 AI（v1.12 修复：基础怪站桩问题） =================
# 未覆写 update_ai 的敌人（史莱姆/苔骨等基础怪）默认追击玩家；
# 特殊行为敌人（EnemyBehaviors 子类）已覆写本函数，不受影响。
const DEFAULT_AGGRO_RANGE: float = 420.0   # 索敌距离
const DEFAULT_STOP_RANGE: float = 46.0     # 接触伤害生效距离，进入后停止
const DEFAULT_CHASE_SPEED: float = 95.0    # 基础追击速度（史莱姆慢速）
const BOSS_CHASE_SPEED: float = 62.0       # 大体型敌人减速

func update_ai(delta: float) -> void:
	if is_dead or player == null or not is_instance_valid(player): return
	var dist = global_position.distance_to(player.global_position)
	if dist > DEFAULT_AGGRO_RANGE:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		return
	if dist <= DEFAULT_STOP_RANGE:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		return
	var dir := signf(player.global_position.x - global_position.x)
	var chase_speed := BOSS_CHASE_SPEED if eff_max_hp > 100 else DEFAULT_CHASE_SPEED
	# 前方地面检测（0.12s 节流）：防止追出平台边缘坠落，同时控制射线开销
	_probe_timer -= delta
	if is_on_floor() and _probe_timer <= 0.0:
		_probe_timer = 0.12
		var space := get_world_2d().direct_space_state
		var probe := global_position + Vector2(dir * 26.0, 4.0)
		var q := PhysicsRayQueryParameters2D.create(probe, probe + Vector2(0, 40))
		q.exclude = [self]
		if not space.intersect_ray(q).has("position"):
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
			_no_ground_ahead = true
			return
		_no_ground_ahead = false
	if _no_ground_ahead:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		return
	velocity.x = dir * chase_speed
	if anim:
		anim.flip_h = dir < 0

func _update_health_bar_position() -> void:
	if not health_bar or not anim or not anim.sprite_frames: return
	if anim.sprite_frames.get_frame_count(anim.animation) == 0: return

	var texture = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	if not texture: return

	var texture_size = texture.get_size() * anim.scale
	var top_y = anim.offset.y
	if anim.centered: top_y -= texture_size.y / 2.0

	var bar_height = health_bar.get_bar_visual_height()
	health_bar.position = Vector2(-health_bar.custom_minimum_size.x / 2.0, top_y - (bar_height / 2.0) + HEALTH_BAR_OFFSET_Y)

func take_damage(damage: int, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	if is_dead or data == null: return

	var actual_damage = max(1, damage - data.defense)
	current_hp -= actual_damage
	current_hp = max(0, current_hp)

	_update_health_bar()

	if not is_in_combat:
		is_in_combat = true
		GameState.add_combat_entity()

	if bar_tween and bar_tween.is_valid(): bar_tween.kill()
	health_bar.visible = true
	health_bar.modulate.a = 1.0

	if OS.is_debug_build(): print("⚔️ [", data.entity_name, "] 受到伤害: ", actual_damage, " (剩余血量: ", current_hp, "/", eff_max_hp, ")")
	_play_sfx("res://assets/audio/sfx/sfx_free_hit_impact.wav")

	# 【v1.1】战斗反馈：世界空间弹出伤害数字；玩家攻击计入连击
	var scene := get_tree().current_scene
	if scene:
		var big: bool = actual_damage >= int(float(eff_max_hp) * 0.25)
		DamageNumber.spawn(scene, global_position, actual_damage, "crit" if big else "enemy")
	if attacker_pos != Vector2.ZERO:
		GameState.register_hit()

	if current_hp <= 0:
		die()
		return

	if damage_tween and damage_tween.is_valid(): damage_tween.kill()
	damage_tween = create_tween()
	damage_tween.tween_property(anim, "modulate", Color(1, 0.3, 0.3), 0.1)
	damage_tween.tween_property(anim, "modulate", Color(1, 1, 1), 0.15)

	if attacker_pos != Vector2.ZERO:
		var knockback_dir = sign(global_position.x - attacker_pos.x)
		if knockback_dir == 0: knockback_dir = 1
		var force_ratio = float(actual_damage) / float(eff_max_hp)
		var final_force = KNOCKBACK_FORCE * data.knockback_multiplier
		var final_max = MAX_KNOCKBACK * data.knockback_multiplier
		var knockback_vel = clamp(final_force * force_ratio, MIN_KNOCKBACK, final_max)

		velocity.x = knockback_dir * knockback_vel
		velocity.y = -350.0 * data.knockback_multiplier
		hurt_timer = 0.4

func die() -> void:
	if is_dead or data == null: return
	is_dead = true
	if OS.is_debug_build(): print("💀 [", data.entity_name, "] 被打碎了!")
	_play_sfx("res://assets/audio/sfx/sfx_free_enemy_die.wav")
	
	if contact_hitbox: contact_hitbox.set_deferred("monitoring", false)

	if is_in_combat:
		is_in_combat = false
		GameState.remove_combat_entity()

	if damage_tween and damage_tween.is_valid(): damage_tween.kill()
	if bar_tween and bar_tween.is_valid(): bar_tween.kill()

	anim.modulate = Color(0.5, 0.5, 0.5)
	if health_bar: health_bar.visible = false

	# 【v1.1】掉落：金币（世界拾取物）/ 材料（保底伪随机）/ 经验 / 刷新菜地生长
	_drop_loot()
	GameState.add_exp(data.exp_reward)
	GameState.refresh_farm_growth(4.0)
	GameState.unlock_codex(data.entity_name)   # v1.9 图鉴：击败即解锁
	GameState.register_kill(data.entity_name)  # v1.10 成就：击杀计数 + Boss 击杀

	await get_tree().create_timer(0.1).timeout
	queue_free()

func _drop_loot() -> void:
	if data == null: return
	var scene := get_tree().current_scene
	if scene == null: return

	# 金币（夜晚 +50%）
	var gold_count: int = data.drop_gold_min
	if data.drop_gold_max > data.drop_gold_min:
		gold_count = data.drop_gold_min + randi() % (data.drop_gold_max - data.drop_gold_min + 1)
	if GameState.is_night():
		gold_count = int(ceil(float(gold_count) * 1.5))
	if gold_count > 0:
		var coin_scene: PackedScene = load("res://fx/gold_coin.tscn")
		if coin_scene:
			var coin = coin_scene.instantiate()
			coin.amount = gold_count
			coin.global_position = global_position + Vector2(0, -12)
			# 死亡由物理回调触发，冲刷期不能直接挂 Area2D，延迟到帧末
			scene.add_child.call_deferred(coin)

	# 材料（伪随机 + 保底，稀有材料权重低但 12 次保底）
	if data.drop_materials.size() > 0:
		var table: Array = []
		for m in data.drop_materials:
			var is_rare: bool = m in ["苔核", "晶髓"]
			table.append({"id": m, "weight": 3.0 if is_rare else 10.0, "rare": is_rare})
		var picked: Dictionary = GameState.roll_drop(data.entity_name, table, 12)
		GameState.add_material(String(picked["id"]), 1)
		if OS.is_debug_build(): print("📦 [掉落] %s → 材料「%s」" % [data.entity_name, String(picked["id"])])

func _is_player_hurtbox(area: Area2D) -> bool:
	if area.is_in_group("player_hurtbox"):
		return true
	if area.name == "Hurtbox":
		if not _warned_hurtbox_group:
			_warned_hurtbox_group = true
			push_warning("⚠️ [实体] 玩家 Hurtbox 未加入 player_hurtbox 组，暂用节点名兜底；请在 player.tscn 的 Hurtbox 节点添加该组。")
		return true
	return false

func _on_contact_hitbox_area_entered(area: Area2D) -> void:
	if is_dead or data == null: return
	if not _is_player_hurtbox(area):
		return

	var player_node = area.get_parent()
	# v1.11 周目轮回：按周目缩放敌人接触伤害（初回不变）
	var contact_dmg: int = ReincarnationData.scale_enemy_dmg(data.contact_damage, GameState.reincarnation_count)
	if player_node.movement and player_node.movement.is_dashing:
		var player_attack = GameState.get_total_attack()
		var crash_damage = max(1, int(player_attack * 1.5) - data.defense)
		take_damage(crash_damage, player_node.global_position)

		if player_node.has_method("take_damage"):
			player_node.take_damage(contact_dmg, global_position)
	else:
		if player_node.has_method("take_damage"):
			player_node.take_damage(contact_dmg, global_position)

func apply_burn(duration_ticks: int = 3, damage_per_tick: int = 2) -> void:
	if is_dead or data == null: return
	for i in range(duration_ticks):
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(self) or is_dead: return
		take_damage(damage_per_tick)

func _update_health_bar() -> void:
	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(current_hp, eff_max_hp)

func _play_sfx(path: String) -> void:
	if ResourceLoader.exists(path):
		var sfx = AudioStreamPlayer.new()
		sfx.stream = load(path)
		sfx.bus = "SFX"   # v1.9 音频总线
		sfx.play()
		sfx.finished.connect(sfx.queue_free)
		add_child(sfx)
