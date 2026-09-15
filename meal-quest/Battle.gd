extends Control

signal textbox_closed

func _ready():
	$Textbox.hide()
	$ActionsPanel.hide()

	display_text("A determined enemy appears!")
	await self.textbox_closed
	$ActionsPanel.show()

func set_health(health):
	pass

func _input(event):
	if (Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and $Textbox.visible:
		$Textbox.hide()
		emit_signal("textbox_closed")

func display_text(text):
	$Textbox.show()
	$Textbox/Label.text = text
