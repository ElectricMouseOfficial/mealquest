class_name TeamManager
extends Node
## Team rules only: HP, turn order, cooldowns, guard / taunt / rally.
## No sprites, no buttons, no animations. Other modules listen to its signals.

signal health_changed(index: int, hp: int, max_hp: int)

@export var members: Array[PartyMemberData] = []
@export var turn_order: Array[int] = [2, 0, 1]   # party indexes: 2 = Soup, 0 = Tomato, 1 = Steak

var hp: Array[int] = []
var max_hp: Array[int] = []
var damage: Array[int] = []
var guarding: Array[bool] = []
var cd_left: Array = []          # cd_left[member][move] = rounds remaining
var taunt_target := -1           # party index the enemy must hit (-1 = none)
var rally_bonus := 1.0           # damage multiplier from Rally, resets each round


func setup():
	if members.is_empty():
		push_error("TeamManager: assign PartyMemberData resources to 'Members' in the Inspector.")
		return
	for m in members:
		if m.use_global_state:
			hp.append(State.current_health)
			max_hp.append(State.max_health)
			damage.append(State.damage)
		else:
			hp.append(m.max_hp)
			max_hp.append(m.max_hp)
			damage.append(m.damage)
		guarding.append(false)
		var cds := []
		for mv in m.moves:
			cds.append(0)
		cd_left.append(cds)


# --- Queries -----------------------------------------------------------------
func is_alive(i: int) -> bool:
	return hp[i] > 0

func is_guarding(i: int) -> bool:
	return guarding[i]

func attack_damage(i: int, move: MoveData) -> int:
	return int(damage[i] * move.mult * rally_bonus)

func cooldown_left(i: int, move_index: int) -> int:
	return cd_left[i][move_index]

func is_move_blocked(i: int, move_index: int) -> bool:
	if cd_left[i][move_index] <= 0:
		return false
	# Safety: if every move is cooling down, let the first one through
	var all_blocked := true
	for left in cd_left[i]:
		if left <= 0:
			all_blocked = false
	return not (all_blocked and move_index == 0)

func next_living_pos(from_pos: int) -> int:
	for p in range(from_pos, turn_order.size()):
		if hp[turn_order[p]] > 0:
			return p
	return -1


# --- Actions -----------------------------------------------------------------
func begin_move(i: int, move_index: int):
	var mv: MoveData = members[i].moves[move_index]
	if mv.cooldown > 0:
		cd_left[i][move_index] = mv.cooldown + 1   # +1 because it ticks down at the end of this same round

func set_guard(i: int):
	guarding[i] = true

func set_taunt(i: int):
	taunt_target = i

func set_rally(bonus: float):
	rally_bonus = bonus

func damage_member(i: int, amount: int):
	_set_hp(i, maxi(0, hp[i] - amount))

func heal_lowest(healer: int, amount: int) -> Dictionary:
	# Heals the living member with the lowest HP ratio
	var target := healer
	for i in members.size():
		if hp[i] > 0 and float(hp[i]) / max_hp[i] < float(hp[target]) / max_hp[target]:
			target = i
	var before := hp[target]
	_set_hp(target, mini(max_hp[target], hp[target] + amount))
	return {"index": target, "healed": hp[target] - before}

func pick_enemy_target() -> int:
	if taunt_target != -1 and hp[taunt_target] > 0:
		return taunt_target
	var living := []
	for i in members.size():
		if hp[i] > 0:
			living.append(i)
	return living.pick_random()

func end_round():
	for i in members.size():
		guarding[i] = false
		for mi in cd_left[i].size():
			if cd_left[i][mi] > 0:
				cd_left[i][mi] -= 1
	taunt_target = -1
	rally_bonus = 1.0


func _set_hp(i: int, value: int):
	hp[i] = value
	if members[i].use_global_state:
		State.current_health = value
	health_changed.emit(i, hp[i], max_hp[i])
