extends Control
## Cena de introducao: a Dra. Helena recebe o residente na clinica.
##
## A cena so organiza o palco; as falas vem de data/dialogos/introducao.json.
## Ao terminar chama GerenciadorCenas.avancar() (proxima etapa: triagem).
## Durante o desenvolvimento, ESC pula a cena.

const DIALOGO := "res://data/dialogos/introducao.json"

@onready var protagonista: Personagem = %Protagonista
@onready var helena: Personagem = %Helena
@onready var caixa: CaixaDialogo = %CaixaDialogo

var _personagens: Dictionary = {}
var _encerrada := false


func _ready() -> void:
	_personagens = {"protagonista": protagonista, "helena": helena}

	# Helena comeca fora da tela, a direita, e caminha ate o residente.
	helena.position.x = 1500.0
	helena.virado_para_esquerda = true

	caixa.fala_iniciada.connect(_on_fala_iniciada)
	caixa.texto_completo.connect(_on_texto_completo)
	caixa.dialogo_concluido.connect(_encerrar)

	await get_tree().create_timer(0.7).timeout
	await helena.andar_ate(880.0, 230.0)
	helena.virado_para_esquerda = true
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
