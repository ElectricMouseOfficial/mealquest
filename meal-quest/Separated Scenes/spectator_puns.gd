class_name SpectatorPuns
extends Node
## Food puns from the spectators. A random spectator speaks, and the pun matches its food:
## egg, apple, broccoli or carrot (detected from the spectator node's name).
## Three situations: the party hits the knife (dealt), the knife hits the party (taken),
## and an attack is blocked (blocked).
## Editable in the Inspector. Use {name} in a pun to insert the character's name.

# --- Egg -------------------------------------------------------------------------
@export_group("Egg puns")
@export var egg_dealt: Array[String] = [
	"You cracked it, {name}!",
	"Egg-cellent hit!",
	"That was egg-stra good!",
	"Now that's an egg-spert move!",
	"Shell yeah, {name}!",
]
@export var egg_taken: Array[String] = [
	"Oh no, {name} is cracking under pressure!",
	"I'm scrambled with worry!",
	"That's no yolk, that hurt!",
	"Don't get egg-xhausted, {name}!",
	"This is getting egg-stremely scary!",
]
@export var egg_blocked: Array[String] = [
	"Phew, no cracks, {name}!",
	"Egg-cellent block!",
	"Over easy! {name} blocked it with ease!",
	"That's one hard-boiled defense!",
	"Not even a shell-shock!",
]

# --- Apple -----------------------------------------------------------------------
@export_group("Apple puns")
@export var apple_dealt: Array[String] = [
	"How do you like them apples?!",
	"That was a-peeling, {name}!",
	"Core-rect, that's a hit!",
	"Apple-solutely brilliant, {name}!",
	"That hit was the core of the matter!",
]
@export var apple_taken: Array[String] = [
	"That's gonna bruise, {name}!",
	"Don't let it get to the core!",
	"An apple a day won't fix that!",
	"Don't go rotten on us, {name}!",
	"Apple-solutely not good!",
]
@export var apple_blocked: Array[String] = [
	"Phew! Not a bruise on {name}!",
	"Core-rect block, {name}!",
	"Apple-solutely safe!",
	"That knife couldn't get past the skin, {name}!",
	"You're the apple of my eye, {name}!",
]

# --- Broccoli --------------------------------------------------------------------
@export_group("Broccoli puns")
@export var broccoli_dealt: Array[String] = [
	"Broc and roll, {name}!",
	"Leaf it to {name} to land that hit!",
	"That was stalk-ing good!",
	"You're a real broc-star!",
	"Green with envy at that hit!",
]
@export var broccoli_taken: Array[String] = [
	"Oh no, {name} is looking a little green!",
	"That's a stalk-ing disaster!",
	"I'm feeling a bit wilted!",
	"Hang in there, {name}, stay crunchy!",
	"Don't turn to mush, {name}!",
]
@export var broccoli_blocked: Array[String] = [
	"Phew! {name} is still crunchy!",
	"Tree-mendous block!",
	"Broc-solid defense, {name}!",
	"That knife just got stalk-ed!",
	"Whew! I nearly lost my florets!",
]

# --- Carrot ----------------------------------------------------------------------
@export_group("Carrot puns")
@export var carrot_dealt: Array[String] = [
	"Orange you glad {name} hit him?",
	"I'm rooting for you, {name}!",
	"That hit was carrot-ly amazing!",
	"That was a root-ly good hit!",
	"That's how you carrot out an attack!",
]
@export var carrot_taken: Array[String] = [
	"I can't carrot believe {name} got hit!",
	"That knife is a real pain in the root!",
	"Orange you worried about {name}?",
	"This is getting dicey for {name}!",
	"Stay strong, {name}, don't get peeled!",
]
@export var carrot_blocked: Array[String] = [
	"Phew! Carrot-ly close call!",
	"That knife couldn't peel {name}!",
	"Orange you glad {name} blocked that?",
	"Root-ly impressive block!",
	"No chopping today, {name}!",
]

# --- Generic (used when a spectator's food isn't recognized) -------------------------
@export_group("Generic puns")
@export var dealt_puns: Array[String] = [
	"Lettuce celebrate, that was a-peeling!",
	"You're on a roll!",
	"Beet him up!",
	"That was gouda!",
	"Kale yeah, {name}!",
	"Turnip the heat!",
	"You really cut the mustard!",
]
@export var taken_puns: Array[String] = [
	"Oh no, {name} is in a real pickle!",
	"Don't go bad on us, {name}!",
	"Gourd help us!",
	"Who's cutting onions in here?!",
	"Don't lose your thyme, {name}!",
	"{name} is toast!",
]
@export var blocked_puns: Array[String] = [
	"Phew! Close call, {name}!",
	"That knife couldn't cut it!",
	"Nice block, {name}! Berry good defense!",
	"Gouda block, {name}!",
	"Lettuce celebrate that block!",
	"The knife didn't even make a dent!",
]

