extends Area2D
class_name SlimeBall

## 吞碑者投掷的史莱姆弹：抛物线弹道，命中玩家造成伤害。

var damage: int = 3
var _vel := Vector2.ZERO
var _life: float = 0.0
var straight: bool = false   # v1.9：直线弹（远程直射型敌人用），不受重力

const GRAVITY := 520.0
const SPEED := 340.0
const LIFT := -150.0
const MAX_LIFE := 6.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_frames()

func _build_frames() -> void:
	var sf: SpriteFrames = SpriteFrames.new()
	sf.add_animation("bounce")
	sf.set_animation_speed("bounce", 12.0)
	sf.set_animation_loop("bounce", true)
	for i in range(1, 8):
		var path := "res://assets/textures/vfx/bullets/slime_ball/bounce_%03d.png" % i
		if ResourceLoader.exists(path):
			sf.add_frame("bounce", load(path))
	anim.sprite_frames = sf
	anim.play("bounce")

func launch(from: Vector2, dir: float, lift: float = LIFT, straight_mode: bool = false) -> void:
	global_position = from
	_vel = Vector2(dir * SPEED, lift)
	straight = straight_mode
	anim.flip_h = dir < 0.0

func _physics_process(delta: float) -> void:
	_life += delta
	if _life > MAX_LIFE:
		queue_free()
		return
	if not straight:
		_vel.y += GRAVITY * delta
	global_position += _vel * delta
	# 简易落地检测：只打世界静态体（层 1），避免误伤发射者自身/邻近敌人/触发器
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 16))
	q.exclude = [self]
	q.collision_mask = 1
	if space.intersect_ray(q).has("position"):
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"): return
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	queue_free()
