# game_manager.gd
# Centro do jogo: liga Database, GameTemp, Interpreter, InputManager e a UI.
# As partes grandes ficam em módulos (src/core/gm/), criados aqui no _ready:
#   FluxoDialogo	 - diálogo/opções entre Interpreter e a tela
#   Teleporte		- troca de mapa
#   FadeTela		 - escurecer/clarear a tela
#   ControlePreparo  - abrir/fechar a cena de preparo e aplicar a poção
#   FerramentasDebug - menu ' e atalhos F1–F6
# A API pública continua aqui (fade_out, abrir_preparo, get_player...), então
# comandos, eventos e UI chamam o GameManager como antes.
extends Node

@onready var database = $DatabaseManager
@onready var game_temp = $GameTemp
@onready var interpeter = $Interpeter
@onready var input_manager = $InputManager

signal preparo_fechado(resultado)
signal fade_out_completed
signal fade_in_completed

# ===== MÓDULOS =====
var dialogo: FluxoDialogo
var teleporte: Teleporte
var fade: FadeTela
var preparo: ControlePreparo
var debug_tools: FerramentasDebug
var debug_menu: DebugMenu = null

# ===== UI =====
var pause_menu_label = null
var notification_label = null
var notification_container = null

var player_locked: bool = false

## true durante a troca de mapa (e a carência logo depois): gatilhos de toque ficam desligados.
func teleportando() -> bool:
	return teleporte != null and teleporte.em_andamento

## true só enquanto o mapa está sendo trocado (a bruxa espera parada).
func trocando_mapa() -> bool:
	return teleporte != null and teleporte.trocando


# =============================================================================
# INICIALIZAÇÃO
# =============================================================================
func _ready():
	_criar_modulos()
	await get_tree().process_frame
	_buscar_ui()
	dialogo.configurar(self)
	_conectar_sinais()
	debug_menu = debug_tools.criar_menu()

	var player = get_player()
	if player:
		player.game_manager = self

	await get_tree().process_frame
	fade.fade_rect = get_node_or_null("/root/Main/CanvasLayer/Fade")
	if not fade.fade_rect:
		push_warning("[GameManager] Fade não encontrado")
	print("[GameManager] ✅ pronto")

func _criar_modulos() -> void:
	dialogo = _modulo(FluxoDialogo.new(), "FluxoDialogo")
	teleporte = _modulo(Teleporte.new(), "Teleporte")
	fade = _modulo(FadeTela.new(), "FadeTela")
	preparo = _modulo(ControlePreparo.new(), "ControlePreparo")
	debug_tools = _modulo(FerramentasDebug.new(), "FerramentasDebug")
	fade.fade_out_completed.connect(fade_out_completed.emit)
	fade.fade_in_completed.connect(fade_in_completed.emit)

func _modulo(m: Node, nome: String) -> Node:
	m.name = nome
	m.set("gm", self)
	add_child(m)
	return m

func _buscar_ui() -> void:
	pause_menu_label = get_node_or_null("/root/Main/CanvasLayer/PauseMenu/Label")
	notification_container = get_node_or_null("/root/Main/CanvasLayer/Notificacao")
	if notification_container:
		var item = notification_container.get_node_or_null("Container/NotificacaoItem")
		notification_label = item.get_node_or_null("Label") if item else null
		if item:
			item.visible = false   # é só o molde: cada notificação é uma cópia dele

func _conectar_sinais() -> void:
	if database:
		database.loaded.connect(debug_tools.resumo_do_banco)
		database.load_error.connect(func(e): push_error("[GameManager] Database: " + str(e)))
	if game_temp and not game_temp.variables_changed.is_connected(_on_variables_changed):
		game_temp.variables_changed.connect(_on_variables_changed)
	# páginas também podem depender de item e personalidade
	if game_temp and not game_temp.inventory_changed.is_connected(_on_variables_changed):
		game_temp.inventory_changed.connect(_on_variables_changed)
	if game_temp and not game_temp.personality_changed.is_connected(_on_personalidade_mudou):
		game_temp.personality_changed.connect(_on_personalidade_mudou)
	if interpeter:
		await get_tree().process_frame
		_conectar_interpreter()

