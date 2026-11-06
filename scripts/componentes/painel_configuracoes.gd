extends Control
## Tela de configuracoes: uma prancheta de prontuario com abas de Audio e Video.
##
## - Roldanas de volume com novelo de la (SliderNovelo): arraste o novelo.
## - Interruptores de madeira (InterruptorMadeira) e campo de selecao (CampoSelecao).
## - Trocar de aba faz a pagina deslizar e a dica do post-it mudar.
## Esc fecha o painel. A logica de salvar/aplicar fica no GerenciadorConfiguracoes.

signal solicitar_fechar()

# Vector2i(0, 0) = automatico (adapta a tela)
const RESOLUCOES: Array = [
	Vector2i(0, 0),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1366, 768),
]

const DICAS: Array[String] = [
	"DICA: 70% DE MÚSICA É O IDEAL.",
	"DICA: AUTOMÁTICO USA A TELA INTEIRA.",
]

var gerenciador
var audio: Node
var _aba := 0
var _aplicando := false
var _tween_aba: Tween
var _tween_entrada: Tween
var _paginas: Array[Control] = []
var _base_pagina_x := 0.0
var _base_pet_y := 0.0

@onready var prancheta: Control = %Prancheta
@onready var pet_tigre: Control = %PetTigre
@onready var pet_fibonacci: Control = %PetFibonacci
@onready var fundo: ColorRect = %FundoEscurecido
@onready var carimbo: Label = %Carimbo
@onready var nota_texto: Label = %NotaTexto

@onready var btn_aba_audio: Button = %BtnAbaAudio
@onready var btn_aba_video: Button = %BtnAbaVideo
@onready var pagina_audio: Control = %PaginaAudio
@onready var pagina_video: Control = %PaginaVideo

@onready var slider_master: SliderNovelo = %SliderMaster
@onready var slider_musica: SliderNovelo = %SliderMusica
@onready var slider_sfx: SliderNovelo = %SliderSfx
@onready var val_master: Label = %ValMaster
@onready var val_musica: Label = %ValMusica
@onready var val_sfx: Label = %ValSfx
@onready var check_mudo: InterruptorMadeira = %CheckMudo
@onready var val_mudo: Label = %ValMudo

@onready var check_tela_cheia: InterruptorMadeira = %CheckTelaCheia
@onready var val_tela_cheia: Label = %ValTelaCheia
@onready var check_vsync: InterruptorMadeira = %CheckVSync
@onready var val_vsync: Label = %ValVSync
@onready var option_resolucao: CampoSelecao = %OptionResolucao

@onready var btn_aplicar: Button = %BtnAplicar
@onready var btn_voltar: Button = %BtnVoltar
@onready var btn_padroes: Button = %BtnPadroes


func _ready() -> void:
	gerenciador = get_node("/root/GerenciadorConfiguracoes")
	audio = get_node("/root/GerenciadorAudio")
	_paginas = [pagina_audio, pagina_video]
	_base_pagina_x = pagina_audio.position.x
	_base_pet_y = pet_tigre.position.y

	_montar_resolucoes()
	_conectar()
	_carregar_ui()
	nota_texto.text = DICAS[0]
	visibility_changed.connect(_on_visibilidade)


func _unhandled_input(evento: InputEvent) -> void:
	if visible and evento.is_action_pressed("ui_cancel"):
		if option_resolucao.get_node("Lista").visible:
			option_resolucao.fechar()
		else:
			solicitar_fechar.emit()
		get_viewport().set_input_as_handled()


func _montar_resolucoes() -> void:
	var nomes := PackedStringArray()
	for resolucao: Vector2i in RESOLUCOES:
		if resolucao == Vector2i.ZERO:
			nomes.append("Automático (tela)")
		else:
			nomes.append("%d x %d" % [resolucao.x, resolucao.y])
	option_resolucao.definir_itens(nomes)


