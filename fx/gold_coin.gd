extends Area2D
class_name GoldCoin

## 敌人死亡掉落的金币拾取物（token 旋转动画）
## 由 EntityBase.die() 生成；玩家碰到自动入账。

var amount: int = 1
var life: float = 0.0
var _vel: Vector2 = Vector2.ZERO
var _grounded: bool = false
var _blinking: bool = false

const GRAVITY := 900.0
const BOUNCE := 0.35
const PICKUP_DELAY := 0.35
const BLINK_AT := 7.0
const EXPIRE_AT := 10.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_frames()
	# 轻微随机上抛，落地弹一次后静止
	_vel = Vector2(randf_range(-90.0, 90.0), randf_range(-320.0, -220.0))
	anim.play("spin")

func _build_frames() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("spin")
	frames.set_animation_speed("spin", 14.0)
	frames.set_animation_loop("spin", true)
	for i in range(1, 21):
		var path := "res://assets/textures/objects/token/spin_%03d.png" % i
		if ResourceLoader.exists(path):
			frames.add_frame("spin", load(path))
	anim.sprite_frames = frames

func _physics_process(delta: float) -> void:
	life += delta
	if life >= EXPIRE_AT:
		queue_free()
		return
	if life >= BLINK_AT and not _blinking:
		_blinking = true
		var t := create_tween().set_loops()
		t.tween_property(anim, "modulate:a", 0.25, 0.18)
		t.tween_property(anim, "modulate:a", 1.0, 0.18)

	if not _grounded:
		_vel.y += GRAVITY * delta
		position += _vel * delta
		# 简易落地判定：用自身相对场景的 y 与生成点比较不可靠，
		# 这里用射线检测下方地面
		var space := get_world_2d().direct_space_state
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 14))
		q.exclude = [self]
		var hit := space.intersect_ray(q)
		if hit.has("position"):
			position.y = hit["position"].y - 10.0
			_vel.y = -_vel.y * BOUNCE
			if abs(_vel.y) < 60.0:
				_vel = Vector2.ZERO
				_grounded = true

func _on_body_entered(body: Node2D) -> void:
	if life < PICKUP_DELAY: return
	if not body.is_in_group("player"): return
	if GameState.has_method("add_gold"):
		GameState.add_gold(amount)
	_play_pickup_fx()
	queue_free()

func _play_pickup_fx() -> void:
	DamageNumber.spawn(get_parent(), global_position, amount, "gold")
	if ResourceLoader.exists("res://assets/audio/sfx/sfx_free_coin_touch.wav"):
		var sfx := AudioStreamPlayer.new()
		sfx.stream = load("res://assets/audio/sfx/sfx_free_coin_touch.wav")
		sfx.bus = "SFX"   # v1.9 音频总线
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)
