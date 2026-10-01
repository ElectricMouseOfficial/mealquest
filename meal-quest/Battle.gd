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

#--- Animations ---------------------------------------------------------------
@export var tomato_frames: Array[Texture2D]   # all 10, in order: 9 roll + 1 splat
@export var roll_count := 9                   # first 9 = roll, the rest = splat
@export var roll_time := 0.6                  # seconds to roll to the enemy
@export var frame_time := 0.08                # seconds per splat frame
@export var splat_hold := 0.5                 # extra seconds the splat stays on screen
@export var return_time := 0.4                # seconds to slide back
@export_range(0.0, 1.0) var impact_x_ratio := 0.3   # where it lands on the enemy (0 = left edge, 0.5 = center)
@export var knife_frames: Array[Texture2D]   # drag your knife frames here, in order
@export var knife_frame_time := 0.06         # seconds per frame
@export var knife_scale := 0.5   # 1.0 = original size, 0.5 = half
var knife_vfx: TextureRect
#---Damaged States-------------------------------------------------------------
@export var hero_damaged_tex: Texture2D
@export var ally1_damaged_tex: Texture2D
@export var ally2_damaged_tex: Texture2D
@export var enemy_damaged_tex: Texture2D
var enemy_normal_tex: Texture2D
#--- Turn indicator -----------------------------------------------------------
@export var turn_indicator_tex: Texture2D     # drag your sprite here (optional)
@export var turn_indicator_scale := 1.0
@export var turn_indicator_offset := Vector2(0, 10)   # nudge relative to "just under the character"
var turn_indicator: Control
#--- DamageNumbers-------------------------------------------------------------
@onready var damage_numbers_origin_enemy = $Enemy/DamageNumbersOriginEnemy
@onready var damage_numbers_origin_hero = $Hero/DamageNumbersOriginHero
@onready var damage_numbers_origin_ally1 = $Ally1/DamageNumbersOriginAlly1
@onready var damage_numbers_origin_ally2 = $Ally2/DamageNumbersOriginAlly2
#--- HealingNumbers------------------------------------------------------------
@onready var healing_numbers_origin_hero = $Hero/HealingNumbersOriginHero
@onready var healing_numbers_origin_ally1 = $Ally1/HealingNumbersOriginAlly1
@onready var healing_numbers_origin_ally2 = $Ally2/HealingNumbersOriginAlly2

#---Move button textures-------------------------------------------------------
@export var hero_move_icons: Array[Texture2D]    # Roll, Defend
@export var ally1_move_icons: Array[Texture2D]   # Meat Mash, Taunt, Harden
@export var ally2_move_icons: Array[Texture2D]   # Broil, Broth, Dinner Call
@export var move_icon_size := Vector2(96, 96)

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
				{"name": "Meat Mash", "kind": "attack", "mult": 1.0,
				 "text": "Ever been slapped by a steak? Well the enemy has!"},
				{"name": "Taunt", "kind": "taunt",
				 "text": "The steak shows off its tantilizing marble!"},
				{"name": "Harden", "kind": "defend",
				 "text": "Steak tenses its muscle fibers for an attack!"},
			],
		},
		{
			# Ally 2: support
			"node": "Ally2", "name": "Soup",
			"hp": 25, "max_hp": 25,
			"damage": 4, "guarding": false,
			"moves": [
				{"name": "Broil", "kind": "attack", "mult": 1.0,
				 "text": "A scalding liquid burns the enemies! I wouldn't want to be them!"},
				{"name": "Hearty Broth", "kind": "heal", "amount": 15,
				 "text": "A hearty broth heals your party! You bet I'm hungry now!"},
				{"name": "Dinner Call", "kind": "rally", "bonus": 1.5,
				 "text": "A nice meal makes your party feel fired up!"},
			],
		},
	]

func _bar(member) -> ProgressBar:
	return get_node("%s/VBoxContainerH/ProgressBar" % member.node)

func _ready():
	_build_knife_vfx()
	_build_turn_indicator()
	_build_party()
	for m in party:
		set_health(_bar(m), m.hp, m.max_hp)
	set_health($Enemy/VBoxContainerE/ProgressBar, enemy.health, enemy.health)
	$Enemy.texture = enemy.texture
	current_enemy_health = enemy.health
	
	_setup_sprites()
	for m in party:
		update_party_sprite(m)

	_build_moves_menu()
	$Textbox.hide()
	$ActionsPanel.hide()

	display_text("A determined %s appears!" % enemy.name.to_upper())
	await self.textbox_closed
	start_player_turn()

func _build_turn_indicator():
	if turn_indicator_tex:
		var tr = TextureRect.new()
		tr.texture = turn_indicator_tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.size = turn_indicator_tex.get_size() * turn_indicator_scale
		turn_indicator = tr
	else:
		# Placeholder until you assign a sprite
		var l = Label.new()
		l.text = "▲"
		l.add_theme_font_size_override("font_size", 32)
		l.add_theme_color_override("font_color", Color.BLACK)
		l.size = Vector2(32, 40)
		turn_indicator = l
	turn_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_indicator.z_index = 2
	turn_indicator.hide()
	add_child(turn_indicator)

