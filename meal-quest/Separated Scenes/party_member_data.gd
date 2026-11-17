class_name PartyMemberData
extends Resource
## One party member's stats, art and moves.

@export var name := ""
@export var scene_node := ""         # node name under Battle: "Hero", "Ally1", "Ally2"
@export var max_hp := 30
@export var damage := 5
@export var use_global_state := false   # true = hp / max_hp / damage come from the State autoload (Tomato)
@export var damaged_tex: Texture2D      # sprite shown below half HP
@export var death_frames: Array[Texture2D] = []   # optional death animation; the last frame is held, then it fades
@export var moves: Array[MoveData] = []
@export var fusion_max := 30   # damage this member must deal to fill their Fusion bar
@export var death_sfx: AudioStream      # this member's own knock-out sound (blank = the generic one)
