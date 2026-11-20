class_name BattleUI
extends Control
## Everything the player sees and clicks: moves menu, tooltips, turn arrow, textbox,
## health bars (+ colors), damaged sprites, floating numbers.
## It never changes game state. It emits `move_chosen` and listens for updates.
## In the scene: set this node to Full Rect, Mouse Filter = Ignore, and keep it
## below the sprites in the tree so it draws on top.

signal move_chosen(move_index: int)
signal textbox_closed
signal fusion_chosen

@export var turn_indicator_frames: Array[Texture2D] = []
var _indicator_frame := 0
@export var turn_indicator_scale := 1.0
@export var turn_indicator_offset := Vector2(0, 10)
@export var move_icon_size := Vector2(96, 96)
@export var enemy_damaged_tex: Texture2D
@export var bar_green := Color("#36b729")

enum Expire { OWN_TURN = 1, HIT = 2, TURNS = 4, TURN_END = 8 }
@export_group("Status Effects")
@export var defend_icon: Texture2D
@export var taunt_icon: Texture2D
@export var dmg_up_icon: Texture2D
var _party_hp := {}   # hero index -> last HP sent to set_party_health
@export_subgroup("Hover text")
@export var defend_name := "Guarded"
@export_multiline var defend_desc := "Blocks the next enemy attack."
@export var taunt_name := "Taunting"
@export_multiline var taunt_desc := "The enemy must attack this ally on its next turn."
@export var dmg_up_name := "Damage Up"
@export_multiline var dmg_up_desc := "Deals extra damage."
@export var status_hover_width := 220.0                 # box width in pixels (long text wraps)
@export var status_hover_offset := Vector2(0, -6)       # nudge the box (+x right, +y down)
@export var status_title_color := Color.GOLD

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

@export_group("Textbox")
@export var textbox_texture: Texture2D            # drag your custom textbox image here
@export var textbox_patch_margin := Vector4i(16, 16, 16, 16)   # left, top, right, bottom (9-slice borders)
@export var textbox_text_color := Color.WHITE
@export var textbox_font_size := 18
@export var textbox_text_padding := Vector2(16, 12)            # label inset from the box edges

@export_group("Fusion")
@export var fusion_button_text := "Fusion!"
@export var fusion_icon: Texture2D                      # drag your Fusion button art here
@export var fusion_text_color := Color.GOLD
@export var fusion_bar_size := Vector2(60, 16)
@export var fusion_bar_color := Color("#3aa0ff")
@export var fusion_bar_full_color := Color.GOLD
@export var fusion_bar_bg_color := Color(0, 0, 0, 0.6)
@export var hover_font_size := 14
@export var hover_text_color := Color.WHITE
@export var hover_bg_color := Color(0, 0, 0, 0.8)
@export var hover_offset := Vector2(0, -8)              # nudge the hover panel (+x right, +y down)
@export var fusion_not_ready_icon: Texture2D
@export var fusion_not_ready_tint := Color(0.5, 0.5, 0.5)         # taller than before so the text fits
@export var fusion_bar_text := "Fusion!"
@export var fusion_bar_font_size := 11
@export var fusion_bar_text_color := Color.WHITE
@export var fusion_bar_text_outline_color := Color.BLACK
@export var fusion_bar_text_outline_size := 3
@export var fusion_bar_border_color := Color.BLACK
@export var fusion_bar_border_width := 2

var team: TeamManager                 # read-only queries (cooldowns, damage preview)
var party_nodes: Array[TextureRect] = []
var enemy_node: TextureRect
var textbox: Control
var actions_panel: Control
var moves_menu: VBoxContainer
var turn_indicator: Control
var normal_tex: Array[Texture2D] = []
var enemy_normal_tex: Texture2D
var fusion_bars: Array[ProgressBar] = []
var hover_panel: PanelContainer
var hover_label: Label
var _hover_index := -1

