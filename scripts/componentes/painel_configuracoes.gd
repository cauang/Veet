extends Control

signal solicitar_fechar()

const RESOLUCOES: Array = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1366, 768),
]

var gerenciador

@onready var slider_master: HSlider = %SliderMaster
@onready var slider_musica: HSlider = %SliderMusica
@onready var slider_sfx: HSlider = %SliderSfx
@onready var check_mudo: CheckButton = %CheckMudo
@onready var check_tela_cheia: CheckButton = %CheckTelaCheia
@onready var check_vsync: CheckButton = %CheckVSync
@onready var option_resolucao: OptionButton = %OptionResolucao
@onready var option_idioma: OptionButton = %OptionIdioma
@onready var btn_aplicar: Button = %BtnAplicar
@onready var btn_voltar: Button = %BtnVoltar
@onready var btn_padroes: Button = %BtnPadroes


func _ready() -> void:
	gerenciador = get_node("/root/GerenciadorConfiguracoes")
	_conectar()
	_carregar_ui()


func _conectar() -> void:
	slider_master.value_changed.connect(_on_master_changed)
	slider_musica.value_changed.connect(_on_musica_changed)
	slider_sfx.value_changed.connect(_on_sfx_changed)
	check_mudo.toggled.connect(_on_mudo_toggled)
	check_tela_cheia.toggled.connect(_on_tela_cheia_toggled)
	check_vsync.toggled.connect(_on_vsync_toggled)
	option_resolucao.item_selected.connect(_on_resolucao_selecionada)
	option_idioma.item_selected.connect(_on_idioma_selecionado)
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

	option_resolucao.clear()
	var indice_resolucao := 0
	for i in range(RESOLUCOES.size()):
		var resolucao: Vector2i = RESOLUCOES[i]
		option_resolucao.add_item("%d x %d" % [resolucao.x, resolucao.y])
		if resolucao.x == largura and resolucao.y == altura:
			indice_resolucao = i
	option_resolucao.select(indice_resolucao)

	option_idioma.clear()
	option_idioma.add_item("Portugues (BR)")
	option_idioma.add_item("English")
	var idioma := str(gerenciador.config_get("idioma"))
	if idioma == "en":
		option_idioma.select(1)
	else:
		option_idioma.select(0)


func _on_master_changed(valor: float) -> void:
	gerenciador.config_set("audio.master", valor)


func _on_musica_changed(valor: float) -> void:
	gerenciador.config_set("audio.musica", valor)


func _on_sfx_changed(valor: float) -> void:
	gerenciador.config_set("audio.sfx", valor)


func _on_mudo_toggled(ativo: bool) -> void:
	gerenciador.config_set("audio.mudo", ativo)


func _on_tela_cheia_toggled(ativo: bool) -> void:
	gerenciador.config_set("video.tela_cheia", ativo)


func _on_vsync_toggled(ativo: bool) -> void:
	gerenciador.config_set("video.vsync", ativo)


func _on_resolucao_selecionada(indice: int) -> void:
	if indice < 0 or indice >= RESOLUCOES.size():
		return
	var resolucao: Vector2i = RESOLUCOES[indice]
	gerenciador.config_set("video.largura", resolucao.x)
	gerenciador.config_set("video.altura", resolucao.y)


func _on_idioma_selecionado(indice: int) -> void:
	var idioma := "pt_br"
	if indice == 1:
		idioma = "en"
	gerenciador.config_set("idioma", idioma)
	TranslationServer.set_locale(idioma)


func _on_aplicar() -> void:
	gerenciador.aplicar_audio()
	gerenciador.aplicar_video()
	gerenciador.salvar()
	solicitar_fechar.emit()


func _on_voltar() -> void:
	solicitar_fechar.emit()


func _on_padroes() -> void:
	gerenciador.restaurar_padroes()
	gerenciador.aplicar_audio()
	gerenciador.aplicar_video()
	_carregar_ui()
