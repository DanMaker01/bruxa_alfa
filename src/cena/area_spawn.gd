# area_spawn.gd
# Área de spawn: no máximo "quantidade" cópias de um EventoData numa faixa
# horizontal do mapa. Coloque o nó dentro de "Eventos" (o mapa conecta as cópias
# como qualquer outro evento).
#
# - Posições e tempos ficam salvos no GameTemp: sair do mapa e voltar mantém tudo.
# - Cada cópia é um nó de evento próprio, com self-variables próprias
#   (chave "mapa:Eventos/<Area>/<Area>_<i>").
# - Coletar = a cópia liga a self-variable LETRA_COLETADO (A). Quando o evento dela
#   termina, começa o cooldown; ao fim dele a cópia renasce num ponto qualquer da
#   faixa, com as self-variables zeradas e um efeito de brilho.
#   O cooldown continua contando mesmo fora do mapa.
#
# Evento usado aqui: página 0 = coleta (dá o item e liga a self-var A);
# página 1 = condição "self" A == 1, sem sprite (fica invisível até renascer).
@tool
class_name AreaSpawn
extends Node2D

const EVENTO_BASE := preload("res://src/cena/evento_base.gd")
const LETRA_COLETADO := "A"
# ---- efeito de nascer ----
const COR_BRILHO := Color(1.0, 0.95, 0.6)
const COR_BRILHO_FIM := Color(0.6, 1.0, 0.7, 0.0)
const TEMPO_APARECER: float = 0.5

@export var evento: EventoData
@export_range(1, 20) var quantidade: int = 3:
	set(v):
		quantidade = v
		queue_redraw()
## Largura da faixa (px), centrada no nó. As cópias ficam na altura (y) do nó.
@export var largura: float = 600.0:
	set(v):
		largura = v
		queue_redraw()
## Variação vertical aleatória (± px).
@export var variacao_y: float = 0.0:
	set(v):
		variacao_y = v
		queue_redraw()
## Tempo (s) depois de coletar até nascer um novo.
@export var cooldown: float = 20.0

var _gt = null
var _chave: String = ""
var _copias: Array = []   # nós de evento; índice = índice em _dados.pos / _dados.renasce
## Guardado em GameTemp.spawns[_chave]: {"pos": [Vector2...], "renasce": [float...]}
## renasce[i] = instante (s, relógio do jogo) em que a cópia i volta; -1 = está no mapa.
var _dados: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if evento == null:
		push_warning("[AreaSpawn] " + name + " sem EventoData")
		return
	_gt = get_node_or_null("/root/Main/GameManager/GameTemp")
	_chave = _chave_area()
	var salvo = _gt.spawns.get(_chave) if _gt else null
	if salvo is Dictionary and salvo.get("pos", []).size() == quantidade:
		_dados = salvo   # já visitou: mesmas posições e mesmos cooldowns
	else:
		_dados = {"pos": [], "renasce": []}
		for i in range(quantidade):
			_dados.pos.append(_ponto_aleatorio())
			_dados.renasce.append(-1.0)
		if _gt:
			_gt.spawns[_chave] = _dados
			_gt.limpar_self_vars(_chave + "/")
	for i in range(quantidade):
		var no := CharacterBody2D.new()
		no.set_script(EVENTO_BASE)
		no.name = "%s_%d" % [name, i]
		no.set("evento", evento)
		no.position = _dados.pos[i]
		add_child(no)
		_copias.append(no)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _gt == null:
		return
	var agora := _relogio()
	for i in range(_copias.size()):
		var no = _copias[i]
		if not is_instance_valid(no):
			continue
		var chave_no: String = no.chave_self()
		if _gt.get_self_var(chave_no, LETRA_COLETADO) < 1.0:
			continue   # está no mapa
		if _dados.renasce[i] < 0.0:
			# acabou de ser coletada: espera o evento dela terminar e liga o cooldown
			if not _rodando(chave_no):
				_dados.renasce[i] = agora + cooldown
		elif agora >= _dados.renasce[i]:
			_renascer(i)

func _rodando(chave_no: String) -> bool:
	var interp = get_node_or_null("/root/Main/GameManager/Interpeter")
	if interp == null:
		return false
	for e in interp.running_events:
		if not e.finished and e.chave_self == chave_no:
			return true
	return false

func _renascer(i: int) -> void:
	var no = _copias[i]
	var nova := _ponto_aleatorio()
	no.position = nova
	_dados.pos[i] = nova
	_dados.renasce[i] = -1.0
	_gt.limpar_self_vars(no.chave_self())   # volta para a página 0 (sem emitir sinal)
	if no.has_method("reset_event_state"):
		no.reset_event_state()
	if no.has_method("refresh_event"):
		no.refresh_event()
	_efeito_nascer(no)

func _ponto_aleatorio() -> Vector2:
	return Vector2(randf_range(-largura * 0.5, largura * 0.5), randf_range(-variacao_y, variacao_y))

## Relógio do jogo em segundos (continua contando fora do mapa).
func _relogio() -> float:
	return Time.get_ticks_msec() / 1000.0

# =============================================================================
# EFEITO DE NASCER: brilho subindo + a cópia cresce e aparece
# =============================================================================
func _efeito_nascer(no: Node2D) -> void:
	# brilhos
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = 18
	p.lifetime = 0.8
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(18, 6)
	p.direction = Vector2.UP
	p.spread = 35.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2(0, -40)
	p.damping_min = 20.0
	p.damping_max = 50.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	var rampa := Gradient.new()
	rampa.set_color(0, Color.WHITE)
	rampa.set_color(1, COR_BRILHO_FIM)
	rampa.add_point(0.3, COR_BRILHO)
	p.color_ramp = rampa
	p.position = no.position
	p.z_index = 1
	add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)
	# a cópia aparece (alfa) e o sprite da página cresce com um pulinho
	no.modulate = Color(1, 1, 1, 0)
	no.create_tween().tween_property(no, "modulate", Color.WHITE, TEMPO_APARECER)
	var pagina = no._get_active_page_node() if no.has_method("_get_active_page_node") else null
	var sprite: Node2D = pagina.get_node_or_null("AnimatedSprite2D") if pagina else null
	if sprite:
		var escala: Vector2 = sprite.scale
		sprite.scale = escala * 0.2
		sprite.create_tween().tween_property(sprite, "scale", escala, TEMPO_APARECER) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _chave_area() -> String:
	var n: Node = self
	while n.get_parent() and n.get_parent().name != "Mundo":
		n = n.get_parent()
	if n.get_parent():
		return n.scene_file_path.get_file().get_basename() + ":" + str(n.get_path_to(self))
	return str(get_path())

# Editor: mostra a faixa de spawn.
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := Rect2(-largura * 0.5, -variacao_y - 4.0, largura, variacao_y * 2.0 + 8.0)
	draw_rect(r, Color(0.3, 1.0, 0.4, 0.15), true)
	draw_rect(r, Color(0.3, 1.0, 0.4, 0.8), false, 2.0)
	for i in range(quantidade):
		var x := -largura * 0.5 + largura * (i + 0.5) / quantidade
		draw_circle(Vector2(x, 0), 6.0, Color(0.3, 1.0, 0.4, 0.8))