func _apply_textbox_style():
	if textbox == null:
		return

	var label: Label = textbox.get_node("Label")

	# Text styling
	label.add_theme_color_override("font_color", textbox_text_color)
	label.add_theme_font_size_override("font_size", textbox_font_size)

	if textbox_texture == null:
		return   # nothing assigned, keep the original look

	# Hide the old background so the custom art shows
	if textbox is Panel or textbox is PanelContainer:
		textbox.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	elif textbox is ColorRect:
		textbox.color = Color(0, 0, 0, 0)

	# Remove an earlier custom background if setup runs twice
	var old := textbox.get_node_or_null("CustomBG")
	if old:
		old.queue_free()

	# Stretchable background (9-slice, so the corners don't distort)
	var bg := NinePatchRect.new()
	bg.name = "CustomBG"
	bg.texture = textbox_texture
	bg.patch_margin_left = textbox_patch_margin.x
	bg.patch_margin_top = textbox_patch_margin.y
	bg.patch_margin_right = textbox_patch_margin.z
	bg.patch_margin_bottom = textbox_patch_margin.w
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textbox.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	textbox.move_child(bg, 0)   # behind the Label

	# Keep the text inside the art's borders
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = textbox_text_padding.x
	label.offset_right = -textbox_text_padding.x
	label.offset_top = textbox_text_padding.y
	label.offset_bottom = -textbox_text_padding.y

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
	_build_fusion_bars()
	_build_hover_info()
	textbox.hide()
	_apply_textbox_style()
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
	if turn_indicator_frames.size() > 0:
		var first := turn_indicator_frames[0]
		var arrow := TextureRect.new()
		arrow.texture = first
		arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arrow.stretch_mode = TextureRect.STRETCH_SCALE
		var s := first.get_size() * turn_indicator_scale
		arrow.custom_minimum_size = s
		arrow.size = s
		turn_indicator = arrow
	else:
		var l := Label.new()   # placeholder until you assign a sprite
		l.text = "▲"
		l.add_theme_font_size_override("font_size", 32)
		l.add_theme_color_override("font_color", Color.GOLDENROD)
		l.size = Vector2(32, 40)
		turn_indicator = l
	turn_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_indicator.z_index = 0
	turn_indicator.hide()
	add_child(turn_indicator)
	
	var flip_timer := Timer.new()
	flip_timer.wait_time = 0.15
	flip_timer.autostart = true
	flip_timer.timeout.connect(_flip_indicator)
	add_child(flip_timer)
	
func _flip_indicator():
	if not (turn_indicator is TextureRect) or turn_indicator_frames.size() < 2:
		return
	_indicator_frame = (_indicator_frame + 1) % turn_indicator_frames.size()
	turn_indicator.texture = turn_indicator_frames[_indicator_frame]

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
			var text := "Deals about %d damage to the enemy." % team.attack_damage(i, move)
			if move.enemy_attack_down > 0.0:
				text += " Lowers the enemy's next attack by %d%%." % int(move.enemy_attack_down * 100)
			return text
		"defend":
			return "Blocks an attack for the next enemy turn. %s." % member.name
		"taunt":
			return "Draws the enemy's attack to %s." % member.name
		"heal":
			return "Heals the most wounded ally for %d HP." % move.heal_amount
		"rally":
			return "Boosts the party's damage by %d%% this round." % int((move.rally_bonus - 1.0) * 100)
	return ""
func describe_fusion(f: FusionData) -> String:
	if f.desc != "":
		return f.desc   

	match f.fusion_effect:
		"party_shield":
			var text := "Shields the whole party from the next enemy attack."
			if f.dot_damage > 0 and f.dot_turns > 0:
				text += " The enemy takes %d damage a turn for %d turns if it hits the shield." % [f.dot_damage, f.dot_turns]
			return text
		"heal_buff":
			return "Heals the whole party for %d HP and boosts damage by %d%% for %d round(s)." % [
				f.heal_amount, int((f.rally_bonus - 1.0) * 100), f.buff_rounds]
		_:
			var dmg := team.fusion_damage(team.fusion_users(f), f)
			var text := "Deals about %d damage to the enemy." % dmg
			if f.dot_damage > 0 and f.dot_turns > 0:
				text += " Then %d damage a turn for %d turns." % [f.dot_damage, f.dot_turns]
			return text

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

	# Fusion button: ONE per menu, after the loop
	if team.fusion_full(i):
		_add_fusion_button(row, i)

	show_turn_indicator(i)
	moves_menu.show()

