extends Control
## Batalha clinica por turnos (estilo Undertale) de um paciente.
##
## Ciclo do turno:
##   1. MENU: o jogador escolhe TRATAMENTO / ANALISAR / CARINHO / DIAGNOSTICO;
##   2. SUBMENU: escolhe o que fazer dentro da acao (na propria caixa de batalha);
##   3. TEXTO: o resultado aparece e a barra de DIAGNOSTICO sobe;
##   4. ESQUIVA: vez do paciente, o minigame da caixinha com a patinha;
##   volta ao MENU. Quando a barra chega a 100% o caso esta resolvido e o jogo
##   segue para a proxima etapa (GerenciadorCenas.avancar()).
##
## Todo o conteudo (acoes, pistas, progresso, textos) vem de
## data/batalha/<paciente_id>.json. Para outro paciente, troque `paciente_id`.

enum Estado { MENU, SUBMENU, TEXTO, ESQUIVA, FIM }

const ORDEM_ACOES: Array[String] = ["tratamento", "analisar", "carinho", "diagnostico"]
const ROTULOS := {
	"tratamento": "TRATAMENTO",
	"analisar": "ANALISAR",
	"carinho": "CARINHO",
	"diagnostico": "DIAGNÓSTICO",
}
const SPRITE_PACIENTE := "res://assets/animais/%s/exportado/%s_%s.png"
const FONTE: Font = preload("res://assets/fontes/PressStart2P-Regular.ttf")
const COR_NORMAL := Color(0.89, 0.8, 0.64)
const COR_SEL := Color(0.949, 0.839, 0.459)
const COR_USADO := Color(0.55, 0.55, 0.6)
const VELOCIDADE_TEXTO := 46.0

@export var paciente_id := "fibonacci"

@onready var paciente: TextureRect = %Paciente
@onready var caixinha = %Caixinha
@onready var texto_caixa: Label = %TextoCaixa
@onready var lista: VBoxContainer = %ListaOpcoes
@onready var menu: HBoxContainer = %Menu
@onready var cursor: TextureRect = %Cursor
@onready var barra_diagnostico: ProgressBar = %BarraDiagnostico
@onready var barra_estresse: ProgressBar = %BarraEstresse
@onready var resolvido: Control = %Resolvido
@onready var gato_final: TextureRect = %GatoFinal

var caso: Dictionary = {}
var estado := Estado.MENU
var progresso := 0
var estresse := 0
var pistas: Array[String] = []
var diagnostico_confirmado := false

var _usados: Dictionary = {}
var _acao := ""
var _opcoes: Array = []
var _indice_menu := 0
var _indice_sub := 0
var _botoes: Array[Button] = []
var _rotulos_sub: Array[Label] = []
var _digitando := false
var _tween_texto: Tween
var _depois_do_texto := Callable()
var _audio: Node
var _estilo_normal: StyleBoxFlat
var _estilo_sel: StyleBoxFlat


func _ready() -> void:
	_audio = get_node_or_null("/root/GerenciadorAudio")
	caso = _carregar_caso()
	if caso.is_empty():
		push_error("Batalha: caso '%s' nao encontrado em data/batalha/" % paciente_id)
		return

	_criar_estilos()
	_criar_menu()
	caixinha.fase_sobrevivida.connect(_on_esquiva_terminou)

	barra_diagnostico.value = 0
	barra_estresse.value = 0
	_atualizar_paciente()
	_animar_paciente()
	_voltar_ao_menu(String(caso["texto_estados"]["neutro"]))


func _carregar_caso() -> Dictionary:
	var caminho := "res://data/batalha/%s.json" % paciente_id
	if not FileAccess.file_exists(caminho):
		return {}
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	return dados if dados is Dictionary else {}


# ------------------------------------------------------------------ montagem

func _criar_estilos() -> void:
	_estilo_normal = _novo_estilo(COR_NORMAL)
	_estilo_sel = _novo_estilo(COR_SEL)


