class_name GameAudio
extends Node
## Small synthesized cues keep the prototype self-contained.

var enabled: bool = true
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0


func _ready() -> void:
	_streams["turn"] = _tone(260.0, 0.035)
	_streams["land"] = _tone(170.0, 0.06)
	_streams["clear"] = _tone(660.0, 0.18)
	_streams["end"] = _tone(110.0, 0.36)
	for index: int in range(4):
		var player := AudioStreamPlayer.new()
		player.volume_db = -16.0
		add_child(player)
		_players.append(player)


func play_cue(kind: String, pitch: float = 1.0) -> void:
	if not enabled or _players.is_empty() or not _streams.has(kind):
		return
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _streams[kind]
	player.pitch_scale = pitch
	player.play()


func _tone(frequency: float, duration: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var data := PackedByteArray()
	var count: int = int(duration * sample_rate)
	data.resize(count)
	for sample: int in range(count):
		var progress: float = float(sample) / count
		var envelope: float = sin(minf(progress * 15.0, 1.0) * PI * 0.5) * pow(1.0 - progress, 2.0)
		var wave: float = sin(TAU * frequency * sample / sample_rate)
		data[sample] = int(128.0 + wave * envelope * 80.0)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
