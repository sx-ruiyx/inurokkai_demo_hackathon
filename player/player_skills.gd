extends Node
class_name PlayerSkillComponent

@onready var player = get_parent()

# 【修复】严格对齐 vfx/skills/ 目录下的 vfx_ 前缀文件
const FIREBALL_SCENE = preload("res://vfx/skills/vfx_fireball.tscn")
const FIREBALL_CARD = preload("res://data/skills/fireball.tres")
const HEAL_CARD = preload("res://data/skills/heal.tres") 

var fireball_cd_timer: float = 0.0
var heal_cd_timer: float = 0.0

# v1.14 两段式火球：第一段悬浮在玩家身前，第二段朝鼠标发射
var held_fireball: Node2D = null

func is_holding_fireball() -> bool:
	return is_instance_valid(held_fireball)

func _process(delta: float) -> void:
	if fireball_cd_timer > 0: fireball_cd_timer -= delta
	if heal_cd_timer > 0: heal_cd_timer -= delta

func cast_skill(skill_id: String) -> bool:
	match skill_id:
		"fireball": return try_cast_fireball()
		"heal":     return try_cast_heal()
	push_warning("⚠️ [技能] 未知 skill_id: %s（请检查 SkillData.skill_id 或 cast_skill 分支）" % skill_id)
	return false

func try_cast_fireball() -> bool:
	# 第二段：已有悬浮火球 → 朝鼠标发射（不查 CD、不耗 BP）
	if is_instance_valid(held_fireball):
		_launch_held_fireball()
		return true
	# 第一段：生成悬浮火球
	if fireball_cd_timer > 0: return false
	var mods: Dictionary = GameState.get_branch_mods("fireball")
	var cd_mult := float(mods.get("cooldown_mult", 1.0))
	var dmg_mult := float(mods.get("damage_mult", 1.0))
	var fb_scale := float(mods.get("fireball_scale", 1.0))
	if not GameState.spend_bp(FIREBALL_CARD.cost_bp): return false

	var fireball = FIREBALL_SCENE.instantiate()
	fireball.held = true
	# 挂在玩家身上、身前 80px、手部高度 -20，随玩家移动
	var face: float = -1.0 if player.anim.flip_h else 1.0
	fireball.position = Vector2(80.0 * face, -20.0)
	fireball.damage_multiplier = FIREBALL_CARD.damage_multiplier * dmg_mult \
		* GameState.get_card_level_multiplier("fireball")   # v1.15 卡牌等级倍率（Lv1 ×1.0，每级 +0.2）
	fireball.visual_scale = fb_scale
	held_fireball = fireball
	player.add_child.call_deferred(fireball)
	return true

func _launch_held_fireball() -> void:
	var fb = held_fireball
	held_fireball = null
	if not is_instance_valid(fb): return
	_play_sfx("res://assets/audio/sfx/sfx_free_fireball_throw.wav")
	var target: Vector2 = player.get_global_mouse_position()
	var mods: Dictionary = GameState.get_branch_mods("fireball")
	var shots := int(mods.get("shots", 1))
	var launch_pos: Vector2 = fb.global_position   # 发射点 = 火球生成点（悬浮位置）
	fb.launch_towards(target)
	# v1.16 连珠火弹：两发大小与基础火球相同、重叠在同一发射点；
	# 第一发瞬间发射，第二发延迟 0.2s 按第一发的方向射出（不散射、不偏移）
	if shots > 1:
		var dir: Vector2 = fb.aim_vector   # 第一发方向判定与基础火球相同，第二发以其为准
		var delay: float = float(mods.get("shot_delay", 0.2))
		for i in shots - 1:
			var extra = FIREBALL_SCENE.instantiate()
			extra.held = true   # 悬浮定住不动、碰撞关闭，等延迟到点再发射
			extra.damage_multiplier = fb.damage_multiplier
			extra.visual_scale = fb.visual_scale
			extra.global_position = launch_pos
			player.get_parent().add_child.call_deferred(extra)
			var tree := player.get_tree()
			tree.create_timer(delay * float(i + 1)).timeout.connect(func():
				if is_instance_valid(extra):
					extra.launch_in_direction(dir)
			)
	fireball_cd_timer = FIREBALL_CARD.cooldown * float(mods.get("cooldown_mult", 1.0))

func try_cast_heal() -> bool:
	if heal_cd_timer > 0: return false
	var mods: Dictionary = GameState.get_branch_mods("heal")
	var cd_mult := float(mods.get("cooldown_mult", 1.0))
	var heal_mult := float(mods.get("heal_mult", 1.0))
	var heal_add := int(mods.get("heal_flat_add", 0))
	if not GameState.spend_bp(HEAL_CARD.cost_bp): return false

	_play_sfx("res://assets/audio/sfx/sfx_heal.wav")

	var heal_amount = int((GameState.get_max_hp() * HEAL_CARD.heal_percent + HEAL_CARD.heal_flat) * heal_mult \
		* GameState.get_card_level_multiplier("heal")) + heal_add   # v1.15 卡牌等级倍率
	# v1.17 迅愈：heals=2 → 每次施放释放两次治疗（每次 60%，总计 120%）；基础治疗 heals=1
	# v1.18 两段治疗隔开：第 1 段瞬间生效，后续每段间隔 heal_delay 秒（迅愈 = 1 秒）
	var heals := int(mods.get("heals", 1))
	var heal_delay := float(mods.get("heal_delay", 0.0))
	GameState.heal(heal_amount)
	if heals > 1:
		var tree := player.get_tree()
		for i in heals - 1:
			var delay := heal_delay * float(i + 1)
			tree.create_timer(delay).timeout.connect(func():
				# 玩家可能在间隔内死亡/离场，失效则跳过该段治疗
				if is_instance_valid(player):
					GameState.heal(heal_amount)
					if player.health: player.health.play_heal_effect()
			)

	# 铁壁润泽：8 秒内护盾上限 +2（potence），立即获得 2 点护盾值（shield_gain）；
	# 到期时护盾值回吸 2 点（drain_on_expire，不足则归零不扣血，见 GameState._tick_buffs）
	if mods.has("shield_buff"):
		var sb: Dictionary = mods["shield_buff"]
		GameState.add_buff("shield", float(sb["duration"]), int(sb["potence"]),
			bool(sb.get("drain_on_expire", false)))
		if sb.has("shield_gain"):
			GameState.gain_shield(int(sb["shield_gain"]))

	if player.health: player.health.play_heal_effect()

	# 【修复】严格对齐 vfx/skills/ 目录下的 vfx_ 前缀文件
	var heal_fx = load("res://vfx/skills/vfx_heal.tscn").instantiate()
	heal_fx.global_position = player.global_position
	player.get_parent().add_child.call_deferred(heal_fx)
	heal_cd_timer = HEAL_CARD.cooldown * cd_mult
	return true

func _play_sfx(path: String) -> void:
	if ResourceLoader.exists(path):
		var sfx = AudioStreamPlayer.new()
		sfx.stream = load(path)
		sfx.bus = "SFX"   # v1.9 音频总线
		player.add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)
