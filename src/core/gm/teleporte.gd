# teleporte.gd
# Troca de mapa: tira o mapa antigo, reposiciona a bruxa, instancia o novo e
# reativa as interações depois que a física estabiliza.
class_name Teleporte
extends Node

var gm   # GameManager

## Tempo depois da troca de mapa em que gatilhos de TOQUE ficam ignorados (s).
## Evita encadear passagens: a bruxa nasce no mapa novo e uma passagem "toque"
## que coincide com a posição antiga (ou com o ponto de chegada) não dispara sozinha.
const CARENCIA_TOQUE: float = 0.4
## true do começo da troca até o fim da carência.
var em_andamento: bool = false
## true só enquanto o mapa está sendo trocado (antes da carência).
var trocando: bool = false
var _troca_id: int = 0   # cada troca tem um id; só a mais recente encerra a carência


func teleportar(mapa: String, x: float, y: float, direcao: String = "centro") -> void:
	print("[Teleporte] 📍 ", mapa, " (", x, ", ", y, ") ", direcao)
	em_andamento = true
	trocando = true
	_troca_id += 1
	var minha_troca := _troca_id
	var player = gm.get_player()
	var input_manager = gm.input_manager

	# 1. bruxa parada e sem interagir durante a troca (o jogo NÃO pausa)
	if player and player.has_method("disable_interaction"):
		player.disable_interaction()
	if input_manager:
		input_manager.force_reset(true)   # mantém o dedo: segue andando no mapa novo
	if player:
		player.velocity = Vector2.ZERO
		if player.has_method("force_stop"):
			player.force_stop()

	# 2. carrega o mapa novo
	var mundo = gm.get_node_or_null("/root/Main/Mundo")
	var path := "res://mapas/" + mapa + ".tscn"
	if not mundo or not ResourceLoader.exists(path):
		push_warning("[Teleporte] mapa não encontrado: " + path)
		gm._show_notification("Mapa não encontrado: " + mapa)
		_reativar_player(player)
		em_andamento = false
		trocando = false
		return
	var cena_mapa: PackedScene = load(path)
	if not cena_mapa:
		push_warning("[Teleporte] erro ao carregar: " + path)
		_reativar_player(player)
		em_andamento = false
		trocando = false
		return

	# 3. remove o mapa antigo (mantém o Player). remove_child tira da árvore AGORA:
	#    buscas por evento (Interpreter) não acham mais nós do mapa antigo.
	for child in mundo.get_children():
		if child.name != "Player":
			mundo.remove_child(child)
			child.queue_free()

	# 4. reposiciona a bruxa ANTES do mapa novo entrar na árvore
	#    (assim as zonas "touch" novas não a detectam na posição antiga)
	if player:
		player.position = Vector2(x, y)
		player.velocity = Vector2.ZERO
		if player.has_method("force_stop"):
			player.force_stop()
		aplicar_direcao(player, direcao)
		_camera_no_player(player)

	# 5. mapa novo
	mundo.add_child(cena_mapa.instantiate())
	_camera_no_player(player)   # de novo, já com os limites do mapa novo
	if input_manager:
		input_manager.force_reset(true)   # mantém o dedo: segue andando no mapa novo
		if input_manager.player != player:
			input_manager.player = player

	# 6. espera a física estabilizar e devolve o controle
	await get_tree().process_frame
	await get_tree().process_frame
	_reativar_player(player)
	_reativar_zonas(mundo)
	if input_manager:
		input_manager.force_reset(true)   # mantém o dedo: segue andando no mapa novo
	print("[Teleporte] ✅ concluído")
	if minha_troca == _troca_id:
		trocando = false   # dedo ainda apertado? ela volta a andar quando o fade clarear
	# carência: passagens de toque só valem depois que a bruxa "assentou" no mapa novo
	await get_tree().create_timer(CARENCIA_TOQUE, true).timeout
	if minha_troca == _troca_id:
		em_andamento = false

func aplicar_direcao(player: Node, direcao: String) -> void:
	var sprite = player.get_node_or_null("Sprite2D") if player else null
	if sprite:
		sprite.flip_h = direcao == "esq"

func _camera_no_player(player: Node) -> void:
	var cam = player.get_node_or_null("Camera2D") if player else null
	if cam and cam.has_method("snap_to_player"):
		cam.snap_to_player()

func _reativar_player(player: Node) -> void:
	if player and player.has_method("enable_interaction"):
		player.enable_interaction()

## Reativa a zona de interação da página ativa de cada evento do mapa.
func _reativar_zonas(node: Node) -> void:
	for child in node.get_children():
		if child.has_method("_get_active_page_node"):
			var page = child._get_active_page_node()
			if page and page.has_method("get_interaction_zone"):
				var zone = page.get_interaction_zone()
				if zone and zone.has_method("set_zone_active"):
					zone.set_zone_active(true)
		_reativar_zonas(child)
