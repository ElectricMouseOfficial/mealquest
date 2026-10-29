extends Control
## Turn flow only. This is the one script that knows about all the modules.
##   Team       (team_manager.gd)       rules + data
##   Animations (battle_animations.gd)  movement and effects
##   UI         (battle_ui.gd)          menus, bars, text

@export var enemy: Resource

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

# --- Dev shortcuts (work only when running from the editor / debug builds) ---------
@export var debug_shortcuts := true
@export var debug_win_key: Key = KEY_W     # instantly win the battle
@export var debug_lose_key: Key = KEY_L    # instantly lose the battle


func _ready():
	team.setup()
	for m in team.members:
		party_nodes.append(get_node(m.scene_node) as TextureRect)
	enemy_hp = enemy.health

	anim.setup($AnimationPlayer, enemy_sprite, self)
	if puns == null:
		# No (working) Puns node in the scene: make one so the puns still work
		puns = SpectatorPuns.new()
		puns.name = "Puns"
		add_child(puns)
		push_warning("No Puns node with spectator_puns.gd found, created one with the default puns.")
	puns.setup(get_node_or_null("Background/Spectators"), self)
	ui.setup(team, party_nodes, enemy_sprite, enemy, $Textbox, $ActionsPanel)
	ui.set_enemy_health(enemy_hp, enemy.health)

	team.health_changed.connect(ui.set_party_health)
	ui.move_chosen.connect(_on_move_chosen)

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
		"taunt":
			team.set_taunt(i)
		"heal":
			await _do_heal(i, move)
		"rally":
			team.set_rally(move.rally_bonus)

	if enemy_hp == 0:
		return   # _do_attack already handled the victory

	var next := team.next_living_pos(turn_pos + 1)
	if next == -1:
		await get_tree().create_timer(.25).timeout
		enemy_turn()
	else:
		turn_pos = next
		active_index = team.turn_order[turn_pos]
		ui.show_moves(active_index)


# --- Player moves ------------------------------------------------------------
func _apply_enemy_damage(dmg: int, attacker: String = ""):
	enemy_hp = maxi(0, enemy_hp - dmg)
	ui.set_enemy_health(enemy_hp, enemy.health)
	ui.show_enemy_damage_number(dmg)
	
	# Automatically finds the Spectators node inside Background folder
	var bg_manager = get_node_or_null("Background/Spectators")
	if bg_manager and bg_manager.has_method("trigger_damage_reaction"):
		bg_manager.trigger_damage_reaction()

	if puns:
		puns.say_dealt(attacker)

func _do_attack(i: int, move: MoveData):
	var dmg := team.attack_damage(i, move)

	if team.members[i].scene_node == "Hero":
		await anim.play_tomato_attack(party_nodes[i], func(): _apply_enemy_damage(dmg, team.members[i].name))
	else:
		_apply_enemy_damage(dmg, team.members[i].name)
		await anim.play_enemy_hit()

	await ui.say("%s dealt %d damage!" % [team.members[i].name, dmg])

	if enemy_hp == 0:
		await _win_battle()

func _win_battle():
	_ending = true
	ui.show_text("%s was defeated!" % enemy.name)
	await anim.play_enemy_death()
	if puns:
		await puns.play_victory()   # all spectators cheer and jump
	await get_tree().create_timer(.25).timeout
	get_tree().quit()

func _do_heal(healer: int, move: MoveData):
	var result := team.heal_lowest(healer, move.heal_amount)   # emits health_changed -> UI updates
	ui.show_heal_number(result.index, move.heal_amount)
	await ui.say("%s recovered %d HP!" % [team.members[result.index].name, result.healed])


# --- Enemy turn --------------------------------------------------------------
func enemy_turn():
	if _ending:
		return
	var idx := team.pick_enemy_target()
	var target := team.members[idx]

	await ui.say("%s slices at %s OWCH!" % [enemy.name, target.name])
	await anim.play_knife_attack(party_nodes[idx])

	if team.is_guarding(idx):
		if puns:
			puns.say_blocked(target.name)
		await anim.play_mini_shake()
		await ui.say("%s defended successfully!" % target.name)
	else:
		# Impact: HP drops and the screen shakes immediately, then the text
		team.damage_member(idx, enemy.damage)
		ui.show_party_damage_number(idx, enemy.damage)
		if puns:
			puns.say_taken(target.name)
		await anim.play_shake()
		await ui.say("%s dealt %d damage to %s!" % [enemy.name, enemy.damage, target.name])

		if not team.is_alive(idx):
			await anim.play_party_death(party_nodes[idx], team.members[idx].death_frames)
			await ui.say("%s was knocked out!" % target.name)

	team.end_round()
	start_player_turn()

func _party_wiped():
	_ending = true
	ui.show_text("Your party was defeated...")
	if puns:
		await puns.play_defeat()   # all spectators cry
	if ui.textbox.visible:
		await ui.textbox_closed
	get_tree().quit()
