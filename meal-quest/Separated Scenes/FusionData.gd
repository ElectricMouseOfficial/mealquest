class_name FusionData
extends MoveData
## A fusion attack. Which allies it needs is set in `partners`.

@export_group("Fusion")
@export var partners: Array[PartyMemberData] = []   # drag the party member files here (2 or 3)
@export_enum("damage", "party_shield", "heal_buff") var fusion_effect := "damage"

@export_group("Damage over time")
@export var dot_damage := 0          # damage per tick (0 = no DOT)
@export var dot_turns := 0           # how many enemy turns it lasts
@export var dot_name := "burn"       # shown in battle text

@export_group("Party buff")
@export var buff_rounds := 1         # how many rounds the damage buff lasts