func _conectar_interpreter() -> void:
	dialogo.conectar_interpreter(interpeter)
	if not interpeter.teleport_requested.is_connected(teleporte.teleportar):
		interpeter.teleport_requested.connect(teleporte.teleportar)
	if not interpeter.event_completed.is_connected(_on_evento_concluido):
		interpeter.event_completed.connect(_on_evento_concluido)
	if not preparo_fechado.is_connected(interpeter.on_preparo_fechado):
		preparo_fechado.connect(interpeter.on_preparo_fechado)
	
func _on_evento_concluido(nome: String, ok: bool) -> void:
	_show_notification("Evento concluído: " + nome if ok else "Falha no evento: " + nome)

# =============================================================================
# EVENTOS DO MAPA
# =============================================================================
## Quando uma variável muda, todos os eventos do mapa reavaliam a página ativa.
func _on_personalidade_mudou(_nome) -> void:
	_on_variables_changed()

func _on_variables_changed() -> void:
	var mundo = get_node_or_null("/root/Main/Mundo")
	if mundo:
		_atualizar_eventos(mundo)

func _atualizar_eventos(node: Node) -> void:
	for child in node.get_children():
		if child.has_method("refresh_event"):
			child.refresh_event()
		_atualizar_eventos(child)

func on_map_event(evento: EventoData, origem: Node = null) -> void:
	if interpeter:
		interpeter.trigger_event(evento, origem)

## Anda até o evento. Retorna true só se chegou (false se cancelado/travado).
func move_player_to_event(event_node: Node2D) -> bool:
	if not is_instance_valid(event_node) or not input_manager or not input_manager.can_move():
		return false
	var alvo: Vector2 = event_node.global_position + Vector2(-30, -80)
	input_manager.move_to_position(alvo.x, alvo.y)
	var meu_clique = input_manager.click_id
	const TIMEOUT := 15.0
	var passado := 0.0
	while input_manager.is_player_moving():
		await get_tree().process_frame
		passado += get_process_delta_time()
		# cancelado: o jogador clicou em outro lugar, o evento sumiu ou travou o player
		if not is_instance_valid(event_node) or not event_node.is_inside_tree():
			return false
		if input_manager.click_id != meu_clique or not input_manager.auto_moving and input_manager.is_moving:
			return false
		if passado > TIMEOUT:
			push_warning("[GameManager] timeout andando até o evento")
			return false
	var player = get_player()
	if not player or not is_instance_valid(event_node):
		return false
	if abs(player.global_position.x - alvo.x) < 20.0:
		return true
	# evento sólido: a bruxa para encostada nele (o ponto alvo fica dentro da colisão)
	return event_node.has_method("player_encostado") and event_node.player_encostado()

func try_activate_event(event_node: Node2D) -> bool:
	if not is_instance_valid(event_node) or not event_node.has_method("_activate"):
		return false
	var perto: bool = event_node.is_player_near() if event_node.has_method("is_player_near") else true
	if not perto:
		perto = await move_player_to_event(event_node)
	if perto and is_instance_valid(event_node):
		event_node._activate()
		return true
	return false

func request_event_activation(event_node: Node2D) -> void:
	if is_instance_valid(event_node):
		try_activate_event(event_node)

# =============================================================================
# API PÚBLICA (repassada aos módulos)
# =============================================================================
func abrir_preparo() -> void: preparo.abrir()
func fechar_preparo(resultado: Dictionary = {}) -> void: preparo.fechar(resultado)
func fade_out(tempo: float = 1.0) -> void: fade.fade_out(tempo)
func fade_in(tempo: float = 1.0) -> void: fade.fade_in(tempo)
func is_fading() -> bool: return fade.is_fading()
## Ao clarear, a bruxa volta a andar quando o preto fica abaixo deste alfa
## (0 = só no fim do clarear, 1 = assim que começa a clarear).
const ALFA_LIBERA_PLAYER: float = 0.7

