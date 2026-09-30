class_name Sfx
extends Node
## Procedural sound effects: short synthesized WAV tones, no assets.

const MIX_RATE := 22050

var enabled := true
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	_streams["move"] = _tone(320.0, 0.045, 0.25, _sine)
	_streams["push"] = _tone(150.0, 0.09, 0.45, _sine)
	_streams["deny"] = _tone(90.0, 0.08, 0.3, _sine)
	_streams["undo"] = _tone(240.0, 0.05, 0.2, _sine)
	_streams["switch"] = _tone(520.0, 0.1, 0.3, _square)
	_streams["win"] = _jingle([523.0, 659.0, 784.0, 1047.0], 0.09, 0.3)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(name: String) -> void:
	if not enabled or not _streams.has(name) or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.play()


static func _sine(t: float) -> float:
	return sin(TAU * t)


static func _square(t: float) -> float:
	return 1.0 if fposmod(t, 1.0) < 0.5 else -1.0


static func _tone(freq: float, dur: float, vol: float, wave: Callable) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := 1.0 - float(i) / n
		var v: float = wave.call(freq * t)
		data[i] = int(clampf(128.0 + v * vol * env * 127.0, 0, 255))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav


static func _jingle(freqs: Array, note_dur: float, vol: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * note_dur * freqs.size())
	var data := PackedByteArray()
	data.resize(n)
	var per := int(MIX_RATE * note_dur)
	for i in n:
		var fi := mini(i / per, freqs.size() - 1)
		var t := float(i - fi * per) / MIX_RATE
		var env := 1.0 - float(i - fi * per) / per
		var v := sin(TAU * float(freqs[fi]) * t)
		data[i] = int(clampf(128.0 + v * vol * env * 127.0, 0, 255))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav
