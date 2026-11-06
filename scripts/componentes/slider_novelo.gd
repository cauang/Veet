class_name SliderNovelo
extends Range
## Roldana de volume: um fio de la vai se enchendo e um novelo faz de botao.
##
## Funciona como qualquer Range (value, min_value, max_value, step e o sinal
## value_changed). Arraste o novelo com o mouse, clique no trilho ou use as
## setas do teclado. O desenho segue o valor com suavizacao.
## Desenhado na escala da base 640x360 (1 pixel de arte = 1 unidade).

const NOVELO: Texture2D = preload("res://assets/home/logo/novelo.png")
const COR_BORDA := Color("#2e1d13")
const COR_MADEIRA := Color("#6b4a33")
const COR_FIO := Color("#c4574f")
const COR_FIO_ESCURO := Color("#e2685f")
const ALTURA_TRILHO := 8.0
const TAMANHO_NOVELO := 17.0

var _arrastando := false
var _visual := 0.0


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_visual = _razao()
	value_changed.connect(_on_valor_mudou)


func _razao() -> float:
	if max_value <= min_value:
		return 0.0
	return clampf((value - min_value) / (max_value - min_value), 0.0, 1.0)


func _on_valor_mudou(_novo: float) -> void:
	queue_redraw()


func _process(delta: float) -> void:
	var alvo := _razao()
	if absf(_visual - alvo) > 0.0004:
		_visual = lerpf(_visual, alvo, 1.0 - exp(-delta * 22.0))
		queue_redraw()
	elif _visual != alvo:
		_visual = alvo
		queue_redraw()


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		_arrastando = evento.pressed
		if evento.pressed:
			grab_focus()
			_definir_por_x(evento.position.x)
		accept_event()
	elif evento is InputEventMouseMotion and _arrastando:
		_definir_por_x(evento.position.x)
		accept_event()
	elif evento.is_action_pressed("ui_left") or evento.is_action_pressed("ui_down"):
		value -= step
		accept_event()
	elif evento.is_action_pressed("ui_right") or evento.is_action_pressed("ui_up"):
		value += step
		accept_event()


func _definir_por_x(x: float) -> void:
	var u := clampf(x / maxf(size.x, 1.0), 0.0, 1.0)
	value = min_value + u * (max_value - min_value)


func _notification(que: int) -> void:
	if que == NOTIFICATION_FOCUS_ENTER or que == NOTIFICATION_FOCUS_EXIT or que == NOTIFICATION_MOUSE_ENTER or que == NOTIFICATION_MOUSE_EXIT:
		queue_redraw()


func _draw() -> void:
	var cy := size.y * 0.5
	var topo := cy - ALTURA_TRILHO * 0.5

	# Trilho de madeira com sombra interna
	draw_rect(Rect2(0, topo, size.x, ALTURA_TRILHO), COR_BORDA)
	draw_rect(Rect2(1, topo + 1, size.x - 2, ALTURA_TRILHO - 2), COR_MADEIRA)
	draw_rect(Rect2(1, topo + 1, size.x - 2, 2), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(0, topo + ALTURA_TRILHO, size.x, 1), Color(1, 1, 1, 0.3))

	# Fio de la trancado em diagonal
	var largura := int(roundf(_visual * (size.x - 2.0)))
	for x in range(largura):
		for y in range(int(ALTURA_TRILHO) - 2):
			var listra := (x + y) % 7 < 4
			draw_rect(Rect2(1 + x, topo + 1 + y, 1, 1), COR_FIO_ESCURO if listra else COR_FIO)
	if largura > 0:
		draw_rect(Rect2(1, topo + 1, largura, 2), Color(0, 0, 0, 0.28))

	# Novelo: gira conforme o valor
	var centro := Vector2(_visual * size.x, cy)
	if has_focus() or _arrastando or get_global_rect().has_point(get_global_mouse_position()):
		draw_circle(centro, TAMANHO_NOVELO * 0.62, Color(1.0, 0.85, 0.54, 0.35))
	draw_circle(centro + Vector2(0, 2.0), TAMANHO_NOVELO * 0.45, Color(0.23, 0.14, 0.08, 0.45))
	var escala := TAMANHO_NOVELO / float(NOVELO.get_width())
	draw_set_transform(centro, _visual * TAU * 2.0, Vector2(escala, escala))
	draw_texture(NOVELO, -NOVELO.get_size() * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
