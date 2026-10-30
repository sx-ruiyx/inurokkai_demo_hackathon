extends Node

var _transition_layer: CanvasLayer
var _rect: ColorRect
var _is_transitioning: bool = false

func _ready() -> void:
	_transition_layer = CanvasLayer.new()
	_transition_layer.layer = 128 
	add_child(_transition_layer)
	
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_layer.add_child(_rect)

func goto_scene_direct(scene_path: String) -> void:
	DialogueManager.force_stop()
	get_tree().change_scene_to_file(scene_path)
	GameState.reset_combat_state()

func goto_scene(scene_path: String) -> void:
	if _is_transitioning: return
	_is_transitioning = true
	
	DialogueManager.force_stop()
	
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var t = create_tween()
	t.tween_property(_rect, "color:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	await t.finished
	
	print("🚪 [StageRouter] 正式切换场景至: ", scene_path)
	get_tree().change_scene_to_file(scene_path)
	GameState.reset_combat_state()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var t2 = create_tween()
	t2.tween_property(_rect, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	await t2.finished
	
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
