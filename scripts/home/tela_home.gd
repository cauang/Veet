extends Control
## Tela inicial do Veet.
##
## Abertura (Capivara Studios -> eletrocardiograma -> logo -> novelo de la ->
## ambulatorio) seguida do menu. Todas as animacoes usam Tween com curvas
## suaves, sem degraus, e rodam na taxa de quadros da tela.
##
## Qualquer tecla ou clique durante a abertura acelera tudo ate o menu.

# A abertura completa toca uma vez por execucao; ao voltar do jogo ela e rapida.
static var _abertura_ja_vista := false

# Geometria do fio e do novelo (1 celula do desenho = 6,4 px na base 1280x720).
const CELULA := 6.4
const ORIGEM_FIO := Vector2(284.13, 31.2)
const NOVELO_X0 := 8.0
const NOVELO_X1 := 103.0
const NOVELO_RAIO := 5.5
const LARGURA_FIO_CELULAS := 95.0

const ALMA_X := 420.6
const COR_BOTAO_APAGADO := Color(1, 1, 1, 1)

@onready var fundo: ColorRect = %Fundo
@onready var cenario: Control = %Cenario

@onready var letra_v: Control = %LetraV
@onready var letra_e1: Control = %LetraE1
@onready var letra_e2: Control = %LetraE2
@onready var letra_t: Control = %LetraT
@onready var fio_clip: Control = %FioClip
@onready var novelo: Control = %Novelo
@onready var subtitulo: Control = %Subtitulo
@onready var pet_tigre: Control = %PetTigre
@onready var pet_fibonacci: Control = %PetFibonacci

@onready var btn_jogar: TextureButton = %BtnJogar
@onready var btn_configuracoes: TextureButton = %BtnConfiguracoes
@onready var btn_fechar_jogo: TextureButton = %BtnFecharJogo
@onready var alma: Control = %Alma
@onready var dica: Control = %Dica
@onready var dica_cima: Control = %DicaCima
@onready var dica_baixo: Control = %DicaBaixo
@onready var dica_texto: Control = %DicaTexto
@onready var versao: Control = %Versao

@onready var estudio: Control = %Estudio
@onready var selo: Control = %Selo
@onready var foto_coracao: Control = %FotoCoracao
@onready var txt_nome: Control = %TxtNome
@onready var txt_apresenta: Control = %TxtApresenta
@onready var ecg_intro: Control = %EcgIntro
@onready var cortina: ColorRect = %Cortina

@onready var painel_configuracoes: Control = %PainelConfiguracoes
@onready var confirmacao_fechar: ConfirmationDialog = %ConfirmacaoFechar

var audio: Node
var _ignorar_foco := false
var _velocidade_abertura := 1.0
var _abertura: Tween
var _abertura_ativa := false
var _menu_pronto := false
var letras: Array[Control] = []
var _botoes: Array[TextureButton] = []
var _destino: Dictionary = {}  # Control -> posicao final
var _alma_tween: Tween
var _painel_tween: Tween
var _tempo := 0.0


func _ready() -> void:
	audio = get_node("/root/GerenciadorAudio")
	letras = [letra_v, letra_e1, letra_e2, letra_t]
	_botoes = [btn_jogar, btn_configuracoes, btn_fechar_jogo]
	_conectar_sinais()
	_preparar_estado_inicial()
	_iniciar_ambiente()
	_iniciar_abertura()


func _process(delta: float) -> void:
	_tempo += delta
	# A alma balanca de leve ao lado do botao selecionado.
	alma.position.x = ALMA_X + sin(_tempo * 4.0) * 3.0


func _input(event: InputEvent) -> void:
	if not _abertura_ativa:
		return

	var apertou := false
	if event is InputEventKey:
		apertou = event.pressed and not event.echo
	elif event is InputEventMouseButton:
		apertou = event.pressed

	if apertou:
		_velocidade_abertura = 14.0
		_abertura.set_speed_scale(_velocidade_abertura)
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- preparacao

