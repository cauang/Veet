extends Control
# Teste temporario: abre a Home, pula a abertura e abre o painel de configuracoes.


func _ready() -> void:
	var home: Control = load("res://scenes/home/tela_home.tscn").instantiate()
	add_child(home)
	await get_tree().create_timer(0.4).timeout
	var tecla := InputEventKey.new()
	tecla.pressed = true
	tecla.keycode = KEY_SPACE
	Input.parse_input_event(tecla)
	await get_tree().create_timer(2.2).timeout
	print("MARCA_HOME")
	var botao: BaseButton = home.find_child("BtnConfiguracoes", true, false)
	botao.pressed.emit()
	await get_tree().create_timer(1.2).timeout
	print("MARCA_CFG")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