func _icon_for(member, move_index):
	var sets = [hero_move_icons, ally1_move_icons, ally2_move_icons]
	var icons = sets[party.find(member)]
	if move_index < icons.size():
		return icons[move_index]
	return null
	
func _move_description(member, move) -> String:
	# A hand-written "desc" on the move wins
	if move.has("desc"):
		return move.desc
	match move.kind:
		"attack":
			var dmg = int(member.damage * move.mult * rally_bonus)
			return "Deals about %d damage to the enemy." % dmg
		"defend":
			return "Blocks the next enemy attack on %s." % member.name
		"taunt":
			return "Draws the enemy's attack to %s." % member.name
		"heal":
			return "Heals the most wounded ally for %d HP." % move.amount
		"rally":
			return "Boosts the party's damage by %d%% this round." % int((move.bonus - 1.0) * 100)
	return ""
	
func show_turn_indicator(member):
	var node = get_node(member.node)
	var sprite_rect = node.get_global_rect()
	var bar_rect = get_node(member.node + "/VBoxContainerH").get_global_rect()
	# Sit below whichever is lower: the sprite or its health bar
	var bottom_y = max(sprite_rect.end.y, bar_rect.end.y)
	turn_indicator.global_position = Vector2(
		sprite_rect.get_center().x - turn_indicator.size.x / 2.0,
		bottom_y) + turn_indicator_offset
	turn_indicator.show()
	
func set_health(progress_bar, health, max_health):
	progress_bar.value = health
	progress_bar.max_value = max_health
	progress_bar.get_node("Label").text = "HP:%d/%d" % [health, max_health]

