extends Control
## Particulas do ambulatorio com mistura normal.
##
## Chuva e gotas na janela, vapor da caneca, folhas caindo das plantas,
## coracoes subindo dos gatos, brilhos e a vinheta quente da tela.
## Coordenadas da base 640x360; o no e ampliado 2x.

@export var densidade := 2.0

const JANELA := Rect2(27, 34, 92, 88)
const PLANTAS := [516.0, 628.0, 150.0]

var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _chuva: Array = []
var _gotas: Array = []
var _vapor: Array = []
var _coracoes: Array = []
var _folhas: Array = []
var _brilhos: Array = []
var _prox_vapor := 0.0
var _prox_coracao := 1.5
var _prox_folha := 3.0
var _prox_brilho := 0.5
var _vinheta: Texture2D


func _ready() -> void:
	_rng.randomize()
	_vinheta = _criar_vinheta()

	for i in range(roundi(75 * densidade)):
		_chuva.append({
			"x": JANELA.position.x + _rng.randf() * JANELA.size.x,
			"y": JANELA.position.y + _rng.randf() * JANELA.size.y,
			"vel": 70.0 + _rng.randf() * 80.0,
			"comp": 3.0 + _rng.randf() * 5.0,
		})

	for i in range(roundi(6 * densidade)):
		_gotas.append({
			"x": 30.0 + _rng.randf() * 86.0, "y": 36.0 + _rng.randf() * 80.0,
			"vel": 3.0 + _rng.randf() * 7.0, "raio": 0.8 + _rng.randf() * 0.9, "rastro": [],
		})


