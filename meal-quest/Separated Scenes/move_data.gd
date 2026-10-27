class_name MoveData
extends Resource
## One move. Balancing lives here, edited in the Inspector (no code).

@export var name := ""
@export_enum("attack", "defend", "heal", "taunt", "rally") var kind := "attack"
@export var mult := 1.0              # attack: damage multiplier
@export var heal_amount := 0         # heal: HP restored
@export var rally_bonus := 1.5       # rally: party damage multiplier for the round
@export var cooldown := 0            # rounds before it can be used again (0 = none)
@export var icon: Texture2D          # button texture (optional)
@export_multiline var text := ""     # battle text when the move is used
@export_multiline var desc := ""     # tooltip text (blank = auto-generated)
