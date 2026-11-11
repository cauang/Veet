extends Control
## Sala de Triagem do primeiro caso (Fibonacci).
##
## Por enquanto e uma conversa linear com o Prof. Euler (data/dialogos/
## triagem_fibonacci.json). A anamnese ramificada (DAG) do caso entra aqui
## quando o card "Primeiro caso do Fibonacci" estiver pronto: basta trocar o
## dialogo linear pela arvore de decisao e manter o fim chamando
## GerenciadorCenas.avancar(). ESC pula a cena.

const DIALOGO := "res://data/dialogos/triagem_fibonacci.json"

@onready var protagonista: Personagem = %Protagonista
@onready var helena: Personagem = %Helena
@onready var euler: Personagem = %Euler
@onready var caixa: CaixaDialogo = %CaixaDialogo

var _personagens: Dictionary = {}
var _encerrada := false


func _ready() -> void:
	_personagens = {"protagonista": protagonista, "helena": helena, "euler": euler}

	helena.virado_para_esquerda = false
	euler.virado_para_esquerda = true
	euler.position.x = 1500.0

	caixa.fala_iniciada.connect(_on_fala_iniciada)
	caixa.texto_completo.connect(_on_texto_completo)
	caixa.dialogo_concluido.connect(_encerrar)

	await get_tree().create_timer(0.7).timeout
	await euler.andar_ate(960.0, 230.0)
	euler.virado_para_esquerda = true
	caixa.tocar_arquivo(DIALOGO)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		_encerrar()


func _on_fala_iniciada(_indice: int, fala: Dictionary) -> void:
	var quem: Node = _personagens.get(String(fala.get("quem", "")))
	for p: Personagem in _personagens.values():
		if p != quem:
			p.tocar("idle")
	if quem != null:
		(quem as Personagem).tocar(String(fala.get("anim", "falar")))


func _on_texto_completo(_indice: int) -> void:
	for p: Personagem in _personagens.values():
		p.tocar("idle")


func _encerrar() -> void:
	if _encerrada:
		return
	_encerrada = true
	await get_tree().create_timer(0.3).timeout
	GerenciadorCenas.avancar()