# --- Settings --------------------------------------------------------------------
@export_group("Settings")
@export_range(0.0, 1.0) var pun_chance := 1.0    # 1.0 = every time, 0.5 = about half the time
@export var show_time := 1.6                     # seconds the bubble stays
@export var fade_time := 0.3
@export var font: Font                           # blank = project default
@export var font_size := 16
@export var text_color := Color.BLACK
@export var bubble_color := Color.WHITE
@export var border_color := Color.BLACK
@export var bubble_offset := Vector2(0, -6)      # nudge the bubble (+x right, +y down)
@export var fallback_position := Vector2(500, 170)   # used if no spectator nodes are found
@export var debug_log := false                   # prints what the puns are doing to the Output panel
@export var ignore_names: Array[String] = ["Group"]  # spectator nodes whose name contains any of these are skipped

@export_group("Win and lose")
@export var victory_cheers: Array[String] = ["HOORAY!", "WE DID IT!", "KALE YEAH!", "YEAH!!", "WE WON!"]   # one is picked, and EVERY spectator shouts it
@export var victory_jumps := 3                   # how many times everyone jumps
@export var victory_jump_height := 40.0          # pixels
@export var victory_jump_time := 0.18            # seconds going up (same coming down)
@export var victory_bubble_time := 2.0           # seconds the cheers stay
@export var defeat_cries: Array[String] = ["WAAAH!", "*sob*", "Boo hoo...", "Why?!", "Sniff..."]   # each spectator cries its own
@export var defeat_time := 3.0                   # how long the crying lasts
@export var defeat_shiver := 3.0                 # pixels the crying spectators tremble
@export var defeat_tint := Color(0.7, 0.8, 1.0)  # sad blue tint
@export var defeat_bubble_time := 2.5

# Words in a spectator's node name that identify its food (handles the "Brocolli" spelling)
const FOOD_KEYWORDS := {
	"egg": ["egg"],
	"apple": ["apple"],
	"broccoli": ["broccoli", "brocolli", "brocoli"],
	"carrot": ["carrot"],
}

var spectators: Node
var overlay: Control
var bubble: Control
var last_pun := ""
var _rest := {}     # spectator node -> its resting position (so jumps always return home)


func setup(spectators_node: Node, overlay_parent: Control):
	spectators = spectators_node
	overlay = overlay_parent
	_rest.clear()
	for c in _group_children(true):
		_rest[c] = c.position
	if debug_log:
		print("[Puns] ready. Spectators node: ", spectators, " overlay: ", overlay)


func say_dealt(who: String = ""):
	_say("dealt", who)

func say_taken(who: String = ""):
	_say("taken", who)

func say_blocked(who: String = ""):
	_say("blocked", who)


func _say(kind: String, who: String):
	if overlay == null or randf() > pun_chance:
		return
	var spot := _pick_spot()
	var list := _list_for(spot.food, kind)
	if list.is_empty():
		return
	var text := _pick(list).replace("{name}", who if who != "" else "someone")
	if debug_log:
		print("[Puns] ", kind, " | food: '", spot.food, "' | at ", spot.pos, " | ", text)
	_show_bubble(text, spot.pos)


# The pun list for this food and situation, or the generic list as a fallback
func _list_for(food: String, kind: String) -> Array[String]:
	if food != "":
		var specific = get("%s_%s" % [food, kind])
		if specific is Array and not specific.is_empty():
			return specific
	match kind:
		"dealt":
			return dealt_puns
		"taken":
			return taken_puns
	return blocked_puns


func _pick(list: Array[String]) -> String:
	var choice: String = list.pick_random()
	var tries := 0
	while list.size() > 1 and choice == last_pun and tries < 5:
		choice = list.pick_random()
		tries += 1
	last_pun = choice
	return choice


func _food_of(node: Node) -> String:
	var n := String(node.name).to_lower()
	for food in FOOD_KEYWORDS:
		for word in FOOD_KEYWORDS[food]:
			if n.contains(word):
				return food
	return ""


# Top-center point of a spectator (Vector2.INF if it is not a drawable node)
func _head_pos(c) -> Vector2:
	if c is Control and c.visible:
		var r: Rect2 = c.get_global_rect()
		return Vector2(r.get_center().x, r.position.y)
	if c is Sprite2D and c.visible and c.texture:
		var sr: Rect2 = c.get_rect()
		return c.get_global_transform() * Vector2(sr.get_center().x, sr.position.y)
	if c is Node2D and c.visible:
		return c.global_position + Vector2(0, -30)
	return Vector2.INF


