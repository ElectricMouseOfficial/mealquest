extends Control

signal textbox_closed

@export var enemy: Resource

# --- Party -----------------------------------------------------------------
# Each member: node (scene node name), name, hp, max_hp, damage, guarding, moves
# Move "kind" values: attack, defend, heal, taunt, rally
var party: Array = []
var active_index := 0
var current_enemy_health = 0
var taunt_target := -1        # party index the enemy is forced to hit (-1 = none)
var rally_bonus := 1.0        # damage multiplier applied by Rally, resets each round
var moves_menu: VBoxContainer

func _build_party():
	party = [
		{
			"node": "Hero", "name": "Tomato",
			"hp": State.current_health, "max_hp": State.max_health,
			"damage": State.damage, "guarding": false,
			"moves": [
				{"name": "Roll", "kind": "attack", "mult": 1.0,
				 "text": "You roll your juicy body!"},
				{"name": "Defend", "kind": "defend",
				 "text": "Your fine stem hairs tense!"},
			],
		},
		{
			# Ally 1: tank
			"node": "Ally1", "name": "Steak",
			"hp": 40, "max_hp": 40,
			"damage": 6, "guarding": false,
			"moves": [
				{"name": "Spike Slam", "kind": "attack", "mult": 1.3,
				 "text": "Thorn slams into the enemy with spiky arms!"},
				{"name": "Taunt", "kind": "taunt",
				 "text": "Thorn bristles and dares the enemy to attack!"},
				{"name": "Harden", "kind": "defend",
				 "text": "Thorn hardens its prickly hide!"},
			],
		},
		{
			# Ally 2: support
			"node": "Ally2", "name": "Soup",
			"hp": 25, "max_hp": 25,
			"damage": 4, "guarding": false,
			"moves": [
				{"name": "Sting", "kind": "attack", "mult": 1.0,
				 "text": "Pip zips in and stings!"},
				{"name": "Nectar", "kind": "heal", "amount": 15,
				 "text": "Pip shares sweet nectar!"},
				{"name": "Buzz Rally", "kind": "rally", "bonus": 1.5,
				 "text": "Pip buzzes loudly! The party feels fired up!"},
			],
		},
	]

func _bar(member) -> ProgressBar:
	return get_node("%s/VBoxContainerH/ProgressBar" % member.node)

func _ready():
	_build_party()
	for m in party:
		set_health(_bar(m), m.hp, m.max_hp)
	set_health($Enemy/VBoxContainerE/ProgressBar, enemy.health, enemy.health)
	$Enemy.texture = enemy.texture
	current_enemy_health = enemy.health

	_build_moves_menu()
	$Textbox.hide()
	$ActionsPanel.hide()

	display_text("A determined %s appears!" % enemy.name.to_upper())
	await self.textbox_closed
	start_player_turn()

func set_health(progress_bar, health, max_health):
	progress_bar.value = health
	progress_bar.max_value = max_health
	progress_bar.get_node("Label").text = "HP:%d/%d" % [health, max_health]

func _input(event):
	if (Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and $Textbox.visible:
		$Textbox.hide()
		emit_signal("textbox_closed")

func display_text(text):
	$ActionsPanel.hide()
	moves_menu.hide()
	$Textbox.show()
	$Textbox/Label.text = text

# --- Moves menu (built in code, so no scene changes needed for the buttons) --
func _build_moves_menu():
	moves_menu = VBoxContainer.new()
	moves_menu.position = Vector2(20, 20)   # adjust to fit your layout
	add_child(moves_menu)
	moves_menu.hide()

func show_moves_for(member):
	for child in moves_menu.get_children():
		child.queue_free()

	var title = Label.new()
	title.text = "%s's turn" % member.name
	moves_menu.add_child(title)

	for move in member.moves:
		var b = Button.new()
		b.text = move.name
		b.pressed.connect(_on_move_chosen.bind(move))
		moves_menu.add_child(b)
	moves_menu.show()

# --- Turn flow ---------------------------------------------------------------
func start_player_turn():
	active_index = _next_living(0)
	if active_index == -1:
		_party_wiped()
		return
	show_moves_for(party[active_index])

func _next_living(from_index: int) -> int:
	for i in range(from_index, party.size()):
		if party[i].hp > 0:
			return i
	return -1

func _on_move_chosen(move):
	var member = party[active_index]
	moves_menu.hide()

	display_text(move.text)
	await self.textbox_closed

	match move.kind:
		"attack":
			await _do_attack(member, move)
		"defend":
			member.guarding = true
		"taunt":
			taunt_target = active_index
			member.guarding = true
		"heal":
			await _do_heal(member, move)
		"rally":
			rally_bonus = move.bonus

	if current_enemy_health == 0:
		return   # _do_attack already handled the victory

	# Next living party member, or the enemy if everyone has acted
	var next = _next_living(active_index + 1)
	if next == -1:
		await get_tree().create_timer(.25).timeout
		enemy_turn()
	else:
		active_index = next
		show_moves_for(party[active_index])

func _do_attack(member, move):
	var dmg = int(member.damage * move.mult * rally_bonus)
	current_enemy_health = max(0, current_enemy_health - dmg)
	set_health($Enemy/VBoxContainerE/ProgressBar, current_enemy_health, enemy.health)

	$AnimationPlayer.play("enemy_damaged")
	await $AnimationPlayer.animation_finished

	display_text("%s dealt %d damage!" % [member.name, dmg])
	await self.textbox_closed

	if current_enemy_health == 0:
		display_text("%s was defeated!" % enemy.name)
		$AnimationPlayer.play("enemy_died")
		await $AnimationPlayer.animation_finished
		await get_tree().create_timer(.25).timeout
		get_tree().quit()

func _do_heal(healer, move):
	# Heal the living ally with the lowest HP ratio
	var target = healer
	for m in party:
		if m.hp > 0 and float(m.hp) / m.max_hp < float(target.hp) / target.max_hp:
			target = m
	var before = target.hp
	target.hp = min(target.max_hp, target.hp + move.amount)
	set_health(_bar(target), target.hp, target.max_hp)
	if target.node == "Hero":
		State.current_health = target.hp

	display_text("%s recovered %d HP!" % [target.name, target.hp - before])
	await self.textbox_closed

func enemy_turn():
	# Pick target: taunter if any, otherwise a random living member
	var idx = taunt_target
	if idx == -1 or party[idx].hp <= 0:
		var living = []
		for i in party.size():
			if party[i].hp > 0:
				living.append(i)
		idx = living.pick_random()
	var target = party[idx]

	display_text("%s slices at %s OWCH!" % [enemy.name, target.name])
	await self.textbox_closed

	if target.guarding:
		$AnimationPlayer.play("mini_shake")
		await $AnimationPlayer.animation_finished
		display_text("%s defended successfully!" % target.name)
		await self.textbox_closed
	else:
		target.hp = max(0, target.hp - enemy.damage)
		set_health(_bar(target), target.hp, target.max_hp)
		if target.node == "Hero":
			State.current_health = target.hp
		display_text("%s dealt %d damage to %s!" % [enemy.name, enemy.damage, target.name])
		await self.textbox_closed
		$AnimationPlayer.play("shake")
		await $AnimationPlayer.animation_finished

		if target.hp == 0:
			display_text("%s was knocked out!" % target.name)
			await self.textbox_closed

	# Reset per-round effects
	for m in party:
		m.guarding = false
	taunt_target = -1
	rally_bonus = 1.0

	start_player_turn()

func _party_wiped():
	display_text("Your party was defeated...")
	await self.textbox_closed
	get_tree().quit()
