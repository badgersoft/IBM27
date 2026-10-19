extends Node
## Sound effects (autoloaded as "Sfx").
##
## Every sound is synthesised in code when the game starts, so there are no
## audio files to manage or license:
##   bell   - a boxing bell "ding" built from a few inharmonic partials; the
##            start-of-round bell is a shorter, lower, softer single ring
##   cheer  - a short burst of cheering and clapping
##   oooh   - the crowd's doubtful "oooh" (many voices, a falling pitch)
##   punch  - a low thud with a slap of noise on top
##   block  - a short, higher "pap" of gloves hitting gloves
##   crowd  - a looping murmur, louder in bigger venues
##   roar   - the crowd reacting to a big moment
##   hype   - a looping cheer under everything that swells when the crowd
##            gets excited and holds for a while before it dies away (excite)
##
## The crowd reacts a moment after the punch: roar and excite wait
## CROWD_DELAY seconds (a little more or less each time) before they sound,
## so the thud comes first and the cheer follows it.

const RATE := 22050
## The cheering bed: silent at rest, HYPE_LOUDEST at full excitement. Once
## the hold runs out it fades by HYPE_FADE (0 - 1 excitement) a second.
const HYPE_QUIET_DB := -60.0
const HYPE_LOUDEST_DB := -8.0
const HYPE_FADE := 0.25
## How fast the volume follows the excitement (a second's share of the gap).
const HYPE_FOLLOW := 6.0
## By venue (Small Town Gym, City Gym, Boxing Hall, Grand Arena): the
## murmur's volume, and how much quieter the cheering and roars are than in
## the Grand Arena - fewer people, less noise.
const CROWD_DB: Array[float] = [-24.0, -19.0, -14.0, -10.0]
const CHEER_DB: Array[float] = [-11.0, -7.0, -3.5, 0.0]
## The crowd's reaction time, seconds: [shortest, longest].
const CROWD_DELAY := Vector2(0.25, 0.4)

var _bell: AudioStreamWAV
var _start_bell: AudioStreamWAV
var _cheer: AudioStreamWAV
var _oooh: AudioStreamWAV
var _punch: AudioStreamWAV
var _block: AudioStreamWAV
var _crowd: AudioStreamWAV
var _roar: AudioStreamWAV
var _hype: AudioStreamWAV

var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _crowd_player: AudioStreamPlayer
var _roar_player: AudioStreamPlayer
var _hype_player: AudioStreamPlayer
var _hype_level := 0.0          ## 0 - 1, how excited the crowd is.
var _hype_hold := 0.0           ## Seconds before the cheering starts to fade.
var _venue_db := 0.0            ## This venue's CHEER_DB.
var _rng := RandomNumberGenerator.new()
## Crowd reactions still to come: [seconds left, Callable].
var _pending: Array = []


func _ready() -> void:
	_rng.seed = 27
	_bell = _make_wav(_synth_bell())
	_start_bell = _make_wav(_synth_start_bell())
	_cheer = _make_wav(_synth_cheer())
	_oooh = _make_wav(_synth_oooh())
	_punch = _make_wav(_synth_punch())
	_block = _make_wav(_synth_block())
	_crowd = _make_wav(_synth_crowd(), true)
	_roar = _make_wav(_synth_roar())
	_hype = _make_wav(_synth_hype(), true)

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
	_hype_player = AudioStreamPlayer.new()
	_hype_player.stream = _hype
	_hype_player.volume_db = HYPE_QUIET_DB
	add_child(_hype_player)


## Rings the bell [param strikes] times. One strike starts a round with the
## short, soft start bell; several (3 to end a round, 5 for a stoppage) use
## the full ring.
func bell(strikes: int = 1) -> void:
	if strikes == 1:
		_play(_start_bell, -11.0, 1.0)
		return
	for i in strikes:
		_play(_bell, -7.0, 1.0)
		if i < strikes - 1:
			await get_tree().create_timer(0.32).timeout


