# Mostra um efeito visual na bruxa, num evento ou na tela toda.
#   MAGICO  = brilhos subindo + clarão + tremor leve (o mesmo de aplicar poção)
#   BRILHOS = só os brilhos subindo no alvo
#   CLARAO  = só a tela piscando na cor escolhida
#   FUMACA  = nuvem cinza que se espalha (ex.: alguém sumindo)
#   SOM     = três risquinhos saindo do alvo num cone de 30° (ex.: batida na porta); se o alvo estiver fora
#             da tela, aparecem na beira da tela do lado dele
class_name CmdMostrarEfeito
extends Comando

enum Alvo { BRUXA, EVENTO, TELA }
enum Tipo { MAGICO, BRILHOS, CLARAO, FUMACA, SOM }
const TIPOS := ["magico", "brilhos", "clarao", "fumaca", "som"]
const COR_PADRAO := Color(0.85, 0.7, 1.0)

@export var alvo: Alvo = Alvo.BRUXA:
	set(v):
		alvo = v
		notify_property_list_changed()
## id do evento (alvo = EVENTO).
@export var evento: String = ""
@export var tipo: Tipo = Tipo.MAGICO
@export var cor: Color = COR_PADRAO
## Altura do efeito acima dos pés do alvo (px).
@export var altura: float = 80.0
## Ligado: o evento espera o efeito terminar.
@export var esperar: bool = true

func to_dict() -> Dictionary:
	return {"nome": "mostrar_efeito", "args": [["bruxa", evento, "tela"][alvo], TIPOS[tipo]]}

func executar(interp, ev) -> int:
	var no = null
	match alvo:
		Alvo.BRUXA: no = interp.game_manager.get_player() if interp.game_manager else null
		Alvo.EVENTO: no = interp.encontrar_evento(evento)
	if alvo != Alvo.TELA and not (no is Node2D):
		interp.falhar(ev, self, "alvo não encontrado")
		return AVANCAR
	if not esperar:
		mostrar(interp, no, tipo, cor, altura)
		return AVANCAR
	ev.pause("efeito")
	_rodar(interp, ev, no)
	return MANTER

func _rodar(interp, ev, no) -> void:
	await mostrar(interp, no, tipo, cor, altura)
	if not ev.finished and ev.pause_reason == "efeito":
		ev.resume_and_advance()

## Efeito pronto para outros scripts (ex.: aplicar poção, usar item).
static func mostrar(interp, no, qual: int = Tipo.MAGICO, c: Color = COR_PADRAO, alt: float = 80.0) -> void:
	var tree: SceneTree = interp.get_tree()
	match qual:
		Tipo.MAGICO:
			_brilhos(tree, no, c, alt)
			var cam = interp.get_camera()
			if cam and cam.has_method("tremer_camera"):
				cam.tremer_camera(4.0, 0.05, 0.6)
			await _clarao(tree, c)
			await tree.create_timer(0.6).timeout
		Tipo.BRILHOS:
			_brilhos(tree, no, c, alt)
			await tree.create_timer(1.4).timeout
		Tipo.CLARAO:
			await _clarao(tree, c)
		Tipo.FUMACA:
			_fumaca(tree, no, alt)
			await tree.create_timer(1.2).timeout
		Tipo.SOM:
			_som(tree, no, c, alt)
			await tree.create_timer(Ondas.DURACAO).timeout

static func _brilhos(tree: SceneTree, no, c: Color, alt: float) -> void:
	if not (no is Node2D):
		return
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
	rampa.set_color(1, Color(c, 0.0))
	rampa.add_point(0.3, c)
	p.color_ramp = rampa
	_por_no_mapa(p, no, Vector2(0, -alt))
	p.emitting = true
	tree.create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)

## Põe as partículas no mapa, onde o alvo está (não como filhas dele): assim continuam
## aparecendo se o alvo sumir logo depois (ex.: a bruxa some com o Pó de Retorno).
static func _por_no_mapa(p: CPUParticles2D, no: Node2D, desloc: Vector2) -> void:
	p.z_index = 20
	p.z_as_relative = false
	var pai: Node = no.get_parent() if no.get_parent() else no
	pai.add_child(p)
	p.global_position = no.global_position + desloc

