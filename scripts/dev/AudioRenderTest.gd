extends Node
## Dev-only: the shipped music and ambience loops (assets/audio) load, loop and start playing once
## the player turns the music up, and the game itself synthesises nothing at runtime.
## Run the scene scenes/dev/AudioRenderTest.tscn.

func _ready() -> void:
	var failures := 0
	print("music on by default: ", AudioManager.music_volume > 0.0)
	if AudioManager.music_volume > 0.0:
		failures += 1
	for path in [AudioManager.AMBIENCE_PATH, AudioManager.MUSIC_PATH]:
		var stream: AudioStream = load(path)
		var ok: bool = stream != null and stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.get_length() > 5.0
		print("%s: %s" % [path, "OK" if ok else "BAD"])
		if not ok:
			failures += 1
	AudioManager.music_volume = 0.5
	for i in range(30):
		await get_tree().process_frame
	var playing: bool = AudioManager._music_player.playing and AudioManager._ambience_player.playing
	print("loops playing after turning the music up: ", playing)
	if not playing:
		failures += 1
	print("=== Audio trace finished: %s ===" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit()
