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
@export var slice_sfx: AudioStream                          # the Knife starts its attack
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var slice_volume_db := 0.0
@export var hit_sfx: AudioStream                            # a food hits the Knife (blank = uses Damage Sfx)
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var hit_volume_db := 0.0
@export var death_sfx: AudioStream                          # generic knock-out sound (a member's own sound wins)
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var death_volume_db := 0.0

@export_group("Crowd")
@export var cheer_sfx: AudioStream                          # the food lands a hit / wins
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var cheer_volume_db := -6.0
@export var jeer_sfx: AudioStream                           # the food gets hit / loses
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var jeer_volume_db := -6.0
@export_range(0.0, 1.0, 0.05) var crowd_react_chance := 0.4   # chance the crowd reacts to a normal hit (win/lose always react)

var _music_player: AudioStreamPlayer


func _ready():
	print("BattleAudio ready at ", get_path(), " has_music=", music != null)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)
	_music_player.finished.connect(_restart_music)


func play_music():
	print("play_music called on ", get_path(), " has_music=", music != null)
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
	
func play_slice():
	_play_sfx(slice_sfx, slice_volume_db, 0.05)

func play_hit():
	if hit_sfx != null:
		_play_sfx(hit_sfx, hit_volume_db, damage_pitch_variation)
	else:
		play_damage()          # no hit sound assigned: fall back to the generic one

func play_death(member_sfx: AudioStream = null):
	_play_sfx(member_sfx if member_sfx != null else death_sfx, death_volume_db)

func play_cheer(always := false):
	if always or randf() < crowd_react_chance:
		_play_sfx(cheer_sfx, cheer_volume_db)

func play_jeer(always := false):
	if always or randf() < crowd_react_chance:
		_play_sfx(jeer_sfx, jeer_volume_db)

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
