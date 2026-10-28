extends Control

func trigger_damage_reaction():
	var jump_waves = randi_range(2, 3)
	
	for wave in range(jump_waves):
		if wave > 0:
			await get_tree().create_timer(randf_range(0.2, 0.4)).timeout
		
		for child in get_children():
			if child is Sprite2D:
				if randf() > 0.75:
					continue
				
				if child.has_meta("is_jumping") and child.get_meta("is_jumping"):
					continue
				
				child.set_meta("is_jumping", true)
				
				var jump_height = randf_range(15.0, 45.0)
				var duration = randf_range(0.3, 0.5)
				var original_y = child.position.y
				
				var tween = create_tween()
				tween.tween_property(child, "position:y", original_y - jump_height, duration * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
				tween.tween_property(child, "position:y", original_y, duration * 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
				
				tween.finished.connect(func(): child.set_meta("is_jumping", false))
