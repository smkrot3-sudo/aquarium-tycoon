extends Node
## Dev-only: renders the ambience and music loops once with AudioManager's synthesiser and writes
## them as ordinary WAV files under res://assets/audio/. The game plays those files; it no longer
## synthesises anything while running (that was what made some phones close the game).
## Run: godot --headless --path . res://scenes/dev/AudioBake.tscn


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/audio"))
	var jobs := {
		"_render_ambience": "res://assets/audio/ambience_loop.wav",
		"_render_music": "res://assets/audio/music_loop.wav",
	}
	for which in jobs.keys():
		var data: PackedByteArray = await AudioManager.call(which)
		var stream := AudioManager._wrap_wav(data, AudioManager.LOOP_RATE, true)
		var err := stream.save_to_wav(jobs[which])
		print("%s -> %s (%d samples, %.1f s) %s" % [which, jobs[which], data.size() / 2, float(data.size() / 2) / AudioManager.LOOP_RATE, error_string(err)])
	get_tree().quit()