func _novo_estilo(borda: Color) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = Color(0, 0, 0, 0.92)
	e.border_color = borda
	e.set_border_width_all(3)
	e.content_margin_left = 54.0
	e.content_margin_right = 8.0
	e.content_margin_top = 8.0
	e.content_margin_bottom = 8.0
	return e


func _criar_menu() -> void:
	for i in ORDEM_ACOES.size():
		var b := Button.new()
		b.text = ROTULOS[ORDEM_ACOES[i]]
		b.custom_minimum_size = Vector2(270, 42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", FONTE)
		b.add_theme_font_size_override("font_size", 13)
		b.mouse_entered.connect(_on_botao_hover.bind(i))
		b.pressed.connect(_on_botao_pressionado.bind(i))
		menu.add_child(b)
		_botoes.append(b)
	_marcar_menu()


func _marcar_menu() -> void:
	for i in _botoes.size():
		var sel := i == _indice_menu and estado == Estado.MENU
		var estilo := _estilo_sel if sel else _estilo_normal
		var cor := COR_SEL if sel else COR_NORMAL
		for nome in ["normal", "hover", "pressed", "focus", "disabled"]:
			_botoes[i].add_theme_stylebox_override(nome, estilo)
		for nome in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			_botoes[i].add_theme_color_override(nome, cor)
	_posicionar_cursor()


func _posicionar_cursor() -> void:
	await get_tree().process_frame
	if estado == Estado.MENU:
		var b := _botoes[_indice_menu]
		cursor.global_position = b.global_position + Vector2(14, (b.size.y - cursor.size.y) / 2.0)
		cursor.visible = true
	elif estado == Estado.SUBMENU and _indice_sub < _rotulos_sub.size():
		var l := _rotulos_sub[_indice_sub]
		cursor.global_position = l.global_position + Vector2(-38, (l.size.y - cursor.size.y) / 2.0)
		cursor.visible = true
	else:
		cursor.visible = false


# ------------------------------------------------------------------ entrada

func _unhandled_input(evento: InputEvent) -> void:
	match estado:
		Estado.MENU:
			if evento.is_action_pressed("ui_left"):
				_mover_menu(-1)
			elif evento.is_action_pressed("ui_right"):
				_mover_menu(1)
			elif evento.is_action_pressed("ui_accept"):
				_ativar_acao(ORDEM_ACOES[_indice_menu])
			else:
				return
		Estado.SUBMENU:
			if evento.is_action_pressed("ui_up"):
				_mover_sub(-1)
			elif evento.is_action_pressed("ui_down"):
				_mover_sub(1)
			elif evento.is_action_pressed("ui_accept"):
				_escolher_opcao(_opcoes[_indice_sub])
			elif evento.is_action_pressed("ui_cancel"):
				_voltar_ao_menu(String(caso["texto_estados"][_estado_visual()]))
			else:
				return
		Estado.TEXTO:
			if evento.is_action_pressed("ui_accept") or _clique(evento):
				if _digitando:
					_completar_texto()
				else:
					var proximo := _depois_do_texto
					_depois_do_texto = Callable()
					if proximo.is_valid():
						proximo.call()
			else:
				return
		Estado.FIM:
			if evento.is_action_pressed("ui_accept") or _clique(evento):
				GerenciadorCenas.avancar()
			else:
				return
		_:
			return
	get_viewport().set_input_as_handled()


func _clique(evento: InputEvent) -> bool:
	return evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT


func _on_botao_hover(i: int) -> void:
	if estado == Estado.MENU and i != _indice_menu:
		_indice_menu = i
		_som("hover")
		_marcar_menu()


func _on_botao_pressionado(i: int) -> void:
	if estado == Estado.MENU:
		_indice_menu = i
		_ativar_acao(ORDEM_ACOES[i])


func _mover_menu(passo: int) -> void:
	_indice_menu = wrapi(_indice_menu + passo, 0, ORDEM_ACOES.size())
	_som("hover")
	_marcar_menu()


func _mover_sub(passo: int) -> void:
	_indice_sub = wrapi(_indice_sub + passo, 0, _opcoes.size())
	_som("hover")
	_marcar_sub()


# ------------------------------------------------------------------ menu / submenu

func _voltar_ao_menu(texto := "") -> void:
	estado = Estado.MENU
	lista.visible = false
	texto_caixa.visible = true
	menu.modulate.a = 1.0
	if texto != "":
		_digitar(texto)
	_marcar_menu()


func _ativar_acao(acao: String) -> void:
	_som("confirmar")
	var dados: Dictionary = caso["acoes"][acao]

	if acao == "tratamento" and dados.get("requer_diagnostico", false) and not diagnostico_confirmado:
		_dizer(String(dados["texto_sem_diagnostico"]), _voltar_ao_menu.bind(String(caso["texto_estados"][_estado_visual()])))
		return
	if acao == "diagnostico" and pistas.size() < int(dados.get("requer_pistas", 0)):
		_dizer(String(dados["texto_sem_pistas"]), _voltar_ao_menu.bind(String(caso["texto_estados"][_estado_visual()])))
		return

	_acao = acao
	_opcoes = dados["opcoes"]
	_indice_sub = 0
	estado = Estado.SUBMENU
	texto_caixa.visible = false
	_montar_lista()
	_marcar_menu()


func _montar_lista() -> void:
	for filho in lista.get_children():
		filho.queue_free()
	_rotulos_sub.clear()

	for opcao in _opcoes:
		var l := Label.new()
		var feito: bool = _usados.has(_chave(opcao))
		l.text = String(opcao["rotulo"]) + ("  (feito)" if feito and _acao != "diagnostico" and _acao != "tratamento" else "")
		l.add_theme_font_override("font", FONTE)
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", COR_USADO if feito and _acao in ["analisar", "carinho"] else Color.WHITE)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lista.add_child(l)
		_rotulos_sub.append(l)

	var titulo := Label.new()
	titulo.text = "* " + String(caso["acoes"][_acao]["titulo"]).to_upper()
	titulo.add_theme_font_override("font", FONTE)
	titulo.add_theme_font_size_override("font_size", 11)
	titulo.add_theme_color_override("font_color", COR_SEL)
	lista.add_child(titulo)
	lista.move_child(titulo, 0)
	lista.visible = true
	_marcar_sub()


func _marcar_sub() -> void:
	for i in _rotulos_sub.size():
		var cor := Color.WHITE
		if _usados.has(_chave(_opcoes[i])) and _acao in ["analisar", "carinho"]:
			cor = COR_USADO
		if i == _indice_sub:
			cor = COR_SEL
		_rotulos_sub[i].add_theme_color_override("font_color", cor)
	_posicionar_cursor()


func _chave(opcao: Dictionary) -> String:
	return "%s:%s" % [_acao, opcao["id"]]


# ------------------------------------------------------------------ efeito das acoes

func _escolher_opcao(opcao: Dictionary) -> void:
	_som("confirmar")
	lista.visible = false
	texto_caixa.visible = true
	cursor.visible = false

	var gasta_turno := true
	var ganho := int(opcao.get("progresso", 0))
	var variacao_estresse := int(opcao.get("estresse", 0))
	var texto := String(opcao["texto"])

	match _acao:
		"analisar", "carinho":
			if _usados.has(_chave(opcao)):
				_dizer("* Você já fez isso. Tente outra coisa.", _voltar_ao_menu.bind(String(caso["texto_estados"][_estado_visual()])))
				return
			_usados[_chave(opcao)] = true
			var pista := String(opcao.get("pista", ""))
			if pista != "" and not pistas.has(pista):
				pistas.append(pista)
		"diagnostico":
			if opcao.get("correta", false):
				diagnostico_confirmado = true
			else:
				ganho = 0
		"tratamento":
			if not opcao.get("correto", false):
				ganho = 0

	_aplicar_efeitos(ganho, variacao_estresse)

	var intensidade := float(opcao.get("intensidade", 1.0))
	var padrao := String(opcao.get("padrao", ""))
	var duracao := float(opcao.get("duracao", -1.0))
	if progresso >= 100:
		_dizer(texto, _finalizar_caso)
	elif gasta_turno:
		_dizer(texto, _iniciar_esquiva.bind(padrao, duracao, intensidade))


func _aplicar_efeitos(ganho: int, variacao_estresse: int) -> void:
	progresso = clampi(progresso + ganho, 0, 100)
	estresse = clampi(estresse + variacao_estresse, 0, 10)
	create_tween().tween_property(barra_diagnostico, "value", float(progresso), 0.6).set_trans(Tween.TRANS_SINE)
	create_tween().tween_property(barra_estresse, "value", float(estresse), 0.5).set_trans(Tween.TRANS_SINE)
	_atualizar_paciente()


func _estado_visual() -> String:
	if progresso >= 100:
		return "curado"
	if estresse >= 7:
		return "dor"
	if estresse >= 4:
		return "assustado"
	if progresso >= 70:
		return "aliviado"
	return "neutro"


func _atualizar_paciente() -> void:
	var caminho := SPRITE_PACIENTE % [paciente_id, paciente_id, _estado_visual()]
	if ResourceLoader.exists(caminho):
		paciente.texture = load(caminho)


func _animar_paciente() -> void:
	var base := paciente.position.y
	var t := create_tween().set_loops()
	t.tween_property(paciente, "position:y", base - 6.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(paciente, "position:y", base, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ------------------------------------------------------------------ esquiva (vez do paciente)

func _iniciar_esquiva(padrao: String, duracao: float, intensidade: float) -> void:
	estado = Estado.ESQUIVA
	texto_caixa.visible = false
	lista.visible = false
	cursor.visible = false
	menu.modulate.a = 0.4
	_marcar_menu()
	caixinha.iniciar_esquiva(padrao, duracao, intensidade * (1.0 + estresse * 0.05))


func _on_esquiva_terminou() -> void:
	caixinha.encerrar_esquiva()
	_voltar_ao_menu(String(caso["texto_estados"][_estado_visual()]))


# ------------------------------------------------------------------ fim do caso

func _finalizar_caso() -> void:
	estado = Estado.TEXTO
	_atualizar_paciente()
	_dizer(String(caso["fim"]["texto"]), _mostrar_resolvido)


func _mostrar_resolvido() -> void:
	estado = Estado.FIM
	gato_final.texture = paciente.texture
	%FalaTutor.text = "%s:\n\"%s\"" % [caso.get("tutor", ""), caso["fim"]["fala_tutor"]]
	resolvido.modulate.a = 0.0
	resolvido.visible = true
	create_tween().tween_property(resolvido, "modulate:a", 1.0, 0.6)
	_som("carimbo")


# ------------------------------------------------------------------ texto

## Mostra um texto na caixa e espera o jogador confirmar antes de chamar `depois`.
func _dizer(texto: String, depois: Callable) -> void:
	estado = Estado.TEXTO
	_depois_do_texto = depois
	lista.visible = false
	texto_caixa.visible = true
	cursor.visible = false
	_digitar(texto)


func _digitar(texto: String) -> void:
	texto_caixa.text = texto
	texto_caixa.visible_ratio = 0.0
	_digitando = true
	if _tween_texto != null and _tween_texto.is_valid():
		_tween_texto.kill()
	_tween_texto = create_tween()
	_tween_texto.tween_property(texto_caixa, "visible_ratio", 1.0, maxf(texto.length() / VELOCIDADE_TEXTO, 0.05))
	_tween_texto.finished.connect(func() -> void: _digitando = false)


func _completar_texto() -> void:
	if _tween_texto != null and _tween_texto.is_valid():
		_tween_texto.kill()
	texto_caixa.visible_ratio = 1.0
	_digitando = false


func _som(nome: String) -> void:
	if _audio != null and _audio.has_method(nome):
		_audio.call(nome)