func _conectar() -> void:
	slider_master.value_changed.connect(_on_master_changed)
	slider_musica.value_changed.connect(_on_musica_changed)
	slider_sfx.value_changed.connect(_on_sfx_changed)
	check_mudo.toggled.connect(_on_mudo_toggled)
	check_tela_cheia.toggled.connect(_on_tela_cheia_toggled)
	check_vsync.toggled.connect(_on_vsync_toggled)
	option_resolucao.item_selected.connect(_on_resolucao_selecionada)

	btn_aba_audio.pressed.connect(_selecionar_aba.bind(0))
	btn_aba_video.pressed.connect(_selecionar_aba.bind(1))
	# Sons de interface
	for botao: Button in [btn_aba_audio, btn_aba_video, btn_aplicar, btn_voltar, btn_padroes]:
		botao.mouse_entered.connect(audio.hover)
	btn_aba_audio.pressed.connect(audio.clique)
	btn_aba_video.pressed.connect(audio.clique)
	btn_voltar.pressed.connect(audio.clique)
	btn_padroes.pressed.connect(audio.clique)
	check_mudo.toggled.connect(audio.alternar)
	check_tela_cheia.toggled.connect(audio.alternar)
	check_vsync.toggled.connect(audio.alternar)
	option_resolucao.get_node("Botao").pressed.connect(audio.clique)
	option_resolucao.item_selected.connect(func(_i: int) -> void: audio.confirmar())

	btn_aplicar.pressed.connect(_on_aplicar)
	btn_voltar.pressed.connect(_on_voltar)
	btn_padroes.pressed.connect(_on_padroes)


func _carregar_ui() -> void:
	slider_master.set_value_no_signal(float(gerenciador.config_get("audio.master")))
	slider_musica.set_value_no_signal(float(gerenciador.config_get("audio.musica")))
	slider_sfx.set_value_no_signal(float(gerenciador.config_get("audio.sfx")))
	check_mudo.set_pressed_no_signal(bool(gerenciador.config_get("audio.mudo")))

	check_tela_cheia.set_pressed_no_signal(bool(gerenciador.config_get("video.tela_cheia")))
	check_vsync.set_pressed_no_signal(bool(gerenciador.config_get("video.vsync")))

	var largura := int(gerenciador.config_get("video.largura"))
	var altura := int(gerenciador.config_get("video.altura"))
	var indice_resolucao := 0
	for i in range(RESOLUCOES.size()):
		var resolucao: Vector2i = RESOLUCOES[i]
		if resolucao.x == largura and resolucao.y == altura:
			indice_resolucao = i
	option_resolucao.selecionar(indice_resolucao, false)

	_atualizar_rotulos()


func _atualizar_rotulos() -> void:
	val_master.text = "%d%%" % roundi(slider_master.value * 100.0)
	val_musica.text = "%d%%" % roundi(slider_musica.value * 100.0)
	val_sfx.text = "%d%%" % roundi(slider_sfx.value * 100.0)
	val_mudo.text = _estado(check_mudo.button_pressed)
	val_tela_cheia.text = _estado(check_tela_cheia.button_pressed)
	val_vsync.text = _estado(check_vsync.button_pressed)


func _estado(ligado: bool) -> String:
	return "LIGADO" if ligado else "DESLIGADO"


# -------------------------------------------------------------------- abas

