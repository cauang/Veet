extends Node
## Gerenciador de audio do jogo (autoload).
##
## - Musica de fundo em loop com fade (canal "Music").
## - Efeitos curtos por um conjunto de players, podendo se sobrepor (canal "SFX").
## - Atalhos de interface: hover, clique, interruptor, tick de roldana e carimbo.
##
## Os volumes de cada canal vem do GerenciadorConfiguracoes (tela de configuracoes).

const MUSICA_HOME: AudioStream = preload("res://assets/audio/Sons/Ambiente/ambiente2-11325622-good-vibes-sequence-130bpm-273350.mp3")
const MUSICA_CALMA: AudioStream = preload("res://assets/audio/Sons/Ambiente/ambiente1-idoberg-ambient-pads-loop-296968.mp3")
const MUSICA_RITMO: AudioStream = preload("res://assets/audio/Sons/Ambiente/ambiente3-bannyfernandes77-amapiano-loop-base-banny-fernandes-297939.mp3")
const MUSICA_EMOTIVA: AudioStream = preload("res://assets/audio/Sons/Ambiente/ambiente4-u_c2qquy9wvl-emotionalguitar-337834.mp3")

## Musica de cada rota do GerenciadorCenas (a Home toca a propria, em tela_home.gd).
## Cada cena tem a sua; para trocar, mude a faixa e o volume aqui.
const MUSICAS_CENAS := {
	"introducao": {"faixa": MUSICA_CALMA, "volume": -12.0},
	"triagem": {"faixa": MUSICA_EMOTIVA, "volume": -13.0},
	"batalha": {"faixa": MUSICA_RITMO, "volume": -15.0},
	"resumo": {"faixa": MUSICA_CALMA, "volume": -12.0},
}

const SOM_MIADO: AudioStream = preload("res://assets/audio/Sons/GatoETutor/miado-dragon-studio-cute-cat-meow-472372.mp3")
const SOM_MIADOS: AudioStream = preload("res://assets/audio/Sons/GatoETutor/miados-dragon-studio-cat-meow-321642.mp3")
const SOM_PASSOS: AudioStream = preload("res://assets/audio/Sons/GatoETutor/passos-u_xg7ssi08yr-footsteps-male-362053.mp3")
const SOM_VITORIA: AudioStream = preload("res://assets/audio/Sons/Interação/vitória2-puyopuyomegafan1234-winner-game-sound-404167.mp3")
const SOM_BONUS: AudioStream = preload("res://assets/audio/Sons/Interação/vitória1-universfield-game-bonus-144751.mp3")
const SOM_DERROTA: AudioStream = preload("res://assets/audio/Sons/Interação/Erro-alphix-game-over-417465.mp3")

## "Voz" dos personagens: um blip curto por timbre (gerado por prototipos/audio/gerar_vozes.py).
const VOZES := {
	"narrador": preload("res://assets/audio/sfx/voz_narrador.wav"),
	"protagonista": preload("res://assets/audio/sfx/voz_protagonista.wav"),
	"helena": preload("res://assets/audio/sfx/voz_helena.wav"),
	"euler": preload("res://assets/audio/sfx/voz_euler.wav"),
	"davi": preload("res://assets/audio/sfx/voz_davi.wav"),
	"rita": preload("res://assets/audio/sfx/voz_rita.wav"),
	"beatriz": preload("res://assets/audio/sfx/voz_beatriz.wav"),
}

const SOM_CLIQUE: AudioStream = preload("res://assets/audio/Sons/Click/click-universfield-computer-mouse-click-352734.mp3")
const SOM_SINO: AudioStream = preload("res://assets/audio/Sons/GatoETutor/sino-dragon-studio-doorbell-ding-dong-482879.mp3")
const SOM_PIU: AudioStream = preload("res://assets/audio/sfx/piu_passarinho.wav")
const SOM_PIU_PIU: AudioStream = preload("res://assets/audio/sfx/piu_piu_passarinho.wav")
const SOM_CARIMBO: AudioStream = preload("res://assets/audio/sfx/carimbo_aplicado.wav")
const SOM_ECG: AudioStream = preload("res://assets/audio/sfx/ecg_bip.wav")

const TAMANHO_PISCINA := 10
const VOLUME_MUSICA_DB := -14.0

var _musica: AudioStreamPlayer
var _fade_musica: Tween
var _efeitos: Array[AudioStreamPlayer] = []
var _proximo := 0
var _ultimo_tick := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Os MP3 precisam repetir sozinhos para a musica ser um loop.
	for faixa: AudioStream in [MUSICA_HOME, MUSICA_CALMA, MUSICA_RITMO, MUSICA_EMOTIVA]:
		faixa.set("loop", true)

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
## Se outra musica estiver tocando, ela some com um fade curto antes da nova entrar.
func tocar_musica(fluxo: AudioStream, fade := 2.5, volume_db := VOLUME_MUSICA_DB) -> void:
	if _musica.stream == fluxo and _musica.playing:
		return

	if _fade_musica != null and _fade_musica.is_valid():
		_fade_musica.kill()

	_fade_musica = create_tween()
	if _musica.playing:
		_fade_musica.tween_property(_musica, "volume_db", -60.0, 0.5).set_trans(Tween.TRANS_SINE)
	_fade_musica.tween_callback(func() -> void:
		_musica.stream = fluxo
		_musica.volume_db = -60.0
		_musica.play())
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


## Toca a musica da cena (rota do GerenciadorCenas). Rotas sem musica propria
## (como "home") param a musica atual.
func tocar_musica_cena(rota: String, fade := 1.5) -> void:
	if not MUSICAS_CENAS.has(rota):
		parar_musica(0.6)
		return
	var dados: Dictionary = MUSICAS_CENAS[rota]
	tocar_musica(dados["faixa"], fade, float(dados["volume"]))


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


## "Pi" do monitor cardiaco, no pico do batimento da abertura.
func bip_ecg() -> void:
	tocar(SOM_ECG, -5.0)


# ------------------------------------------------------- voz, gatos e jingles

## Blip de voz do personagem `id` (ver VOZES). Ids desconhecidos usam o narrador.
func voz(id: String) -> void:
	var stream: AudioStream = VOZES.get(id, VOZES["narrador"])
	tocar(stream, -5.0, randf_range(0.9, 1.15))


func miado(agudo := false) -> void:
	tocar(SOM_MIADO if not agudo else SOM_MIADOS, -4.0, randf_range(0.95, 1.05))


## Passos enquanto um personagem anda. Retorna o player para parar no fim do trajeto.
func passos() -> AudioStreamPlayer:
	return tocar(SOM_PASSOS, -10.0)


func vitoria() -> void:
	parar_musica(0.4)
	tocar(SOM_VITORIA, -4.0)


func bonus() -> void:
	tocar(SOM_BONUS, -6.0)


func derrota() -> void:
	parar_musica(0.4)
	tocar(SOM_DERROTA, -4.0)
