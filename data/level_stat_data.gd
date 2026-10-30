extends Resource
class_name LevelStatData

# 用一个大数组把所有种族、所有等级的数据全装进去
# 在检查器里直接点“新建字典”填数据就行，非常直观
@export var all_stats: Array[Dictionary] = [
	{"race": "兽人", "level": 1, "hp": 20, "atk": 2, "shield": 4, "bp": 3},
	{"race": "兽人", "level": 2, "hp": 30, "atk": 3, "shield": 5, "bp": 3},
	{"race": "兽人", "level": 3, "hp": 42, "atk": 4, "shield": 7, "bp": 4},
	{"race": "兽人", "level": 4, "hp": 56, "atk": 5, "shield": 9, "bp": 4},
	{"race": "兽人", "level": 5, "hp": 72, "atk": 7, "shield": 11, "bp": 5},
	{"race": "精灵", "level": 1, "hp": 15, "atk": 4, "shield": 2, "bp": 4}
]
