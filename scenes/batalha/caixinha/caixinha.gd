extends Node2D

@export var velocidade: float = 200.0

@onready var caixa: ColorRect = $Caixa
@onready var patinha: Sprite2D = $Patinha


func _process(delta):
	var direcao = Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	# Movimentação da patinha
	patinha.position += direcao * velocidade * delta

	# Metade do tamanho da patinha
	var metade_patinha = patinha.texture.get_size() * patinha.scale / 2

	# Limites da caixa
	var limite_esquerdo = caixa.position.x + metade_patinha.x
	var limite_direito = caixa.position.x + caixa.size.x - metade_patinha.x

	var limite_superior = caixa.position.y + metade_patinha.y
	var limite_inferior = caixa.position.y + caixa.size.y - metade_patinha.y

	# Impedir que a patinha saia da caixa
	patinha.position.x = clamp(patinha.position.x, limite_esquerdo, limite_direito)
	patinha.position.y = clamp(patinha.position.y, limite_superior, limite_inferior)
