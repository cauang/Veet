extends Control
## HUD da batalha: barra de Vinculo (vida) e tempo restante da fase de esquiva.

signal vida_alterada(vida_atual: int, vida_maxima: int)
signal vida_zerada()

@onready var barra_vida: ProgressBar = $BarraVida
@onready var texto_saude: Label = $TextoSaude
@onready var texto_tempo: Label = $TextoTempo
@onready var texto_fase: Label = $TextoFase

var vida_atual: int = 8
var vida_maxima: int = 10


var _tween_fase: Tween


func _ready() -> void:
	texto_tempo.visible = false
	texto_fase.visible = false
	atualizar_hud()


# Atualiza a vida atual e maxima.
func atualizar_vida(nova_vida: int, nova_vida_maxima: int) -> void:
	vida_maxima = maxi(1, nova_vida_maxima)
	vida_atual = clampi(nova_vida, 0, vida_maxima)

	atualizar_hud()
	vida_alterada.emit(vida_atual, vida_maxima)


# Atualiza a barra e o texto.
func atualizar_hud() -> void:
	barra_vida.max_value = vida_maxima
	barra_vida.value = vida_atual

	texto_saude.text = str(vida_atual) + " / " + str(vida_maxima)


# Diminui a vida. Retorna false se o dano foi ignorado (vida ja zerada).
func receber_dano(quantidade: int = 1) -> bool:
	if vida_atual <= 0:
		return false

	atualizar_vida(vida_atual - quantidade, vida_maxima)
	piscar_barra()

	if vida_atual <= 0:
		vida_zerada.emit()

	return true


# Faz a barra piscar ao receber dano.
func piscar_barra() -> void:
	var tween = create_tween()

	for i in range(3):
		tween.tween_property(self, "modulate", Color(1, 0.3, 0.3), 0.08)
		tween.tween_property(self, "modulate", Color.WHITE, 0.08)


# Mostra o tempo restante da fase de esquiva.
func mostrar_tempo(restante: float) -> void:
	texto_tempo.visible = true
	texto_tempo.text = "%0.1fs" % maxf(restante, 0.0)
	if restante <= 3.0:
		texto_tempo.modulate = Color(1.0, 0.45, 0.35)
	elif restante <= 6.0:
		texto_tempo.modulate = Color(1.0, 0.9, 0.45)
	else:
		texto_tempo.modulate = Color.WHITE


func esconder_tempo() -> void:
	texto_tempo.visible = false
	texto_tempo.modulate = Color.WHITE


# Mostra o nome da fase por um instante (telegraph).
func mostrar_fase(nome: String, subtitulo := "Desvie!") -> void:
	texto_fase.visible = true
	texto_fase.modulate = Color(1, 1, 1, 0)
	texto_fase.text = nome.to_upper() + "\n" + subtitulo

	if _tween_fase != null and _tween_fase.is_valid():
		_tween_fase.kill()

	_tween_fase = create_tween()
	_tween_fase.tween_property(texto_fase, "modulate:a", 1.0, 0.15)
	_tween_fase.tween_interval(1.15)
	_tween_fase.tween_property(texto_fase, "modulate:a", 0.0, 0.35)
	_tween_fase.tween_callback(func(): texto_fase.visible = false)
