extends Node
## Game-wide sound effects + a master volume control. Every SFX is a short PCM waveform
## generated at startup (sine-wave blips/chords, a noise burst for the "splash") rather than an
## imported audio asset — consistent with the rest of this project's code-drawn-everything
## approach, and it means there's nothing to source/license.

const SAMPLE_RATE := 22050
const PLAYER_POOL_SIZE := 6

var master_volume: float = 0.8:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(maxf(master_volume, 0.0001)))

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	_streams["click"] = _make_tone([880.0], 0.05, 0.3)
	_streams["coin"] = _make_tone([1046.5, 1568.0], 0.1, 0.35)       ## buying something — a short rising "cha-ching"
	_streams["cash"] = _make_tone([1318.5, 1046.5], 0.1, 0.3)        ## selling a fish — a short falling chime
	_streams["splash"] = _make_noise_burst(0.3, 0.22)                ## water change
	_streams["alert"] = _make_tone([660.0, 440.0], 0.15, 0.4)        ## warnings / random events
	_streams["feed"] = _make_tone([523.0], 0.07, 0.25)               ## feeding the tank

	for i in range(PLAYER_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

	master_volume = master_volume ## re-trigger the setter to apply the initial bus volume


func play(sfx_name: String) -> void:
	if not _streams.has(sfx_name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[sfx_name]
			p.play()
			return
	_players[0].stream = _streams[sfx_name] ## pool exhausted — steal the first voice
	_players[0].play()


## `freqs` plays as a short sequence of equal-length notes (one entry = a single tone, two+ =
## a tiny melodic blip) — simplest way to make "buy" sound different from "sell" without needing
## a real synth.
func _make_tone(freqs: Array, note_duration: float, volume: float) -> AudioStreamWAV:
	var sample_count: int = int(SAMPLE_RATE * note_duration * freqs.size())
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t: float = float(i) / SAMPLE_RATE
		var note_index: int = mini(int(t / note_duration), freqs.size() - 1)
		var local_t: float = t - note_index * note_duration
		var freq: float = freqs[note_index]
		var envelope: float = clampf(1.0 - local_t / note_duration, 0.0, 1.0)
		envelope *= envelope ## smoother decay than a linear ramp
		var sample: float = sin(TAU * freq * local_t) * envelope * volume
		data.encode_s16(i * 2, clampi(int(sample * 32767.0), -32768, 32767))
	return _wrap_wav(data)


func _make_noise_burst(duration: float, volume: float) -> AudioStreamWAV:
	var sample_count: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t: float = float(i) / SAMPLE_RATE
		var envelope: float = clampf(1.0 - t / duration, 0.0, 1.0)
		var sample: float = (randf() * 2.0 - 1.0) * envelope * volume
		data.encode_s16(i * 2, clampi(int(sample * 32767.0), -32768, 32767))
	return _wrap_wav(data)


func _wrap_wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
