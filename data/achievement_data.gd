class_name AchievementData
extends RefCounted

## 成就数据（v1.10 P3）：全部由系统钩子自动解锁，无需手动领取。
## 字段：name 名称 / desc 描述 / cat 分类（战斗/探索/收集/成长）

const ENTRIES := {
	# ---- 战斗 ----
	"first_blood": {"name": "初战告捷", "desc": "击败第一只敌人。轮回的第一步，从一次挥击开始。", "cat": "战斗"},
	"kill_10": {"name": "见习猎手", "desc": "累计击败 10 只敌人。手里的武器开始变得趁手了。", "cat": "战斗"},
	"kill_50": {"name": "身经百战", "desc": "累计击败 50 只敌人。你的名字已让森林里的怪物闻风丧胆。", "cat": "战斗"},
	"boss_1": {"name": "碑林征服者", "desc": "击败吞碑者——以古老石碑为食的巨型史莱姆。", "cat": "战斗"},
	"boss_2": {"name": "荆棘克星", "desc": "击败荆棘之母——密林巢穴的统治者。", "cat": "战斗"},
	"boss_3": {"name": "沙海平定者", "desc": "击败沙暴之核——绿洲之主。", "cat": "战斗"},
	"boss_4": {"name": "轮回见证者", "desc": "击败回响之冠——承载犬六回全部记忆与悔恨的虚空王冠。", "cat": "战斗"},
	"phase2": {"name": "狂暴见证", "desc": "首次见证 Boss 半血狂暴。那是它们真正的样子。", "cat": "战斗"},
	# ---- 探索 ----
	"chapter1": {"name": "森林行者", "desc": "通关第一章全部 5 关。森林深处的低语已对你不再陌生。", "cat": "探索"},
	"chapter2": {"name": "沙海旅人", "desc": "通关第二章全部 5 关。烈日与流沙都没能留住你的脚步。", "cat": "探索"},
	"chapter3": {"name": "霜峰王者", "desc": "通关第三章全部 5 关。霜峰之巅，只余你与王冠的对峙。", "cat": "探索"},
	"all_clear": {"name": "轮回终结者", "desc": "三章 15 关全部通关。但轮回，真的结束了吗？", "cat": "探索"},
	"hidden": {"name": "秘境探索者", "desc": "首次进入隐藏关卡。只有被命运选中的人才能看见那些门。", "cat": "探索"},
	# ---- 收集 ----
	"codex_5": {"name": "见习学者", "desc": "图鉴解锁 5 条。观察，是变强的第一步。", "cat": "收集"},
	"codex_all": {"name": "万物志", "desc": "图鉴全部 12 条解锁。世间万象，尽在你手。", "cat": "收集"},
	# ---- 成长 ----
	"crafter": {"name": "能工巧匠", "desc": "首次打造装备。铁与火的艺术，从此为你所用。", "cat": "成长"},
	"companion": {"name": "盟约召唤师", "desc": "首次召唤福瑞勇者。生死之交，不必多言。", "cat": "成长"},
	"potion": {"name": "炼金术士", "desc": "首次酿造药水。草叶与露水，亦是回天妙药。", "cat": "成长"},
	"skill": {"name": "技能觉醒", "desc": "首次解锁技能分支。天赋的另一半，已然显现。", "cat": "成长"},
}

static func entry_for(id: String) -> Dictionary:
	return ENTRIES.get(id, {})

static func total() -> int:
	return ENTRIES.size()
