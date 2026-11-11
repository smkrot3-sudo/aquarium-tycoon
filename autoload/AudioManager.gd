extends Node
## Game-wide sound: short effects, an underwater ambience and a slow ambient music loop, with
## separate Music and Effects volumes on top of the master one. Everything is generated in code
## (sine blips for the effects; filtered noise and soft chord pads for the ambience and music)
## rather than imported — consistent with the project's code-drawn-everything approach, and
## there is nothing to source or license. The long loops are rendered on a worker thread right
## after start-up so the game never stalls waiting for them.
##
## At night the music is muffled with a low-pass filter and turned down a little, so the tank
## "goes to sleep" with the in-game clock.

const SAMPLE_RATE := 22050
const LOOP_RATE := 11025
const PLAYER_POOL_SIZE := 6
const SINE_TABLE_SIZE := 4096

var master_volume: float = 0.8:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		_apply_bus_volume("Master", master_volume)
var music_volume: float = 0.6:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_apply_bus_volume("Music", music_volume)
var sfx_volume: float = 0.9:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		_apply_bus_volume("SFX", sfx_volume)

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _music_filter: AudioEffectLowPassFilter
var _thread: Thread
var _cancel: bool = false
var _filter_timer: float = 0.0


func _ready() -> void:
	_setup_buses()
	_streams["click"] = _make_tone([880.0], 0.05, 0.3)
	_streams["coin"] = _make_tone([1046.5, 1568.0], 0.1, 0.35)       ## buying something — a short rising "cha-ching"
	_streams["cash"] = _make_tone([1318.5, 1046.5], 0.1, 0.3)        ## selling a fish — a short falling chime
	_streams["splash"] = _make_noise_burst(0.3, 0.22)                ## water change
	_streams["alert"] = _make_tone([660.0, 440.0], 0.15, 0.4)        ## warnings / random events
	_streams["feed"] = _make_tone([523.0], 0.07, 0.25)               ## feeding the tank
	_streams["fanfare"] = _make_tone([523.25, 659.25, 783.99, 1046.5], 0.11, 0.35)  ## goal reached, order filled
	_streams["scrub"] = _make_noise_burst(0.06, 0.12)                ## scraper / vacuum stroke

	for i in range(PLAYER_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.volume_db = -3.0
	add_child(_music_player)
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = "Music"
	_ambience_player.volume_db = -11.0
	add_child(_ambience_player)

	master_volume = master_volume  ## re-trigger the setters to apply the initial bus volumes
	music_volume = music_volume
	sfx_volume = sfx_volume

	_thread = Thread.new()
	_thread.start(_render_loops)


func _exit_tree() -> void:
	_cancel = true
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
	_music_filter = AudioEffectLowPassFilter.new()
	_music_filter.cutoff_hz = 9000.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), _music_filter)


func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))


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


## Slowly muffles and lowers the music as the in-game evening comes on.
func _process(delta: float) -> void:
	_filter_timer += delta
	if _filter_timer < 0.5 or _music_filter == null:
		return
	_filter_timer = 0.0
	var hour: float = TimeManager.current_hour_of_day()
	var daylight: float = clampf(sin((hour - 6.0) / 12.0 * PI) * 1.4 + 0.2, 0.0, 1.0)
	_music_filter.cutoff_hz = lerpf(1600.0, 9000.0, daylight)
	_music_player.volume_db = lerpf(-8.0, -3.0, daylight)


# ----------------------------------------------------------------------------------------
# Effects
# ----------------------------------------------------------------------------------------

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
	return _wrap_wav(data, SAMPLE_RATE, false)


func _make_noise_burst(duration: float, volume: float) -> AudioStreamWAV:
	var sample_count: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t: float = float(i) / SAMPLE_RATE
		var envelope: float = clampf(1.0 - t / duration, 0.0, 1.0)
		var sample: float = (randf() * 2.0 - 1.0) * envelope * volume
		data.encode_s16(i * 2, clampi(int(sample * 32767.0), -32768, 32767))
	return _wrap_wav(data, SAMPLE_RATE, false)


