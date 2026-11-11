class_name Personagem
extends Node2D
## Personagem humano animado a partir das folhas de assets/personagens/<id>/.
##
## A folha tem 4 linhas (idle, falar, andar, acenar) x 4 quadros de 64x96.
## A origem do node fica nos pes (centro-inferior do quadro), entao basta
## posicionar o node no chao da cena.
## Ids disponiveis: protagonista, helena, euler, davi, rita, beatriz.

const LARGURA_QUADRO := 64
const ALTURA_QUADRO := 96
const LINHAS: Array[String] = ["idle", "falar", "andar", "acenar"]
const FPS := {"idle": 6.0, "falar": 8.0, "andar": 8.0, "acenar": 6.0}
const EXPRESSOES: Array[String] = ["neutro", "falando", "sorrindo", "preocupado", "surpreso"]

@export var id := "helena":
	set(valor):
		id = valor
		if is_node_ready():
			_montar()

@export var virado_para_esquerda := false:
	set(valor):
		virado_para_esquerda = valor
		if is_node_ready():
			sprite.flip_h = valor

var animacao_atual := "idle"
@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	_montar()


func _montar() -> void:
	var caminho := "res://assets/personagens/%s/%s_sheet.png" % [id, id]
	if not ResourceLoader.exists(caminho):
		push_error("Personagem: folha nao encontrada: " + caminho)
		return

	var folha: Texture2D = load(caminho)
	var quadros := SpriteFrames.new()
	quadros.remove_animation("default")

	for linha in LINHAS.size():
		var nome := LINHAS[linha]
		quadros.add_animation(nome)
		quadros.set_animation_speed(nome, FPS[nome])
		quadros.set_animation_loop(nome, true)
		for coluna in 4:
			var atlas := AtlasTexture.new()
			atlas.atlas = folha
			atlas.region = Rect2(coluna * LARGURA_QUADRO, linha * ALTURA_QUADRO, LARGURA_QUADRO, ALTURA_QUADRO)
			quadros.add_frame(nome, atlas)

	sprite.sprite_frames = quadros
	sprite.centered = true
	sprite.offset = Vector2(0, -ALTURA_QUADRO / 2.0)   # pes na origem do node
	sprite.flip_h = virado_para_esquerda
	tocar(animacao_atual)


func tocar(animacao: String) -> void:
	if not LINHAS.has(animacao):
		push_warning("Personagem: animacao desconhecida '%s'" % animacao)
		return
	animacao_atual = animacao
	if sprite.sprite_frames != null:
		sprite.play(animacao)


## Anda ate a coordenada x (em px da cena pai) e volta ao idle. Pode ser awaited.
func andar_ate(destino_x: float, velocidade := 140.0) -> void:
	var distancia := absf(destino_x - position.x)
	if distancia < 1.0:
		return
	virado_para_esquerda = destino_x < position.x
	tocar("andar")
	var audio := get_node_or_null("/root/GerenciadorAudio")
	var passos: AudioStreamPlayer = audio.call("passos") if audio != null else null
	var tween := create_tween()
	tween.tween_property(self, "position:x", destino_x, distancia / velocidade)
	await tween.finished
	if passos != null:
		passos.stop()
	tocar("idle")


## Retrato 64x64 da expressao (indice ou nome em EXPRESSOES) para a caixa de dialogo.
func retrato(expressao: Variant = 0) -> AtlasTexture:
	return Personagem.retrato_de(id, expressao)


static func retrato_de(personagem_id: String, expressao: Variant = 0) -> AtlasTexture:
	var indice: int = expressao if expressao is int else maxi(EXPRESSOES.find(String(expressao)), 0)
	var caminho := "res://assets/personagens/%s/%s_retratos.png" % [personagem_id, personagem_id]
	if not ResourceLoader.exists(caminho):
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = load(caminho)
	atlas.region = Rect2(indice * 64, 0, 64, 64)
	return atlas