func _conectar_sinais() -> void:
	btn_jogar.pressed.connect(_on_jogar)
	btn_configuracoes.pressed.connect(_on_configuracoes)
	btn_fechar_jogo.pressed.connect(_on_fechar_jogo)
	painel_configuracoes.connect("solicitar_fechar", _fechar_painel)
	confirmacao_fechar.confirmed.connect(_on_confirmar_fechar)

	for i in range(_botoes.size()):
		var botao := _botoes[i]
		botao.focus_entered.connect(_on_foco.bind(i))
		botao.focus_exited.connect(_on_perdeu_foco.bind(i))
		botao.mouse_entered.connect(_on_mouse_sobre.bind(botao))


func _preparar_estado_inicial() -> void:
	painel_configuracoes.visible = false
	painel_configuracoes.modulate = Color(1, 1, 1, 0)

	cenario.modulate.a = 0.0

	var inclinacoes := [-7.0, 6.0, -5.0, 7.0]
	for i in range(letras.size()):
		var letra := letras[i]
		_destino[letra] = letra.position
		letra.position.y -= 320.0
		letra.rotation_degrees = inclinacoes[i]
		letra.modulate.a = 0.0

	for pet in [pet_tigre, pet_fibonacci]:
		_destino[pet] = pet.position
		pet.position.y += 380.0
		pet.modulate.a = 0.0

	subtitulo.modulate.a = 0.0
	novelo.modulate.a = 0.0
	fio_clip.size.x = 0.0

	for botao in _botoes:
		_destino[botao] = botao.position
		botao.position.y += 36.0
		botao.modulate.a = 0.0
		botao.mouse_filter = Control.MOUSE_FILTER_IGNORE
		botao.focus_mode = Control.FOCUS_NONE
		# Botao sem foco fica um pouco mais apagado; o brilho vem da camada "Sel".
		botao.self_modulate = COR_BOTAO_APAGADO

	alma.modulate.a = 0.0
	dica.modulate.a = 0.0
	versao.modulate.a = 0.0

	estudio.modulate.a = 0.0
	selo.scale = Vector2(0.72, 0.72)
	_destino[txt_nome] = txt_nome.position
	txt_nome.position.y += 18.0
	txt_nome.modulate.a = 0.0
	txt_apresenta.modulate.a = 0.0

	ecg_intro.modulate.a = 0.0
	ecg_intro.set("progresso", 0.0)

	cortina.color.a = 0.0


# ------------------------------------------------------------------ abertura

func _anim(alvo: Object, propriedade: NodePath, valor: Variant, duracao: float, atraso: float,
		curva: Tween.TransitionType = Tween.TRANS_SINE, suavizacao: Tween.EaseType = Tween.EASE_OUT) -> void:
	_abertura.tween_property(alvo, propriedade, valor, duracao).set_delay(atraso).set_trans(curva).set_ease(suavizacao)


