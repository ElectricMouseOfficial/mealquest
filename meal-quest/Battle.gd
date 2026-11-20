extends Control
## Turn flow only. This is the one script that knows about all the modules.
##   Team       (team_manager.gd)       rules + data
##   Animations (battle_animations.gd)  movement and effects
##   UI         (battle_ui.gd)          menus, bars, text

@export var enemy: Resource
@export_multiline var double_attack_text := "Out of desperation it attacks again!"   # shown before the second slash ({enemy} = the enemy's name)

@onready var team: TeamManager = $Team
@onready var anim: BattleAnimations = $Animations
@onready var ui: BattleUI = $UI
@onready var enemy_sprite: TextureRect = $Enemy
@onready var puns: SpectatorPuns = get_node_or_null("Puns") as SpectatorPuns   # optional

var party_nodes: Array[TextureRect] = []
var enemy_hp := 0
var active_index := 0     # party index of whoever is acting
var turn_pos := 0         # position within team.turn_order
var _ending := false      # true once a win or loss has started
var enemy_dot_damage := 0
var enemy_dot_turns := 0
var shield_fusion: FusionData = null   # set while a party shield is up this round
var enemy_dot_name := "burn"
var audio: BattleAudio   # found in _ready(), however the audio scene is named or nested
var enemy_attack_mult := 1.0       # Locular Lob lowers this; it resets after the enemy's next attack
var _shield_dot_done := false      # so a shield only applies its DOT once per enemy turn

# --- Dev shortcuts (work only when running from the editor / debug builds) ---------
@export var debug_shortcuts := true
@export var debug_win_key: Key = KEY_W     # instantly win the battle
@export var debug_lose_key: Key = KEY_L    # instantly lose the battle
@export_group("Enemy attacks")
@export_range(0.0, 1.0, 0.05) var double_attack_chance := 0.35      # chance the Knife swings at 2 allies
@export_range(0.1, 1.0, 0.05) var double_attack_damage_ratio := 0.5 # each target takes this share of the normal damage


func _ready():
	team.setup()
	for m in team.members:
		party_nodes.append(get_node(m.scene_node) as TextureRect)
		ui.status_register(get_node(m.scene_node) as TextureRect)
	enemy_hp = enemy.health

	anim.setup($AnimationPlayer, enemy_sprite, self)
	if puns == null:
		# No (working) Puns node in the scene: make one so the puns still work
		puns = SpectatorPuns.new()
		puns.name = "Puns"
		add_child(puns)
		push_warning("No Puns node with spectator_puns.gd found, created one with the default puns.")
	puns.setup(get_node_or_null("Background/Spectators"), self)
	audio = _find_audio(self)
	if audio == null:
		print("Battle is using audio node: ", audio.get_path())
		audio = BattleAudio.new()
		audio.name = "Audio"
		add_child(audio)
		push_warning("No BattleAudio node found, created a silent one.")
	audio.play_music()
	ui.setup(team, party_nodes, enemy_sprite, enemy, $Textbox, $ActionsPanel)
	ui.set_enemy_health(enemy_hp, enemy.health)

	team.health_changed.connect(ui.set_party_health)
	ui.move_chosen.connect(_on_move_chosen)
	team.fusion_changed.connect(ui.set_fusion_bar)
	ui.fusion_chosen.connect(_on_fusion_chosen)

	await ui.say("A determined %s appears!" % enemy.name.to_upper())
	start_player_turn()


# --- Dev shortcuts -----------------------------------------------------------
func _input(event):
	if not debug_shortcuts or not OS.is_debug_build() or _ending:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == debug_win_key:
			debug_win()
		elif event.keycode == debug_lose_key:
			debug_lose()

func debug_win():
	enemy_hp = 0
	ui.set_enemy_health(0, enemy.health)
	_win_battle()

func debug_lose():
	_party_wiped()