static func _fumaca(tree: SceneTree, no, alt: float) -> void:
	if not (no is Node2D):
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 28
	p.lifetime = 1.1
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 30.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0
	p.gravity = Vector2(0, -20)
	p.scale_amount_min = 10.0
	p.scale_amount_max = 22.0
	var rampa := Gradient.new()
	rampa.set_color(0, Color(0.85, 0.85, 0.85, 0.9))
	rampa.set_color(1, Color(0.5, 0.5, 0.55, 0.0))
	p.color_ramp = rampa
	_por_no_mapa(p, no, Vector2(0, -alt * 0.6))
	p.emitting = true
	tree.create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)

static func _clarao(tree: SceneTree, c: Color) -> void:
	var camada := CanvasLayer.new()
	camada.layer = 15
	tree.root.add_child(camada)
	var flash := ColorRect.new()
	flash.color = Color(c, 0.0)
	flash.size = tree.root.get_visible_rect().size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(flash)
	var tw := camada.create_tween()
	tw.tween_property(flash, "color:a", 0.7, 0.15)
	tw.tween_property(flash, "color:a", 0.0, 0.8)
	await tw.finished
	camada.queue_free()

func _validate_property(property: Dictionary) -> void:
	if property.name == "evento" and alvo != Alvo.EVENTO:
		property.usage = PROPERTY_USAGE_STORAGE
	if property.name == "altura" and alvo == Alvo.TELA:
		property.usage = PROPERTY_USAGE_STORAGE

# =============================================================================
# SOM: três risquinhos num cone de 30°, virados para o meio da tela
# =============================================================================
static func _som(_tree: SceneTree, no, c: Color, alt: float) -> void:
	if not (no is Node2D):
		return
	var pos: Vector2 = no.global_position + Vector2(0, -alt)
	var dir := -1.0
	var cam: Camera2D = no.get_viewport().get_camera_2d()
	if cam:
		var centro: Vector2 = cam.get_screen_center_position()
		var meia: Vector2 = no.get_viewport_rect().size * 0.5 / cam.zoom
		const MARGEM := 48.0
		dir = -1.0 if pos.x > centro.x else 1.0
		pos.x = clampf(pos.x, centro.x - meia.x + MARGEM, centro.x + meia.x - MARGEM)
		pos.y = clampf(pos.y, centro.y - meia.y + MARGEM, centro.y + meia.y - MARGEM)
	var o := Ondas.new()
	o.dir = dir
	o.cor = c
	o.z_index = 30
	o.z_as_relative = false
	var pai: Node = no.get_parent() if no.get_parent() else no
	pai.add_child(o)
	o.global_position = pos
	var tw := o.create_tween()
	tw.tween_property(o, "prog", 1.0, Ondas.DURACAO)
	tw.tween_callback(o.queue_free)

class Ondas extends Node2D:
	## Três risquinhos saindo de um ponto, num cone de 30° (para a esquerda se dir = -1).
	const DURACAO := 0.45
	const CONE := 30.0         # abertura total do cone, em graus
	var dir := -1.0          # -1 = para a esquerda, 1 = para a direita
	var cor := Color.WHITE
	var prog := 0.0:
		set(v):
			prog = v
			queue_redraw()
	func _draw() -> void:
		var base := 0.0 if dir > 0.0 else PI
		var a := clampf(1.0 - prog, 0.0, 1.0)
		var ini := 10.0 + prog * 28.0          # os risquinhos se afastam do centro
		var comp := 18.0 - prog * 5.0
		for i in 3:
			var ang := base + deg_to_rad((i - 1) * CONE * 0.5)
			var v := Vector2(cos(ang), sin(ang))
			draw_line(v * ini, v * (ini + comp), Color(cor, a), 5.0, true)
