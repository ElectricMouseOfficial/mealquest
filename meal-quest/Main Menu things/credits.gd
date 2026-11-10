extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var s := get_viewport_rect().size
	_place($TopSparkles,    Vector2(s.x / 2, 20),     Vector3(s.x / 2, 4, 1))
	_place($BottomSparkles, Vector2(s.x / 2, s.y - 20),   Vector3(s.x / 2, 4, 1))
	_place($LeftSparkles,   Vector2(20, s.y / 2),     Vector3(4, s.y / 2, 1))
	_place($RightSparkles,  Vector2(s.x - 20, s.y / 2),   Vector3(4, s.y / 2, 1))

func _place(p: GPUParticles2D, pos: Vector2, extents: Vector3) -> void:
	p.position = pos
	p.process_material = p.process_material.duplicate()  # don't share one material
	p.process_material.emission_box_extents = extents


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Main Menu things/main_menu.tscn")