# All visible spectators. Ignored nodes (like the group image) are left out unless
# include_ignored is true: they get no speech bubbles but they still jump and tremble.
# (Dj: This bc Im lazy an dont wanna make that group talk bc the bubble messes up)
func _group_children(include_ignored: bool = false) -> Array:
	var out: Array = []
	if spectators == null:
		return out
	var kids: Array = spectators.get_children()
	if kids.is_empty():
		kids = [spectators]
	for c in kids:
		if not include_ignored and _is_ignored(c):
			continue
		if (c is Node2D or c is Control) and c.visible:
			out.append(c)
	return out


# A random spectator: where its head is, and what food it is
func _pick_spot() -> Dictionary:
	var spots: Array[Dictionary] = []
	for c in _group_children():
		var pos := _head_pos(c)
		if pos != Vector2.INF:
			spots.append({"pos": pos, "food": _food_of(c)})
	if spots.is_empty():
		return {"pos": fallback_position, "food": ""}
	return spots.pick_random()


func _is_ignored(node: Node) -> bool:
	for part in ignore_names:
		if String(node.name).contains(part):
			return true
	return false


# --- Win ----------------------
func play_victory():
	var kids := _group_children(true)
	if kids.is_empty():
		return
	_clear_bubble()

	var cheer: String = "HOORAY!"
	if not victory_cheers.is_empty():
		cheer = victory_cheers.pick_random()

	for c in kids:
		var head := _head_pos(c)
		if head != Vector2.INF and not _is_ignored(c):
			_spawn_bubble(cheer, head - Vector2(0, victory_jump_height), victory_bubble_time)

		# Every spectator starts on the same frame, so they jump in unison
		var rest_y: float = _rest.get(c, c.position).y
		var hop := create_tween()
		for n in victory_jumps:
			hop.tween_property(c, "position:y", rest_y - victory_jump_height, victory_jump_time) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			hop.tween_property(c, "position:y", rest_y, victory_jump_time) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await get_tree().create_timer(victory_jumps * victory_jump_time * 2.0 + 0.4).timeout


# --- Lose ---------------------------------------------------------
func play_defeat():
	var kids := _group_children(true)
	if kids.is_empty():
		return
	_clear_bubble()

	var shakes := maxi(1, int(defeat_time / 0.2))
	for c in kids:
		if not defeat_cries.is_empty() and not _is_ignored(c):
			var head := _head_pos(c)
			if head != Vector2.INF:
				_spawn_bubble(defeat_cries.pick_random(), head, defeat_bubble_time)

		# Tremble in place, then settle back
		var rest_x: float = _rest.get(c, c.position).x
		var shiver := create_tween().set_loops(shakes)
		shiver.tween_property(c, "position:x", rest_x - defeat_shiver, 0.05)
		shiver.tween_property(c, "position:x", rest_x + defeat_shiver, 0.1)
		shiver.tween_property(c, "position:x", rest_x, 0.05)

		# Turn a little blue
		create_tween().tween_property(c, "modulate", defeat_tint, 0.6)

	await get_tree().create_timer(defeat_time).timeout


# --- Speech Bubbles -----------------------------------------------------------------------
func _clear_bubble():
	if is_instance_valid(bubble):
		bubble.queue_free()
	bubble = null


# One bubble at a time for the puns (a new one replaces the old one)
func _show_bubble(text: String, spot: Vector2):
	_clear_bubble()
	bubble = _spawn_bubble(text, spot, show_time)


# Creates a bubble above `spot` that pops in, holds, fades and frees itself
func _spawn_bubble(text: String, spot: Vector2, hold: float) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bubble_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 10

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", text_color)
	if font:
		label.add_theme_font_override("font", font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	overlay.add_child(panel)

	# Centered above the spot, kept on screen
	var bsize := panel.get_combined_minimum_size()
	var pos := spot + bubble_offset - Vector2(bsize.x / 2.0, bsize.y)
	var vp := overlay.get_viewport_rect().size
	pos.x = clampf(pos.x, 4.0, maxf(4.0, vp.x - bsize.x - 4.0))
	pos.y = maxf(pos.y, 4.0)
	panel.global_position = pos

	# Pop in, hold, fade out
	panel.pivot_offset = bsize / 2.0
	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.1)
	tw.chain().tween_interval(hold)
	tw.chain().tween_property(panel, "modulate:a", 0.0, fade_time)
	tw.chain().tween_callback(panel.queue_free)
	return panel
