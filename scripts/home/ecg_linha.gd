extends Control
## Linha de eletrocardiograma desenhada de forma suave (sem degraus).
##
## Dois usos:
##  - abertura do jogo: a linha e desenhada da esquerda para a direita conforme
##    `progresso` vai de 0 a 1 (animado por Tween);
##  - monitor da parede (`modo_monitor = true`): um batimento que varre a tela
##    continuamente, deixando um rastro que desaparece aos poucos.

@export var modo_monitor := false
@export var cor := Color(0.44, 0.88, 0.63)
@export var espessura := 4.0
@export var duracao_varredura := 2.4

var progresso := 0.0:
	set(valor):
		progresso = clampf(valor, 0.0, 1.0)
		queue_redraw()

# Forma do batimento da abertura, em unidades de 600 x 160.
const FORMA_ABERTURA: Array[Vector2] = [
	Vector2(0, 80), Vector2(170, 80), Vector2(182, 66), Vector2(194, 80),
	Vector2(222, 80), Vector2(236, 90), Vector2(252, 12), Vector2(270, 146),
	Vector2(286, 80), Vector2(326, 80), Vector2(338, 68), Vector2(350, 80),
	Vector2(600, 80),
]
const TAM_ABERTURA := Vector2(600, 160)

# Um batimento do monitor, em unidades de 50 x 50 (repete a cada 50).
const FORMA_MONITOR: Array[Vector2] = [
	Vector2(0, 28), Vector2(14, 28), Vector2(18, 28), Vector2(21, 18),
	Vector2(25, 42), Vector2(29, 10), Vector2(33, 34), Vector2(36, 28),
	Vector2(50, 28),
]
const LARGURA_BATIMENTO := 50.0
const ALTURA_MONITOR := 50.0

var _tempo := 0.0


func _process(delta: float) -> void:
	if modo_monitor:
		_tempo += delta
		queue_redraw()


func _draw() -> void:
	if modo_monitor:
		_desenhar_monitor()
	else:
		_desenhar_abertura()


func _desenhar_abertura() -> void:
	if progresso <= 0.0:
		return

	var escala := Vector2(size.x / TAM_ABERTURA.x, size.y / TAM_ABERTURA.y)
	var pontos := PackedVector2Array()
	for p in FORMA_ABERTURA:
		pontos.append(p * escala)

	# Comprimento total e ponto em que a linha termina neste instante.
	var total := 0.0
	for i in range(1, pontos.size()):
		total += pontos[i - 1].distance_to(pontos[i])

	var alvo := total * progresso
	var visiveis := PackedVector2Array([pontos[0]])
	var percorrido := 0.0
	for i in range(1, pontos.size()):
		var seg := pontos[i - 1].distance_to(pontos[i])
		if percorrido + seg >= alvo:
			var t := (alvo - percorrido) / maxf(seg, 0.001)
			visiveis.append(pontos[i - 1].lerp(pontos[i], t))
			break
		visiveis.append(pontos[i])
		percorrido += seg

	if visiveis.size() < 2:
		return

	# Brilho em camadas, do mais largo e fraco ao nucleo.
	draw_polyline(visiveis, Color(cor, 0.10), espessura * 5.0, true)
	draw_polyline(visiveis, Color(cor, 0.22), espessura * 2.6, true)
	draw_polyline(visiveis, cor, espessura, true)
	var ponta := visiveis[visiveis.size() - 1]
	draw_circle(ponta, espessura * 1.6, Color(1, 1, 1, 0.9))
	draw_circle(ponta, espessura * 3.4, Color(cor, 0.25))


func _desenhar_monitor() -> void:
	if size.x <= 1.0:
		return

	var escala := size.y / ALTURA_MONITOR
	var cursor := fposmod(_tempo / duracao_varredura, 1.0) * size.x
	var passo := 1.5

	# Dois trechos: de cursor ate a direita (rastro antigo) e da esquerda ate cursor.
	_tracar(cursor, size.x, cursor, escala, passo)
	_tracar(0.0, cursor, cursor, escala, passo)

	# Ponto brilhante na cabeca do rastro.
	var yc := _altura_em(cursor, escala)
	draw_circle(Vector2(cursor, yc), espessura * 1.4, Color(1, 1, 1, 0.9))
	draw_circle(Vector2(cursor, yc), espessura * 3.0, Color(cor, 0.25))


func _tracar(de: float, ate: float, cursor: float, escala: float, passo: float) -> void:
	if ate - de < passo:
		return

	var pontos := PackedVector2Array()
	var cores := PackedColorArray()
	var x := de
	while x <= ate:
		pontos.append(Vector2(x, _altura_em(x, escala)))
		var atras := fposmod(cursor - x, size.x) / size.x
		cores.append(Color(cor, clampf(1.0 - atras * 1.25, 0.0, 1.0)))
		x += passo

	if pontos.size() >= 2:
		draw_polyline_colors(pontos, cores, espessura, true)


func _altura_em(x: float, escala: float) -> float:
	var u := fposmod(x / escala, LARGURA_BATIMENTO)
	for i in range(1, FORMA_MONITOR.size()):
		var a := FORMA_MONITOR[i - 1]
		var b := FORMA_MONITOR[i]
		if u <= b.x:
			var t := (u - a.x) / maxf(b.x - a.x, 0.001)
			return lerpf(a.y, b.y, t) * escala
	return FORMA_MONITOR[FORMA_MONITOR.size() - 1].y * escala