# --- Fusion bars and button ----------------------------------------------------------
func _build_fusion_bars():
	for i in party_nodes.size():
		var bar := ProgressBar.new()
		bar.name = "FusionBar"
		bar.show_percentage = false
		bar.custom_minimum_size = fusion_bar_size
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg := StyleBoxFlat.new()
		bg.bg_color = fusion_bar_bg_color
		bar.add_theme_stylebox_override("background", bg)

		# Border: drawn on top of the bar so the fill can't cover it
		var border := Panel.new()
		border.name = "Border"
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var border_style := StyleBoxFlat.new()
		border_style.draw_center = false
		border_style.set_border_width_all(fusion_bar_border_width)
		border_style.border_color = fusion_bar_border_color
		border.add_theme_stylebox_override("panel", border_style)
		bar.add_child(border)
		border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		# Text inside the bar
		var text := Label.new()
		text.name = "Text"
		text.text = fusion_bar_text
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.add_theme_font_size_override("font_size", fusion_bar_font_size)
		text.add_theme_color_override("font_color", fusion_bar_text_color)
		text.add_theme_color_override("font_outline_color", fusion_bar_text_outline_color)
		text.add_theme_constant_override("outline_size", fusion_bar_text_outline_size)
		bar.add_child(text)
		text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		party_nodes[i].get_node("VBoxContainerH").add_child(bar)   # sits under the HP bar
		fusion_bars.append(bar)
		set_fusion_bar(i, team.fusion_charge[i], team.members[i].fusion_max)

func set_fusion_bar(i: int, charge: int, max_charge: int):
	var bar := fusion_bars[i]
	bar.max_value = max_charge
	bar.value = charge
	var fill := StyleBoxFlat.new()
	fill.bg_color = fusion_bar_full_color if charge >= max_charge else fusion_bar_color
	bar.add_theme_stylebox_override("fill", fill)
	if hover_panel != null and _hover_index != -1:
		_refresh_hover()

func _add_fusion_button(row: HBoxContainer, i: int):
	if row.get_node_or_null("FusionButton") != null:
		return   # already has one

	var fusion := team.find_fusion(i)
	var can_fuse := fusion != null
	# Show the fusion's own name; fall back to "Fusion!" when no partner is ready yet
	var btn_text := fusion.name if can_fuse else fusion_button_text
	# Use the fusion's own icon if it has one, otherwise the shared Fusion Icon
	var icon_tex: Texture2D
	if can_fuse:
		icon_tex = fusion.icon if fusion.icon else fusion_icon
	else:
		icon_tex = fusion_not_ready_icon if fusion_not_ready_icon else fusion_icon

	var b: BaseButton
	var label: Label = null

	if icon_tex:
		var tb := TextureButton.new()
		tb.texture_normal = icon_tex
		tb.texture_disabled = icon_tex
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		tb.custom_minimum_size = move_icon_size

		label = Label.new()
		label.text = btn_text
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", fusion_text_color)
		label.add_theme_color_override("font_outline_color", move_outline_color)
		label.add_theme_constant_override("outline_size", move_outline_size)
		tb.add_child(label)
		b = tb
	else:
		var tb := Button.new()
		tb.text = btn_text
		tb.add_theme_color_override("font_color", fusion_text_color)
		b = tb

	b.disabled = not can_fuse
	if can_fuse:
		b.tooltip_text = "%s\n%s" % [fusion.name, describe_fusion(fusion)]
	else:
		b.modulate = fusion_not_ready_tint
		b.tooltip_text = "%s\nNeeds another ally with a full Fusion bar." % fusion_button_text

	b.pressed.connect(func(): fusion_chosen.emit())
	b.name = "FusionButton"
	row.add_child(b)
	if label:
		_fit_label(label, move_icon_size.x) 


# --- Hover info ------------------------------------------------------------------
func _build_hover_info():
	hover_panel = PanelContainer.new()
	hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_panel.z_index = 10
	var bg := StyleBoxFlat.new()
	bg.bg_color = hover_bg_color
	bg.set_content_margin_all(8)
	bg.set_corner_radius_all(4)
	hover_panel.add_theme_stylebox_override("panel", bg)

	hover_label = Label.new()
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_label.add_theme_font_size_override("font_size", hover_font_size)
	hover_label.add_theme_color_override("font_color", hover_text_color)
	hover_panel.add_child(hover_label)

	hover_panel.hide()
	add_child(hover_panel)

# Polls the mouse instead of using mouse_entered, so it works without touching
# the sprites' Mouse Filter settings and doesn't flicker over child nodes.
func _process(_delta):
	if team == null or hover_panel == null:
		return
	var mouse := get_global_mouse_position()

	# Buff icons take priority over the ally info panel
	var sid := _status_id_under_mouse(mouse)
	if sid != _hover_status:
		_hover_status = sid
		_refresh_status_hover()
	if sid != &"":
		if _hover_index != -1:
			_hover_index = -1
			_refresh_hover()
		return
		
	var found := -1
	for i in party_nodes.size():
		var rect := party_nodes[i].get_global_rect().merge(
			(party_nodes[i].get_node("VBoxContainerH") as Control).get_global_rect())
		if rect.has_point(mouse):
			found = i
			break
	if found != _hover_index:
		_hover_index = found
		_refresh_hover()

