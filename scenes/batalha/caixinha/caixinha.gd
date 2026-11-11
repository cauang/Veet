extends Node2D
## Fase de esquiva da batalha.
##
## A patinha se move dentro da caixa desviando dos inimigos (projetis). O
## objetivo e sobreviver ate o tempo da fase acabar. Levar dano reduz o Vinculo;
## se ele zerar, o atendimento e interrompido.

signal fase_sobrevivida()
signal vida_zerada()

@export var velocidade := 200.0
@export var tempo_invulneravel := 0.9

## No prototipo a cena roda sozinha para testar a esquiva em sequencia.
@export var iniciar_automatico := true
@export var repetir_fase := true

@onready var caixa: ColorRect = $Caixa
@onready var patinha: Sprite2D = $Patinha
@onready var area_patinha: Area2D = $Patinha/AreaPatinha
@onready var hud_saude = $HudSaude
@onready var emissor = $EmissorProjeteis
@onready var fim_de_jogo = $CamadaFimDeJogo/FimDeJogo

var _limites := Rect2()
var _metade_patinha := Vector2.ZERO
var _invulneravel := 0.0
var _ativo := true
var _tween_piscar: Tween


func _ready() -> void:
	_limites = Rect2(caixa.position, caixa.size)
	if _limites.size.x <= 0.0 or _limites.size.y <= 0.0:
		_limites = Rect2(365.0, 360.0, 550.0, 300.0)

	if patinha.texture != null:
		_metade_patinha = patinha.texture.get_size() * patinha.scale * 0.5

	area_patinha.area_entered.connect(_on_area_patinha_area_entered)
	hud_saude.vida_zerada.connect(_on_vida_zerada)
	emissor.fase_iniciada.connect(_on_fase_iniciada)
	emissor.tempo_alterado.connect(_on_tempo_alterado)
	emissor.fase_terminou.connect(_on_fase_terminou)
	emissor.definir_limites(_limites)
	fim_de_jogo.tentar_novamente.connect(_on_tentar_novamente)
	fim_de_jogo.voltar_ao_menu.connect(_on_voltar_ao_menu)

	if iniciar_automatico:
		emissor.iniciar_fase()
	else:
		# Modo por turnos: a batalha chama iniciar_esquiva() quando for a vez do paciente.
		_ativo = false
		patinha.visible = false


## Comeca a fase de esquiva (turno do paciente) no modo por turnos.
func iniciar_esquiva(padrao := "", duracao := -1.0, intensidade := 1.0) -> void:
	_ativo = true
	_invulneravel = 0.0
	patinha.modulate.a = 1.0
	patinha.visible = true
	patinha.position = _limites.get_center()
	emissor.iniciar_fase(padrao, duracao, intensidade)


func encerrar_esquiva() -> void:
	_ativo = false
	patinha.visible = false
	emissor.parar_fase()
	hud_saude.esconder_tempo()


func _physics_process(delta: float) -> void:
	if not _ativo:
		return

	var passo := minf(delta, 0.05)

	if _invulneravel > 0.0:
		_invulneravel = maxf(_invulneravel - passo, 0.0)
		if _invulneravel <= 0.0:
			patinha.modulate.a = 1.0

	var direcao := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	patinha.position += direcao * velocidade * passo

	# Impede que a patinha saia da caixa.
	var minimo := _limites.position + _metade_patinha
	var maximo := _limites.end - _metade_patinha
	patinha.position.x = clampf(patinha.position.x, minimo.x, maximo.x)
	patinha.position.y = clampf(patinha.position.y, minimo.y, maximo.y)


# Quando a patinha encosta em um inimigo.
func _on_area_patinha_area_entered(area: Area2D) -> void:
	if not _ativo or _invulneravel > 0.0:
		return

	if not area.is_in_group("projetil"):
		return

	if not hud_saude.receber_dano(1):
		return

	_invulneravel = tempo_invulneravel
	_piscar_patinha()
	_feedback_dano()


func _piscar_patinha() -> void:
	if _tween_piscar != null and _tween_piscar.is_valid():
		_tween_piscar.kill()

	_tween_piscar = create_tween().set_loops(4)
	_tween_piscar.tween_property(patinha, "modulate:a", 0.25, 0.09)
	_tween_piscar.tween_property(patinha, "modulate:a", 1.0, 0.09)


func _feedback_dano() -> void:
	var audio := get_node_or_null("/root/GerenciadorAudio")
	if audio != null and audio.has_method("clique"):
		audio.call("clique")

	var tween := create_tween()
	tween.tween_property(caixa, "modulate", Color(1.0, 0.55, 0.55), 0.06)
	tween.tween_property(caixa, "modulate", Color.WHITE, 0.12)


# ---------------------------------------------------------------- fases

func _on_fase_iniciada(_id: String, nome: String) -> void:
	hud_saude.mostrar_fase(nome)

func _on_tempo_alterado(restante: float, _total: float) -> void:
	hud_saude.mostrar_tempo(restante)


func _on_fase_terminou() -> void:
	if not _ativo:
		return

	fase_sobrevivida.emit()
	hud_saude.esconder_tempo()

	# Rodando a cena solta (F6) a fase repete para testar a esquiva. Embutida na
	# batalha (iniciar_automatico = false) ela so avisa que o turno acabou.
	if iniciar_automatico and repetir_fase:
		await get_tree().create_timer(1.2).timeout
		if _ativo:
			emissor.iniciar_fase()
	else:
		_ativo = false


func _on_vida_zerada() -> void:
	if not _ativo:
		return

	_ativo = false
	emissor.parar_fase()
	hud_saude.esconder_tempo()
	vida_zerada.emit()

	# Deixa o ultimo dano aparecer antes de abrir o modal.
	await get_tree().create_timer(0.6).timeout
	if is_inside_tree():
		fim_de_jogo.abrir()


func _on_tentar_novamente() -> void:
	GerenciadorCenas.reiniciar_etapa()


func _on_voltar_ao_menu() -> void:
	GerenciadorCenas.voltar_ao_menu()
