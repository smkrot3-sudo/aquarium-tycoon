extends SceneTree
## Dev-only: times the ambience/music renderers and checks they produce sensible, non-silent,
## non-clipping audio. Run with: godot --headless -s res://scripts/dev/AudioRenderTest.gd

func _initialize() -> void:
	var audio := root.get_node("AudioManager")
	for which in ["_render_ambience", "_render_music"]:
		var t0 := Time.get_ticks_msec()
		var data: PackedByteArray = audio.call(which)
		var ms := Time.get_ticks_msec() - t0
		var peak := 0
		var energy := 0.0
		var count := data.size() / 2
		for i in range(count):
			var v := absi(data.decode_s16(i * 2))
			peak = maxi(peak, v)
			energy += float(v) * float(v)
		var rms := sqrt(energy / maxf(1.0, float(count)))
		print("%s: %d samples (%.1f s) in %d ms | peak %d | rms %.0f | %s" % [which, count, float(count) / audio.LOOP_RATE, ms, peak, rms, "OK" if peak > 4000 and peak < 32000 and rms > 800.0 else "SUSPICIOUS"])
	quit()
