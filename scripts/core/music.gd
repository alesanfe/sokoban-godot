class_name AmbientMusic
extends AudioStreamPlayer
## Generative ambient music: slow chord pads (Am9 → Fmaj7 → G6/9 →
## Cmaj9) plus sparse pentatonic bells, synthesized in realtime with an
## AudioStreamGenerator. No assets, infinitely evolving, no loop seam.

const RATE := 22050.0
const CHORD_S := 12.0
const CHORDS := [  # MIDI semitone voicings
	[45, 60, 64, 67, 71],  # Am9
	[41, 57, 60, 64, 67],  # Fmaj7
	[43, 55, 59, 62, 66],  # G6/9
	[48, 55, 60, 64, 69],  # Cmaj(add6)
]
const SCALE := [57, 60, 62, 64, 67, 69, 72, 74, 76, 79]  # A-minor pentatonic

var enabled := true:
	set(v):
		enabled = v
		playing = v
		_gen = null  # fresh playback object after a stop/start toggle

var _gen: AudioStreamGeneratorPlayback
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _bells: Array = []    # [{t0, f}]
var _next_bell := 1.5


func _ready() -> void:
	if AudioServer.get_driver_name() == "Dummy":
		return  # headless: no playback object → no exit-time leak
	var s := AudioStreamGenerator.new()
	s.mix_rate = RATE
	s.buffer_length = 0.7
	stream = s
	volume_db = -16.0
	_rng.seed = 20260928
	playing = enabled


func _notification(what: int) -> void:
	# Guaranteed at object destruction (earlier & surer than _exit_tree):
	# release the playback so no ObjectDB instance leaks at exit.
	if what == NOTIFICATION_PREDELETE:
		stop()
		_gen = null
		stream = null


func _exit_tree() -> void:
	stop()
	_gen = null
	stream = null  # releases the generator + its playback (ObjectDB leak)


func _process(_dt: float) -> void:
	if _gen == null:
		if is_playing():
			_gen = get_stream_playback()
		return
	var avail := _gen.get_frames_available()
	if avail <= 0:
		return
	var n := mini(avail, int(RATE * 0.2))
	var buf := PackedVector2Array()
	buf.resize(n)
	var step := 1.0 / RATE
	for i in n:
		var v := _sample(_t)
		buf[i] = Vector2(v, v)
		_t += step
	_gen.push_buffer(buf)


func _sample(t: float) -> float:
	# pads: current chord fading out + next fading in (crossfade last 2s)
	var ci := int(t / CHORD_S) % CHORDS.size()
	var ph := fposmod(t, CHORD_S)
	var w_cur := clampf(minf(ph, CHORD_S - ph) / 2.0, 0.0, 1.0)
	var w_nxt := clampf((ph - (CHORD_S - 2.0)) / 2.0, 0.0, 1.0)
	var v := _chord(CHORDS[ci], t) * w_cur + _chord(CHORDS[(ci + 1) % CHORDS.size()], t) * w_nxt
	# sparse bells
	if t >= _next_bell:
		var sn: int = SCALE[_rng.randi() % SCALE.size()]
		_bells.append({"t0": t, "f": _freq(sn)})
		_next_bell = t + _rng.randf_range(1.4, 3.6)
		if _bells.size() > 10:
			_bells.pop_front()
	for b in _bells:
		var dt2: float = t - b["t0"]
		if dt2 < 3.0:
			var e := exp(-dt2 * 1.6)
			v += sin(TAU * b["f"] * dt2) * 0.10 * e
			v += sin(TAU * b["f"] * 2.0 * dt2) * 0.04 * e
	return clampf(v, -0.9, 0.9)


func _chord(notes: Array, t: float) -> float:
	var v := 0.0
	for sn in notes:
		var f := _freq(int(sn))
		v += sin(TAU * f * t) * 0.05
		v += sin(TAU * f * 1.0035 * t) * 0.03  # detuned shimmer
	return v


static func _freq(semitone: int) -> float:
	return 440.0 * pow(2.0, (semitone - 69) / 12.0)
