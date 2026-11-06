extends Control
## Camada pixel animada do ambulatorio.
##
## Desenha, por cima da imagem estatica `cenario_base.png`, tudo o que se mexe e
## continua em pixel art: estrelas, luzinhas, plantas penduradas, relogio com a
## hora real, monitor de ECG, cruz neon, abajures e o soro.
##
## As coordenadas sao as da base 640x360; o no e ampliado 2x na cena (1280x720).

const FIOS := [[0, 12, 214, 20], [214, 12, 430, 18], [430, 12, 640, 20]]
const PENDENTES := [150.0, 500.0]

const COR_FIO := Color("#2a1d14")
const COR_TERRA := Color("#c0603f")
const COR_TERRA_ESCURA := Color("#8a3f27")
const COR_TERRA_CLARA := Color("#dc8560")
const COR_VERDE_1 := Color("#3e7d52")
const COR_VERDE_2 := Color("#5fa86a")
const COR_VERDE_3 := Color("#8fd08a")
const CORES_LUZ := [Color("#ffd98a"), Color("#ffb3c6"), Color("#bfe3ff"), Color("#c8f0a8")]

var _t := 0.0
var _bulbs: Array = []
var _estrelas: Array = []
var _pendurados: Array = [
	{"x": 516, "topo": 12, "comp": 58, "semente": 1},
	{"x": 628, "topo": 12, "comp": 78, "semente": 2},
	{"x": 150, "topo": 12, "comp": 30, "semente": 3},
]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11

	for i in range(FIOS.size()):
		var fio: Array = FIOS[i]
		var n := int(floor((fio[2] - fio[0]) / 17.0))
		for k in range(n + 1):
			var u := float(k) / n
			_bulbs.append({
				"x": fio[0] + (fio[2] - fio[0]) * u,
				"y": _y_fio(fio, u),
				"cor": CORES_LUZ[(k + i) % 4],
				"fase": rng.randf() * TAU,
				"vel": 0.8 + rng.randf() * 1.4,
			})

	for i in range(28):
		_estrelas.append({
			"x": 27.0 + rng.randf() * 92.0,
			"y": 34.0 + rng.randf() * 50.0,
			"fase": rng.randf() * TAU,
			"vel": 0.6 + rng.randf() * 2.0,
			"t": 2 if rng.randf() < 0.2 else 1,
		})


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


# --------------------------------------------------------------- utilidades

func _y_fio(fio: Array, u: float) -> float:
	return fio[1] + fio[3] * 4.0 * u * (1.0 - u)


func _r(cor: Color, x: float, y: float, w: float, h: float) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), roundf(w), roundf(h)), cor)


func _elipse(cor: Color, cx: float, cy: float, rx: float, ry: float) -> void:
	for y in range(int(-ry), int(ry) + 1):
		var hw := roundf(rx * sqrt(maxf(0.0, 1.0 - float(y * y) / (ry * ry))))
		_r(cor, cx - hw, cy + y, hw * 2.0, 1.0)


func _mix(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, t)


# ---------------------------------------------------------------------- draw

func _draw() -> void:
	_estrelas_e_luzinhas()
	_plantas_penduradas()
	_relogio()
	_monitor_ecg()
	_cruz_neon()
	_abajures()
	_soro()


func _estrelas_e_luzinhas() -> void:
	for s in _estrelas:
		var a := 0.35 + 0.65 * absf(sin(_t * s.vel + s.fase))
		_r(Color(1, 1, 1, a), s.x, s.y, s.t, s.t)

	for fio in FIOS:
		for x in range(int(fio[0]), int(fio[2])):
			var u: float = (x - fio[0]) / float(fio[2] - fio[0])
			_r(COR_FIO, x, _y_fio(fio, u), 1, 1)

	for b in _bulbs:
		var k := 0.55 + 0.45 * sin(_t * b.vel * 2.0 + b.fase)
		_r(Color("#1d130c"), b.x - 1, b.y + 1, 2, 2)
		_r(_mix(Color("#6b5a44"), b.cor, k), b.x - 1, b.y + 3, 3, 4)
		_r(Color(1, 1, 1, 0.5 * k), b.x - 1, b.y + 3, 1, 2)


func _plantas_penduradas() -> void:
	for h in _pendurados:
		var balanco := sin(_t * 1.1 + h.semente) * 1.6
		_r(COR_FIO, h.x, h.topo, 1, 6)
		_r(COR_TERRA, h.x - 6, h.topo + 6, 13, 7)
		_r(COR_TERRA_ESCURA, h.x - 6, h.topo + 11, 13, 2)
		_r(COR_TERRA_CLARA, h.x - 6, h.topo + 6, 13, 1)
		for k in range(7):
			var desloc := (k - 3) * 3.0
			var comp: float = h.comp * (0.5 + float((k * 37) % 10) / 16.0)
			var s := 0.0
			while s < comp:
				var u := s / comp
				var x: float = h.x + desloc * (0.4 + u) + sin(_t * 1.3 + k + s * 0.07) * (0.6 + u * 2.2) + _balanco_x(balanco, u)
				var y: float = h.topo + 13.0 + s
				_r(COR_VERDE_2 if int(s) % 7 < 3 else COR_VERDE_1, x, y, 1.5, 1.5)
				if int(s) % 6 == 3:
					_r(COR_VERDE_3, x + (2 if k % 2 == 1 else -2), y, 2, 2)
				s += 1.0


func _balanco_x(balanco: float, u: float) -> float:
	return balanco * u * 2.0


