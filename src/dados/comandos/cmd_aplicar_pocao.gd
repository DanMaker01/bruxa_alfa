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
	var tree: SceneTree = interp.get_tree()
	if alvo is Node2D:
		var p := CPUParticles2D.new()
		p.one_shot = true
		p.explosiveness = 0.6
		p.amount = 40
		p.lifetime = 1.4
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(40, 60)
		p.direction = Vector2.UP
		p.spread = 40.0
		p.initial_velocity_min = 30.0
		p.initial_velocity_max = 90.0
		p.gravity = Vector2(0, -30)
		p.scale_amount_min = 3.0
		p.scale_amount_max = 7.0
		var rampa := Gradient.new()
		rampa.set_color(0, Color.WHITE)
		rampa.set_color(1, Color(COR_BRILHO, 0.0))
		rampa.add_point(0.3, COR_BRILHO)
		p.color_ramp = rampa
		p.z_index = 20
		alvo.add_child(p)
		p.position = Vector2(0, -80)
		p.emitting = true
		tree.create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)
	var cam = interp.get_camera()
	if cam and cam.has_method("tremer_camera"):
		cam.tremer_camera(4.0, 0.05, 0.6)
	# clarão
	var camada := CanvasLayer.new()
	camada.layer = 15
	tree.root.add_child(camada)
	var flash := ColorRect.new()
	flash.color = Color(COR_BRILHO, 0.0)
	flash.size = tree.root.get_visible_rect().size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(flash)
	var tw := camada.create_tween()
	tw.tween_property(flash, "color:a", 0.7, 0.15)
	tw.tween_property(flash, "color:a", 0.0, 0.8)
	await tw.finished
	camada.queue_free()
	await tree.create_timer(0.6).timeout
