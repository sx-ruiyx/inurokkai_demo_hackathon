extends RefCounted
class_name ScreenShake

## 全局震屏工具：ScreenShake.shake(强度, 时长)
## 自动寻找当前场景中启用的 Camera2D，做衰减随机抖动；无相机时静默跳过。

static func shake(intensity: float = 6.0, duration: float = 0.25) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	if tree == null or tree.current_scene == null: return
	var cam := _find_camera(tree.current_scene)
	if cam == null: return
	if cam.has_meta("shaking"): return
	cam.set_meta("shaking", true)

	var base_offset: Vector2 = cam.offset
	var steps := maxi(2, int(duration / 0.045))
	var t := cam.create_tween()
	for i in steps:
		var fade := 1.0 - float(i) / float(steps)
		var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * intensity * fade
		t.tween_property(cam, "offset", base_offset + jitter, 0.045)
	t.tween_property(cam, "offset", base_offset, 0.05)
	t.tween_callback(func():
		if is_instance_valid(cam):
			cam.offset = base_offset
			cam.remove_meta("shaking")
	)

static func _find_camera(node: Node) -> Camera2D:
	if node is Camera2D:
		var cam := node as Camera2D
		if cam.enabled: return cam
	for c in node.get_children():
		var r := _find_camera(c)
		if r != null: return r
	return null
