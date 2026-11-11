extends Node
## Rotas e transicoes do jogo (autoload "GerenciadorCenas").
##
## Centraliza os caminhos das cenas e a ordem do fluxo principal, para que
## nenhuma cena precise conhecer a proxima. Fluxo atual:
##   Home -> Introducao -> Triagem -> Batalha
## Cada cena do fluxo chama GerenciadorCenas.avancar() quando termina.

const ROTAS := {
	"home": "res://scenes/home/tela_home.tscn",
	"introducao": "res://scenes/introducao/introducao.tscn",
	"triagem": "res://scenes/triagem/triagem.tscn",
	"batalha": "res://scenes/batalha/caixinha/caixinha.tscn",
}

## Ordem das etapas apos apertar JOGAR. Para encaixar uma tela nova
## (ex.: "prontuario"), registre a rota acima e coloque o nome aqui.
const FLUXO_JOGO: Array[String] = ["introducao", "triagem", "batalha"]

const DURACAO_FADE := 0.4

var etapa_atual := -1
var _ocupado := false
var _cortina: ColorRect


func _ready() -> void:
	_criar_cortina()


func _criar_cortina() -> void:
	if _cortina != null:
		return
	var camada := CanvasLayer.new()
	camada.layer = 100
	add_child(camada)

	_cortina = ColorRect.new()
	_cortina.color = Color(0.02, 0.03, 0.05, 1.0)
	_cortina.modulate.a = 0.0
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)
	camada.add_child(_cortina)


## true quando a cena atual foi aberta pelo fluxo do jogo (e nao rodando solta com F6).
func em_fluxo() -> bool:
	return etapa_atual >= 0


## Inicia o fluxo principal (chamado pelo botao JOGAR da Home).
## `cortina_ja_fechada` = true quando a cena de origem ja escureceu a tela.
func iniciar_jogo(cortina_ja_fechada := false) -> void:
	etapa_atual = -1
	avancar(cortina_ja_fechada)


## Vai para a proxima etapa do fluxo; ao fim do fluxo volta para a Home.
func avancar(cortina_ja_fechada := false) -> void:
	etapa_atual += 1
	if etapa_atual >= FLUXO_JOGO.size():
		voltar_ao_menu(cortina_ja_fechada)
		return
	ir_para(FLUXO_JOGO[etapa_atual], cortina_ja_fechada)


func voltar_ao_menu(cortina_ja_fechada := false) -> void:
	etapa_atual = -1
	ir_para("home", cortina_ja_fechada)


## Recarrega a etapa atual (ex.: "tentar novamente" depois do fim de jogo).
func reiniciar_etapa() -> void:
	get_tree().reload_current_scene()


func ir_para(rota: String, cortina_ja_fechada := false) -> void:
	if _ocupado:
		return
	if not ROTAS.has(rota):
		push_error("GerenciadorCenas: rota desconhecida '%s'" % rota)
		return

	_criar_cortina()
	_ocupado = true
	if cortina_ja_fechada:
		_cortina.modulate.a = 1.0
	else:
		var entrada := create_tween()
		entrada.tween_property(_cortina, "modulate:a", 1.0, DURACAO_FADE).set_trans(Tween.TRANS_SINE)
		await entrada.finished

	get_tree().change_scene_to_file(ROTAS[rota])
	await get_tree().process_frame
	await get_tree().process_frame

	var saida := create_tween()
	saida.tween_property(_cortina, "modulate:a", 0.0, DURACAO_FADE).set_trans(Tween.TRANS_SINE)
	await saida.finished
	_ocupado = false
