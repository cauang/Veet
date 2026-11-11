class_name CaixaConfirmacao
extends Control
## Caixa de confirmacao estilizada (no lugar do ConfirmationDialog padrao).
##
## Uso:
##   var caixa: CaixaConfirmacao = preload("res://scenes/componentes/caixa_confirmacao.tscn").instantiate()
##   add_child(caixa)
##   caixa.confirmado.connect(_ao_confirmar)
##   caixa.perguntar("FECHAR JOGO", "Tem certeza que deseja sair?", "SIM, FECHAR", "CANCELAR")
##
## Teclado: setas esquerda/direita escolhem, ENTER confirma e ESC cancela.
## Mouse: passar por cima seleciona e o clique confirma. O botao "nao" vem
## selecionado para evitar confirmar sem querer, e o foco volta para quem o
## tinha antes de a caixa abrir.

signal confirmado()
signal cancelado()

const COR_NORMAL := Color(0.89, 0.8, 0.64)
const COR_SEL := Color(0.949, 0.839, 0.459)
const PATA: Texture2D = preload("res://assets/patinha/patinha.png")

@onready var painel: PanelContainer = %Painel
@onready var titulo: Label = %Titulo
@onready var mensagem: Label = %Mensagem
@onready var btn_sim: Button = %BtnSim
@onready var btn_nao: Button = %BtnNao

var _foco_anterior: Control
var _tween: Tween
var _audio: Node
var _patas: Dictionary = {}


func _ready() -> void:
	_audio = get_node_or_null("/root/GerenciadorAudio")
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	for botao: Button in [btn_sim, btn_nao]:
		_estilizar(botao)
		botao.pressed.connect(_responder.bind(botao == btn_sim))
		botao.mouse_entered.connect(botao.grab_focus)
		botao.focus_entered.connect(_atualizar_foco)
		botao.focus_exited.connect(_atualizar_foco)
	# Vizinhos explicitos: esquerda/direita alternam os dois botoes.
	btn_sim.focus_neighbor_right = btn_nao.get_path()
	btn_nao.focus_neighbor_left = btn_sim.get_path()
	btn_sim.focus_neighbor_left = btn_nao.get_path()
	btn_nao.focus_neighbor_right = btn_sim.get_path()


## Abre a caixa. `texto_sim` / `texto_nao` personalizam os botoes.
func perguntar(texto_titulo: String, texto_mensagem: String, texto_sim := "SIM", texto_nao := "NÃO") -> void:
	titulo.text = texto_titulo
	mensagem.text = texto_mensagem
	btn_sim.text = texto_sim
	btn_nao.text = texto_nao

	_foco_anterior = get_viewport().gui_get_focus_owner()
	move_to_front()
	visible = true
	modulate.a = 0.0
	painel.pivot_offset = painel.size / 2.0
	painel.scale = Vector2(0.92, 0.92)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.14)
	_tween.tween_property(painel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_som("clique")
	btn_nao.grab_focus()
	_atualizar_foco()


## Enquanto aberta, a caixa trata todo o teclado/controle e nao deixa nada vazar
## para a cena de baixo (senao o ENTER que confirma tambem agiria no menu).
func _input(evento: InputEvent) -> void:
	if not visible:
		return
	if evento is InputEventMouse:
		return   # o fundo escuro ja bloqueia os cliques; os botoes recebem o mouse normalmente

	if evento.is_action_pressed("ui_cancel"):
		_responder(false)
	elif evento.is_action_pressed("ui_accept"):
		_responder(btn_sim.has_focus())
	elif evento.is_action_pressed("ui_left") or evento.is_action_pressed("ui_right"):
		(btn_nao if btn_sim.has_focus() else btn_sim).grab_focus()
		_som("hover")
	get_viewport().set_input_as_handled()


func _responder(sim: bool) -> void:
	if not visible:
		return
	_som("confirmar" if sim else "clique")
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = false
	if _foco_anterior != null and is_instance_valid(_foco_anterior) and _foco_anterior.is_inside_tree():
		_foco_anterior.grab_focus()
	if sim:
		confirmado.emit()
	else:
		cancelado.emit()


# ------------------------------------------------------------------ aparencia

func _estilizar(botao: Button) -> void:
	botao.add_theme_font_size_override("font_size", 14)
	var pata := TextureRect.new()
	pata.texture = PATA
	pata.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pata.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pata.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pata.custom_minimum_size = Vector2(26, 26)
	pata.size = Vector2(26, 26)
	pata.position = Vector2(14, 11)
	pata.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pata.visible = false
	botao.add_child(pata)
	_patas[botao] = pata


func _atualizar_foco() -> void:
	for botao: Button in [btn_sim, btn_nao]:
		var sel := botao.has_focus()
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color(0.06, 0.08, 0.12, 0.96) if sel else Color(0, 0, 0, 0.9)
		estilo.border_color = COR_SEL if sel else COR_NORMAL
		estilo.set_border_width_all(3)
		estilo.content_margin_left = 44.0
		estilo.content_margin_right = 12.0
		for nome in ["normal", "hover", "pressed", "focus", "disabled"]:
			botao.add_theme_stylebox_override(nome, estilo)
		for nome in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			botao.add_theme_color_override(nome, COR_SEL if sel else COR_NORMAL)
		(_patas[botao] as TextureRect).visible = sel


func _som(nome: String) -> void:
	if _audio != null and _audio.has_method(nome):
		_audio.call(nome)