func _input(event):
	if (Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and $Textbox.visible:
		$Textbox.hide()
		emit_signal("textbox_closed")

func display_text(text):
	turn_indicator.hide()
	$ActionsPanel.hide()
	moves_menu.hide()
	$Textbox.show()
	$Textbox/Label.text = text

# --- Moves menu (built in code, so no scene changes needed for the buttons) --
func _build_moves_menu():
	moves_menu = VBoxContainer.new()
	moves_menu.add_theme_constant_override("separation", 4)
	add_child(moves_menu)
	moves_menu.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	moves_menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	moves_menu.hide()

# --- Tomato roll -> splat -> return ------------------------------------------
func play_tomato_attack(dmg):
	var hero = $Hero
	var bar_box = $Hero/VBoxContainerH   # health bar is a child of Hero, so hide it while the tomato moves
	var start_pos = hero.global_position
	var original_texture = hero.texture
	var roll = tomato_frames.slice(0, roll_count)
	var splat = tomato_frames.slice(roll_count)

	# Landing point: inside the enemy at impact_x_ratio across, vertically centered.
	# Subtracting half the hero's size centers the tomato on that point.
	var enemy_rect = $Enemy.get_global_rect()
	var target_center = Vector2(
		enemy_rect.position.x + enemy_rect.size.x * impact_x_ratio,
		enemy_rect.get_center().y)
	var target_pos = target_center - hero.size / 2.0

	hero.z_index = 1
	bar_box.hide()

	# Roll: each roll frame shows once, evenly spread across the trip
	var tween = create_tween()
	tween.tween_property(hero, "global_position", target_pos, roll_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var step = roll_time / roll.size()
	for f in roll:
		hero.texture = f
		await get_tree().create_timer(step).timeout
	if tween.is_running():
		await tween.finished

	# Splat on impact
	_apply_enemy_damage(dmg)
	$AnimationPlayer.play("enemy_damaged")
	for f in splat:
		hero.texture = f
		await get_tree().create_timer(frame_time).timeout
	await get_tree().create_timer(splat_hold).timeout
	if $AnimationPlayer.is_playing():
		await $AnimationPlayer.animation_finished

	# Return
	hero.texture = original_texture
	var back = create_tween()
	back.tween_property(hero, "global_position", start_pos, return_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished

	hero.z_index = 0
	bar_box.show()
	
	#Knife Attack----------------------------------------------------
func _build_knife_vfx():
	knife_vfx = TextureRect.new()
	knife_vfx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	knife_vfx.stretch_mode = TextureRect.STRETCH_SCALE
	knife_vfx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knife_vfx.z_index = 2   # draw above the characters
	knife_vfx.hide()
	add_child(knife_vfx)

func play_knife_attack(target_node: Control):
	if knife_frames.is_empty():
		return

	$Enemy.self_modulate.a = 0.0   # hide the enemy sprite, keep its health bar

	var center = target_node.get_global_rect().get_center()
	knife_vfx.show()
	for f in knife_frames:
		knife_vfx.texture = f
		knife_vfx.size = f.get_size() * knife_scale
		knife_vfx.global_position = center - knife_vfx.size / 2.0
		await get_tree().create_timer(knife_frame_time).timeout
	knife_vfx.hide()

	$Enemy.self_modulate.a = 1.0   # bring the enemy back

func show_moves_for(member):
	for child in moves_menu.get_children():
		child.queue_free()

	var title = Label.new()
	title.text = "%s's turn" % member.name
	title.add_theme_color_override("font_color", Color.BLACK)
	moves_menu.add_child(title)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)   # gap between buttons; 0 = touching
	moves_menu.add_child(row)
	
	for i in member.moves.size():
		var move = member.moves[i]
		var tex = _icon_for(member, i)
		var b: BaseButton

		if tex:
			var tb = TextureButton.new()
			tb.texture_normal = tex
			tb.ignore_texture_size = true
			tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			tb.custom_minimum_size = move_icon_size

			# The move's name, drawn on top of the texture
			var label = Label.new()
			label.text = move.name
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 4)
			tb.add_child(label)

			b = tb
		else:
			var tb = Button.new()
			tb.text = move.name
			b = tb

		b.tooltip_text = "%s\n%s" % [move.name, _move_description(member, move)]
		b.pressed.connect(_on_move_chosen.bind(move))
		row.add_child(b)

	show_turn_indicator(member)
	moves_menu.show()
# --- Turn flow ---------------------------------------------------------------
func start_player_turn():
	active_index = _next_living(0)
	if active_index == -1:
		_party_wiped()
		return
	show_moves_for(party[active_index])
func _apply_enemy_damage(dmg):
	current_enemy_health = max(0, current_enemy_health - dmg)
	set_health($Enemy/VBoxContainerE/ProgressBar, current_enemy_health, enemy.health)
	update_enemy_sprite()
	DamageNumbers.display_number(dmg, damage_numbers_origin_enemy.global_position)

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
			member.guarding = false
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

func _setup_sprites():
	# Order matches the party: Tomato, Steak, Soup
	var damaged = [hero_damaged_tex, ally1_damaged_tex, ally2_damaged_tex]
	for i in party.size():
		party[i]["normal_tex"] = get_node(party[i].node).texture
		party[i]["damaged_tex"] = damaged[i]
	enemy_normal_tex = enemy.texture

func update_party_sprite(member):
	var node = get_node(member.node)
	if member.damaged_tex and member.hp * 2 < member.max_hp:
		node.texture = member.damaged_tex
	else:
		node.texture = member.normal_tex

func update_enemy_sprite():
	if enemy_damaged_tex and current_enemy_health * 2 < enemy.health:
		$Enemy.texture = enemy_damaged_tex
	else:
		$Enemy.texture = enemy_normal_tex
		
func _do_attack(member, move):
	var dmg = int(member.damage * move.mult * rally_bonus)

	if member.node == "Hero":
		await play_tomato_attack(dmg)
	else:
		_apply_enemy_damage(dmg)
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
	update_party_sprite(target)
	if target.node == "Hero":
		State.current_health = target.hp
		HealingNumbers.display_number(move.amount, healing_numbers_origin_hero.global_position)
	if target.node == "Ally1":
		HealingNumbers.display_number(move.amount, healing_numbers_origin_ally1.global_position)
	if target.node == "Ally2":
		HealingNumbers.display_number(move.amount, healing_numbers_origin_ally2.global_position)
		
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
	
	await play_knife_attack(get_node(target.node))

	if target.guarding:
		$AnimationPlayer.play("mini_shake")
		await $AnimationPlayer.animation_finished
		display_text("%s defended successfully!" % target.name)
		await self.textbox_closed
	else:
		# Impact: HP drops and the screen shakes immediately
		target.hp = max(0, target.hp - enemy.damage)
		set_health(_bar(target), target.hp, target.max_hp)
		update_party_sprite(target)
		if target.node == "Hero":
			State.current_health = target.hp
			DamageNumbers.display_number(enemy.damage, damage_numbers_origin_hero.global_position)
		if target.node == "Ally1":
			DamageNumbers.display_number(enemy.damage, damage_numbers_origin_ally1.global_position)
		if target.node == "Ally2":
			DamageNumbers.display_number(enemy.damage, damage_numbers_origin_ally2.global_position)
		$AnimationPlayer.play("shake")
		await $AnimationPlayer.animation_finished

		# Then the text
		display_text("%s dealt %d damage to %s!" % [enemy.name, enemy.damage, target.name])
		await self.textbox_closed

		if target.hp == 0:
			await play_party_death(target)
			display_text("%s was knocked out!" % target.name)
			await self.textbox_closed

	# Reset per-round effects
	for m in party:
		m.guarding = false
	taunt_target = -1
	rally_bonus = 1.0

	start_player_turn()

func play_party_death(member):
	var node = get_node(member.node)
	var bar_box = get_node(member.node + "/VBoxContainerH")
	var tween = create_tween().set_parallel(true)
	tween.tween_property(node, "self_modulate:a", 0.0, 0.5)
	tween.tween_property(bar_box, "modulate:a", 0.0, 0.5)
	await tween.finished
	bar_box.hide()
	
func _party_wiped():
	display_text("Your party was defeated...")
	await self.textbox_closed
	get_tree().quit()