func _relogio() -> void:
	var agora := Time.get_datetime_dict_from_system()
	var seg := float(agora.second) + float(Time.get_ticks_msec() % 1000) / 1000.0
	var mn := float(agora.minute) + seg / 60.0
	var hr := float(agora.hour % 12) + mn / 60.0
	_ponteiro(hr / 12.0 * TAU, 9, Color("#2a1d14"), 2.0)
	_ponteiro(mn / 60.0 * TAU, 13, Color("#2a1d14"), 1.5)
	_ponteiro(seg / 60.0 * TAU, 14, Color("#c4574f"), 1.0)
	_r(Color("#2a1d14"), 474, 48, 3, 3)


func _ponteiro(angulo: float, comp: int, cor: Color, espessura: float) -> void:
	for s in range(comp):
		_r(cor, 475.0 + sin(angulo) * s - espessura / 2.0, 49.0 - cos(angulo) * s - espessura / 2.0, espessura, espessura)


func _monitor_ecg() -> void:
	_r(Color("#d8cdb6"), 134, 54, 50, 34)
	_r(Color("#aaa08a"), 134, 86, 50, 2)
	_r(Color("#0b1218"), 137, 57, 44, 26)

	var mx := 137
	var my := 57
	var cursor := fmod(_t / 2.2, 1.0) * 44.0
	for i in range(44):
		var u := float(i % 22)
		var yy := 13.0
		if u > 5.0 and u < 7.0:
			yy = 13.0 - (u - 5.0) * 3.0
		elif u >= 7.0 and u < 9.0:
			yy = 7.0 + (u - 7.0) * 9.0
		elif u >= 9.0 and u < 11.0:
			yy = 25.0 - (u - 9.0) * 12.0
		elif u >= 11.0 and u < 12.5:
			yy = 1.0 + (u - 11.0) * 8.0
		var dist := fposmod(cursor - i, 44.0)
		var a := maxf(0.0, 1.0 - dist / 30.0)
		if a > 0.04:
			_r(Color(0.44, 0.88, 0.63, a), mx + i, my + yy, 1, 2)
	_r(Color.WHITE, mx + int(cursor), my + 13, 2, 2)
	_r(Color("#6fe0a0"), mx + 34, my + 2, 8, 1)
	_r(Color("#6fe0a0"), mx + 34, my + 4, 6, 1)


func _cruz_neon() -> void:
	var k := 0.7 + 0.3 * sin(_t * 2.2)
	var verde := Color(0.44, 0.88, 0.63, k)
	_r(verde, 310, 18, 6, 22)
	_r(verde, 302, 26, 22, 6)
	_r(Color(1, 1, 1, k * 0.6), 311, 19, 2, 20)
	_r(COR_FIO, 312, 12, 1, 6)


func _abajures() -> void:
	var k := 0.9 + 0.1 * sin(_t * 3.1) * sin(_t * 1.3)
	_r(_mix(Color("#c98a3a"), Color("#ffd98a"), k), 103, 132, 20, 12)
	_r(Color("#fff0b8"), 105, 134, 16, 8)
	_r(Color(0, 0, 0, 0.2), 103, 142, 20, 2)

	for x in PENDENTES:
		_r(COR_FIO, x, 12, 1, 16)
		_elipse(Color("#d9983f"), x, 34, 12, 6)
		_r(Color("#f5c773"), x - 11, 34, 22, 6)
		_elipse(Color("#fff0b8"), x, 40, 8, 2)
		_r(COR_FIO, x - 12, 34, 24, 1)


func _soro() -> void:
	var iv := 594.0
	var topo := 150.0
	_r(Color("#2b3640"), iv - 1, topo - 1, 4, 200)
	_r(Color("#aab8c2"), iv, topo, 2, 198)
	_r(Color("#dfe8ee"), iv, topo, 1, 198)
	_r(Color("#2b3640"), iv - 13, topo - 2, 28, 3)
	_r(Color("#aab8c2"), iv - 12, topo - 1, 26, 1)
	_r(Color("#2b3640"), iv - 11, 344, 24, 6)
	_r(Color("#8c9ca7"), iv - 10, 345, 22, 3)
	_r(Color("#4d5c67"), iv - 10, 348, 22, 1)
	_r(Color("#2b3640"), iv - 12, 349, 5, 4)
	_r(Color("#2b3640"), iv + 9, 349, 5, 4)
	_elipse(Color(0, 0, 0, 0.35), iv + 1, 354, 16, 2)

	# bolsa
	_r(Color("#e9f2f8"), iv - 6, topo + 4, 12, 22)
	_r(Color("#cfe6ff"), iv - 5, topo + 5, 10, 6)
	_r(Color("#7ea6dc"), iv - 5, topo + 11, 10, 14)
	_r(Color("#ffb3c6"), iv - 2, topo + 16, 4, 3)
	_r(Color("#ffb3c6"), iv - 3, topo + 17, 6, 1)
	_r(Color("#e9f2f8"), iv - 1, topo + 26, 2, 5)

	# equipo e gota
	_r(Color(0.81, 0.9, 1, 0.9), iv, topo + 35, 1, 4)
	var queda := fmod(_t, 1.1) / 1.1
	_r(Color(0.62, 0.8, 1, 1.0 - queda), iv, topo + 39 + queda * 8.0, 1, 2)
	_r(Color(0.81, 0.9, 1, 0.7), iv, topo + 50, 1, 70)
	_r(Color(0.81, 0.9, 1, 0.7), iv - 14, topo + 120, 15, 1)
