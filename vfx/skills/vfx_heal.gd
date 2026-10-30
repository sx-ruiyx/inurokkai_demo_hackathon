extends Node2D

func _ready() -> void:
	# 等待 1 秒钟（比粒子的生命周期稍长一点），确保所有加号都飘完了
	await get_tree().create_timer(1.0).timeout
	# 销毁自己
	queue_free()
