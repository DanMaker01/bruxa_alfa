# status.gd
extends Control

# =============================================================================
# REFERÊNCIAS
# =============================================================================
@onready var pivo: Node2D = $Pivo
@onready var icone_o: TextureRect = $Pivo/Icone_O
@onready var icone_c: TextureRect = $Pivo/Icone_C
@onready var icone_e: TextureRect = $Pivo/Icone_E
@onready var icone_a: TextureRect = $Pivo/Icone_A
@onready var icone_n: TextureRect = $Pivo/Icone_N

var game_temp = null

# =============================================================================
# CICLO DE VIDA
# =============================================================================

const NOMES_TRACOS := ["Abertura", "Conscienciosidade", "Extroversão", "Amabilidade", "Neuroticismo"]
## Segundos que o nome fica na tela depois do toque.
const TEMPO_BALAO: float = 1.5
var _balao: Label
var _tw_balao: Tween

func _ready():
	_criar_balao()
	_find_dependencies()
	_atualizar_cores()
	_conectar_sinais()
	print("[Status] Inicializado!")

func _find_dependencies():
	var main = get_tree().current_scene
	if not main:
		return
	var game_manager = main.get_node_or_null("GameManager")
	if game_manager:
		game_temp = game_manager.get_node_or_null("GameTemp")

func _conectar_sinais():
	if game_temp and game_temp.has_signal("personality_changed"):
		game_temp.personality_changed.connect(_on_personality_changed)
		print("[Status] Conectado ao sinal personality_changed!")

# =============================================================================
# CORES
# =============================================================================

func _atualizar_cores():
	if not game_temp:
		print("[Status] ❌ GameTemp não disponível!")
		return
	
	var personalidades = game_temp.get_all_personalities()
	var bruxa = personalidades.get("bruxa", [0, 0, 0, 0, 0])
	
	var icones = [icone_o, icone_c, icone_e, icone_a, icone_n]
	for i in range(icones.size()):
		var valor = bruxa[i] if i < bruxa.size() else 0.0
		var cor = _valor_para_cor(valor)
		_aplicar_cor(icones[i], cor)

func _valor_para_cor(valor: float) -> Color:
	var v = clamp(valor, -5.0, 5.0)
	var t = (v + 5.0) / 10.0
	# Verde → Cinza → Roxo
	var inicio = Color(0.0, 0.8, 0.0)   # Verde (valor baixo)
	var meio = Color(0.9, 0.9, 0.9)     # Cinza (neutro)
	var fim = Color(0.8, 0.0, 0.8)      # Roxo (valor alto)
	
	if t < 0.5:
		return inicio.lerp(meio, t * 2)
	else:
		return meio.lerp(fim, (t - 0.5) * 2)

func _aplicar_cor(node: TextureRect, cor: Color):
	if not node:
		return
	node.modulate = cor

# =============================================================================
# SINAIS
# =============================================================================

func _on_personality_changed(_name: String):
	print("[Status] Personalidade mudou!")
	_atualizar_cores()

func atualizar():
	_atualizar_cores()

# =============================================================================
# BALÃO: toque num ícone mostra o nome do traço (e o valor)
# =============================================================================
func _criar_balao() -> void:
	_balao = Label.new()
	_balao.name = "Balao"
	_balao.z_as_relative = false
	_balao.z_index = 300
	_balao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balao.add_theme_font_size_override("font_size", 20)
	_balao.add_theme_color_override("font_color", Color.WHITE)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0.85)
	st.set_corner_radius_all(8)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	_balao.add_theme_stylebox_override("normal", st)
	_balao.visible = false
	add_child(_balao)
	var icones = [icone_o, icone_c, icone_e, icone_a, icone_n]
	for i in range(icones.size()):
		if icones[i]:
			icones[i].mouse_filter = Control.MOUSE_FILTER_STOP
			icones[i].gui_input.connect(_on_icone_input.bind(i))

func _on_icone_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_mostrar_balao(i)

func _mostrar_balao(i: int) -> void:
	var icones = [icone_o, icone_c, icone_e, icone_a, icone_n]
	var valor := 0.0
	if game_temp:
		var b = game_temp.get_all_personalities().get("bruxa", [])
		if i < b.size():
			valor = b[i]
	_balao.text = "%s  %+.2f" % [NOMES_TRACOS[i], valor]
	_balao.size = _balao.get_combined_minimum_size()
	var ic: Control = icones[i]
	var centro: Vector2 = ic.global_position + ic.size * 0.5
	var tela := get_viewport_rect().size
	var x := clampf(centro.x - _balao.size.x * 0.5, 4.0, tela.x - _balao.size.x - 4.0)
	_balao.global_position = Vector2(x, ic.global_position.y - _balao.size.y - 4.0)
	_balao.visible = true
	_balao.modulate.a = 1.0
	if _tw_balao and _tw_balao.is_valid():
		_tw_balao.kill()
	_tw_balao = _balao.create_tween()
	_tw_balao.tween_interval(TEMPO_BALAO)
	_tw_balao.tween_property(_balao, "modulate:a", 0.0, 0.25)
	_tw_balao.tween_callback(_balao.hide)
