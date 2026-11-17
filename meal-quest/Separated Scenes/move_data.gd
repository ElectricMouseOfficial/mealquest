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

@export_group("Effect (VFX)")
@export var vfx_frames: Array[Texture2D] = []   # effect that plays over the character this move affects
@export_enum("default", "self", "all_allies", "enemy", "screen") var vfx_target := "default"   # default: heal = the healed ally, rally = every ally, others = the user. screen = one full-screen cutscene
@export var vfx_fade_time := 0.15               # screen only: fade in/out seconds (0 = hard cut)
@export var vfx_frame_time := 0.06              # seconds per frame
@export var vfx_scale := 1.0                    # 1.0 = original image size
@export var vfx_offset := Vector2.ZERO          # nudge the effect (+x right, +y down)
@export_group("Debuff")
@export_range(0.0, 0.9, 0.05) var enemy_attack_down := 0.0   # attack: lowers the enemy's NEXT attack by this fraction (0.3 = 30% less)
@export_group("Attack animation")
@export_enum("default", "vfx_only") var attack_anim := "default"   # default = the character's usual attack animation; vfx_only = just play this move's Effect (VFX) frames
