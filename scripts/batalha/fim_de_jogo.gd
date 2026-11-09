extends Control
## Modal de fim de jogo exibido quando o Vinculo da patinha chega a zero.
##
## A navegacao fica com quem instancia o modal: ele apenas emite os sinais
## "tentar_novamente" e "voltar_ao_menu".

signal tentar_novamente()
signal voltar_ao_menu()

@onready var painel: PanelContainer = $Centro/Painel
@onready var btn_tentar: Button = %BtnTentarNovamente
@onready var btn_voltar: Button = %BtnVoltarMenu

var _audio: Node
var _tween: Tween


func _ready() -> void:
	visible = false
	_audio = get_node_or_null("/root/GerenciadorAudio")

	btn_tentar.pressed.connect(_on_tentar)
	btn_voltar.pressed.connect(_on_voltar)
	btn_tentar.mouse_entered.connect(_som_hover)
	btn_voltar.mouse_entered.connect(_som_hover)
	painel.resized.connect(_atualizar_pivo)


func abrir() -> void:
	if visible:
		return

	# Garante tamanho/ancoras corretos mesmo quando filho de Node2D via CanvasLayer.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vp := get_viewport_rect().size
	if vp.x > 0.0 and vp.y > 0.0:
		size = vp
		position = Vector2.ZERO

	visible = true
	modulate.a = 0.0
	painel.scale = Vector2(0.92, 0.92)
	_atualizar_pivo()

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(painel, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	btn_tentar.grab_focus()


func _atualizar_pivo() -> void:
	painel.pivot_offset = painel.size * 0.5


func _on_tentar() -> void:
	_som_clique()
	tentar_novamente.emit()


func _on_voltar() -> void:
	_som_clique()
	voltar_ao_menu.emit()


func _som_hover() -> void:
	if _audio != null and visible:
		_audio.hover()


func _som_clique() -> void:
	if _audio != null:
		_audio.clique()
