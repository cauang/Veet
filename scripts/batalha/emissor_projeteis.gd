extends Node2D
## Emissor dos inimigos (projetis) da fase de esquiva.
##
## Le um padrao de ataque de data/padroes_ataque/*.json, cria os projetis em
## pool e controla a duracao da fase. A patinha precisa sobreviver ate o tempo
## acabar; nao existe combate nem forma de destruir o projetil.

signal fase_iniciada(id: String, nome: String)
signal tempo_alterado(restante: float, total: float)
signal fase_terminou()

const CENA_PROJETIL: PackedScene = preload("res://scenes/batalha/projeteis/projetil.tscn")
const PASTA_PADROES := "res://data/padroes_ataque/"
const MARGEM := 34.0
const POOL_PADRAO := 32

@export var padroes: PackedStringArray = ["ondas_dor", "gotas_cistite", "ziguezague", "rajada_diagonal"]
@export var duracao_fase := 10.0
@export var tamanho_pool := POOL_PADRAO
## Dificuldade aumenta levemente a cada fase sobrevivida (capada).
@export var dificuldade_progressiva := true

var _limites := Rect2()
var _projeteis: Array[Area2D] = []
var _emissoes: Array[Dictionary] = []
var _indice_padrao := 0
var _proximo_lado := 1
var _duracao_atual := 10.0
var _tempo_restante := 0.0
var _fase_ativa := false
var _rng := RandomNumberGenerator.new()
var _fases_concluidas := 0
var _multiplicador_velocidade := 1.0
var _multiplicador_intervalo := 1.0


func _ready() -> void:
	_rng.randomize()
	_criar_pool()


## A caixinha informa os limites da area de jogo antes de iniciar a fase.
func definir_limites(area: Rect2) -> void:
	_limites = area


func iniciar_fase() -> void:
	if _fase_ativa:
		return

	if _limites.size.x <= 0.0 or _limites.size.y <= 0.0:
		_limites = Rect2(365.0, 360.0, 550.0, 300.0)

	if padroes.is_empty():
		push_warning("EmissorProjeteis: nenhum padrao de ataque configurado.")
		return

	var id: String = padroes[_indice_padrao % padroes.size()]
	_indice_padrao = (_indice_padrao + 1) % padroes.size()
	_atualizar_dificuldade()

	var definicao := _carregar_definicao(id)
	if definicao.is_empty():
		definicao = _definicao_padrao()

	_duracao_atual = maxf(1.0, float(definicao.get("duracao", duracao_fase)))
	_preparar_emissoes(definicao)
	_tempo_restante = _duracao_atual
	_fase_ativa = true

	var nome := String(definicao.get("nome", id))
	fase_iniciada.emit(id, nome)
	tempo_alterado.emit(_tempo_restante, _duracao_atual)


## Interrompe a fase sem emitir fase_terminou (usado quando a vida zera).
func parar_fase() -> void:
	_fase_ativa = false
	for projetil in _projeteis:
		projetil.desativar()


func _process(delta: float) -> void:
	if not _fase_ativa:
		return

	var passo := minf(delta, 0.1)
	_tempo_restante = maxf(_tempo_restante - passo, 0.0)
	tempo_alterado.emit(_tempo_restante, _duracao_atual)

	if _tempo_restante <= 0.0:
		_encerrar_fase()
		return

	for emissao in _emissoes:
		emissao["proximo"] = float(emissao["proximo"]) - passo
		if float(emissao["proximo"]) <= 0.0:
			_emitir(emissao)
			var intervalo := float(emissao.get("intervalo", 1.0)) * _multiplicador_intervalo
			var variacao := float(emissao.get("intervalo_variacao", 0.0)) * _multiplicador_intervalo
			emissao["proximo"] = maxf(0.06, intervalo + _rng.randf_range(-variacao, variacao))


func _encerrar_fase() -> void:
	if not _fase_ativa:
		return

	_fase_ativa = false
	_fases_concluidas += 1
	for projetil in _projeteis:
		projetil.desativar()

	tempo_alterado.emit(0.0, _duracao_atual)
	fase_terminou.emit()


# ------------------------------------------------------------------- pool

func _criar_pool() -> void:
	var quantidade := maxi(tamanho_pool, 4)
	for i in range(quantidade):
		_projeteis.append(_novo_projetil())


func _novo_projetil() -> Area2D:
	var projetil: Area2D = CENA_PROJETIL.instantiate()
	add_child(projetil)
	projetil.desativar()
	return projetil


func _pegar_projetil() -> Area2D:
	for projetil in _projeteis:
		if not projetil.esta_ativo():
			return projetil

	# Pool esgotado: cria mais um para nao perder a rajada.
	var novo := _novo_projetil()
	_projeteis.append(novo)
	return novo


# --------------------------------------------------------------- emissao

