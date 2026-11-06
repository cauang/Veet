extends Control
## Luzes e brilhos do ambulatorio (desenhados com mistura ADITIVA).
##
## Cones dos pendentes, abajur, luz da lua, halos das luzinhas, poeira na luz,
## vagalumes e mariposas. Coordenadas da base 640x360; o no e ampliado 2x.

@export var densidade := 2.0

const PENDENTES := [150.0, 500.0]
const FIOS := [[0, 12, 214, 20], [214, 12, 430, 18], [430, 12, 640, 20]]
const CORES_HALO := [Color(1.0, 0.85, 0.54), Color(1.0, 0.7, 0.78), Color(0.75, 0.89, 1.0), Color(0.78, 0.94, 0.66)]

var _t := 0.0
var _brilho: Texture2D
var _rng := RandomNumberGenerator.new()
var _halos: Array = []
var _vagalumes: Array = []
var _poeira: Array = []
var _mariposas: Array = []


func _ready() -> void:
	_rng.seed = 23
	_brilho = _criar_brilho()

	for i in range(FIOS.size()):
		var fio: Array = FIOS[i]
		var n := int(floor((fio[2] - fio[0]) / 17.0))
		for k in range(n + 1):
			var u := float(k) / n
			_halos.append({
				"x": fio[0] + (fio[2] - fio[0]) * u,
				"y": fio[1] + fio[3] * 4.0 * u * (1.0 - u),
				"cor": CORES_HALO[(k + i) % 4],
				"fase": _rng.randf() * TAU,
				"vel": 0.8 + _rng.randf() * 1.4,
			})

	for i in range(roundi(26 * densidade)):
		var x := _rng.randf() * 640.0
		var y := 160.0 + _rng.randf() * 190.0
		_vagalumes.append({
			"cx": x, "cy": y, "fase": _rng.randf() * 9.0, "vel": 0.25 + _rng.randf() * 0.5,
			"raio": 20.0 + _rng.randf() * 50.0, "pulso": 1.0 + _rng.randf() * 2.0,
			"cor": Color(1.0, 0.93, 0.55) if _rng.randf() < 0.8 else Color(0.78, 1.0, 0.63),
		})

	for i in range(roundi(70 * densidade)):
		_poeira.append({"t": _rng.randf(), "fase": _rng.randf() * 6.0, "vel": 0.02 + _rng.randf() * 0.04, "tam": 0.6 + _rng.randf() * 1.1})

	for i in range(roundi(5 * densidade)):
		_mariposas.append({
			"lampada": PENDENTES[i % 2], "ang": _rng.randf() * TAU, "raio": 10.0 + _rng.randf() * 16.0,
			"vel": 0.8 + _rng.randf() * 1.5, "fase": _rng.randf() * 5.0,
		})


func _criar_brilho() -> Texture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex


func _process(delta: float) -> void:
	_t += delta

	for p in _poeira:
		p.t = fmod(p.t + delta * p.vel, 1.0)
	for v in _vagalumes:
		v.fase += delta * v.vel
	for m in _mariposas:
		m.ang += delta * m.vel
	queue_redraw()


func _brilhar(x: float, y: float, raio: float, cor: Color, alfa: float) -> void:
	draw_texture_rect(_brilho, Rect2(x - raio, y - raio, raio * 2.0, raio * 2.0), false, Color(cor.r, cor.g, cor.b, alfa))


func _cone(x: float, y: float, r1: float, r2: float, comprimento: float, cor: Color, alfa: float) -> void:
	var pontos := PackedVector2Array([Vector2(x - r1, y), Vector2(x + r1, y), Vector2(x + r2, y + comprimento), Vector2(x - r2, y + comprimento)])
	var topo := Color(cor.r, cor.g, cor.b, alfa)
	var base := Color(cor.r, cor.g, cor.b, 0.0)
	draw_polygon(pontos, PackedColorArray([topo, topo, base, base]))


