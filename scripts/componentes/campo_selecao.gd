class_name CampoSelecao
extends Control
## Campo de selecao de madeira com lista que abre embaixo.
## Funciona dentro da propria cena (sem janelas do sistema), entao escala junto.
##
## Use `definir_itens()`, `selecionar()` e o sinal `item_selected(indice)`.

signal item_selected(indice: int)

const FONTE: Font = preload("res://assets/fontes/PressStart2P-Regular.ttf")

var selecionado := 0
var itens: PackedStringArray = []
var _aberto := false
var _tween: Tween

@onready var botao: Button = $Botao
@onready var lista: Control = $Lista
@onready var colunas: VBoxContainer = $Lista/Itens


func _ready() -> void:
	botao.pressed.connect(alternar)
	lista.visible = false
	lista.modulate.a = 0.0


func definir_itens(novos: PackedStringArray) -> void:
	itens = novos
	for filho in colunas.get_children():
		filho.queue_free()

	for i in range(itens.size()):
		var item := Button.new()
		item.text = itens[i]
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.custom_minimum_size = Vector2(0, 16)
		item.add_theme_font_override("font", FONTE)
		item.add_theme_font_size_override("font_size", 8)
		item.add_theme_color_override("font_color", Color("#3a2415"))
		item.add_theme_color_override("font_hover_color", Color("#fff3d6"))
		item.add_theme_color_override("font_pressed_color", Color("#fff3d6"))
		item.add_theme_stylebox_override("normal", _estilo(Color(0, 0, 0, 0)))
		item.add_theme_stylebox_override("hover", _estilo(Color("#e2685f")))
		item.add_theme_stylebox_override("pressed", _estilo(Color("#c4574f")))
		item.add_theme_stylebox_override("focus", _estilo(Color("#e2685f")))
		item.pressed.connect(_escolher.bind(i))
		colunas.add_child(item)

	var altura := itens.size() * 16.0 + 4.0
	lista.size.y = altura
	var fundo_borda := lista.get_node("FundoLista") as ColorRect
	var fundo_papel := lista.get_node("FundoLista2") as ColorRect
	fundo_borda.size = Vector2(size.x + 2.0, altura + 2.0)
	fundo_papel.size = Vector2(size.x, altura)
	colunas.size = Vector2(size.x, altura - 4.0)
	selecionar(selecionado, false)


func _estilo(cor: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.content_margin_left = 5
	estilo.content_margin_right = 5
	return estilo


func selecionar(indice: int, emitir := true) -> void:
	if indice < 0 or indice >= itens.size():
		return
	selecionado = indice
	botao.text = itens[indice]
	if emitir:
		item_selected.emit(indice)


func _escolher(indice: int) -> void:
	selecionar(indice)
	fechar()


func alternar() -> void:
	if _aberto:
		fechar()
	else:
		abrir()


func abrir() -> void:
	_aberto = true
	lista.visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	lista.position.y = botao.size.y - 2.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(lista, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(lista, "position:y", botao.size.y + 1.0, 0.25).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(lista, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func() -> void: lista.visible = false)