## true enquanto a bruxa deve ficar parada pelo fade: escurecendo, tela preta e
## o começo do clarear (até o alfa cair abaixo de ALFA_LIBERA_PLAYER).
func tela_em_fade() -> bool:
	if fade == null or fade.fade_rect == null or not fade.fade_rect.visible:
		return false
	if fade.clareando():
		return fade.fade_rect.color.a > ALFA_LIBERA_PLAYER
	return true

func mostrar_hud() -> void: _hud_visivel(true)
func sumir_hud() -> void: _hud_visivel(false)

func _hud_visivel(v: bool) -> void:
	var hud = get_node_or_null("/root/Main/CanvasLayer/HUD")
	if hud and hud.has_method("set_ativo"):
		hud.set_ativo(v)   # cartas do HUD (no diálogo elas aparecem mesmo inativas)
	elif hud:
		hud.visible = v

func get_player() -> Node:
	var mundo = get_node_or_null("/root/Main/Mundo")
	return mundo.get_node_or_null("Player") if mundo else null

func get_player_position() -> Vector2:
	var player = get_player()
	return player.global_position if player else Vector2.ZERO

func get_input_manager():
	return input_manager

func lock_player() -> void: player_locked = true
func unlock_player() -> void: player_locked = false
func is_player_locked() -> bool: return player_locked

## Notificações empilhadas: cada uma é uma cópia de NotificacaoItem, entra com fade,
## fica NOTIF_TEMPO segundos e sai com fade. Mais que NOTIF_MAX: a mais antiga sai na hora.
const NOTIF_TEMPO: float = 2.5
const NOTIF_FADE: float = 0.25
const NOTIF_MAX: int = 4

func _show_notification(t: String) -> void:
	print("[GameManager] Notificação: ", t)
	var molde = notification_label.get_parent() if notification_label else null
	if molde and molde.get_parent():
		var caixa: Node = molde.get_parent()
		notification_container.visible = true
		var nova: Control = molde.duplicate()
		nova.get_node("Label").text = t
		nova.visible = true
		nova.modulate.a = 0.0
		caixa.add_child(nova)
		# limite: some com as mais antigas (o molde escondido não conta)
		var ativas: Array = caixa.get_children().filter(func(c): return c != molde and not c.is_queued_for_deletion())
		while ativas.size() > NOTIF_MAX:
			ativas.pop_front().queue_free()
		var tw := nova.create_tween()
		tw.tween_property(nova, "modulate:a", 1.0, NOTIF_FADE)
		tw.tween_interval(NOTIF_TEMPO)
		tw.tween_property(nova, "modulate:a", 0.0, NOTIF_FADE)
		tw.tween_callback(nova.queue_free)
	elif pause_menu_label:
		pause_menu_label.text = "NOTIFICAÇÃO: " + t
	else:
		push_warning("[GameManager] Notificação sem label: " + t)

# =============================================================================
# PAUSA (sempre limpando o input, para a bruxa não sair andando sozinha)
# =============================================================================
func _pause_game_with_reset() -> void:
	if input_manager and input_manager.has_method("force_reset"):
		input_manager.force_reset()
	get_tree().paused = true

func _unpause_game_with_reset() -> void:
	get_tree().paused = false
	if input_manager and input_manager.has_method("force_reset"):
		input_manager.force_reset()

# =============================================================================
# BOTÕES DO MENU DE PAUSA
# =============================================================================
func _on_continuar_pressed() -> void:
	var pm = get_node_or_null("/root/Main/CanvasLayer/PauseMenu")
	if pm:
		pm.visible = false
		get_tree().paused = false

func _on_sair_pressed() -> void:
	get_tree().quit()
