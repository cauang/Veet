extends Control
## Linha tracejada usada como separador na prancheta.

@export var cor := Color(0.48, 0.35, 0.25, 0.45)
@export var traco := 3.0
@export var vazio := 2.0


func _draw() -> void:
	var x := 0.0
	while x < size.x:
		draw_rect(Rect2(x, 0, minf(traco, size.x - x), 1), cor)
		x += traco + vazio
