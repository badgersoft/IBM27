extends Node
## Sound effects (autoloaded as "Sfx").
##
## Every sound is synthesised in code when the game starts, so there are no
## audio files to manage or license:
##   bell   - a boxing bell "ding" built from a few inharmonic partials
##   punch  - a low thud with a slap of noise on top
##   block  - a short, higher "pap" of gloves hitting gloves
##   crowd  - a looping murmur, louder in bigger venues
##   roar   - the crowd reacting to a big moment

const RATE := 22050

var _bell: AudioStreamWAV
var _punch: AudioStreamWAV
var _block: AudioStreamWAV
var _crowd: AudioStreamWAV
var _roar: AudioStreamWAV

var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _crowd_player: AudioStreamPlayer
var _roar_player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 27
	_bell = _make_wav(_synth_bell())
	_punch = _make_wav(_synth_punch())
	_block = _make_wav(_synth_block())
	_crowd = _make_wav(_synth_crowd(), true)
	_roar = _make_wav(_synth_roar())

	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_crowd_player = AudioStreamPlayer.new()
	_crowd_player.stream = _crowd
	add_child(_crowd_player)
	_roar_player = AudioStreamPlayer.new()
	_roar_player.stream = _roar
	add_child(_roar_player)


## Rings the bell [param strikes] times (1 to start a round, 3 to end it).
func bell(strikes: int = 1) -> void:
	for i in strikes:
		_play(_bell, -4.0, 1.0)
		if i < strikes - 1:
			await get_tree().create_timer(0.32).timeout


## A punch landing. [param power] 0 - 1 makes it deeper and louder.
func punch(power: float) -> void:
	var p := clampf(power, 0.0, 1.0)
	_play(_punch, lerpf(-12.0, -2.0, p), lerpf(1.25, 0.85, p) * _rng.randf_range(0.95, 1.05))


func block() -> void:
	_play(_block, -10.0, _rng.randf_range(0.95, 1.1))


## Starts the crowd murmur. Bigger venues are louder.
func crowd_start(venue_id: int) -> void:
	_crowd_player.volume_db = [-24.0, -19.0, -14.0][clampi(venue_id, 0, 2)]
	if not _crowd_player.playing:
		_crowd_player.play()


func crowd_stop() -> void:
	_crowd_player.stop()


## The crowd reacts. [param amount] 0 - 1.
func roar(amount: float) -> void:
	_roar_player.volume_db = lerpf(-20.0, -6.0, clampf(amount, 0.0, 1.0))
	_roar_player.play()


# ============================================================================
#  Playback
# ============================================================================

func _play(stream: AudioStream, volume_db: float, pitch: float) -> void:
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


# ============================================================================
#  Synthesis
# ============================================================================

func _synth_bell() -> PackedFloat32Array:
	var length := int(RATE * 1.8)
	var out := PackedFloat32Array()
	out.resize(length)
	var base := 830.0
	var partials := [[1.00, 1.00, 1.6], [2.32, 0.55, 1.0], [4.25, 0.30, 0.6], [6.63, 0.15, 0.35]]
	for i in length:
		var t := float(i) / RATE
		var v := 0.0
		for p in partials:
			v += sin(TAU * base * p[0] * t) * p[1] * exp(-t / p[2])
		if t < 0.006:
			v += _rng.randf_range(-0.6, 0.6) * (1.0 - t / 0.006)   # Strike click.
		out[i] = v * 0.4
	return out


func _synth_punch() -> PackedFloat32Array:
	var length := int(RATE * 0.18)
	var out := PackedFloat32Array()
	out.resize(length)
	var phase := 0.0
	var noise := 0.0
	for i in length:
		var t := float(i) / RATE
		var freq := lerpf(130.0, 50.0, minf(t / 0.12, 1.0))
		phase += TAU * freq / RATE
		noise = lerpf(noise, _rng.randf_range(-1.0, 1.0), 0.35)   # Softened noise.
		var thud := sin(phase) * exp(-t / 0.06)
		var slap := noise * exp(-t / 0.018)
		out[i] = (thud * 0.8 + slap * 0.6) * 0.8
	return out


func _synth_block() -> PackedFloat32Array:
	var length := int(RATE * 0.08)
	var out := PackedFloat32Array()
	out.resize(length)
	var lp := 0.0
	for i in length:
		var t := float(i) / RATE
		var n := _rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, n, 0.5)
		out[i] = (n - lp) * exp(-t / 0.015) * 0.7 + sin(TAU * 420.0 * t) * exp(-t / 0.02) * 0.3
	return out


## Two seconds of murmur that loops without a click: the end is faded into the
## start.
func _synth_crowd() -> PackedFloat32Array:
	var length := RATE * 2
	var fade := int(RATE * 0.25)
	var raw := PackedFloat32Array()
	raw.resize(length + fade)
	var brown := 0.0
	var smooth := 0.0
	for i in raw.size():
		brown = clampf(brown + _rng.randf_range(-0.05, 0.05), -1.0, 1.0)
		smooth = lerpf(smooth, _rng.randf_range(-1.0, 1.0), 0.08)
		var t := float(i) / RATE
		var swell := 0.8 + 0.2 * sin(TAU * 0.5 * t)
		raw[i] = (brown * 0.6 + smooth * 0.8) * swell * 0.5
	var out := PackedFloat32Array()
	out.resize(length)
	for i in length:
		out[i] = raw[i]
	for i in fade:
		var k := float(i) / fade
		out[i] = raw[i] * k + raw[length + i] * (1.0 - k)
	return out


func _synth_roar() -> PackedFloat32Array:
	var length := int(RATE * 1.6)
	var out := PackedFloat32Array()
	out.resize(length)
	var smooth := 0.0
	for i in length:
		var t := float(i) / RATE
		smooth = lerpf(smooth, _rng.randf_range(-1.0, 1.0), 0.18)
		var env := minf(t / 0.15, 1.0) * exp(-maxf(t - 0.3, 0.0) / 0.5)
		out[i] = smooth * env * 0.9
	return out


func _make_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav
