extends Node
# 효과음: 실행 시 사인/사각/톱니파로 합성 (외부 파일 없음)

const RATE := 22050
var streams := {}
var players: Array = []
var muted := false


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	streams.click = _make([[700, 900, 0.06, "tri", 0.05, 0.0]])
	streams.chop = _make([[320, 140, 0.05, "sq", 0.03, 0.0], [320, 140, 0.05, "sq", 0.03, 0.09], [320, 140, 0.05, "sq", 0.03, 0.18]])
	streams.ding = _make([[1318, 1318, 0.35, "sin", 0.08, 0.0], [1760, 1760, 0.45, "sin", 0.05, 0.1]])
	streams.buzz = _make([[170, 90, 0.25, "saw", 0.05, 0.0]])
	streams.boom = _make([[140, 40, 0.5, "saw", 0.09, 0.0]])
	streams.fanfare = _make([[523, 523, 0.22, "tri", 0.08, 0.0], [659, 659, 0.22, "tri", 0.08, 0.1], [784, 784, 0.22, "tri", 0.08, 0.2], [1046, 1046, 0.22, "tri", 0.08, 0.3]])
	streams.sad = _make([[392, 380, 0.28, "tri", 0.07, 0.0], [330, 320, 0.28, "tri", 0.07, 0.18], [262, 254, 0.28, "tri", 0.07, 0.36]])
	streams.pop = _make([[500, 1100, 0.07, "sin", 0.07, 0.0]])
	streams.thud = _make([[180, 60, 0.18, "sin", 0.12, 0.0]])
	streams.tick = _make([[1600, 1600, 0.02, "sq", 0.02, 0.0]])


func _make(tones: Array) -> AudioStreamWAV:
	var total := 0.0
	for t in tones: total = maxf(total, t[2] + t[5])
	var n := int((total + 0.03) * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for t in tones:
		var f1: float = t[0]; var f2: float = t[1]; var dur: float = t[2]; var typ: String = t[3]; var vol: float = t[4] * 3.0
		var st := int(t[5] * RATE)
		var len := int(dur * RATE)
		var ph := 0.0
		for i in len:
			var k := float(i) / len
			var f := f1 * pow(f2 / f1, k)
			ph += f / RATE
			var x := fmod(ph, 1.0)
			var w := 0.0
			match typ:
				"sin": w = sin(x * TAU)
				"tri": w = 1.0 - 4.0 * absf(x - 0.5)
				"sq": w = 1.0 if x < 0.5 else -1.0
				"saw": w = 2.0 * x - 1.0
			var g := vol * pow(0.0001 / vol, k)
			if i < 40: g *= i / 40.0
			if st + i < n: buf[st + i] += w * g
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1, 1) * 32000))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s


func play(name: String) -> void:
	if muted or not streams.has(name): return
	for p in players:
		if not p.playing:
			p.stream = streams[name]
			p.play()
			return
	players[0].stream = streams[name]
	players[0].play()
