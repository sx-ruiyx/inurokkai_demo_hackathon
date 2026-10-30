extends CharacterBody2D

@onready var anim = $AnimatedSprite2D

# 提供给外部调用的方法，让任何控制器都能控制它的动画
func update_animation(is_moving: bool, is_dashing: bool = false):
	if not is_on_floor():
		anim.play("jump" if velocity.y < 0 else "fall")
	elif is_dashing:
		anim.play("dash")
	elif is_moving or abs(velocity.x) > 10.0:
		anim.play("walk")
	else:
		anim.play("idle")

# 翻转贴图
func flip_sprite(dir_x: float):
	if dir_x != 0:
		anim.flip_h = dir_x < 0
