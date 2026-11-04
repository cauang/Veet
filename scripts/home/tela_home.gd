extends Control

@onready var btn_jogar: Button = %BtnJogar
@onready var btn_configuracoes: Button = %BtnConfiguracoes
@onready var btn_fechar_jogo: Button = %BtnFecharJogo
@onready var painel_configuracoes: Control = %PainelConfiguracoes
@onready var confirmacao_fechar: ConfirmationDialog = %ConfirmacaoFechar

var _tween: Tween


func _ready() -> void:
	btn_jogar.pressed.connect(_on_jogar)
	btn_configuracoes.pressed.connect(_on_configuracoes)
	btn_fechar_jogo.pressed.connect(_on_fechar_jogo)
	painel_configuracoes.connect("solicitar_fechar", _fechar_painel)
	confirmacao_fechar.confirmed.connect(_on_confirmar_fechar)

	_painel_invisivel()
	btn_jogar.grab_focus()


func _painel_invisivel() -> void:
	painel_configuracoes.visible = false
	painel_configuracoes.modulate = Color(1, 1, 1, 0)


func _on_jogar() -> void:
	get_tree().change_scene_to_file("res://scenes/home/cena_placeholder.tscn")


func _on_configuracoes() -> void:
	painel_configuracoes.modulate = Color(1, 1, 1, 0)
	painel_configuracoes.visible = true

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(painel_configuracoes, "modulate:a", 1.0, 0.2)


func _fechar_painel() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(painel_configuracoes, "modulate:a", 0.0, 0.15)
	_tween.tween_callback(_painel_invisivel)


func _on_fechar_jogo() -> void:
	confirmacao_fechar.popup_centered()


func _on_confirmar_fechar() -> void:
	var gerenciador = get_node("/root/GerenciadorConfiguracoes")
	gerenciador.salvar()
	get_tree().quit()
