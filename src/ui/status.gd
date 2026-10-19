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

func _ready():
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
