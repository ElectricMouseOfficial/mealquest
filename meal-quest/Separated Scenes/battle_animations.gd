class_name BattleAnimations
extends Node
## Everything that moves: tomato roll, knife slash, shakes, death fades.
## Each function is awaitable, so the battle script just does `await anim.play_x()`.

# --- Tomato roll -> splat -> return ------------------------------------------
@export var tomato_frames: Array[Texture2D]   # in order: 9 roll + 1 splat
@export var roll_count := 9                   # first 9 = roll, the rest = splat
@export var roll_time := 0.6                  # seconds to roll to the enemy
@export var frame_time := 0.08                # seconds per splat frame
@export var splat_hold := 0.5                 # extra seconds the splat stays on screen
@export var return_time := 0.4                # seconds to slide back
@export_range(0.0, 1.0) var impact_x_ratio := 0.3   # where it lands on the enemy (0 = left edge, 0.5 = center)

# --- Knife slash ---------------------------------------------------------------
@export var knife_frames: Array[Texture2D]
@export var knife_frame_time := 0.06
@export var knife_scale := 0.5

# --- Death ---------------------------------------------------------------------
@export var death_frame_time := 0.1    # seconds per death frame
@export var death_hold := 0.6          # seconds the last frame (the puddle) stays before fading
@export var death_fade_time := 0.5

const BAR_BOX := "VBoxContainerH"   # health bar container under each party sprite

var player: AnimationPlayer
var enemy_sprite: TextureRect
var knife_vfx: TextureRect


func setup(anim_player: AnimationPlayer, enemy: TextureRect, overlay_parent: Control):
	player = anim_player
	enemy_sprite = enemy
	knife_vfx = TextureRect.new()
	knife_vfx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	knife_vfx.stretch_mode = TextureRect.STRETCH_SCALE
	knife_vfx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knife_vfx.z_index = 2
	knife_vfx.hide()
	overlay_parent.add_child(knife_vfx)


# --- AnimationPlayer wrappers ------------------------------------------------
func play_enemy_hit():
	player.play("enemy_damaged")
	await player.animation_finished

func play_enemy_death():
	player.play("enemy_died")
	await player.animation_finished

func play_shake():
	player.play("shake")
	await player.animation_finished

func play_mini_shake():
	player.play("mini_shake")
	await player.animation_finished


# --- Tomato attack ---------------------------------------------------------------
# on_impact is called the moment the tomato lands (apply damage there).
func play_tomato_attack(hero: TextureRect, on_impact: Callable):
	if tomato_frames.is_empty():
		on_impact.call()
		await play_enemy_hit()
		return

	var bar_box: Control = hero.get_node(BAR_BOX)   # child of the hero, so hide it while moving
	var start_pos := hero.global_position
	var original_texture := hero.texture
	var roll := tomato_frames.slice(0, roll_count)
	var splat := tomato_frames.slice(roll_count)

	var enemy_rect := enemy_sprite.get_global_rect()
	var target_center := Vector2(
		enemy_rect.position.x + enemy_rect.size.x * impact_x_ratio,
		enemy_rect.get_center().y)
	var target_pos := target_center - hero.size / 2.0

	hero.z_index = 1
	bar_box.hide()

	# Roll: each roll frame shows once, spread across the trip
	var tween := create_tween()
	tween.tween_property(hero, "global_position", target_pos, roll_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var step := roll_time / roll.size()
	for f in roll:
		hero.texture = f
		await get_tree().create_timer(step).timeout
	if tween.is_running():
		await tween.finished

	# Splat on impact
	on_impact.call()
	player.play("enemy_damaged")
	for f in splat:
		hero.texture = f
		await get_tree().create_timer(frame_time).timeout
	await get_tree().create_timer(splat_hold).timeout
	if player.is_playing():
		await player.animation_finished

	# Return
	hero.texture = original_texture
	var back := create_tween()
	back.tween_property(hero, "global_position", start_pos, return_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished

	hero.z_index = 0
	bar_box.show()


# --- Knife attack (enemy) ------------------------------------------------------
func play_knife_attack(target: Control):
	if knife_frames.is_empty():
		return

	enemy_sprite.self_modulate.a = 0.0   # hide the enemy sprite, keep its health bar

	var center := target.get_global_rect().get_center()
	knife_vfx.show()
	for f in knife_frames:
		knife_vfx.texture = f
		knife_vfx.size = f.get_size() * knife_scale
		knife_vfx.global_position = center - knife_vfx.size / 2.0
		await get_tree().create_timer(knife_frame_time).timeout
	knife_vfx.hide()

	enemy_sprite.self_modulate.a = 1.0


# --- Party member death ----------------------------------------------------------
# frames is optional: with frames it plays them, holds the last one, then fades.
# With no frames it just fades.
func play_party_death(node: TextureRect, frames: Array[Texture2D] = []):
	var bar_box: Control = node.get_node(BAR_BOX)

	if not frames.is_empty():
		for f in frames:
			node.texture = f
			await get_tree().create_timer(death_frame_time).timeout
		await get_tree().create_timer(death_hold).timeout

	var tween := create_tween().set_parallel(true)
	tween.tween_property(node, "self_modulate:a", 0.0, death_fade_time)
	tween.tween_property(bar_box, "modulate:a", 0.0, death_fade_time)
	await tween.finished
	bar_box.hide()
