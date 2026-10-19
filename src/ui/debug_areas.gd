# debug_areas.gd
# Desenho de debug por cima do mapa (ligado pelo menu de debug, aba "Mapa"):
#   vermelho  = colisão sólida da página ativa do evento
#   cinza     = colisão desligada (página passável)
#   azul      = área de interação "click"
#   verde     = área de interação "touch"
#   roxo      = área "parallel"
#   amarelo   = colisão da bruxa / laranja = área de interação da bruxa
# Fica fora do Mundo (o teleporte apaga tudo do Mundo menos o Player), mas desenha
# em coordenadas do mundo, então acompanha a câmera.
class_name DebugAreas
extends Node2D

const COR_SOLIDO := Color(1.0, 0.15, 0.15, 0.35)
const COR_PASSAVEL := Color(0.7, 0.7, 0.7, 0.18)
const COR_CLICK := Color(0.2, 0.55, 1.0, 0.25)
const COR_TOUCH := Color(0.2, 1.0, 0.35, 0.25)
const COR_PARALLEL := Color(0.75, 0.35, 1.0, 0.2)
const COR_PLAYER := Color(1.0, 0.9, 0.1, 0.45)
const COR_PLAYER_AREA := Color(1.0, 0.55, 0.1, 0.25)

var mundo: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_as_relative = false
	z_index = 4000
	visible = false

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(mundo):
		return
	var fonte := ThemeDB.fallback_font
	for ev in _eventos(mundo):
		var pagina = ev._get_active_page_node()
		if not pagina or not pagina.visible:
			continue
		# colisão da página
		var cs: CollisionShape2D = pagina.get("collision_shape")
		if cs and cs.shape:
			_desenhar(cs, COR_PASSAVEL if cs.disabled else COR_SOLIDO)
		# área de interação
		var zona = pagina.get_interaction_zone() if pagina.has_method("get_interaction_zone") else null
		if zona:
			var cor := COR_CLICK
			match str(zona.get("trigger_type")):
				"touch": cor = COR_TOUCH
				"parallel": cor = COR_PARALLEL
			if not zona.monitoring:
				cor.a *= 0.4
			var zs: CollisionShape2D = zona.get_node_or_null("CollisionShape2D")
			if zs and zs.shape:
				_desenhar(zs, cor)
		# nome do evento
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var nome: String = ev.evento.id if ev.get("evento") else str(ev.name)
		var p: Vector2 = to_local(ev.global_position) + Vector2(-30, -8)
		draw_string_outline(fonte, p, nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
		draw_string(fonte, p, nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	# bruxa
	var player = mundo.get_node_or_null("Player")
	if player:
		for cs in player.find_children("*", "CollisionShape2D", true, false):
			if cs.shape:
				_desenhar(cs, COR_PLAYER_AREA if cs.get_parent() is Area2D else COR_PLAYER)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _desenhar(cs: CollisionShape2D, cor: Color) -> void:
	draw_set_transform_matrix(get_global_transform().affine_inverse() * cs.get_global_transform())
	cs.shape.draw(get_canvas_item(), cor)
	if cs.shape is RectangleShape2D:
		var t: Vector2 = cs.shape.size
		draw_rect(Rect2(-t * 0.5, t), Color(cor, 0.9), false, 1.5)

static func _eventos(no: Node) -> Array:
	var lista: Array = []
	for c in no.get_children():
		if c.has_method("_get_active_page_node"):
			lista.append(c)
		lista.append_array(_eventos(c))
	return lista
