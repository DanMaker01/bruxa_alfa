# Abre o inventário para a bruxa escolher um item e aplicá-lo numa personalidade:
# tocar no item mostra o botão "Aplicar poção" no popup; "Desistir" cancela.
# Aplicar: personalidade = A · personalidade (A = matriz do item), o item sai do
# inventário e há um efeito mágico no evento alvo.
# A variável recebe 1 se aplicou e 0 se desistiu (use com if).
class_name CmdAplicarPocao
extends Comando

## id da personalidade que recebe a poção (ex.: "princesa").
@export var personalidade: String = ""
## Variável que recebe 1 (aplicou) ou 0 (desistiu).
@export var variavel: String = "aplicou_pocao"
@export var texto_botao: String = "Aplicar poção"
## id do evento onde aparece o efeito mágico (vazio = centro da tela).
@export var evento_alvo: String = ""

const COR_BRILHO := Color(0.85, 0.7, 1.0)

func to_dict() -> Dictionary:
	return {"nome": "aplicar_pocao", "args": [personalidade, variavel]}

func executar(interp, ev) -> int:
	var hud = interp.get_node_or_null("/root/Main/CanvasLayer/HUD")
	var gt = interp.game_temp
	if hud == null or not hud.has_method("escolher_item") or gt == null:
		interp.falhar(ev, self, "sem HUD/GameTemp")
		return AVANCAR
	if not gt.has_personality(personalidade):
		interp.falhar(ev, self, "personalidade '%s' não existe" % personalidade)
		return AVANCAR
	ev.pause("item")
	_escolher(interp, ev, hud, gt)
	return MANTER

func _escolher(interp, ev, hud, gt) -> void:
	hud.escolher_item(texto_botao)
	var id: String = await hud.item_escolhido
	var aplicou := 0.0
	if id != "":
		var item: ItemData = interp.database.get_item(id) if interp.database else null
		if item:
			_aplicar(interp, gt, CalculadoraPocao.matriz_do_item(item))
			gt.remove_item(id, 1)
			aplicou = 1.0
			var alvo = interp.encontrar_evento(evento_alvo) if evento_alvo != "" else null
			await efeito_magico(interp, alvo)
	var antigo = gt.get_var(variavel)
	gt.set_var(variavel, aplicou)
	interp.variable_changed.emit(variavel, antigo, aplicou)
	if not ev.finished and ev.pause_reason == "item":
		ev.resume_and_advance()

func _aplicar(interp, gt, A: Array) -> void:
	aplicar_matriz(interp, gt, personalidade, A)

## p' = A · p (linhas O, C, E, A, N), limitado a −10..10. Também usado ao "Usar" item no inventário.
static func aplicar_matriz(interp, gt, personalidade: String, A: Array) -> void:
	var p: Array = gt.get_personality(personalidade)
	var novo: Array = []
	for i in 5:
		var v := 0.0
		for j in 5:
			v += float(A[i][j]) * float(p[j])
		novo.append(clampf(v, -10.0, 10.0))
	gt.set_personality(personalidade, novo)
	for i in 5:
		if not is_equal_approx(float(p[i]), novo[i]):
			interp.personality_changed.emit(personalidade, i, p[i], novo[i])
	print("[AplicarPocao] ", personalidade, ": ", p, " -> ", novo)

## Clarão + brilhos subindo no alvo (evento ou bruxa) + câmera tremendo um pouco.
static func efeito_magico(interp, alvo) -> void:
	await CmdMostrarEfeito.mostrar(interp, alvo, CmdMostrarEfeito.Tipo.MAGICO, COR_BRILHO)