## A punch landing. [param power] 0 - 1 makes it deeper and louder.
func punch(power: float) -> void:
	var p := clampf(power, 0.0, 1.0)
	_play(_punch, lerpf(-12.0, -2.0, p), lerpf(1.25, 0.85, p) * _rng.randf_range(0.95, 1.05))


## A big, significant punch: a deeper, heavier thud and the crowd rising,
## sensing a knockdown.
func big_hit() -> void:
	_play(_punch, 0.0, 0.72)
	roar(0.7)


## The crowd approves of a judge's score.
func cheer() -> void:
	_play(_cheer, -13.0 + _venue_db, _rng.randf_range(0.97, 1.03))


## The crowd is not so sure about a judge's score.
func oooh() -> void:
	_play(_oooh, -17.0 + _venue_db, _rng.randf_range(0.97, 1.03))


func block() -> void:
	_play(_block, -10.0, _rng.randf_range(0.95, 1.1))


## Starts the crowd murmur and sets how loud this venue's crowd is
## (CROWD_DB, CHEER_DB): bigger venues are louder.
func crowd_start(venue_id: int) -> void:
	var venue := clampi(venue_id, 0, CROWD_DB.size() - 1)
	_crowd_player.volume_db = CROWD_DB[venue]
	_venue_db = CHEER_DB[venue]
	if not _crowd_player.playing:
		_crowd_player.play()


func crowd_stop() -> void:
	_pending.clear()
	_crowd_player.stop()
	_hype_player.stop()
	_hype_level = 0.0
	_hype_hold = 0.0


## Gets the crowd going: cheering at [param amount] (0 - 1) excitement, kept
## up for [param hold] seconds before it slowly dies away. A bigger moment
## lifts it further; a smaller one never cuts a bigger one short.
func excite(amount: float, hold: float) -> void:
	_later(_excite_now.bind(amount, hold))


func _excite_now(amount: float, hold: float) -> void:
	if not _hype_player.playing:
		_hype_player.play()
	_hype_level = maxf(_hype_level, clampf(amount, 0.0, 1.0))
	_hype_hold = maxf(_hype_hold, hold)


func _process(delta: float) -> void:
	for i in range(_pending.size() - 1, -1, -1):
		_pending[i][0] -= delta
		if _pending[i][0] <= 0.0:
			var react: Callable = _pending[i][1]
			_pending.remove_at(i)
			react.call()
	if not _hype_player.playing:
		return
	if _hype_hold > 0.0:
		_hype_hold -= delta
	else:
		_hype_level = maxf(_hype_level - HYPE_FADE * delta, 0.0)
	var target := lerpf(HYPE_QUIET_DB, HYPE_LOUDEST_DB + _venue_db, sqrt(_hype_level)) if _hype_level > 0.0 else HYPE_QUIET_DB
	_hype_player.volume_db = lerpf(_hype_player.volume_db, target, minf(HYPE_FOLLOW * delta, 1.0))


## The crowd reacts. [param amount] 0 - 1.
func roar(amount: float) -> void:
	_later(_roar_now.bind(amount))


func _roar_now(amount: float) -> void:
	_roar_player.volume_db = lerpf(-20.0, -6.0, clampf(amount, 0.0, 1.0)) + _venue_db
	_roar_player.play()


# ============================================================================
#  Playback
# ============================================================================

## Runs [param react] after the crowd's reaction time.
func _later(react: Callable) -> void:
	_pending.append([_rng.randf_range(CROWD_DELAY.x, CROWD_DELAY.y), react])


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


## The start-of-round bell: one ring, lower and rounder than the full bell
## (fewer high partials, a softer strike) and gone in under a second.
func _synth_start_bell() -> PackedFloat32Array:
	var length := int(RATE * 0.75)
	var out := PackedFloat32Array()
	out.resize(length)
	var base := 600.0
	var partials := [[1.00, 1.00, 0.45], [2.32, 0.30, 0.25], [4.25, 0.06, 0.12]]
	for i in length:
		var t := float(i) / RATE
		var v := 0.0
		for p in partials:
			v += sin(TAU * base * p[0] * t) * p[1] * exp(-t / p[2])
		if t < 0.004:
			v += _rng.randf_range(-0.25, 0.25) * (1.0 - t / 0.004)
		v *= minf(t / 0.003, 1.0)                                   # No hard click.
		v *= minf((length - i) / (RATE * 0.05), 1.0)               # Fade the tail.
		out[i] = v * 0.4
	return out