# --- Turn flow ---------------------------------------------------------------
func start_player_turn():
	if _ending:
		return
	turn_pos = team.next_living_pos(0)
	if turn_pos == -1:
		await _party_wiped()
		return
	active_index = team.turn_order[turn_pos]
	ui.status_turn_start(ui.party_nodes[active_index])
	ui.show_moves(active_index)

func _on_move_chosen(move_index: int):
	var i := active_index
	var move: MoveData = team.members[i].moves[move_index]

	team.begin_move(i, move_index)
	ui.hide_moves()
	await ui.say(move.text)
	if _ending:
		return

	match move.kind:
		"attack":
			await _do_attack(i, move)
		"defend":
			team.set_guard(i)
			await _play_move_vfx(move, i)
			ui.status_add(ui.party_nodes[i], &"defend", ui.Expire.OWN_TURN | ui.Expire.HIT)
		"taunt":
			team.set_taunt(i)
			await _play_move_vfx(move, i)
			ui.status_add(ui.party_nodes[i], &"taunt")
		"heal":
			await _do_heal(i, move)
		"rally":
			team.set_rally(move.rally_bonus)
			await _play_move_vfx(move, i)
			ui.status_add_to_others(i, &"dmg_up", ui.Expire.TURN_END)

	if enemy_hp == 0:
		return   # _do_attack already handled the victory
	_advance_turn()

func _advance_turn():
	var next := team.next_living_pos(turn_pos + 1)
	if next == -1:
		ui.status_turn_end(ui.party_nodes[active_index])
		await get_tree().create_timer(.25).timeout
		enemy_turn()
	else:
		turn_pos = next
		ui.status_turn_end(ui.party_nodes[active_index])
		active_index = team.turn_order[turn_pos]
		ui.status_turn_start(ui.party_nodes[active_index])
		ui.show_moves(active_index)


# --- Player moves ------------------------------------------------------------
func _apply_enemy_damage(dmg: int, attacker: String = "", source: int = -1):
	enemy_hp = maxi(0, enemy_hp - dmg)
	if source != -1:
		team.add_fusion_charge(source, dmg)   # dealing damage charges that ally's bar
	ui.set_enemy_health(enemy_hp, enemy.health)
	ui.show_enemy_damage_number(dmg)
	audio.play_hit()
	audio.play_cheer()
	
	# Automatically finds the Spectators node inside Background folder
	var bg_manager = get_node_or_null("Background/Spectators")
	if bg_manager and bg_manager.has_method("trigger_damage_reaction"):
		bg_manager.trigger_damage_reaction()

	if puns:
		puns.say_dealt(attacker)

func _do_attack(i: int, move: MoveData):
	var dmg := team.attack_damage(i, move)
	var attacker := team.members[i].name

	if move.attack_anim == "vfx_only":
		await _play_move_vfx(move, i)                 # this move's own frames, no tomato roll
		_apply_enemy_damage(dmg, attacker, i)
		await anim.play_enemy_hit()
	elif team.members[i].scene_node == "Hero":
		await anim.play_tomato_attack(party_nodes[i], func(): _apply_enemy_damage(dmg, attacker, i))
	else:
		_apply_enemy_damage(dmg, attacker, i)
		await anim.play_enemy_hit()

	await ui.say("%s dealt %d damage!" % [attacker, dmg])

	if enemy_hp == 0:
		await _win_battle()
		return
	if move.enemy_attack_down > 0.0:
		await _apply_enemy_attack_down(move.enemy_attack_down)

func _apply_enemy_attack_down(amount: float):
	enemy_attack_mult = minf(enemy_attack_mult, 1.0 - amount)   # the strongest weakening wins; they don't stack
	await ui.say("%s's next attack is weakened!" % enemy.name)
	
func _win_battle():
	_ending = true
	ui.show_text("%s was defeated!" % enemy.name)
	audio.play_cheer(true)
	await anim.play_enemy_death()
	if puns:
		await puns.play_victory()   # all spectators cheer and jump
	await get_tree().create_timer(.25).timeout
	get_tree().quit()

