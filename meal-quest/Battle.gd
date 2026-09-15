extends Control

signal textbox_closed

@export var enemy: Resource

var current_player_health = 0
var current_enemy_health = 0

func _ready():
	set_health($Hero/VBoxContainerH/ProgressBar, State.current_health, State.max_health)
	set_health($Enemy/VBoxContainerE/ProgressBar, enemy.health, enemy.health)
	$Enemy.texture = enemy.texture
	
	current_player_health = State.current_health
	current_enemy_health = enemy.health
	
	$Textbox.hide()
	$ActionsPanel.hide()

	display_text("A determined %s appears!" % enemy.name.to_upper())
	await self.textbox_closed
	$ActionsPanel.show()

func set_health(progress_bar, health, max_health):
	progress_bar.value = health
	progress_bar.max_value = max_health
	progress_bar.get_node("Label").text = "HP:%d/%d" % [health, max_health]
	

func _input(event):
	if (Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and $Textbox.visible:
		$Textbox.hide()
		emit_signal("textbox_closed")

func display_text(text):
	$Textbox.show()
	$Textbox/Label.text = text