func _selecionar_aba(indice: int) -> void:
	if indice == _aba:
		return

	option_resolucao.fechar()
	if _tween_aba != null and _tween_aba.is_valid():
		_tween_aba.kill()

	var antiga := _paginas[_aba]
	var nova := _paginas[indice]
	_aba = indice

	nova.visible = true
	nova.modulate.a = 0.0
	nova.position.x = _base_pagina_x + 10.0

	_tween_aba = create_tween().set_parallel(true)
	_tween_aba.tween_property(antiga, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE)
	_tween_aba.tween_property(nova, "modulate:a", 1.0, 0.3).set_delay(0.08).set_trans(Tween.TRANS_SINE)
	_tween_aba.tween_property(nova, "position:x", _base_pagina_x, 0.4).set_delay(0.08) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_tween_aba.tween_callback(func() -> void: antiga.visible = false).set_delay(0.18)

	# Dica do post-it troca com um pequeno fade
	var nota := create_tween()
	nota.tween_property(nota_texto, "modulate:a", 0.0, 0.12)
	nota.tween_callback(func() -> void: nota_texto.text = DICAS[indice])
	nota.tween_property(nota_texto, "modulate:a", 1.0, 0.2)


# ----------------------------------------------------------------- entrada

func _on_visibilidade() -> void:
	if not visible:
		return

	if _tween_entrada != null and _tween_entrada.is_valid():
		_tween_entrada.kill()

	prancheta.scale = Vector2(1.88, 1.88)
	pet_tigre.position.y = _base_pet_y + 26.0
	pet_fibonacci.position.y = _base_pet_y + 26.0
	_tween_entrada = create_tween().set_parallel(true)
	_tween_entrada.tween_property(prancheta, "scale", Vector2(2, 2), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_entrada.tween_property(pet_tigre, "position:y", _base_pet_y, 0.8).set_delay(0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_entrada.tween_property(pet_fibonacci, "position:y", _base_pet_y, 0.8).set_delay(0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	btn_aba_audio.grab_focus()


# ------------------------------------------------------------- valores

func _on_master_changed(valor: float) -> void:
	audio.tick(valor)
	gerenciador.config_set("audio.master", valor)
	val_master.text = "%d%%" % roundi(valor * 100.0)


func _on_musica_changed(valor: float) -> void:
	audio.tick(valor)
	gerenciador.config_set("audio.musica", valor)
	val_musica.text = "%d%%" % roundi(valor * 100.0)


func _on_sfx_changed(valor: float) -> void:
	audio.tick(valor)
	gerenciador.config_set("audio.sfx", valor)
	val_sfx.text = "%d%%" % roundi(valor * 100.0)


func _on_mudo_toggled(ativo: bool) -> void:
	gerenciador.config_set("audio.mudo", ativo)
	val_mudo.text = _estado(ativo)


func _on_tela_cheia_toggled(ativo: bool) -> void:
	gerenciador.config_set("video.tela_cheia", ativo)
	val_tela_cheia.text = _estado(ativo)


func _on_vsync_toggled(ativo: bool) -> void:
	gerenciador.config_set("video.vsync", ativo)
	val_vsync.text = _estado(ativo)


func _on_resolucao_selecionada(indice: int) -> void:
	if indice < 0 or indice >= RESOLUCOES.size():
		return
	var resolucao: Vector2i = RESOLUCOES[indice]
	gerenciador.config_set("video.largura", resolucao.x)
	gerenciador.config_set("video.altura", resolucao.y)


# ----------------------------------------------------------------- rodape

func _on_aplicar() -> void:
	if _aplicando:
		return
	_aplicando = true
	audio.carimbo()

	gerenciador.aplicar_audio()
	gerenciador.aplicar_video()
	gerenciador.salvar()

	# Carimbo "APLICADO" bate no papel e depois o painel fecha.
	carimbo.modulate.a = 0.0
	carimbo.scale = Vector2(2.2, 2.2)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(carimbo, "modulate:a", 0.95, 0.15)
	t.tween_property(carimbo, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(0.55)
	t.chain().tween_property(carimbo, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(_terminar_aplicar)


func _terminar_aplicar() -> void:
	_aplicando = false
	solicitar_fechar.emit()


func _on_voltar() -> void:
	solicitar_fechar.emit()


func _on_padroes() -> void:
	gerenciador.restaurar_padroes()
	gerenciador.aplicar_audio()
	gerenciador.aplicar_video()
	_carregar_ui()