# Plays the move's effect. `user` is who used the move; `healed` is the ally a heal landed on.
func _play_move_vfx(move: MoveData, user: int, healed: int = -1):
	if move.vfx_frames.is_empty():
		return
	if move.vfx_target == "screen":
		await anim.play_fullscreen_vfx(move.vfx_frames, move.vfx_frame_time, move.vfx_fade_time)
		return
		
	var mode := move.vfx_target
	if mode == "default":
		if move.kind == "rally":
			mode = "all_allies"
		elif healed != -1:
			mode = "healed"
		elif move.kind == "attack":
			mode = "enemy"
		else:
			mode = "self"

	var targets: Array = []
	match mode:
		"all_allies":
			for k in party_nodes.size():
				if team.is_alive(k):
					targets.append(party_nodes[k])
		"enemy":
			targets.append(enemy_sprite)
		"healed":
			targets.append(party_nodes[healed])
		_:
			targets.append(party_nodes[user])

	await anim.play_vfx(targets, move.vfx_frames, move.vfx_frame_time, move.vfx_scale, move.vfx_offset)

func _do_heal(healer: int, move: MoveData):
	var target := team.heal_target(healer)
	await _play_move_vfx(move, healer, target)   # effect first, then the HP changes
	var result := team.heal_lowest(healer, move.heal_amount)   # emits health_changed -> UI updates
	ui.show_heal_number(result.index, move.heal_amount)
	audio.play_heal()
	await ui.say("%s recovered %d HP!" % [team.members[result.index].name, result.healed])


# --- Enemy turn --------------------------------------------------------------
func enemy_turn():
	if _ending:
		return
	if enemy_dot_turns > 0:
		await _tick_enemy_dot()
		if _ending:
			return

	# Usually one ally, sometimes a wide swing at two
	var targets: Array[int] = []
	if randf() < double_attack_chance:
		targets = team.pick_enemy_targets(2)
	if targets.size() < 2:
		targets.clear()
		targets.append(team.pick_enemy_target())

	var base_dmg := maxi(1, int(enemy.damage * enemy_attack_mult))
	var dmg := base_dmg
	if targets.size() == 2:
		dmg = maxi(1, int(base_dmg * double_attack_damage_ratio))
	await ui.say("%s slices at %s OWCH!" % [enemy.name, team.members[targets[0]].name])

	_shield_dot_done = false
	for n in targets.size():
		if n > 0:
			await ui.say(double_attack_text.replace("{enemy}", enemy.name))
		await _enemy_strike(targets[n], dmg)

	enemy_attack_mult = 1.0      # a Locular Lob weakening only lasts for this one attack
	shield_fusion = null
	team.end_round()
	start_player_turn()

# One slash on one ally: animation, then block or damage.
func _enemy_strike(idx: int, dmg: int):
	var target := team.members[idx]
	audio.play_slice()
	await anim.play_knife_attack(party_nodes[idx])

	if team.is_guarding(idx):
		if puns:
			puns.say_blocked(target.name)
		await anim.play_mini_shake()
		await ui.say("%s defended successfully!" % target.name)
		ui.status_hit(ui.party_nodes[idx])
		if shield_fusion != null and not _shield_dot_done:
			_shield_dot_done = true
			await _try_apply_dot(shield_fusion)
	else:
		# Impact: HP drops and the screen shakes immediately, then the text
		team.damage_member(idx, dmg)
		ui.show_party_damage_number(idx, dmg)
		audio.play_damage()
		audio.play_jeer()
		if puns:
			puns.say_taken(target.name)
		await anim.play_shake()
		await ui.say("%s dealt %d damage to %s!" % [enemy.name, dmg, target.name])

		if not team.is_alive(idx):
			audio.play_death(target.death_sfx)
			await anim.play_party_death(party_nodes[idx], target.death_frames)
			await ui.say("%s was knocked out!" % target.name)
			ui.status_clear(ui.party_nodes[idx])

	shield_fusion = null
	team.end_round()
	start_player_turn()

