class_name BattleUI
extends Control
## Everything the player sees and clicks: moves menu, tooltips, turn arrow, textbox,
## health bars (+ colors), damaged sprites, floating numbers.
## It never changes game state. It emits `move_chosen` and listens for updates.
## In the scene: set this node to Full Rect, Mouse Filter = Ignore, and keep it
## below the sprites in the tree so it draws on top.

signal move_chosen(move_index: int)
signal textbox_closed

@export var turn_indicator_tex: Texture2D
@export var turn_indicator_scale := 1.0
@export var turn_indicator_offset := Vector2(0, 10)
@export var move_icon_size := Vector2(96, 96)
@export var enemy_damaged_tex: Texture2D
@export var bar_green := Color("#36b729")

@export_group("Move button text")
@export var move_font: Font                       # optional custom font (blank = project default)
@export var move_font_size := 16                  # maximum size
@export var move_font_color := Color.WHITE
@export var move_outline_color := Color.BLACK
@export var move_outline_size := 4
@export var shrink_to_fit := true                 # shrink long names so they stay inside the button

@export_group("Turn title and menu position")
@export var title_font_size := 18
@export var title_color := Color.BLACK
@export var title_outline_color := Color.WHITE
@export var title_outline_size := 4
@export var menu_shift := Vector2.ZERO            # nudge the whole moves menu (+x right, +y down)

var team: TeamManager                 # read-only queries (cooldowns, damage preview)
var party_nodes: Array[TextureRect] = []
var enemy_node: TextureRect
var textbox: Control
var actions_panel: Control
var moves_menu: VBoxContainer
var turn_indicator: Control
var normal_tex: Array[Texture2D] = []
var enemy_normal_tex: Texture2D


func setup(team_ref: TeamManager, nodes: Array[TextureRect], enemy_sprite: TextureRect,
		enemy_res: Resource, textbox_node: Control, actions_node: Control):
	team = team_ref
	party_nodes = nodes
	enemy_node = enemy_sprite
	textbox = textbox_node
	actions_panel = actions_node

	enemy_node.texture = enemy_res.texture
	enemy_normal_tex = enemy_res.texture
	for node in party_nodes:
		normal_tex.append(node.texture)

	_build_turn_indicator()
	_build_moves_menu()
	textbox.hide()
	actions_panel.hide()

	for i in party_nodes.size():
		set_party_health(i, team.hp[i], team.max_hp[i])


# --- Textbox -----------------------------------------------------------------
func _input(_event):
	if textbox == null:
		return
	if (Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and textbox.visible:
		textbox.hide()
		textbox_closed.emit()

func show_text(text: String):
	turn_indicator.hide()
	actions_panel.hide()
	moves_menu.hide()
	textbox.show()
	textbox.get_node("Label").text = text

func say(text: String):
	show_text(text)
	await textbox_closed


# --- Health bars, colors and damaged sprites ---------------------------------
func set_party_health(i: int, hp: int, max_hp: int):
	var bar: ProgressBar = party_nodes[i].get_node("VBoxContainerH/ProgressBar")
	_set_bar(bar, hp, max_hp)
	var damaged := team.members[i].damaged_tex
	if damaged and hp * 2 < max_hp:
		party_nodes[i].texture = damaged
	else:
		party_nodes[i].texture = normal_tex[i]

func set_enemy_health(hp: int, max_hp: int):
	var bar: ProgressBar = enemy_node.get_node("VBoxContainerE/ProgressBar")
	_set_bar(bar, hp, max_hp)
	if enemy_damaged_tex and hp * 2 < max_hp:
		enemy_node.texture = enemy_damaged_tex
	else:
		enemy_node.texture = enemy_normal_tex

func _set_bar(bar: ProgressBar, hp: int, max_hp: int):
	bar.max_value = max_hp
	bar.value = hp
	bar.get_node("Label").text = "HP:%d/%d" % [hp, max_hp]

	var ratio := float(hp) / max_hp
	var color := bar_green
	if ratio <= 0.25:
		color = Color.RED
	elif ratio <= 0.5:
		color = Color.YELLOW
	var style: StyleBoxFlat = bar.get_theme_stylebox("fill").duplicate()
	style.bg_color = color
	bar.add_theme_stylebox_override("fill", style)


# --- Floating numbers (origin nodes are looked up by sprite name) ---------------
func show_party_damage_number(i: int, amount: int):
	var origin = party_nodes[i].get_node_or_null("DamageNumbersOrigin" + str(party_nodes[i].name))
	if origin:
		DamageNumbers.display_number(amount, origin.global_position)

func show_enemy_damage_number(amount: int):
	var origin = enemy_node.get_node_or_null("DamageNumbersOrigin" + str(enemy_node.name))
	if origin:
		DamageNumbers.display_number(amount, origin.global_position)

func show_heal_number(i: int, amount: int):
	var origin = party_nodes[i].get_node_or_null("HealingNumbersOrigin" + str(party_nodes[i].name))
	if origin:
		HealingNumbers.display_number(amount, origin.global_position)


# --- Turn indicator --------------------------------------------------------------
func _build_turn_indicator():
	if turn_indicator_tex:
		var arrow := TextureRect.new()
		arrow.texture = turn_indicator_tex
		arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arrow.stretch_mode = TextureRect.STRETCH_SCALE
		arrow.size = turn_indicator_tex.get_size() * turn_indicator_scale
		turn_indicator = arrow
	else:
		var l := Label.new()   # placeholder until you assign a sprite
		l.text = "▲"
		l.add_theme_font_size_override("font_size", 32)
		l.add_theme_color_override("font_color", Color.GOLDENROD)
		l.size = Vector2(32, 40)
		turn_indicator = l
	turn_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_indicator.z_index = 2
	turn_indicator.hide()
	add_child(turn_indicator)

func show_turn_indicator(i: int):
	var node := party_nodes[i]
	var sprite_rect := node.get_global_rect()
	var bar_rect := (node.get_node("VBoxContainerH") as Control).get_global_rect()
	var bottom_y := maxf(sprite_rect.end.y, bar_rect.end.y)   # below the sprite or its health bar
	turn_indicator.global_position = Vector2(
		sprite_rect.get_center().x - turn_indicator.size.x / 2.0,
		bottom_y) + turn_indicator_offset
	turn_indicator.show()


# --- Moves menu --------------------------------------------------------------------
func _build_moves_menu():
	moves_menu = VBoxContainer.new()
	moves_menu.add_theme_constant_override("separation", 4)
	add_child(moves_menu)
	moves_menu.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	moves_menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	moves_menu.offset_left += menu_shift.x
	moves_menu.offset_right += menu_shift.x
	moves_menu.offset_top += menu_shift.y
	moves_menu.offset_bottom += menu_shift.y
	moves_menu.hide()

func hide_moves():
	moves_menu.hide()

func describe_move(i: int, move: MoveData) -> String:
	if move.desc != "":
		return move.desc
	var member := team.members[i]
	match move.kind:
		"attack":
			return "Deals about %d damage to the enemy." % team.attack_damage(i, move)
		"defend":
			return "Blocks the next enemy attack on %s." % member.name
		"taunt":
			return "Draws the enemy's attack to %s." % member.name
		"heal":
			return "Heals the most wounded ally for %d HP." % move.heal_amount
		"rally":
			return "Boosts the party's damage by %d%% this round." % int((move.rally_bonus - 1.0) * 100)
	return ""

func _widest_line(text: String, font: Font, font_px: int) -> float:
	var widest := 0.0
	for line in text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x)
	return widest