## A short cheer: a bright swell of voices with scattered claps on top.
func _synth_cheer() -> PackedFloat32Array:
	var length := int(RATE * 1.4)
	var out := PackedFloat32Array()
	out.resize(length)
	var smooth := 0.0
	var low := 0.0
	var clap := 0.0
	for i in length:
		var t := float(i) / RATE
		smooth = lerpf(smooth, _rng.randf_range(-1.0, 1.0), 0.35)
		low = lerpf(low, smooth, 0.25)
		var voices := smooth - low * 0.6
		if _rng.randf() < 0.004:
			clap = 1.0
		clap *= 0.93
		var env := minf(t / 0.08, 1.0) * exp(-maxf(t - 0.25, 0.0) / 0.35)
		out[i] = (voices * 0.8 + _rng.randf_range(-1.0, 1.0) * clap * 0.5) * env
	return out


## "Oooh": a crowd of voices on an "oo" vowel (harmonics through a heavy
## low-pass), drifting down in pitch as doubt sets in.
func _synth_oooh() -> PackedFloat32Array:
	var length := int(RATE * 1.5)
	var out := PackedFloat32Array()
	out.resize(length)
	var voices := 16
	var freqs: Array[float] = []
	var phases: Array[float] = []
	var wobble: Array[float] = []
	for v in voices:
		freqs.append(_rng.randf_range(170.0, 290.0))
		phases.append(_rng.randf() * TAU)
		wobble.append(_rng.randf_range(4.0, 6.5))
	var lp := 0.0
	var peak := 0.0
	for i in length:
		var t := float(i) / RATE
		var glide := lerpf(1.06, 0.88, minf(t / 1.2, 1.0))
		var v := 0.0
		for k in voices:
			var f: float = freqs[k] * glide * (1.0 + 0.012 * sin(TAU * wobble[k] * t))
			phases[k] += TAU * f / RATE
			var ph: float = phases[k]
			v += sin(ph) + 0.45 * sin(ph * 2.0) + 0.2 * sin(ph * 3.0)
		lp = lerpf(lp, v, 0.12)
		var env := minf(t / 0.22, 1.0) * clampf((1.5 - t) / 0.6, 0.0, 1.0)
		out[i] = lp * env
		peak = maxf(peak, absf(out[i]))
	for i in length:
		out[i] = out[i] / maxf(peak, 0.001) * 0.8
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


## A seamless loop of a crowd cheering: bright voices, a low swell and
## scattered claps, cross-faded at the join.
func _synth_hype() -> PackedFloat32Array:
	var length := RATE * 3
	var fade := int(RATE * 0.3)
	var raw := PackedFloat32Array()
	raw.resize(length + fade)
	var smooth := 0.0
	var low := 0.0
	var clap := 0.0
	for i in raw.size():
		var t := float(i) / RATE
		smooth = lerpf(smooth, _rng.randf_range(-1.0, 1.0), 0.32)
		low = lerpf(low, smooth, 0.2)
		if _rng.randf() < 0.006:
			clap = 1.0
		clap *= 0.92
		var swell := 0.85 + 0.15 * sin(TAU * 0.7 * t)
		raw[i] = ((smooth - low * 0.5) * 0.7 * swell + _rng.randf_range(-1.0, 1.0) * clap * 0.4) * 0.8
	var out := PackedFloat32Array()
	out.resize(length)
	for i in length:
		out[i] = raw[i]
	for i in fade:
		var k := float(i) / fade
		out[i] = raw[i] * k + raw[length + i] * (1.0 - k)
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
