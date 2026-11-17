class_name TeamManager
extends Node
## Team rules only: HP, turn order, cooldowns, guard / taunt / rally.
## No sprites, no buttons, no animations. Other modules listen to its signals.

signal health_changed(index: int, hp: int, max_hp: int)
signal fusion_changed(index: int, charge: int, max_charge: int)

@export var fusions: Array[FusionData] = []
@export var members: Array[PartyMemberData] = []
@export var turn_order: Array[int] = [2, 0, 1]   # party indexes: 2 = Soup, 0 = Tomato, 1 = Steak

var hp: Array[int] = []
var max_hp: Array[int] = []
var damage: Array[int] = []
var guarding: Array[bool] = []
var cd_left: Array = []          # cd_left[member][move] = rounds remaining
var taunt_target := -1           # party index the enemy must hit (-1 = none)
var rally_bonus := 1.0           # damage multiplier from Rally, resets each round
var fusion_charge: Array[int] = []
var turn_spent: Array[bool] = []     # true if a fusion already used this member's turn
var rally_rounds := 0            # rounds left on the current damage buff

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
		fusion_charge.append(0)
		turn_spent.append(false)
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
		var m := turn_order[p]
		if hp[m] > 0 and not turn_spent[m]:
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

func set_rally(bonus: float, rounds: int = 1):
	rally_bonus = maxf(rally_bonus, bonus)       # the stronger buff wins
	rally_rounds = maxi(rally_rounds, rounds)

func damage_member(i: int, amount: int):
	_set_hp(i, maxi(0, hp[i] - amount))

func heal_target(healer: int) -> int:
	# The living member with the lowest HP ratio
	var target := healer
	for i in members.size():
		if hp[i] > 0 and float(hp[i]) / max_hp[i] < float(hp[target]) / max_hp[target]:
			target = i
	return target

func heal_lowest(healer: int, amount: int) -> Dictionary:
	var target := heal_target(healer)
	var before := hp[target]
	_set_hp(target, mini(max_hp[target], hp[target] + amount))
	return {"index": target, "healed": hp[target] - before}

func heal_party(amount: int) -> Array:
	var results := []
	for k in members.size():
		if hp[k] > 0:
			var before := hp[k]
			_set_hp(k, mini(max_hp[k], hp[k] + amount))
			results.append({"index": k, "healed": hp[k] - before})
	return results
	
func pick_enemy_target() -> int:
	if taunt_target != -1 and hp[taunt_target] > 0:
		return taunt_target
	var living := []
	for i in members.size():
		if hp[i] > 0:
			living.append(i)
	return living.pick_random()

# Up to `count` different living allies. A taunting ally is always picked first.
func pick_enemy_targets(count: int) -> Array[int]:
	var living: Array[int] = []
	for i in members.size():
		if hp[i] > 0:
			living.append(i)
	living.shuffle()

	var picked: Array[int] = []
	if taunt_target != -1 and hp[taunt_target] > 0:
		picked.append(taunt_target)
		living.erase(taunt_target)
	while picked.size() < count and not living.is_empty():
		picked.append(living.pop_back())
	return picked
	
func end_round():
	for i in members.size():
		guarding[i] = false
		turn_spent[i] = false
		for mi in cd_left[i].size():
			if cd_left[i][mi] > 0:
				cd_left[i][mi] -= 1
	taunt_target = -1
	rally_rounds -= 1
	if rally_rounds <= 0:
		rally_rounds = 0
		rally_bonus = 1.0


func _set_hp(i: int, value: int):
	hp[i] = value
	if members[i].use_global_state:
		State.current_health = value
	health_changed.emit(i, hp[i], max_hp[i])
	
	# --- Fusion --------------------------------------------------------------------
func add_fusion_charge(i: int, amount: int):
	if amount <= 0 or hp[i] <= 0:
		return
	_set_charge(i, mini(members[i].fusion_max, fusion_charge[i] + amount))

func fusion_full(i: int) -> bool:
	return fusion_charge[i] >= members[i].fusion_max

func _fusion_ready(i: int) -> bool:
	return hp[i] > 0 and fusion_full(i) and not turn_spent[i]

func _same_member(a: PartyMemberData, b: PartyMemberData) -> bool:
	return a == b or (a.resource_path != "" and a.resource_path == b.resource_path)

func _member_index(p: PartyMemberData) -> int:
	for j in members.size():
		if _same_member(members[j], p):
			return j
	return -1

func index_of(p: PartyMemberData) -> int:      # public version, used by the hover panel
	return _member_index(p)

# The biggest fusion that includes member `i` and whose partners are ALL ready. Null if none.
func find_fusion(i: int) -> FusionData:
	if not _fusion_ready(i):
		return null
	var best: FusionData = null
	for f in fusions:
		if f == null or f.partners.size() < 2:
			continue
		var ok := true
		var has_user := false
		for p in f.partners:
			var j := _member_index(p) if p else -1
			if j == -1 or not _fusion_ready(j):
				ok = false
				break
			if j == i:
				has_user = true
		if ok and has_user and (best == null or f.partners.size() > best.partners.size()):
			best = f
	return best

func fusion_users(fusion: FusionData) -> Array[int]:
	var users: Array[int] = []
	for p in fusion.partners:
		users.append(_member_index(p))
	return users

func fusion_damage(users: Array[int], fusion: FusionData) -> int:
	var total := 0
	for j in users:
		total += damage[j]
	return int(total * fusion.mult * rally_bonus)

# Empties every participant's bar; everyone except the one acting loses their turn this round.
func spend_fusion(users: Array[int], actor: int):
	for j in users:
		_set_charge(j, 0)
		if j != actor:
			turn_spent[j] = true

func _set_charge(i: int, value: int):
	fusion_charge[i] = value
	fusion_changed.emit(i, value, members[i].fusion_max)