func _fit_label(label: Label, max_width: float):
	if move_font:
		label.add_theme_font_override("font", move_font)
	var font: Font = move_font if move_font else label.get_theme_font("font")
	var font_px := move_font_size
	if shrink_to_fit:
		var usable := max_width - move_outline_size * 2 - 4
		while font_px > 8 and _widest_line(label.text, font, font_px) > usable:
			font_px -= 1
	label.add_theme_font_size_override("font_size", font_px)

func show_moves(i: int):
	for child in moves_menu.get_children():
		child.queue_free()

	var member := team.members[i]

	var title := Label.new()
	title.text = "%s's turn" % member.name
	title.add_theme_font_size_override("font_size", title_font_size)
	title.add_theme_color_override("font_color", title_color)
	title.add_theme_color_override("font_outline_color", title_outline_color)
	title.add_theme_constant_override("outline_size", title_outline_size)
	moves_menu.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	moves_menu.add_child(row)

	for mi in member.moves.size():
		var move := member.moves[mi]
		var blocked := team.is_move_blocked(i, mi)
		var cd_text := "\nCD: %d" % team.cooldown_left(i, mi) if blocked else ""
		var b: BaseButton
		var label: Label = null

		if move.icon:
			var tb := TextureButton.new()
			tb.texture_normal = move.icon
			tb.texture_disabled = move.icon
			tb.ignore_texture_size = true
			tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			tb.custom_minimum_size = move_icon_size

			# The move's name (plus cooldown), drawn on top of the texture
			label = Label.new()
			label.text = move.name + cd_text
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_color_override("font_color", move_font_color)
			label.add_theme_color_override("font_outline_color", move_outline_color)
			label.add_theme_constant_override("outline_size", move_outline_size)
			tb.add_child(label)
			b = tb
		else:
			var tb := Button.new()
			tb.text = move.name + cd_text.replace("\n", " ")   # "Roll CD: 2"
			b = tb

		b.disabled = blocked
		if blocked:
			b.modulate = Color(0.5, 0.5, 0.5)

		var cd_info := "\nCooldown: %d round(s)" % move.cooldown if move.cooldown > 0 else ""
		b.tooltip_text = "%s\n%s%s" % [move.name, describe_move(i, move), cd_info]
		b.pressed.connect(func(): move_chosen.emit(mi))
		row.add_child(b)
		if label:
			_fit_label(label, move_icon_size.x)

	show_turn_indicator(i)
	moves_menu.show()