func _refresh_hover():
	if _hover_index == -1:
		hover_panel.hide()
		return
	hover_label.text = _fusion_info_text(_hover_index)
	hover_panel.show()
	hover_panel.reset_size()
	var rect := party_nodes[_hover_index].get_global_rect()
	var pos := Vector2(
		rect.get_center().x - hover_panel.size.x / 2.0,
		rect.position.y - hover_panel.size.y) + hover_offset
	pos.x = clampf(pos.x, 0.0, maxf(0.0, get_viewport_rect().size.x - hover_panel.size.x))
	pos.y = maxf(pos.y, 0.0)
	hover_panel.global_position = pos

func _partner_status(j: int) -> String:
	var m := team.members[j]
	if team.hp[j] <= 0:
		return "%s (KO)" % m.name
	if team.fusion_full(j):
		return "%s READY" % m.name
	return "%s %d/%d" % [m.name, team.fusion_charge[j], m.fusion_max]

func _fusion_info_text(i: int) -> String:
	var m := team.members[i]
	if team.hp[i] <= 0:
		return "%s is knocked out." % m.name

	var lines := PackedStringArray()
	var need := m.fusion_max - team.fusion_charge[i]
	if need <= 0:
		lines.append("%s: Fusion READY" % m.name)
	else:
		lines.append("%s: Fusion %d/%d (%d more damage)" % [
			m.name, team.fusion_charge[i], m.fusion_max, need])

	# Every fusion this ally is part of, and how ready each partner is
	for f in team.fusions:
		if f == null or f.partners.size() < 2:
			continue
		var involved := false
		for p in f.partners:
			if p and team.index_of(p) == i:
				involved = true
		if not involved:
			continue
		var parts := PackedStringArray()
		for p in f.partners:
			var j := team.index_of(p) if p else -1
			if j != -1:
				parts.append(_partner_status(j))
		lines.append("- %s: %s" % [f.name, ", ".join(parts)])

	return "\n".join(lines)


#Status Effects script:
const STATUS_ICON_SIZE := Vector2(70, 70)

var _status_icons := {}   # id -> Texture2D, filled in _setup_status_icons()
# unit -> { "bar": HBoxContainer, "active": { id: { "icon", "expire", "remaining" } } }
var _status_units := {}
var _status_info := {}                  # id -> { "name", "desc" }
var status_panel: PanelContainer
var status_name_label: Label
var status_desc_label: Label
var _hover_status: StringName = &""
var _hover_status_rect := Rect2()

func _ready() -> void:
	_status_icons = {
		&"defend": defend_icon,
		&"taunt": taunt_icon,
		&"dmg_up": dmg_up_icon,
	}
	_status_info = {
		&"defend": {"name": defend_name, "desc": defend_desc},
		&"taunt": {"name": taunt_name, "desc": taunt_desc},
		&"dmg_up": {"name": dmg_up_name, "desc": dmg_up_desc},
	}
	_build_status_hover()
	
# --- Status icons ---
func status_register(unit: Control) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", -25)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	unit.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_top = -4
	_status_units[unit] = { "bar": bar, "active": {} }

func status_has(unit: Control, id: StringName) -> bool:
	return _status_units.has(unit) and _status_units[unit]["active"].has(id)

