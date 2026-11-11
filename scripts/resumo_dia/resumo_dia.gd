extends Control
## Resumo do Dia: nota e numeros do caso que acabou de ser resolvido.
##
## Os dados chegam em GerenciadorCenas.dados_partida (preenchido pela batalha).
## No fim o jogador escolhe: jogar de novo ou voltar ao menu principal. Nada
## acontece sozinho, ele nunca e mandado para a Home sem querer.

const COR_NORMAL := Color(0.89, 0.8, 0.64)
const COR_SEL := Color(0.949, 0.839, 0.459)
const CORES_NOTA := {"S": Color(0.949, 0.839, 0.459), "A": Color(0.659, 0.835, 0.729),
		"B": Color(0.62, 0.77, 0.88), "C": Color(0.91, 0.71, 0.72)}

@onready var caso: Label = %Caso
@onready var nota: Label = %Nota
@onready var vinculo: Label = %Vinculo
@onready var pistas: Label = %Pistas
@onready var erros: Label = %Erros
@onready var estresse: Label = %Estresse
@onready var btn_novamente: Button = %BtnNovamente
@onready var btn_menu: Button = %BtnMenu

var _botoes: Array[Button] = []
var _indice := 0
var _pronto := false
var _audio: Node


func _ready() -> void:
	_audio = get_node_or_null("/root/GerenciadorAudio")
	var d: Dictionary = GerenciadorCenas.dados_partida

	caso.text = "Caso: %s%s" % [d.get("paciente", "-"), "  (tutor: %s)" % d["tutor"] if d.get("tutor", "") != "" else ""]
	var letra := String(d.get("nota", "-"))
	nota.text = letra
	nota.add_theme_color_override("font_color", CORES_NOTA.get(letra, COR_SEL))
	vinculo.text = "Vínculo restante: %s/%s" % [d.get("vinculo", "-"), d.get("vinculo_max", "-")]
	pistas.text = "Pistas coletadas: %s" % d.get("pistas", "-")
	erros.text = "Erros clínicos: %s" % d.get("erros", "-")
	estresse.text = "Estresse final: %s/10" % d.get("estresse", "-")

	_botoes = [btn_novamente, btn_menu]
	btn_novamente.pressed.connect(_ativar.bind(0))
	btn_menu.pressed.connect(_ativar.bind(1))
	btn_novamente.mouse_entered.connect(_selecionar.bind(0))
	btn_menu.mouse_entered.connect(_selecionar.bind(1))
	_marcar()

	# Pequena pausa para o jogador ver a nota antes de poder escolher.
	await get_tree().create_timer(0.8).timeout
	_pronto = true
	if _audio != null:
		_audio.call("bonus")


func _unhandled_input(evento: InputEvent) -> void:
	if not _pronto:
		return
	if evento.is_action_pressed("ui_left") or evento.is_action_pressed("ui_right"):
		_selecionar(wrapi(_indice + (1 if evento.is_action_pressed("ui_right") else -1), 0, _botoes.size()))
	elif evento.is_action_pressed("ui_accept"):
		_ativar(_indice)
	else:
		return
	get_viewport().set_input_as_handled()


func _selecionar(i: int) -> void:
	if i == _indice:
		return
	_indice = i
	if _audio != null:
		_audio.call("hover")
	_marcar()


func _marcar() -> void:
	for i in _botoes.size():
		var sel := i == _indice
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color(0, 0, 0, 0.92)
		estilo.border_color = COR_SEL if sel else COR_NORMAL
		estilo.set_border_width_all(3)
		for nome in ["normal", "hover", "pressed", "focus"]:
			_botoes[i].add_theme_stylebox_override(nome, estilo)
		for nome in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			_botoes[i].add_theme_color_override(nome, COR_SEL if sel else COR_NORMAL)


func _ativar(i: int) -> void:
	if not _pronto:
		return
	_pronto = false
	if _audio != null:
		_audio.call("confirmar")
	if i == 0:
		GerenciadorCenas.iniciar_jogo()
	else:
		GerenciadorCenas.voltar_ao_menu()
