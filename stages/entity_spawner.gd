extends Node2D

@export_group("Config")
@export var entity_scene: PackedScene 
@export var spawn_count: int = 1     
@export var spawn_interval: float = 0.0 
@export var spawn_radius: float = 50.0  
@export var auto_spawn_on_ready: bool = false 

func _ready() -> void:
	if auto_spawn_on_ready:
		spawn_entities()

func spawn_entities(_trigger_body: Node2D = null) -> void:
	if entity_scene == null:
		push_error("⚠️ [系统] 刷怪失败: 没有指定实体场景 (entity_scene)!")
		return
		
	print("📦 [刷怪] 开始生成实体, 数量: ", spawn_count)
	
	for i in range(spawn_count):
		if spawn_interval > 0.0 and i > 0:
			await get_tree().create_timer(spawn_interval).timeout
			
		_spawn_single_entity()

func _spawn_single_entity() -> void:
	var entity = entity_scene.instantiate()
	var random_offset = Vector2(
		randf_range(-spawn_radius, spawn_radius),
		randf_range(-spawn_radius / 2, spawn_radius / 2)
	)
	
	entity.global_position = global_position + random_offset
	entity.z_index = 5 
	
	get_parent().add_child.call_deferred(entity)
	print("📦 [刷怪] 生成实体, 位置: ", entity.global_position)
