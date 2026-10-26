class_name PartyMemberData
extends Resource
## One party member's stats, art and moves.

@export var name := ""
@export var scene_node := ""         # node name under Battle: "Hero", "Ally1", "Ally2"
@export var max_hp := 30
@export var damage := 5
@export var use_global_state := false   # true = hp / max_hp / damage come from the State autoload (Tomato)
@export var damaged_tex: Texture2D      # sprite shown below half HP
@export var moves: Array[MoveData] = []
