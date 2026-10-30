extends Node2D
class_name DamageNumber

## 战斗伤害数字弹出（-N 粒子）
## 用法：DamageNumber.spawn(场景根节点, 世界坐标, 数值, 类型)
## 类型：enemy=敌人受伤(白) crit=暴击(金) player=玩家受伤(红) heal=治疗(绿) gold=金币(黄)

static func spawn(parent: Node, world_pos: Vector2, amount: int, kind: String = "enemy") -> void:
	if parent == null or amount <= 0:
		if kind == "heal" and parent != null:
			pass
		else:
			return
	if parent == null: return

	var label := Label.new()
	var size := 16
	var color := Color(1.0, 0.96, 0.88)
	match kind:
		"crit":
			size = 24
			color = Color(1.0, 0.78, 0.25)
			label.text = "%d!" % amount
		"player":
			size = 18
			color = Color(1.0, 0.28, 0.28)
			label.text = "-%d" % amount
		"heal":
			size = 18
			color = Color(0.45, 1.0, 0.55)
			label.text = "+%d" % amount
		"gold":
			size = 15
			color = Color(1.0, 0.88, 0.35)
			label.text = "+%d$" % amount
		_:
			label.text = "-%d" % amount

	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.position = world_pos + Vector2(randf_range(-16.0, 16.0), -24.0)
	label.z_index = 120
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)

	var t := label.create_tween()
	t.set_parallel(true)
	# 先弹大再稳定
	t.tween_property(label, "scale", Vector2(1.4, 1.4), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "position:y", label.position.y - 52.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, 0.75).set_delay(0.15)
	t.chain().tween_callback(label.queue_free)