func _draw() -> void:
	var quente := Color(1.0, 0.78, 0.47)

	# Pendentes
	for i in range(PENDENTES.size()):
		var x: float = PENDENTES[i]
		var k := 0.9 + 0.1 * sin(_t * 2.3 + i * 2.0)
		_cone(x, 40.0, 10.0, 70.0, 190.0, quente, 0.17 * k)
		_brilhar(x, 40.0, 40.0, Color(1.0, 0.8, 0.51), 0.34 * k)

	# Abajur da comoda
	var kl := 0.92 + 0.08 * sin(_t * 3.1)
	_brilhar(113.0, 138.0, 70.0, Color(1.0, 0.8, 0.51), 0.4 * kl)
	_brilhar(113.0, 138.0, 26.0, Color(1.0, 0.9, 0.67), 0.35 * kl)

	# Luz da lua entrando pela janela
	var balanco := sin(_t * 0.4) * 6.0
	var luz_lua := Color(0.67, 0.8, 1.0)
	draw_polygon(
		PackedVector2Array([Vector2(30, 126), Vector2(120, 126), Vector2(300 + balanco, 300), Vector2(170 + balanco, 300)]),
		PackedColorArray([Color(luz_lua, 0.2), Color(luz_lua, 0.2), Color(luz_lua, 0.0), Color(luz_lua, 0.0)]))
	_brilhar(100.0, 52.0, 36.0, Color(1.0, 0.95, 0.77), 0.22)

	# Halos das luzinhas
	for h in _halos:
		var kh := 0.55 + 0.45 * sin(_t * h.vel * 2.0 + h.fase)
		_brilhar(h.x, h.y + 5.0, 13.0, h.cor, 0.34 * kh)

	# Cruz neon, monitor e soro
	_brilhar(313.0, 29.0, 30.0, Color(0.44, 0.88, 0.63), 0.22 * (0.7 + 0.3 * sin(_t * 2.2)))
	_brilhar(160.0, 72.0, 40.0, Color(0.44, 0.88, 0.63), 0.16)
	_brilhar(594.0, 172.0, 26.0, Color(0.62, 0.8, 1.0), 0.12)

	# Poeira na luz da lua
	for p in _poeira:
		var t: float = p.t
		var yy := 126.0 + t * 170.0
		var xl := 30.0 + (t * 140.0 + balanco * t)
		var xr := 120.0 + (t * 180.0 + balanco * t)
		var x := xl + (sin(p.fase + _t * 0.5) * 0.5 + 0.5) * (xr - xl)
		var y := yy + sin(_t * 0.7 + p.fase) * 3.0
		var a := 0.7 * sin(PI * t) * (0.5 + 0.5 * sin(_t * 1.5 + p.fase * 3.0))
		draw_rect(Rect2(x, y, p.tam, p.tam), Color(0.84, 0.91, 1.0, maxf(a, 0.0)))

	# Poeira quente perto dos pendentes
	for i in range(roundi(20 * densidade)):
		var fase := i * 1.7
		var x := 150.0 + (350.0 if i % 2 == 1 else 0.0) + sin(_t * 0.3 + fase) * 50.0
		var y := 70.0 + fmod(_t * 6.0 + i * 17.0, 150.0)
		var a := 0.5 * sin(PI * ((y - 70.0) / 150.0)) * (0.5 + 0.5 * sin(_t + fase))
		draw_rect(Rect2(x, y, 1, 1), Color(1.0, 0.88, 0.63, maxf(a, 0.0)))

	# Vagalumes
	for v in _vagalumes:
		var x: float = v.cx + sin(v.fase * 1.3) * v.raio + sin(v.fase * 0.47) * v.raio * 0.6
		var y: float = v.cy + cos(v.fase * 0.9) * v.raio * 0.45 + sin(v.fase * 0.31) * v.raio * 0.3
		var k := pow(0.5 + 0.5 * sin(_t * v.pulso + v.cx), 2.2)
		_brilhar(x, y, 9.0, v.cor, 0.55 * k)
		draw_rect(Rect2(x - 0.5, y - 0.5, 1.2, 1.2), Color(1, 1, 0.9, 0.35 + 0.65 * k))

	# Mariposas em volta dos pendentes
	for m in _mariposas:
		var x: float = m.lampada + cos(m.ang) * m.raio
		var y: float = 40.0 + sin(m.ang * 1.3) * m.raio * 0.5 + sin(_t * 9.0 + m.fase) * 0.8
		var asa := absf(sin(_t * 22.0 + m.fase)) * 2.0 + 0.5
		draw_rect(Rect2(x - asa, y, asa, 1), Color(0.94, 0.9, 0.78, 0.85))
		draw_rect(Rect2(x + 0.5, y, asa, 1), Color(0.94, 0.9, 0.78, 0.85))
		draw_rect(Rect2(x, y, 1, 1.5), Color(0.47, 0.39, 0.31, 0.9))
