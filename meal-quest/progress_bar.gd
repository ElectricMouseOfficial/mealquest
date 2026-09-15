extends ProgressBar

#(Code to update health bar value; needs to attach to character scripts
#@export var player: Player

#func _ready:
#	player.healthChanged.connect(update)
#	update()

#func update():
#	value = player.currenthealth * 100 / player.maxHealth


#(Code to change the health bar color when at certain thresholds
var fill_stylebox: StyleBoxFlat
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var original_stylebox = get_theme_stylebox("fill")
	if original_stylebox is StyleBoxFlat:
		fill_stylebox = original_stylebox.duplicate()
		add_theme_stylebox_override("fill", fill_stylebox)
	value_changed.connect(_on_value_changed)
	_on_value_changed(value)

func _on_value_changed(new_value: float) -> void:
	if not fill_stylebox:
		return
	var ratio = (new_value - min_value) / (max_value - min_value)
	if ratio <= 0.25:
		fill_stylebox.bg_color = Color.RED
	elif ratio <= 0.5:
		fill_stylebox.bg_color = Color.YELLOW
	else:
		fill_stylebox.bg_color = Color.GREEN
#)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
