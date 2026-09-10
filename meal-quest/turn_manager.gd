extends Node
signal turn_started(unit: Unit)
signal turn_ended(unit: Unit)
signal round_started(round_number: int)
signal battle_ended(winning_team: String)
 
var turn_order: Array[Unit] = []
var current_index: int = -1
var round_number: int = 0
var current_unit: Unit = null
var battle_active: bool = false
 
 
func start_battle(units: Array[Unit]) -> void:
	turn_order = units.duplicate()
	round_number = 0
	current_index = -1
	battle_active = true
	_sort_by_speed()
	_next_round()
 
 
func _sort_by_speed() -> void:
	# Higher speed acts first. Change the comparator for a different rule.
	turn_order.sort_custom(func(a, b): return a.speed > b.speed)
 
 
func _next_round() -> void:
	round_number += 1
	current_index = -1
	emit_signal("round_started", round_number)
	advance_turn()
 
 
func advance_turn() -> void:
	if not battle_active:
		return
 
	if current_unit:
		emit_signal("turn_ended", current_unit)
 
	current_index += 1
 
	# End of round: start a new one.
	if current_index >= turn_order.size():
		_next_round()
		return
 
	current_unit = turn_order[current_index]
 
	# Skip dead/defeated units.
	if not is_instance_valid(current_unit) or current_unit.is_defeated():
		advance_turn()
		return
 
	emit_signal("turn_started", current_unit)
 
	if _check_battle_over():
		return
 
	# Let the unit act. AI units act immediately; player units should call
	# `advance_turn()` themselves once the player confirms an action.
	if current_unit.is_ai_controlled:
		current_unit.take_ai_turn(self)
 
 
## Call this once a unit's chosen action (attack, item, skip, etc.) is resolved.
func end_current_turn() -> void:
	advance_turn()
 
 
func remove_unit(unit: Unit) -> void:
	if unit in turn_order:
		turn_order.erase(unit)
	_check_battle_over()
 
 
func _check_battle_over() -> bool:
	var teams_alive := {}
	for unit in turn_order:
		if is_instance_valid(unit) and not unit.is_defeated():
			teams_alive[unit.team] = true
 
	if teams_alive.size() <= 1:
		battle_active = false
		var winner: String = teams_alive.keys()[0] if teams_alive.size() == 1 else "draw"
		emit_signal("battle_ended", winner)
		return true
	return false
