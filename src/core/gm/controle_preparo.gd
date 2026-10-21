# controle_preparo.gd
# Abre/fecha a cena de preparo de poções e aplica o resultado (poção no inventário).
# Ao fechar, o GameManager emite preparo_fechado, que retoma o evento que abriu o preparo.
class_name ControlePreparo
extends Node

var gm   # GameManager
## Fade da cena de preparo ao abrir/fechar (s).
const TEMPO_FADE: float = 0.6
var _tw_fade: Tween

func _cena():
	var cena = gm.get_node_or_null("/root/Main/CanvasLayer/CenaPreparo")
	if not cena:
		push_warning("[ControlePreparo] CenaPreparo não encontrada")
	return cena

func abrir() -> void:
	var cena = _cena()
	if not cena:
		return
	gm._pause_game_with_reset()
	_fade(cena, true)
	if cena.has_method("iniciar"):
		cena.iniciar()
	print("[ControlePreparo] 🧪 preparo aberto")

func fechar(resultado: Dictionary = {}) -> void:
	var cena = _cena()
	if not cena:
		return
	if cena.has_method("encerrar"):
		cena.encerrar()
	# poção pronta: a JanelaResultado já fez a animação (a cena fecha escondida pelo escuro)
	if resultado.is_empty() or resultado.get("cancelado", false):
		_fade(cena, false)
	else:
		cena.visible = false
		cena.modulate.a = 1.0
	gm._unpause_game_with_reset()
	# só aplica o resultado se NÃO for cancelamento
	if not resultado.is_empty() and not resultado.get("cancelado", false):
		_aplicar_resultado(resultado)
	# avisa o Interpreter que pode continuar (mesmo se cancelado)
	gm.preparo_fechado.emit(resultado)
	print("[ControlePreparo] 🧪 preparo fechado", " (cancelado)" if resultado.get("cancelado", false) else "")

## Espaço para as regras do resultado (variáveis, som...). Hoje: a poção vai pro inventário.
func _aplicar_resultado(resultado: Dictionary) -> void:
	if resultado.has("item") and gm.game_temp:
		# a JanelaResultado já pôs a poção no inventário durante a animação
		if not resultado.get("item_ja_adicionado", false):
			gm.game_temp.add_item(resultado.item, resultado.get("quantidade", 1))
		# missão 1: qualquer poção feita libera os guardas (ponte e estradaB)
		if gm.game_temp.get_var("missao01_pocao_feita") != 1.0:
			gm.game_temp.set_var("missao01_pocao_feita", 1.0)

## Entra/sai com fade (roda com o jogo pausado). Ao sair, esconde no fim.
func _fade(cena: CanvasItem, entrar: bool) -> void:
	if _tw_fade and _tw_fade.is_valid():
		_tw_fade.kill()
	_tw_fade = cena.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if entrar:
		cena.modulate.a = 0.0
		cena.visible = true
		_tw_fade.tween_property(cena, "modulate:a", 1.0, TEMPO_FADE)
	else:
		_tw_fade.tween_property(cena, "modulate:a", 0.0, TEMPO_FADE)
		_tw_fade.tween_callback(func():
			cena.visible = false
			cena.modulate.a = 1.0)

## Some com o fundo do preparo (chamado no fim da animação da poção).
func esconder() -> void:
	var cena = _cena()
	if cena and cena.visible:
		_fade(cena, false)
