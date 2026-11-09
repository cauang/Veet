extends Area2D
## Inimigo da fase de esquiva.
##
## O projetil atravessa a caixa de batalha seguindo uma trajetoria definida pelo
## emissor. A patinha apenas desvia: encostar reduz o Vinculo, mas nao destroi
## o projetil. Os projetis sao reciclados pelo emissor (pool), por isso a cena
## nunca e removida da arvore.

var direcao := Vector2.DOWN
var velocidade := 160.0
var tempo_de_vida := 6.0
var oscilacao := 0.0
var frequencia := 0.0

var _ativo := false
var _idade := 0.0
var _base_global := Vector2.ZERO
var _eixo_oscilacao := Vector2.RIGHT
var _limites_saida := Rect2()


func _ready() -> void:
	add_to_group("projetil")
	_parar()


## True enquanto o projetil esta atravessando a caixa.
func esta_ativo() -> bool:
	return _ativo


## Coloca o projetil em movimento. Recebe coordenadas globais.
func ativar(origem: Vector2, nova_direcao: Vector2, nova_velocidade: float, duracao: float,
		limites_saida: Rect2, nova_oscilacao := 0.0, nova_frequencia := 0.0) -> void:
	direcao = nova_direcao.normalized()
	if direcao == Vector2.ZERO:
		direcao = Vector2.DOWN

	velocidade = maxf(nova_velocidade, 1.0)
	tempo_de_vida = maxf(duracao, 0.1)
	oscilacao = nova_oscilacao
	frequencia = nova_frequencia
	_limites_saida = limites_saida

	_idade = 0.0
	_base_global = origem
	_eixo_oscilacao = direcao.orthogonal()
	global_position = origem

	_ativo = true
	visible = true
	# Pode ser chamado de dentro de um sinal de fisica (area_entered).
	set_deferred("monitorable", true)
	set_physics_process(true)


## Tira o projetil de circulacao para voltar ao pool.
func desativar() -> void:
	_parar()


func _parar() -> void:
	_ativo = false
	visible = false
	# Pode ser chamado dentro do area_entered; a Area2D fica travada
	# enquanto as consultas de fisica estao sendo processadas.
	set_deferred("monitorable", false)
	set_physics_process(false)
	global_position = Vector2(-10000.0, -10000.0)


func _physics_process(delta: float) -> void:
	if not _ativo:
		return

	var passo := minf(delta, 0.05)
	_idade += passo
	_base_global += direcao * velocidade * passo

	# O zigue-zague oscila em volta da reta, sem acumular desvio.
	if oscilacao > 0.0 and frequencia > 0.0:
		global_position = _base_global + _eixo_oscilacao * sin(_idade * frequencia) * oscilacao
	else:
		global_position = _base_global

	if _idade >= tempo_de_vida or not _limites_saida.has_point(global_position):
		_parar()
