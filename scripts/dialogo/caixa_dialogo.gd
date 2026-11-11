class_name CaixaDialogo
extends Control
## Caixa de dialogo estilo Undertale: retrato, nome e texto que "digita".
##
## Uso:
##   caixa.fala_iniciada.connect(...)         # opcional: reagir a cada fala
##   caixa.dialogo_concluido.connect(...)     # fim da conversa
##   caixa.tocar_arquivo("res://data/dialogos/introducao.json")
##
## Formato do JSON:
##   { "id": "introducao",
##     "falas": [ { "quem": "helena", "nome": "Dra. Helena",
##                  "expressao": "sorrindo", "anim": "acenar",
##                  "texto": "Boa noite, residente!" }, ... ] }
## "quem" e o id do personagem (usado para achar o retrato); "expressao" e um de
## neutro / falando / sorrindo / preocupado / surpreso. Campos extras ("anim",
## "evento"...) sao repassados no sinal fala_iniciada para a cena reagir.

signal fala_iniciada(indice: int, fala: Dictionary)
signal texto_completo(indice: int)   # terminou de digitar (hora de o personagem parar de falar)
signal fala_concluida(indice: int)   # jogador avancou para a proxima fala
signal dialogo_concluido()

## Caracteres por segundo no efeito de digitacao.
@export var velocidade_texto := 42.0

@onready var painel: PanelContainer = $Painel
@onready var retrato: TextureRect = %Retrato
@onready var nome: Label = %Nome
@onready var texto: Label = %Texto
@onready var seta: Label = $Seta

var falas: Array = []
var indice := -1
var _digitando := false
var _ativo := false
var _tween: Tween
var _audio: Node


func _ready() -> void:
	visible = false
	_audio = get_node_or_null("/root/GerenciadorAudio")


func _process(_delta: float) -> void:
	if seta.visible:
		seta.modulate.a = 1.0 if int(Time.get_ticks_msec() / 350.0) % 2 == 0 else 0.0


## Carrega o JSON e inicia a conversa. Retorna false se o arquivo for invalido.
func tocar_arquivo(caminho: String) -> bool:
	var lista := carregar_falas(caminho)
	if lista.is_empty():
		return false
	iniciar(lista)
	return true


static func carregar_falas(caminho: String) -> Array:
	if not FileAccess.file_exists(caminho):
		push_error("CaixaDialogo: arquivo nao encontrado: " + caminho)
		return []
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if dados is Dictionary and dados.get("falas") is Array:
		return dados["falas"]
	push_error("CaixaDialogo: JSON invalido (esperado {\"falas\": [...]}): " + caminho)
	return []


func iniciar(lista: Array) -> void:
	falas = lista
	indice = -1
	_ativo = true
	visible = true
	_proxima_fala()


func _unhandled_input(evento: InputEvent) -> void:
	if not _ativo:
		return
	var confirmou := evento.is_action_pressed("ui_accept")
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		confirmou = true
	if not confirmou:
		return
	get_viewport().set_input_as_handled()

	if _digitando:
		_completar_texto()
	else:
		_proxima_fala()


func _proxima_fala() -> void:
	if indice >= 0:
		fala_concluida.emit(indice)
	indice += 1
	if indice >= falas.size():
		_encerrar()
		return

	var fala: Dictionary = falas[indice]
	nome.text = String(fala.get("nome", ""))
	retrato.texture = Personagem.retrato_de(String(fala.get("quem", "")), fala.get("expressao", "neutro"))
	retrato.get_parent().visible = retrato.texture != null and not fala.get("sem_retrato", false)
	nome.visible = nome.text != ""
	texto.text = String(fala.get("texto", ""))
	texto.visible_ratio = 0.0
	seta.visible = false
	_digitando = true
	fala_iniciada.emit(indice, fala)

	if _tween != null and _tween.is_valid():
		_tween.kill()
	var duracao := maxf(texto.text.length() / velocidade_texto, 0.05)
	_tween = create_tween()
	_tween.tween_property(texto, "visible_ratio", 1.0, duracao)
	_tween.finished.connect(_texto_completo)


func _completar_texto() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	texto.visible_ratio = 1.0
	_texto_completo()


func _texto_completo() -> void:
	_digitando = false
	seta.visible = true
	texto_completo.emit(indice)
	if _audio != null and _audio.has_method("clique"):
		_audio.call("clique")


func _encerrar() -> void:
	_ativo = false
	visible = false
	dialogo_concluido.emit()


func esta_ativa() -> bool:
	return _ativo
