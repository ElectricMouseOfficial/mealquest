class_name BattleAudio
extends Node
## Music and sound effects for the battle. Drag audio files onto the slots in the Inspector.

@export_group("Music")
@export var music: AudioStream                              # drag your background music here
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var music_volume_db := -6.0
@export var music_fade_in := 1.0                            # seconds (0 = start at full volume)
@export var music_loop_start := 0.0                         # seconds into the track where the loop begins (0 = loop the whole track)

@export_group("Sound effects")
@export var damage_sfx: AudioStream                         # played whenever anyone takes damage
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var damage_volume_db := 0.0
@export_range(0.0, 0.5, 0.01) var damage_pitch_variation := 0.08   # random pitch so repeats don't sound identical
@export var heal_sfx: AudioStream                           # played whenever healing lands
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var heal_volume_db := 0.0

var _music_player: AudioStreamPlayer


func _ready():
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)
	_music_player.finished.connect(_restart_music)


func play_music():
	if music == null:
		return
	_music_player.stream = music
	if music_fade_in > 0.0:
		_music_player.volume_db = -60.0
		_music_player.play()
		create_tween().tween_property(_music_player, "volume_db", music_volume_db, music_fade_in)
	else:
		_music_player.volume_db = music_volume_db
		_music_player.play()

# Called when the track ends: jump back to the loop point instead of the very start.
func _restart_music():
	var start := music_loop_start
	if music == null or start >= music.get_length():
		start = 0.0                  # a loop point past the end of the track would never play
	_music_player.play(start)
	 
func stop_music(fade_out := 1.0):
	if not _music_player.playing:
		return
	if fade_out > 0.0:
		var t := create_tween()
		t.tween_property(_music_player, "volume_db", -60.0, fade_out)
		await t.finished
	_music_player.stop()

func play_damage():
	_play_sfx(damage_sfx, damage_volume_db, damage_pitch_variation)

func play_heal():
	_play_sfx(heal_sfx, heal_volume_db)

# Each sound gets its own player, so quick repeats overlap instead of cutting each other off.
func _play_sfx(stream: AudioStream, volume_db: float, pitch_variation := 0.0):
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
