@tool
extends EditorScript
## Open this file in the Script editor, then File > Run (Ctrl+Shift+X).
## Creates the MoveData / PartyMemberData .tres files in a "data" folder next to this script,
## and links every party member to the move FILES (not embedded copies).
## Safe to run again: existing files keep your edits (icons, cooldowns, damaged textures).

var DIR := ""


func _run():
	DIR = get_script().resource_path.get_base_dir() + "/data/"
	DirAccess.make_dir_recursive_absolute(DIR + "moves")
	DirAccess.make_dir_recursive_absolute(DIR + "party")

	var tomato_moves: Array[MoveData] = [
		_move("roll", "Roll", "attack", {"text": "You roll your juicy body!"}),
		_move("defend", "Defend", "defend", {"text": "Your fine stem hairs tense!"}),
	]
	_member("tomato", "Tomato", "Hero", 30, 5, true, tomato_moves)

	var steak_moves: Array[MoveData] = [
		_move("meat_mash", "Meat Mash", "attack", {"text": "Ever been slapped by a steak? Well the enemy has!"}),
		_move("taunt", "Taunt", "taunt", {"text": "The steak shows off its tantilizing marble!"}),
		_move("harden", "Harden", "defend", {"text": "Steak tenses its muscle fibers for an attack!"}),
	]
	_member("steak", "Steak", "Ally1", 40, 6, false, steak_moves)

	var soup_moves: Array[MoveData] = [
		_move("broil", "Broil", "attack", {"text": "A scalding liquid burns the enemies! I wouldn't want to be them!"}),
		_move("hearty_broth", "Hearty Broth", "heal", {"heal_amount": 15, "text": "A hearty broth heals your party! You bet I'm hungry now!"}),
		_move("dinner_call", "Dinner Call", "rally", {"rally_bonus": 1.5, "text": "A nice meal makes your party feel fired up!"}),
	]
	_member("soup", "Soup", "Ally2", 25, 4, false, soup_moves)

	EditorInterface.get_resource_filesystem().scan()
	print("Done. Party members now link to the files in ", DIR, "moves/")


func _move(file: String, move_name: String, kind: String, props: Dictionary = {}) -> MoveData:
	var path := DIR + "moves/%s.tres" % file
	if not ResourceLoader.exists(path):
		var m := MoveData.new()
		m.name = move_name
		m.kind = kind
		for k in props:
			m.set(k, props[k])
		ResourceSaver.save(m, path)
	# Always return the version loaded from disk, so other resources link to the FILE
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as MoveData


func _member(file: String, member_name: String, node: String, max_hp: int, damage: int,
		use_state: bool, moves: Array[MoveData]):
	var path := DIR + "party/%s.tres" % file
	var p: PartyMemberData
	if ResourceLoader.exists(path):
		p = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PartyMemberData
	else:
		p = PartyMemberData.new()
		p.name = member_name
		p.scene_node = node
		p.max_hp = max_hp
		p.damage = damage
		p.use_global_state = use_state
	p.moves = moves   # re-link to the move files; other fields (damaged_tex, etc.) are kept
	ResourceSaver.save(p, path)
