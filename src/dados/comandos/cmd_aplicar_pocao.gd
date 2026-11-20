# Abre o inventário para a bruxa escolher um item e aplicá-lo numa personalidade:
# tocar no item mostra o botão "Aplicar poção" no popup; "Desistir" cancela.
# Aplicar: personalidade = A · personalidade (A = matriz do item), o item sai do
# inventário e há um efeito mágico no evento alvo.
# A variável recebe 1 se aplicou e 0 se desistiu (use com if).
# Enquanto escolhe aparece o MenuAplicarPocao: face e nome do alvo e o pentagrama da
# personalidade dele; tocar numa poção mostra a prévia; aplicar anima a mudança.
class_name CmdAplicarPocao
extends Comando

## id da personalidade que recebe a poção (ex.: "princesa").
@export var personalidade: String = ""
## Variável que recebe 1 (aplicou) ou 0 (desistiu).
@export var variavel: String = "aplicou_pocao"
@export var texto_botao: String = "Aplicar poção"
## id do evento onde aparece o efeito mágico (vazio = centro da tela).
@export var evento_alvo: String = ""
## Face e nome no menu. Vazio = dados/falantes/<personalidade>.tres, se existir.
@export var personagem: Personagem

const COR_BRILHO := Color(0.85, 0.7, 1.0)
## Depois de confirmar (o popup fecha): espera isto antes do destaque e do efeito.
const ESPERA_DESTAQUE: float = 0.5

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
	var menu := _abrir_menu(interp, gt)
	var previa := func(id_foco: String):
		if menu == null or not is_instance_valid(menu):
			return
		var it: ItemData = interp.database.get_item(id_foco) if interp.database and id_foco != "" else null
		menu.previa(calcular(gt.get_personality(personalidade), CalculadoraPocao.matriz_do_item(it)) if it else null)
	if hud.has_signal("item_em_foco"):
		hud.item_em_foco.connect(previa)
	hud.escolher_item(texto_botao)
	var id: String = await hud.item_escolhido
	if hud.has_signal("item_em_foco") and hud.item_em_foco.is_connected(previa):
		hud.item_em_foco.disconnect(previa)
	var aplicou := 0.0
	if id != "":
		var item: ItemData = interp.database.get_item(id) if interp.database else null
		if item:
			var A := CalculadoraPocao.matriz_do_item(item)
			var novo := calcular(gt.get_personality(personalidade), A)
			_aplicar(interp, gt, A)
			gt.remove_item(id, 1)
			aplicou = 1.0
			var alvo = interp.encontrar_evento(evento_alvo) if evento_alvo != "" else null
			# o popup já fechou: meio segundo e aí o destaque no menu, junto com o efeito no alvo
			await interp.get_tree().create_timer(ESPERA_DESTAQUE).timeout
			var fim_efeito := [false]
			var efeito := func():
				await efeito_magico(interp, alvo)
				fim_efeito[0] = true
			efeito.call()
			if menu and is_instance_valid(menu):
				await menu.aplicar(novo)
			while not fim_efeito[0]:
				await interp.get_tree().process_frame
	if menu and is_instance_valid(menu):
		await menu.fechar()
	var antigo = gt.get_var(variavel)
	gt.set_var(variavel, aplicou)
	interp.variable_changed.emit(variavel, antigo, aplicou)
	if not ev.finished and ev.pause_reason == "item":
		ev.resume_and_advance()

func _aplicar(interp, gt, A: Array) -> void:
	aplicar_matriz(interp, gt, personalidade, A)

## Menu com face e pentagrama do alvo, no CanvasLayer do main.
func _abrir_menu(interp, gt) -> MenuAplicarPocao:
	var camada = interp.get_node_or_null("/root/Main/CanvasLayer")
	if camada == null:
		return null
	var p: Personagem = personagem
	if p == null:
		var caminho := "res://dados/falantes/%s.tres" % personalidade
		if ResourceLoader.exists(caminho):
			p = load(caminho) as Personagem
	var menu := MenuAplicarPocao.new()
	camada.add_child(menu)
	menu.abrir(p, personalidade, gt.get_personality(personalidade))
	return menu

## p' = A · p, limitado a −10..10 (sem aplicar).
static func calcular(p: Array, A: Array) -> Array:
	var novo: Array = []
	for i in 5:
		var v := 0.0
		for j in 5:
			v += float(A[i][j]) * float(p[j])
		novo.append(clampf(v, -10.0, 10.0))
	return novo

## p' = A · p (linhas O, C, E, A, N), limitado a −10..10. Também usado ao "Usar" item no inventário.
static func aplicar_matriz(interp, gt, personalidade: String, A: Array) -> void:
	var p: Array = gt.get_personality(personalidade)
	var novo: Array = calcular(p, A)
	gt.set_personality(personalidade, novo)
	for i in 5:
		if not is_equal_approx(float(p[i]), novo[i]):
			interp.personality_changed.emit(personalidade, i, p[i], novo[i])
	print("[AplicarPocao] ", personalidade, ": ", p, " -> ", novo)

## Clarão + brilhos subindo no alvo (evento ou bruxa) + câmera tremendo um pouco.
static func efeito_magico(interp, alvo) -> void:
	Vibrar.forte()   # aplicar poção (o tremor da câmera logo depois não vibra de novo)
	await CmdMostrarEfeito.mostrar(interp, alvo, CmdMostrarEfeito.Tipo.MAGICO, COR_BRILHO)
