extends Control


func _ready() -> void:
	var painel: Control = load("res://scenes/componentes/painel_configuracoes.tscn").instantiate()
	painel.visible = false
	add_child(painel)
	await get_tree().create_timer(0.3).timeout
	painel.visible = true
	await get_tree().create_timer(1.0).timeout
	for nome in ["BtnAbaAudio", "SliderMaster", "SliderMusica", "CheckMudo", "BtnPadroes", "ValMaster", "RotMaster"]:
		var no: Control = painel.find_child(nome, true, false)
		var p := no.get_global_transform_with_canvas() * (no.size * 0.5)
		var mv := InputEventMouseMotion.new()
		mv.position = p
		mv.global_position = p
		get_viewport().push_input(mv)
		await get_tree().process_frame
		await get_tree().process_frame
		var h := get_viewport().gui_get_hovered_control()
		print("HIT ", nome, " em ", p, " -> ", h.name if h else "nada", " mf=", no.mouse_filter, " size=", no.size)
	get_tree().quit()