func _criar_vinheta() -> Texture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.32, 1.0])
	grad.colors = PackedColorArray([Color(0.08, 0.04, 0.02, 0.0), Color(0.08, 0.04, 0.02, 0.0), Color(0.08, 0.04, 0.02, 0.6)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 144
	return tex


func _process(delta: float) -> void:
	_t += delta
	_atualizar_chuva(delta)
	_atualizar_gotas(delta)
	_gerar_particulas(delta)
	queue_redraw()


func _atualizar_chuva(delta: float) -> void:
	for r in _chuva:
		r.y += delta * r.vel
		r.x -= delta * r.vel * 0.18
		if r.y > JANELA.end.y or r.x < JANELA.position.x:
			r.y = JANELA.position.y
			r.x = JANELA.position.x + _rng.randf() * (JANELA.size.x + 4.0)


func _atualizar_gotas(delta: float) -> void:
	for g in _gotas:
		var lento := 1.0 if sin(_t + g.x) > 0.3 else 0.15
		g.y += delta * g.vel * lento
		g.rastro.append(Vector2(g.x, g.y))
		if g.rastro.size() > 10:
			g.rastro.pop_front()
		if g.y > JANELA.end.y:
			g.y = JANELA.position.y
			g.x = 30.0 + _rng.randf() * 86.0
			g.rastro.clear()


func _gerar_particulas(delta: float) -> void:
	# Vapor da caneca
	_prox_vapor -= delta
	if _prox_vapor <= 0.0:
		_vapor.append({"x": 84.0 + _rng.randf() * 3.0, "y": 140.0, "t": 0.0, "fase": _rng.randf() * 6.0})
		_prox_vapor = 0.28 / densidade
	for i in range(_vapor.size() - 1, -1, -1):
		_vapor[i].t += delta * 0.55
		if _vapor[i].t > 1.0:
			_vapor.remove_at(i)

	# Coracoes dos gatos
	_prox_coracao -= delta
	if _prox_coracao <= 0.0:
		var esquerda := _rng.randf() < 0.5
		_coracoes.append({
			"x": (118.0 if esquerda else 522.0) + (_rng.randf() - 0.5) * 40.0, "y": 200.0, "t": 0.0,
			"fase": _rng.randf() * 6.0, "tam": 1.6 if esquerda else 1.3,
		})
		_prox_coracao = (1.8 + _rng.randf() * 2.2) / densidade
	for i in range(_coracoes.size() - 1, -1, -1):
		_coracoes[i].t += delta * 0.4
		if _coracoes[i].t > 1.0:
			_coracoes.remove_at(i)

	# Folhas das plantas penduradas
	_prox_folha -= delta
	if _prox_folha <= 0.0:
		var x: float = PLANTAS[_rng.randi() % PLANTAS.size()]
		_folhas.append({"x": x, "y": 42.0, "t": 0.0, "fase": _rng.randf() * 6.0, "vx": (_rng.randf() - 0.5) * 10.0})
		_prox_folha = (3.0 + _rng.randf() * 3.0) / densidade
	for i in range(_folhas.size() - 1, -1, -1):
		var f = _folhas[i]
		f.t += delta * 0.16
		f.y += delta * (12.0 + f.t * 10.0)
		if f.y > 335.0:
			_folhas.remove_at(i)

	# Brilhos
	_prox_brilho -= delta
	if _prox_brilho <= 0.0:
		var x: float
		var y: float
		if _rng.randf() < 0.5:
			x = 190.0 + _rng.randf() * 270.0
			y = 48.0 + _rng.randf() * 80.0
		else:
			x = 40.0 + _rng.randf() * 560.0
			y = 190.0 + _rng.randf() * 150.0
		_brilhos.append({
			"x": x, "y": y, "t": 0.0, "tam": 0.8 + _rng.randf() * 0.8,
			"cor": Color(1.0, 0.94, 0.75) if _rng.randf() < 0.6 else Color(0.75, 0.88, 1.0),
		})
		_prox_brilho = (0.22 + _rng.randf() * 0.3) / densidade
	for i in range(_brilhos.size() - 1, -1, -1):
		_brilhos[i].t += delta * 1.1
		if _brilhos[i].t > 1.0:
			_brilhos.remove_at(i)


# ---------------------------------------------------------------------- draw

func _draw() -> void:
	_desenhar_chuva()
	_desenhar_vapor()
	_desenhar_coracoes()
	_desenhar_folhas()
	_desenhar_brilhos()
	draw_texture_rect(_vinheta, Rect2(0, 0, 640, 360), false)


func _desenhar_chuva() -> void:
	var cor := Color(0.75, 0.84, 1.0, 0.45)
	for r in _chuva:
		var a := Vector2(r.x, r.y)
		var b := Vector2(r.x + r.comp * 0.18, r.y - r.comp)
		if JANELA.has_point(a) and JANELA.has_point(b):
			draw_line(a, b, cor, 0.6)

	for g in _gotas:
		for q in g.rastro:
			draw_rect(Rect2(q.x, q.y, 0.7, 1.0), Color(0.84, 0.92, 1.0, 0.25))
		draw_circle(Vector2(g.x, g.y), g.raio, Color(0.9, 0.95, 1.0, 0.6))

	# Respingos no parapeito
	for i in range(4):
		var q := fmod(_t * 3.0 + i * 0.37, 1.0)
		draw_rect(Rect2(34.0 + i * 24.0 + sin(float(i)) * 6.0, 126.0 - q * 3.0, 0.8, 0.8), Color(0.78, 0.88, 1.0, 0.5))


func _desenhar_vapor() -> void:
	for s in _vapor:
		var x: float = s.x + sin(s.fase + s.t * 5.0) * 3.0 * s.t
		var y: float = s.y - s.t * 28.0
		draw_circle(Vector2(x, y), 1.2 + s.t * 2.0, Color(1, 1, 1, 0.28 * sin(PI * s.t)))


func _desenhar_coracoes() -> void:
	var celulas := [
		Vector2i(1, 0), Vector2i(2, 0), Vector2i(4, 0), Vector2i(5, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2),
		Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3),
		Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(3, 5),
	]
	for h in _coracoes:
		var x: float = h.x + sin(h.fase + h.t * 6.0) * 5.0
		var y: float = h.y - h.t * 50.0
		var cor := Color(1.0, 0.48, 0.61, sin(PI * h.t) * 0.95)
		for c in celulas:
			draw_rect(Rect2(x + (c.x - 3) * h.tam, y + c.y * h.tam, h.tam, h.tam), cor)


func _desenhar_folhas() -> void:
	for f in _folhas:
		var x: float = f.x + sin(f.fase + f.t * 14.0) * 8.0 + f.vx * f.t * 8.0
		draw_set_transform(Vector2(x, f.y), sin(f.fase + f.t * 10.0), Vector2.ONE)
		draw_rect(Rect2(-1.5, -0.7, 3.0, 1.4), Color(0.39, 0.75, 0.43, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _desenhar_brilhos() -> void:
	for s in _brilhos:
		var a := sin(PI * s.t)
		var cor := Color(s.cor.r, s.cor.g, s.cor.b, a)
		var tam: float = s.tam
		draw_rect(Rect2(s.x - tam / 2.0, s.y - tam * 2.0, tam, tam * 4.0), cor)
		draw_rect(Rect2(s.x - tam * 2.0, s.y - tam / 2.0, tam * 4.0, tam), cor)
		draw_rect(Rect2(s.x - tam / 2.0, s.y - tam / 2.0, tam, tam), Color(1, 1, 1, a))