func _party_wiped():
	_ending = true
	ui.show_text("Your party was defeated...")
	audio.play_jeer(true)
	if puns:
		await puns.play_defeat()   # all spectators cry
	if ui.textbox.visible:
		await ui.textbox_closed
	get_tree().quit()

func _on_fusion_chosen():
	var i := active_index
	var fusion := team.find_fusion(i)
	if fusion == null:
		return
	var users := team.fusion_users(fusion)
	team.spend_fusion(users, i)
	ui.hide_moves()
	await ui.say(fusion.text)
	if _ending:
		return

	match fusion.fusion_effect:
		"party_shield":
			await _do_party_shield(i, fusion)
		"heal_buff":
			await _do_heal_buff(i, fusion)
		_:
			await _do_fusion_attack(i, users, fusion)
	if enemy_hp == 0:
		return
	_advance_turn()

func _do_fusion_attack(actor: int, users: Array[int], fusion: FusionData):
	var dmg := team.fusion_damage(users, fusion)
	await _play_move_vfx(fusion, actor)
	_apply_enemy_damage(dmg, team.members[actor].name)   # no source, so a fusion doesn't recharge bars
	await anim.play_enemy_hit()
	await ui.say("%s dealt %d damage!" % [fusion.name, dmg])
	if enemy_hp == 0:
		await _win_battle()
		return
	if fusion.dot_damage > 0 and fusion.dot_turns > 0:
		await _try_apply_dot(fusion)
		
func _do_party_shield(actor: int, fusion: FusionData):
	for k in party_nodes.size():
		if team.is_alive(k):
			team.set_guard(k)          # whole party blocks the next enemy attack
	shield_fusion = fusion
	await _play_move_vfx(fusion, actor)

func _do_heal_buff(actor: int, fusion: FusionData):
	await _play_move_vfx(fusion, actor)

	var any_healed := false
	for r in team.heal_party(fusion.heal_amount):   # emits health_changed -> bars update
		if r.healed > 0:
			ui.show_heal_number(r.index, r.healed)
			any_healed = true
	if any_healed:
		audio.play_heal()

	# If nobody is left to act this round, carry the buff into the next round
	var rounds := fusion.buff_rounds
	if team.next_living_pos(turn_pos + 1) == -1:
		rounds += 1
	team.set_rally(fusion.rally_bonus, rounds)

	await ui.say("The party recovers %d HP and feels fired up!" % fusion.heal_amount)

func _tick_enemy_dot():
	enemy_dot_turns -= 1
	enemy_hp = maxi(0, enemy_hp - enemy_dot_damage)
	ui.set_enemy_health(enemy_hp, enemy.health)
	ui.show_enemy_damage_number(enemy_dot_damage)
	audio.play_damage()
	await anim.play_enemy_hit()
	await ui.say("%s takes %d damage from the %s!" % [enemy.name, enemy_dot_damage, enemy_dot_name])
	if enemy_hp == 0:
		await _win_battle()

# Returns true if the new DOT took effect. A weaker DOT never overrides a stronger one.
func _apply_enemy_dot(dmg: int, turns: int, dot_name: String) -> bool:
	if enemy_dot_turns > 0:
		if dmg < enemy_dot_damage:
			return false
		if dmg == enemy_dot_damage and turns <= enemy_dot_turns:
			return false
	enemy_dot_damage = dmg
	enemy_dot_turns = turns
	enemy_dot_name = dot_name
	return true

func _try_apply_dot(fusion: FusionData):
	if _apply_enemy_dot(fusion.dot_damage, fusion.dot_turns, fusion.dot_name):
		await ui.say("%s is afflicted with %s!" % [enemy.name, fusion.dot_name])
	else:
		await ui.say("%s is already suffering a stronger effect!" % enemy.name)

# Searches every child (and their children) for the node running battle_audio.gd.
func _find_audio(node: Node) -> BattleAudio:
	for c in node.get_children():
		if c is BattleAudio:
			return c
		var found := _find_audio(c)
		if found != null:
			return found
	return null
