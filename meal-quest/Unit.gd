extends Node

class_name Unit
## Base class for anything that can take a turn: players, enemies, allies.
 
signal health_changed(current: int, max: int)
signal defeated
 
@export var unit_name: String = "Unit"
@export var team: String = "player"          # e.g. "player" or "enemy"
@export var max_health: int = 100
@export var attack_power: int = 10
@export var speed: int = 5
@export var is_ai_controlled: bool = false
 
var current_health: int
 
 
func _ready() -> void:
	current_health = max_health
 
 
func is_defeated() -> bool:
	return current_health <= 0
 
 
func take_damage(amount: int) -> void:
	current_health = max(current_health - amount, 0)
	emit_signal("health_changed", current_health, max_health)
	if is_defeated():
		emit_signal("defeated")
 
 
func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
	emit_signal("health_changed", current_health, max_health)
 
 
func attack(target: Unit) -> void:
	target.take_damage(attack_power)
 
 
## Very simple AI: attack a random living enemy, then end turn.
## Override this in a subclass for smarter behavior.
func take_ai_turn(turn_manager: TurnManager) -> void:
	var enemies: Array[Unit] = []
	for u in turn_manager.turn_order:
		if is_instance_valid(u) and u.team != team and not u.is_defeated():
			enemies.append(u)
 
	if enemies.size() > 0:
		var target: Unit = enemies[randi() % enemies.size()]
		attack(target)
 
	turn_manager.end_current_turn()
