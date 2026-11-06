extends Control

var painel: Control


func _clicar(no: Control, local: Vector2) -> void:
	var pos := no.get_global_transform_with_canvas() * local
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	get_viewport().push_input(mv, true)
	await get_tree().process_frame
	await get_tree().process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	press.global_position = pos
	get_viewport().push_input(press, true)
	var solta := press.duplicate() as InputEventMouseButton
	solta.pressed = false
	get_viewport().push_input(solta, true)


func _arrastar(no: Control, de: Vector2, para: Vector2) -> void:
	var a := no.get_global_transform_with_canvas() * de
	var b := no.get_global_transform_with_canvas() * para
	var mv0 := InputEventMouseMotion.new()
	mv0.position = a
	mv0.global_position = a
	get_viewport().push_input(mv0, true)
	await get_tree().process_frame
	await get_tree().process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = a
	press.global_position = a
	get_viewport().push_input(press, true)
	for i in range(1, 11):
		var m := InputEventMouseMotion.new()
		m.position = a.lerp(b, i / 10.0)
		m.global_position = m.position
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(m, true)
		await get_tree().process_frame
	var solta := press.duplicate() as InputEventMouseButton
	solta.pressed = false
	solta.position = b
	solta.global_position = b
	get_viewport().push_input(solta, true)


func _ready() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.2, 0.3, 0.3)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	painel = load("res://scenes/componentes/painel_configuracoes.tscn").instantiate()
	painel.visible = false
	add_child(painel)
	await get_tree().create_timer(0.5).timeout
	painel.visible = true
	await get_tree().create_timer(1.2).timeout

	var s: SliderNovelo = painel.find_child("SliderMusica", true, false)
	print("TESTE musica antes=", s.value)
	var centro := s.get_global_transform_with_canvas() * Vector2(s.size.x * 0.7, 11)
	var mv := InputEventMouseMotion.new()
	mv.position = centro
	mv.global_position = centro
	get_viewport().push_input(mv, true)
	await get_tree().process_frame
	print("TESTE mf=", s.mouse_filter, " vis=", s.is_visible_in_tree(), " pai=", s.get_parent().name, " mf_pai=", (s.get_parent() as Control).mouse_filter, " idx=", s.get_index(), " tab_idx=", painel.find_child("Tabuleiro", true, false).get_index(), " pag_idx=", s.get_parent().get_index())
	var pg: Control = s.get_parent()
	print("TESTE pg pos=", pg.position, " size=", pg.size, " scale=", pg.scale, " pres=", s.position, " ssize=", s.size, " clip=", pg.clip_contents, " pgclip_parents=", pg.get_parent().clip_contents)
	print("TESTE hover=", get_viewport().gui_get_hovered_control(), " centro=", centro, " rect=", s.get_global_rect(), " xform=", s.get_global_transform_with_canvas())
	await _arrastar(s, Vector2(s.size.x * 0.7, 11), Vector2(s.size.x * 0.2, 11))
	print("TESTE musica depois=", s.value, " config=", get_node("/root/GerenciadorConfiguracoes").config_get("audio.musica"))
	await get_tree().create_timer(0.6).timeout
	print("FRAME_AUDIO")
	await get_tree().create_timer(0.3).timeout

	var aba: Button = painel.find_child("BtnAbaVideo", true, false)
	await _clicar(aba, aba.size * 0.5)
	await get_tree().create_timer(0.8).timeout
	print("TESTE pagina video visivel=", painel.find_child("PaginaVideo", true, false).visible, " audio=", painel.find_child("PaginaAudio", true, false).visible)
	var tg: InterruptorMadeira = painel.find_child("CheckTelaCheia", true, false)
	await _clicar(tg, tg.size * 0.5)
	await get_tree().create_timer(0.7).timeout
	print("TESTE tela_cheia=", tg.button_pressed)
	var campo: CampoSelecao = painel.find_child("OptionResolucao", true, false)
	await _clicar(campo.get_node("Botao"), Vector2(40, 10))
	await get_tree().create_timer(0.6).timeout
	print("FRAME_VIDEO")
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()
