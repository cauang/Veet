extends Control

@onready var btn_voltar: Button = %BtnVoltar


func _ready() -> void:
	btn_voltar.pressed.connect(_on_voltar)


func _on_voltar() -> void:
	get_tree().change_scene_to_file("res://scenes/home/tela_home.tscn")
