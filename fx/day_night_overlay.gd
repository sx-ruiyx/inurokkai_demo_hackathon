class_name DayNightOverlay
extends CanvasLayer

## 昼夜视觉遮罩：跟随 GameState.day_time 在全屏叠加一层色调
## 白天=无色，黄昏=暖橙，夜晚=深蓝（低透明度，不影响可玩性）
## 挂法：任意场景加 CanvasLayer 节点 + 本脚本即可（鼠标穿透）

const PHASE_COLORS := {
	"day": Color(1, 1, 1, 0.0),
	"dusk": Color(1.0, 0.55, 0.25, 0.18),
	"night": Color(0.12, 0.16, 0.38, 0.42),
}

@onready var _rect: ColorRect = $ColorRect

func _ready() -> void:
	layer = 90  # 低于 HUD(100)，高于世界
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	var phase := GameState.get_day_phase()
	var target: Color = PHASE_COLORS.get(phase, PHASE_COLORS["day"])
	# 平滑过渡（帧率无关的简易插值）
	_rect.color = _rect.color.lerp(target, 0.02)