func _emitir(emissao: Dictionary) -> void:
	var tipo := String(emissao.get("tipo", "queda"))
	var velocidade := float(emissao.get("velocidade", 160.0))
	var variacao_velocidade := float(emissao.get("velocidade_variacao", 0.0))
	velocidade += _rng.randf_range(-variacao_velocidade, variacao_velocidade)
	velocidade = maxf(velocidade * _multiplicador_velocidade, 40.0)

	var origem := Vector2.ZERO
	var direcao := Vector2.DOWN

	match tipo:
		"reta":
			var entra_pela_esquerda := _lado_horizontal(emissao)
			var y := _valor_faixa(emissao, "y")
			if entra_pela_esquerda > 0:
				origem = Vector2(_limites.position.x - MARGEM, y)
				direcao = Vector2.RIGHT
			else:
				origem = Vector2(_limites.end.x + MARGEM, y)
				direcao = Vector2.LEFT
		"diagonal":
			var lado := _lado_horizontal(emissao)
			var x := _limites.position.x - MARGEM if lado > 0 else _limites.end.x + MARGEM
			origem = Vector2(x, _limites.position.y - MARGEM)
			direcao = Vector2(1.0, 1.0).normalized() if lado > 0 else Vector2(-1.0, 1.0).normalized()
		_:
			var x := _valor_faixa(emissao, "x")
			origem = Vector2(x, _limites.position.y - MARGEM)
			direcao = Vector2.DOWN

	var projetil := _pegar_projetil()
	projetil.ativar(
		to_global(origem),
		direcao,
		velocidade,
		_tempo_de_travessia(direcao, velocidade),
		_retangulo_saida(),
		float(emissao.get("oscilacao", 0.0)),
		float(emissao.get("frequencia", 0.0))
	)


func _lado_horizontal(emissao: Dictionary) -> int:
	# 1 = entra pela esquerda; -1 = entra pela direita.
	var lado := String(emissao.get("lado", "alternar"))
	if lado == "esquerda":
		return 1
	if lado == "direita":
		return -1

	var atual := _proximo_lado
	_proximo_lado = -_proximo_lado
	return atual


func _valor_faixa(emissao: Dictionary, eixo: String) -> float:
	var faixa = emissao.get("posicao", [0.1, 0.9])
	var inicio := 0.1
	var fim := 0.9

	if faixa is Array and faixa.size() >= 2:
		inicio = clampf(float(faixa[0]), 0.0, 1.0)
		fim = clampf(float(faixa[1]), 0.0, 1.0)

	if inicio > fim:
		var troca := inicio
		inicio = fim
		fim = troca

	var t := _rng.randf_range(inicio, fim)
	if eixo == "x":
		return _limites.position.x + _limites.size.x * t
	return _limites.position.y + _limites.size.y * t


func _tempo_de_travessia(direcao: Vector2, velocidade: float) -> float:
	var largura := _limites.size.x + MARGEM * 2.0
	var altura := _limites.size.y + MARGEM * 2.0
	var distancia := maxf(largura, altura)

	if absf(direcao.x) > 0.1 and absf(direcao.y) > 0.1:
		distancia = sqrt(largura * largura + altura * altura)
	elif absf(direcao.x) >= absf(direcao.y):
		distancia = largura
	else:
		distancia = altura

	return distancia / maxf(velocidade, 1.0) + 0.3


func _retangulo_saida() -> Rect2:
	var origem := to_global(_limites.position)
	return Rect2(origem, _limites.size).grow(MARGEM + 12.0)


# ------------------------------------------------------------ dificuldade

func _atualizar_dificuldade() -> void:
	if not dificuldade_progressiva:
		_multiplicador_velocidade = 1.0
		_multiplicador_intervalo = 1.0
		return

	# Progressao suave: um pouco mais rapido e frequente, com teto.
	var nivel := mini(_fases_concluidas, 8)
	_multiplicador_velocidade = 1.0 + float(nivel) * 0.045
	_multiplicador_intervalo = maxf(1.0 - float(nivel) * 0.04, 0.72)


# ---------------------------------------------------------------- padroes

func _carregar_definicao(id: String) -> Dictionary:
	var caminho := PASTA_PADROES + id + ".json"
	if not FileAccess.file_exists(caminho):
		push_warning("Padrao de ataque nao encontrado: " + caminho)
		return {}

	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		return {}

	var texto := arquivo.get_as_text()
	arquivo.close()

	var dados = JSON.parse_string(texto)
	if dados is Dictionary:
		return dados

	push_warning("Padrao de ataque invalido: " + caminho)
	return {}


func _preparar_emissoes(definicao: Dictionary) -> void:
	_emissoes.clear()
	var lista = definicao.get("emissoes", [])
	if not (lista is Array):
		return

	for item in lista:
		if not (item is Dictionary):
			continue
		var emissao: Dictionary = item.duplicate(true)
		emissao["proximo"] = _rng.randf_range(0.2, 0.6)
		_emissoes.append(emissao)


func _definicao_padrao() -> Dictionary:
	# Mantem a fase jogavel mesmo se o JSON estiver ausente ou invalido.
	return {
		"duracao": duracao_fase,
		"emissoes": [
			{
				"tipo": "queda",
				"intervalo": 0.8,
				"intervalo_variacao": 0.2,
				"velocidade": 200.0,
				"velocidade_variacao": 20.0,
				"posicao": [0.1, 0.9],
			}
		],
	}
