extends AnimatedSprite2D

## 停钟交互后切换到"已取走"动画。
## 由 01_wooden_house.tscn 中 ClockInteract 的 interacted 信号连接调用。
func _on_clock_interacted(_body: Node2D) -> void:
	play(&"taken")
