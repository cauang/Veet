extends Node

signal configuracoes_alteradas()

const CAMINHO_SALVO := "user://settings.json"

# Versao do arquivo de configuracoes. Se o arquivo salvo for mais antigo, o video volta ao automatico.
const VERSAO_CONFIG := 2

const PADROES := {
	"versao": VERSAO_CONFIG,
	"audio": {
		"master": 0.8,
		"musica": 0.7,
		"sfx": 0.8,
		"mudo": false,
	},
	"video": {
		"tela_cheia": false,
		"vsync": true,
		"largura": 0, # 0 = automatico: a janela abre maximizada e se adapta a tela
		"altura": 0,
	},
	"idioma": "pt_br",
}

var configuracoes: Dictionary = {}


func _ready() -> void:
	configuracoes = PADROES.duplicate(true)
	_carregar()
	aplicar_audio()
	aplicar_video()


func _carregar() -> void:
	if not FileAccess.file_exists(CAMINHO_SALVO):
		return

	var arquivo := FileAccess.open(CAMINHO_SALVO, FileAccess.READ)
	if arquivo == null:
		return

	var texto := arquivo.get_as_text()
	arquivo.close()

	var dados: Variant = JSON.parse_string(texto)
	if dados is Dictionary:
		configuracoes = dados
		_migrar()


func _migrar() -> void:
	var salva: Variant = config_get("versao")
	var versao := 0
	if salva != null:
		versao = int(salva)
	if versao >= VERSAO_CONFIG:
		return

	# Arquivos antigos guardavam 1280x720 fixo; agora o padrao e se adaptar a tela.
	config_set("video.largura", 0)
	config_set("video.altura", 0)
	config_set("versao", VERSAO_CONFIG)


func salvar() -> void:
	var arquivo := FileAccess.open(CAMINHO_SALVO, FileAccess.WRITE)
	if arquivo == null:
		print("Nao foi possivel salvar as configuracoes.")
		return

	arquivo.store_string(JSON.stringify(configuracoes, "\t"))
	arquivo.close()
	configuracoes_alteradas.emit()


func restaurar_padroes() -> void:
	configuracoes = PADROES.duplicate(true)
	salvar()


func config_set(chave: String, valor) -> void:
	var partes := chave.split(".")
	var alvo: Dictionary = configuracoes

	for i in range(partes.size() - 1):
		var parte: String = partes[i]
		if not alvo.has(parte) or not (alvo[parte] is Dictionary):
			alvo[parte] = {}
		alvo = alvo[parte]

	alvo[partes[partes.size() - 1]] = valor


func config_get(chave: String) -> Variant:
	var partes := chave.split(".")
	var alvo: Dictionary = configuracoes

	for i in range(partes.size()):
		var parte: String = partes[i]
		if not alvo.has(parte):
			return null

		var valor: Variant = alvo[parte]
		if i == partes.size() - 1:
			return valor

		if not (valor is Dictionary):
			return null
		alvo = valor

	return null


func aplicar_audio() -> void:
	var mudo := bool(config_get("audio.mudo"))
	_aplicar_bus("Master", float(config_get("audio.master")), mudo)
	_aplicar_bus("Music", float(config_get("audio.musica")), mudo)
	_aplicar_bus("SFX", float(config_get("audio.sfx")), mudo)


func _aplicar_bus(nome: String, volume_linear: float, mudo_geral: bool) -> void:
	var indice := AudioServer.get_bus_index(nome)
	if indice < 0:
		return

	var linear := clampf(volume_linear, 0.0001, 1.0)
	AudioServer.set_bus_volume_db(indice, linear_to_db(linear))
	AudioServer.set_bus_mute(indice, mudo_geral)


func aplicar_video() -> void:
	var tela_cheia := bool(config_get("video.tela_cheia"))
	var vsync := bool(config_get("video.vsync"))

	if tela_cheia:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		var largura := int(config_get("video.largura"))
		var altura := int(config_get("video.altura"))
		if largura <= 0 or altura <= 0:
			# Automatico: ocupa a area util da tela em que o jogo abriu.
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(largura, altura))
			_centralizar_janela()

	var modo_vsync := DisplayServer.VSYNC_DISABLED
	if vsync:
		modo_vsync = DisplayServer.VSYNC_ENABLED
	DisplayServer.window_set_vsync_mode(modo_vsync)


func _centralizar_janela() -> void:
	var tela := DisplayServer.window_get_current_screen()
	var origem := DisplayServer.screen_get_position(tela)
	var area := DisplayServer.screen_get_usable_rect(tela)
	var tamanho := DisplayServer.window_get_size()
	DisplayServer.window_set_position(origem + (area.size - tamanho) / 2)
