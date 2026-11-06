class_name InterruptorMadeira
extends Button
## Interruptor de madeira: o botao desliza e a trilha fica verde quando ligado.
## E um Button sem aparencia propria: todo o desenho e feito aqui.
## Usa `button_pressed`, `set_pressed_no_signal()` e o sinal `toggled`, como CheckButton.
## Desenhado na escala da base 640x360.

const COR_BORDA := Color("#2e1d13")
const COR_DESLIGADO := Color("#6b4a33")
const COR_LIGADO := Color("#5fa86a")
const COR_BOTAO := Color("#f1e4c8")

var _t := 0.0


func _ready() -> void:
	for estado in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(estado, StyleBoxEmpty.new())
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_t = 1.0 if button_pressed else 0.0
	toggled.connect(func(_ligado: bool) -> void: queue_redraw())


func _process(delta: float) -> void:
	var alvo := 1.0 if button_pressed else 0.0
	if _t != alvo:
		_t = move_toward(_t, alvo, delta * 6.0)
		queue_redraw()


func _notification(que: int) -> void:
	if que == NOTIFICATION_FOCUS_ENTER or que == NOTIFICATION_FOCUS_EXIT or que == NOTIFICATION_MOUSE_ENTER or que == NOTIFICATION_MOUSE_EXIT:
		queue_redraw()


func _suave(t: float) -> float:
	# Sai com um pequeno excesso e assenta (efeito "mola").
	var c1 := 1.5
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var k := _suave(_t)

	draw_rect(Rect2(0, 0, w, h), COR_BORDA)
	draw_rect(Rect2(1, 1, w - 2, h - 2), COR_DESLIGADO.lerp(COR_LIGADO, clampf(_t, 0.0, 1.0)))
	draw_rect(Rect2(1, 1, w - 2, 2), Color(0, 0, 0, 0.35))

	var lado := h - 4.0
	var x := lerpf(2.0, w - 2.0 - lado, k)
	draw_rect(Rect2(x, 2, lado, lado), COR_BORDA)
	draw_rect(Rect2(x + 1, 3, lado - 2, lado - 2), COR_BOTAO)
	draw_rect(Rect2(x + lado - 3, 3, 2, lado - 2), Color(0.48, 0.35, 0.25, 0.35))

	if has_focus() or is_hovered():
		draw_rect(Rect2(-1, -1, w + 2, h + 2), Color(1.0, 0.85, 0.54, 0.9), false, 1.0)