func _iniciar_abertura() -> void:
	_abertura_ativa = true
	_abertura = create_tween().set_parallel(true)

	# 1) Vinheta do Capivara Studios
	_anim(estudio, "modulate:a", 1.0, 1.2, 0.3)
	_anim(selo, "scale", Vector2.ONE, 1.9, 0.3, Tween.TRANS_QUINT)
	# A Capivara alterna para a expressao de coracoezinhos e volta
	_anim(foto_coracao, "modulate:a", 1.0, 0.35, 1.5)
	_anim(foto_coracao, "modulate:a", 0.0, 0.35, 2.6)
	_anim(foto_coracao, "modulate:a", 1.0, 0.35, 3.0)
	_anim(foto_coracao, "modulate:a", 0.0, 0.35, 3.9)
	_anim(txt_nome, "modulate:a", 1.0, 1.0, 1.3)
	_anim(txt_nome, "position:y", _destino[txt_nome].y, 1.3, 1.3, Tween.TRANS_QUINT)
	_anim(txt_apresenta, "modulate:a", 1.0, 1.0, 2.0)
	_anim(estudio, "modulate:a", 0.0, 1.0, 4.2, Tween.TRANS_SINE, Tween.EASE_IN_OUT)

	# 2) Eletrocardiograma
	_anim(ecg_intro, "modulate:a", 1.0, 0.5, 4.8)
	_anim(ecg_intro, "progresso", 1.0, 2.0, 5.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_anim(ecg_intro, "modulate:a", 0.0, 0.8, 6.9, Tween.TRANS_SINE, Tween.EASE_IN)

	# 3) Letras do logo caem e assentam
	for i in range(letras.size()):
		var letra := letras[i]
		var atraso := 6.7 + i * 0.13
		_anim(letra, "position:y", _destino[letra].y, 1.25, atraso, Tween.TRANS_BACK)
		_anim(letra, "rotation_degrees", 0.0, 1.4, atraso, Tween.TRANS_BACK)
		_anim(letra, "modulate:a", 1.0, 0.4, atraso)

	# 4) Ambulatorio surge por tras do logo
	_anim(cenario, "modulate:a", 1.0, 2.0, 7.6, Tween.TRANS_SINE, Tween.EASE_IN_OUT)

	# 5) Novelo rola pelo logo deixando o fio
	_anim(novelo, "modulate:a", 1.0, 0.4, 7.9)
	_abertura.tween_method(_atualizar_novelo, 0.0, 1.0, 2.5) \
		.set_delay(8.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_anim(subtitulo, "modulate:a", 1.0, 1.0, 9.2)

	# 6) Gatos sobem e o menu aparece
	_anim(pet_tigre, "position:y", _destino[pet_tigre].y, 1.4, 8.8, Tween.TRANS_BACK)
	_anim(pet_tigre, "modulate:a", 1.0, 0.6, 8.8)
	_anim(pet_fibonacci, "position:y", _destino[pet_fibonacci].y, 1.4, 9.1, Tween.TRANS_BACK)
	_anim(pet_fibonacci, "modulate:a", 1.0, 0.6, 9.1)

	for i in range(_botoes.size()):
		var botao := _botoes[i]
		var atraso_botao := 9.8 + i * 0.15
		_anim(botao, "position:y", _destino[botao].y, 0.9, atraso_botao, Tween.TRANS_QUINT)
		_anim(botao, "modulate:a", 1.0, 0.7, atraso_botao)

	_anim(alma, "modulate:a", 1.0, 0.6, 10.5)
	_anim(dica, "modulate:a", 1.0, 0.8, 10.7)
	_anim(versao, "modulate:a", 1.0, 0.8, 10.7)
	# Sons: piu do passarinho com a Capivara, sino e musica quando o ambulatorio surge
	_som_em(0.4, &"piu")
	_som_em(1.5, &"piu_piu")
	_som_em(3.0, &"piu")
	_som_em(7.6, &"sino")
	_abertura.tween_callback(_iniciar_musica).set_delay(7.6)
	_abertura.tween_callback(_abertura_concluida).set_delay(11.4)

	if _abertura_ja_vista:
		# Voltando do jogo: mesma sequencia, acelerada e com fade vindo do preto.
		_velocidade_abertura = 6.0
		_abertura.set_speed_scale(_velocidade_abertura)
		cortina.color.a = 1.0
		create_tween().tween_property(cortina, "color:a", 0.0, 0.7).set_trans(Tween.TRANS_SINE)


func _som_em(atraso: float, nome: StringName) -> void:
	_abertura.tween_callback(_tocar_da_abertura.bind(nome)).set_delay(atraso)


func _tocar_da_abertura(nome: StringName) -> void:
	# Ao pular a abertura os efeitos nao tocam em sequencia; so a musica entra.
	if _velocidade_abertura > 1.5:
		return
	audio.call(nome)


func _iniciar_musica() -> void:
	audio.tocar_musica_home()


func _y_fio(x: float) -> float:
	return 31.5 + 2.0 * sin((x - NOVELO_X0) * 0.3)


## p vai de 0 a 1: posiciona o novelo na curva do fio, gira e revela o fio atras dele.
func _atualizar_novelo(p: float) -> void:
	var x := lerpf(NOVELO_X0, NOVELO_X1, p)
	var centro := ORIGEM_FIO + Vector2(x - 0.5, _y_fio(x) - 0.5) * CELULA
	novelo.position = centro - novelo.pivot_offset
	novelo.rotation = (x - NOVELO_X0) / NOVELO_RAIO
	fio_clip.size.x = clampf((x - NOVELO_X0 + 1.0) * CELULA, 0.0, LARGURA_FIO_CELULAS * CELULA)


func _abertura_concluida() -> void:
	_abertura_ativa = false
	_menu_pronto = true
	_abertura_ja_vista = true

	for botao in _botoes:
		botao.mouse_filter = Control.MOUSE_FILTER_STOP
		botao.focus_mode = Control.FOCUS_ALL

	_ignorar_foco = true
	btn_jogar.grab_focus()
	_ignorar_foco = false


# ------------------------------------------------------------------ ambiente

func _iniciar_ambiente() -> void:
	# Gatos respirando
	_respirar(pet_tigre, 0.0)
	_respirar(pet_fibonacci, 1.1)

	# Dica do menu: setas se alternam e o texto respira
	_balancar(dica_cima, -4.0, 0.0)
	_balancar(dica_baixo, 4.0, 0.85)
	var respiro := create_tween().set_loops()
	respiro.tween_property(dica_texto, "modulate:a", 0.5, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	respiro.tween_property(dica_texto, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _balancar(no: Control, deslocamento: float, atraso: float) -> void:
	if atraso > 0.0:
		await get_tree().create_timer(atraso).timeout
	var t := create_tween().set_loops()
	t.tween_property(no, "position:y", deslocamento, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(no, "position:y", 0.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _respirar(pet: Control, atraso: float) -> void:
	var t := create_tween().set_loops()
	t.tween_interval(atraso)
	t.tween_property(pet, "scale", Vector2(1.0, 1.014), 2.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(pet, "scale", Vector2.ONE, 2.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------------------------------------------------------------------- menu

func _on_mouse_sobre(botao: TextureButton) -> void:
	if _menu_pronto and painel_configuracoes.modulate.a < 0.05:
		botao.grab_focus()


func _camada_selecao(indice: int) -> Control:
	return _botoes[indice].get_child(0) as Control


func _on_foco(indice: int) -> void:
	if _menu_pronto and not _ignorar_foco:
		audio.hover()

	var camada := _camada_selecao(indice)
	create_tween().tween_property(camada, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)

	var botao := _botoes[indice]
	var alvo_y: float = _destino[botao].y + (botao.size.y - 6.0) / 2.0 - alma.pivot_offset.y
	if _alma_tween != null and _alma_tween.is_valid():
		_alma_tween.kill()
	_alma_tween = create_tween().set_parallel(true)
	_alma_tween.tween_property(alma, "position:y", alvo_y, 0.32).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	alma.scale = Vector2(1.45, 1.45)
	_alma_tween.tween_property(alma, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_perdeu_foco(indice: int) -> void:
	var camada := _camada_selecao(indice)
	create_tween().tween_property(camada, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE)


func _on_jogar() -> void:
	audio.confirmar()
	audio.parar_musica(0.8)   # a musica da Home acaba aqui; cada cena do jogo tem a sua
	_menu_pronto = false
	var t := create_tween()
	t.tween_property(cortina, "color:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(GerenciadorCenas.iniciar_jogo.bind(true))


func _on_configuracoes() -> void:
	audio.clique()
	painel_configuracoes.modulate = Color(1, 1, 1, 0)
	painel_configuracoes.visible = true

	if _painel_tween != null and _painel_tween.is_valid():
		_painel_tween.kill()

	_painel_tween = create_tween()
	_painel_tween.tween_property(painel_configuracoes, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)


func _fechar_painel() -> void:
	if _painel_tween != null and _painel_tween.is_valid():
		_painel_tween.kill()

	_painel_tween = create_tween()
	_painel_tween.tween_property(painel_configuracoes, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	_painel_tween.tween_callback(_painel_invisivel)


func _painel_invisivel() -> void:
	painel_configuracoes.visible = false
	painel_configuracoes.modulate = Color(1, 1, 1, 0)
	_ignorar_foco = true
	btn_configuracoes.grab_focus()
	_ignorar_foco = false


func _on_fechar_jogo() -> void:
	audio.clique()
	confirmacao_fechar.popup_centered()


func _on_confirmar_fechar() -> void:
	var gerenciador = get_node("/root/GerenciadorConfiguracoes")
	gerenciador.salvar()
	get_tree().quit()