static func _wrap_wav(data: PackedByteArray, rate: int, looping: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = data.size() / 2
	return stream


# ----------------------------------------------------------------------------------------
# Ambience and music (rendered on a worker thread)
# ----------------------------------------------------------------------------------------

func _render_loops() -> void:
	var ambience := _render_ambience()
	if _cancel:
		return
	var music := _render_music()
	if _cancel:
		return
	_start_loops.call_deferred(ambience, music)


func _start_loops(ambience: PackedByteArray, music: PackedByteArray) -> void:
	if ambience.size() > 0:
		_ambience_player.stream = _wrap_wav(ambience, LOOP_RATE, true)
		_ambience_player.play()
	if music.size() > 0:
		_music_player.stream = _wrap_wav(music, LOOP_RATE, true)
		_music_player.play()


## Ten seconds of soft low-passed water noise with a few bubbles, cross-faded so it loops
## without a click.
func _render_ambience() -> PackedByteArray:
	var rate := LOOP_RATE
	var n := int(rate * 10.0)
	var fade := int(rate * 0.5)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var lp := 0.0
	var lp2 := 0.0
	for i in range(n + fade):
		var white := rng.randf() * 2.0 - 1.0
		lp += 0.05 * (white - lp)
		lp2 += 0.04 * (lp - lp2)
		var lfo := 0.65 + 0.35 * sin(TAU * 0.17 * float(i) / rate)
		raw[i] = lp2 * lfo * 7.0
	for b in range(16):
		var start := rng.randi_range(0, n - 1)
		var length := int(rate * 0.09)
		var f0 := rng.randf_range(350.0, 700.0)
		var phase := 0.0
		for j in range(length):
			var tt := float(j) / float(length)
			phase += TAU * f0 * (1.0 + 1.6 * tt) / rate
			var env := exp(-5.0 * tt) * sin(PI * minf(1.0, tt * 8.0))
			raw[(start + j) % n] += sin(phase) * env * 0.22
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		if i < fade:
			var w := float(i) / float(fade)
			out[i] = raw[i] * w + raw[n + i] * (1.0 - w)
		else:
			out[i] = raw[i]
	return _to_pcm16(out, 0.5)


## A 32-second loop: four slow chords (Am, F, C, G) of detuned sine pads, with a sparse plucked
## arpeggio over the top. Sine lookups from a table keep the render fast on a phone.
func _render_music() -> PackedByteArray:
	var rate := LOOP_RATE
	var chord_seconds := 8.0
	var chords := [
		[110.0, 164.81, 220.0, 261.63, 329.63],
		[87.31, 130.81, 174.61, 220.0, 329.63],
		[130.81, 196.0, 261.63, 329.63, 392.0],
		[98.0, 146.83, 196.0, 246.94, 293.66],
	]
	var total := int(rate * chord_seconds * chords.size())
	var mix := PackedFloat32Array()
	mix.resize(total)
	var table := PackedFloat32Array()
	table.resize(SINE_TABLE_SIZE)
	for i in range(SINE_TABLE_SIZE):
		table[i] = sin(TAU * float(i) / float(SINE_TABLE_SIZE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 777

	var segment := int(rate * (chord_seconds + 5.0))
	var attack: float = rate * 2.5
	for c in range(chords.size()):
		if _cancel:
			return PackedByteArray()
		var offset := int(rate * chord_seconds * c) - int(rate * 2.5)
		for note in chords[c]:
			for detune in [0.9985, 1.0015]:
				var step: float = float(note) * float(detune) / rate * float(SINE_TABLE_SIZE)
				var phase: float = rng.randf() * SINE_TABLE_SIZE
				for i in range(segment):
					var env: float = minf(1.0, minf(float(i) / attack, float(segment - i) / attack))
					var idx := (offset + i) % total
					if idx < 0:
						idx += total
					mix[idx] += table[int(phase) & (SINE_TABLE_SIZE - 1)] * env * env * 0.05
					phase += step
	## Plucked arpeggio: a note every 0.75 s with some gaps.
	var pluck_len := int(rate * 1.4)
	for k in range(int(chord_seconds * chords.size() / 0.75)):
		if rng.randf() < 0.4:
			continue
		var chord: Array = chords[int(float(k) * 0.75 / chord_seconds) % chords.size()]
		var freq: float = float(chord[rng.randi_range(2, 4)]) * 2.0
		var start := int(float(k) * 0.75 * rate)
		var step: float = freq / rate * float(SINE_TABLE_SIZE)
		var phase := 0.0
		for i in range(pluck_len):
			var env := exp(-4.2 * float(i) / float(pluck_len))
			mix[(start + i) % total] += table[int(phase) & (SINE_TABLE_SIZE - 1)] * env * 0.07
			phase += step
	return _to_pcm16(mix, 0.42)


static func _to_pcm16(samples: PackedFloat32Array, peak: float) -> PackedByteArray:
	var biggest := 0.0001
	for v in samples:
		biggest = maxf(biggest, absf(v))
	var gain := peak / biggest
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, clampi(int(samples[i] * gain * 32767.0), -32768, 32767))
	return data