func status_add(unit: Control, id: StringName, expire: int = Expire.OWN_TURN, turns := 1) -> void:
	if not _status_units.has(unit) or not _status_icons.has(id):
		return
	var active: Dictionary = _status_units[unit]["active"]
	if active.has(id):
		active[id]["expire"] = expire
		active[id]["remaining"] = turns
		_status_pulse(active[id]["icon"])
		return
	var icon := TextureRect.new()
	icon.texture = _status_icons[id]
	icon.custom_minimum_size = STATUS_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.pivot_offset = STATUS_ICON_SIZE / 2.0
	_status_units[unit]["bar"].add_child(icon)
	active[id] = { "icon": icon, "expire": expire, "remaining": turns }
	icon.scale = Vector2.ZERO
	create_tween().tween_property(icon, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func status_remove(unit: Control, id: StringName) -> void:
	if not status_has(unit, id):
		return
	var icon: TextureRect = _status_units[unit]["active"][id]["icon"]
	_status_units[unit]["active"].erase(id)
	var t := create_tween().set_parallel(true)
	t.tween_property(icon, "modulate:a", 0.0, 0.2)
	t.tween_property(icon, "scale", Vector2.ZERO, 0.2)
	t.chain().tween_callback(icon.queue_free)

func status_turn_start(unit: Control) -> void:
	if not _status_units.has(unit):
		return
	var active: Dictionary = _status_units[unit]["active"]
	for id in active.keys():
		var e: int = active[id]["expire"]
		if e & Expire.OWN_TURN:
			status_remove(unit, id)
		elif e & Expire.TURNS:
			active[id]["remaining"] -= 1
			if active[id]["remaining"] <= 0:
				status_remove(unit, id)

func status_hit(unit: Control) -> void:
	if not _status_units.has(unit):
		return
	for id in _status_units[unit]["active"].keys():
		var e: int = _status_units[unit]["active"][id]["expire"]
		if e & Expire.HIT:
			status_remove(unit, id)

func status_turn_end(unit: Control) -> void:
	if not _status_units.has(unit):
		return
	for id in _status_units[unit]["active"].keys():
		if _status_units[unit]["active"][id]["expire"] & Expire.TURN_END:
			status_remove(unit, id)

func _status_pulse(icon: TextureRect) -> void:
	var t := create_tween()
	t.tween_property(icon, "scale", Vector2(1.3, 1.3), 0.08)
	t.tween_property(icon, "scale", Vector2.ONE, 0.12)

# Give the same effect to any list of nodes
func status_add_many(units: Array, id: StringName, expire: int = Expire.OWN_TURN, turns := 1) -> void:
	for u in units:
		status_add(u, id, expire, turns)

# Give it to every party member except the one at user_index
func status_add_to_others(user_index: int, id: StringName, expire: int = Expire.OWN_TURN, turns := 1) -> void:
	for idx in party_nodes.size():
		if idx == user_index:
			continue
		if _party_hp.get(idx, 1) <= 0:   # skip dead allies
			continue
		status_add(party_nodes[idx], id, expire, turns)

func status_clear(unit: Control) -> void:
	if not _status_units.has(unit):
		return
	for id in _status_units[unit]["active"].keys():
		status_remove(unit, id)
		
		# --- Status hover box ----------------------------------------------------------------
func _build_status_hover():
	status_panel = PanelContainer.new()
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.z_index = 10
	var bg := StyleBoxFlat.new()
	bg.bg_color = hover_bg_color
	bg.set_content_margin_all(8)
	bg.set_corner_radius_all(4)
	status_panel.add_theme_stylebox_override("panel", bg)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	status_panel.add_child(box)

	status_name_label = Label.new()
	status_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_name_label.add_theme_font_size_override("font_size", hover_font_size + 2)
	status_name_label.add_theme_color_override("font_color", status_title_color)
	box.add_child(status_name_label)

	status_desc_label = Label.new()
	status_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_desc_label.add_theme_font_size_override("font_size", hover_font_size)
	status_desc_label.add_theme_color_override("font_color", hover_text_color)
	status_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_desc_label.custom_minimum_size = Vector2(status_hover_width, 0)
	box.add_child(status_desc_label)

	status_panel.hide()
	add_child(status_panel)

# Returns the id of the buff icon under the mouse (or &"" for none) and remembers its rect.
func _status_id_under_mouse(mouse: Vector2) -> StringName:
	for unit in _status_units:
		var active: Dictionary = _status_units[unit]["active"]
		var ids := active.keys()
		ids.reverse()                       # later icons are drawn on top
		for id in ids:
			var icon: TextureRect = active[id]["icon"]
			if is_instance_valid(icon) and icon.is_visible_in_tree() \
					and icon.get_global_rect().has_point(mouse):
				_hover_status_rect = icon.get_global_rect()
				return id
	return &""

func _refresh_status_hover():
	if _hover_status == &"" or not _status_info.has(_hover_status):
		status_panel.hide()
		return
	var info: Dictionary = _status_info[_hover_status]
	status_name_label.text = info["name"]
	status_desc_label.text = info["desc"]
	status_panel.show()
	status_panel.reset_size()

	var r := _hover_status_rect
	var pos := Vector2(r.get_center().x - status_panel.size.x / 2.0,
		r.position.y - status_panel.size.y) + status_hover_offset
	if pos.y < 0.0:                          # no room above: put it below the icon instead
		pos.y = r.end.y - status_hover_offset.y
	pos.x = clampf(pos.x, 0.0, maxf(0.0, get_viewport_rect().size.x - status_panel.size.x))
	status_panel.global_position = pos
