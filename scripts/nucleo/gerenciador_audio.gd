extends Node
## Gerenciador de audio do jogo (autoload).
##
## - Musica de fundo em loop com fade (canal "Music").
## - Efeitos curtos por um conjunto de players, podendo se sobrepor (canal "SFX").
## - Atalhos de interface: hover, clique, interruptor, tick de roldana e carimbo.
##
## Os volumes de cada canal vem do GerenciadorConfiguracoes (tela de configuracoes).

const MUSICA_HOME: AudioStream = preload("res://assets/audio/Sons/Ambiente/ambiente2-11325622-good-vibes-sequence-130bpm-273350.mp3")

const SOM_CLIQUE: AudioStream = preload("res://assets/audio/Sons/Click/click-universfield-computer-mouse-click-352734.mp3")
const SOM_SINO: AudioStream = preload("res://assets/audio/Sons/GatoETutor/sino-dragon-studio-doorbell-ding-dong-482879.mp3")
const SOM_PIU: AudioStream = preload("res://assets/audio/sfx/piu_passarinho.wav")
const SOM_PIU_PIU: AudioStream = preload("res://assets/audio/sfx/piu_piu_passarinho.wav")
const SOM_CARIMBO: AudioStream = preload("res://assets/audio/sfx/carimbo_aplicado.wav")

const TAMANHO_PISCINA := 10
const VOLUME_MUSICA_DB := -14.0

var _musica: AudioStreamPlayer
var _fade_musica: Tween
var _efeitos: Array[AudioStreamPlayer] = []
var _proximo := 0
var _ultimo_tick := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# O MP3 precisa repetir sozinho para a musica ser um loop.
	MUSICA_HOME.set("loop", true)

	_musica = AudioStreamPlayer.new()
	_musica.bus = &"Music"
	add_child(_musica)

	for i in range(TAMANHO_PISCINA):
		var jogador := AudioStreamPlayer.new()
		jogador.bus = &"SFX"
		add_child(jogador)
		_efeitos.append(jogador)


# ------------------------------------------------------------------ musica

## Toca a musica com fade de entrada. Se ja for a mesma musica, nao reinicia.
func tocar_musica(fluxo: AudioStream, fade := 2.5, volume_db := VOLUME_MUSICA_DB) -> void:
	if _musica.stream == fluxo and _musica.playing:
		return

	if _fade_musica != null and _fade_musica.is_valid():
		_fade_musica.kill()

	_musica.stream = fluxo
	_musica.volume_db = -60.0
	_musica.play()
	_fade_musica = create_tween()
	_fade_musica.tween_property(_musica, "volume_db", volume_db, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func parar_musica(fade := 1.5) -> void:
	if not _musica.playing:
		return
	if _fade_musica != null and _fade_musica.is_valid():
		_fade_musica.kill()
	_fade_musica = create_tween()
	_fade_musica.tween_property(_musica, "volume_db", -60.0, fade).set_trans(Tween.TRANS_SINE)
	_fade_musica.tween_callback(_musica.stop)


func tocar_musica_home() -> void:
	tocar_musica(MUSICA_HOME)


# ----------------------------------------------------------------- efeitos

## Toca um efeito em qualquer player livre. Retorna o player usado.
func tocar(fluxo: AudioStream, volume_db := 0.0, tom := 1.0) -> AudioStreamPlayer:
	var jogador := _efeitos[_proximo]
	_proximo = (_proximo + 1) % _efeitos.size()
	jogador.stream = fluxo
	jogador.volume_db = volume_db
	jogador.pitch_scale = tom
	jogador.play()
	return jogador


## "Piu" do passarinho que acompanha a Capivara.
func piu() -> void:
	tocar(SOM_PIU, -1.0, randf_range(0.97, 1.03))


func piu_piu() -> void:
	tocar(SOM_PIU_PIU, -1.0, randf_range(0.98, 1.02))


## Campainha: marca a chegada ao ambulatorio.
func sino() -> void:
	tocar(SOM_SINO, -6.0)


# ---------------------------------------------------------------- interface

func hover() -> void:
	tocar(SOM_CLIQUE, -11.0, randf_range(1.35, 1.5))


func clique() -> void:
	tocar(SOM_CLIQUE, -4.0, randf_range(0.97, 1.03))


func confirmar() -> void:
	tocar(SOM_CLIQUE, -2.0, 0.85)


## Interruptor: mais agudo ao ligar, mais grave ao desligar.
func alternar(ligado: bool) -> void:
	tocar(SOM_CLIQUE, -4.0, 1.15 if ligado else 0.8)


## Tique suave da roldana. O tom sobe com o valor (0 a 1); limitado para nao empilhar.
func tick(valor: float) -> void:
	var agora := Time.get_ticks_msec()
	if agora - _ultimo_tick < 45:
		return
	_ultimo_tick = agora
	tocar(SOM_CLIQUE, -10.0, 0.9 + valor * 0.8)


func carimbo() -> void:
	tocar(SOM_CARIMBO, -1.0)
