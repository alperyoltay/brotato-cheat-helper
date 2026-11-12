extends "res://main.gd"

# When materials dropped by enemies are picked up, multiplies the amount gained
# AFTER the game's normal calculation (Metal Detector, material value bonuses, etc.).
# Only materials are multiplied; XP stays the same.

const META_KEY := "cheat_helper_gold_mult"


func on_gold_picked_up(gold: Node, player_index: int) -> void:
	var count: int = RunData.get_player_count()
	var before := []
	for i in count:
		before.append(RunData.get_player_gold(i))

	.on_gold_picked_up(gold, player_index)

	var mult: float = Engine.get_meta(META_KEY) if Engine.has_meta(META_KEY) else 1.0
	if mult <= 1.0:
		return

	for i in count:
		var gained: int = RunData.get_player_gold(i) - before[i]
		if gained > 0:
			RunData.add_gold(int(round(gained * (mult - 1.0))), i)
