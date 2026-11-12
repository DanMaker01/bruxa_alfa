# game_interpeter.gd
# Executa as páginas de evento em paralelo: fila de eventos, pausas, esperas,
# fila única de diálogos/opções e blocos if/else/while. O QUE cada comando faz
# está no próprio comando (src/dados/comandos/cmd_*.gd).
extends Node

const PageSelector = preload("res://src/core/page_selector.gd")

var database = null
var game_temp = null
var game_manager = null

# A página em execução fica em EventInstance (src/core/event_instance.gd).
# Cada comando se executa sozinho: Comando.executar(interp, ev) (src/dados/comandos/).

# ===== FILA DE DIÁLOGOS / OPÇÕES =====
# Item: {"event": EventInstance, "kind": "msg"|"option", ...}
# Diálogos e opções passam pela MESMA fila, então uma pergunta nunca
# sobrescreve um diálogo que já está na tela.
var dialog_queue: Array = []
var current_dialog = null  # item da fila que está na tela agora
var is_dialog_active: bool = false
var running_events: Array = []
var event_id_counter: int = 0

# ===== SINAIS =====
signal option_requested(question, options, falante)
# Emitidos pelos comandos (interp.<sinal>.emit), não por esta classe.
@warning_ignore("unused_signal")
signal variable_changed(var_name, old_value, new_value)
@warning_ignore("unused_signal")
signal personality_changed(name, index, old_value, new_value)
@warning_ignore("unused_signal")
signal item_added(item_name, quantity)
@warning_ignore("unused_signal")
signal item_removed(item_name, quantity)
@warning_ignore("unused_signal")
signal teleport_requested(map_name, x, y, direcao)
signal dialog_requested(messages, falante)
signal dialog_finished
signal event_completed(event_name, success)
signal command_executed(command_name, success)



func _ready():
	print("[Interpreter] Inicializando (PARALELO)...")
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_initialize")

func _initialize():
	game_manager = get_node_or_null("/root/Main/GameManager")
	if not game_manager:
		push_error("[Interpreter] GameManager não encontrado!"); return
	database = game_manager.get_node_or_null("DatabaseManager")
	game_temp = game_manager.get_node_or_null("GameTemp")
	if not game_temp:
		push_error("[Interpreter] GameTemp não encontrado!"); return
	if not dialog_finished.is_connected(_on_dialog_finished):
		dialog_finished.connect(_on_dialog_finished)
	print("[Interpreter] ===== INICIALIZADO (PARALELO) =====")

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		debug_fila()


func _process(delta):
	running_events = running_events.filter(func(e): return not e.finished)

	for event in running_events:
		if event.finished:
			continue

		if event.is_paused:
			# Esperando um evento chamado (CmdChamarEvento): retoma quando ele terminar
			if event.pause_reason == "chamado":
				if event.filho == null or event.filho.finished:
					event.filho = null
					event.resume_and_advance()
				continue
			# Movimento com wait=true: se o alvo sumiu (troca de mapa), não espera para sempre
			if event.pause_reason == "move" and (event.move_target_ref == null or event.move_target_ref.get_ref() == null):
				print("[Interpreter] ⚠️ Evento ", event.id, ": alvo do movimento sumiu, continuando")
				event.move_target_ref = null
				event.resume_and_advance()
			continue

		if event.is_waiting:
			event.wait_timer -= delta
			if event.wait_timer <= 0:
				event.is_waiting = false
				event.current_index += 1
			continue

		_process_event_step(event)

## Comandos que mostram diálogo (pelo nome do arquivo do script).
const CMDS_DIALOGO := ["cmd_mostrar_msg.gd", "cmd_mostrar_opcoes.gd"]
## Comandos instantâneos: olhando para frente, pula eles (não interrompem o diálogo).
const CMDS_INSTANTANEOS := ["cmd_label.gd", "cmd_variavel.gd", "cmd_if.gd", "cmd_else.gd", "cmd_end.gd",
	"cmd_item.gd", "cmd_som.gd", "cmd_goto.gd", "cmd_direcao.gd", "cmd_break.gd", "cmd_estilo_dialogo.gd",
	"cmd_mudar_personalidade.gd", "cmd_apagar_evento.gd"]
const OLHAR_A_FRENTE: int = 6

## Vem diálogo logo em seguida? (fila de diálogos, ou algum evento rodando cujo próximo
## comando que conta é um diálogo). Esperar, mover, fade etc. interrompem: aí não.
## A carta do HUD pergunta isto para não desvirar entre dois diálogos seguidos.
func dialogo_a_seguir() -> bool:
	if not dialog_queue.is_empty():
		return true
	for ev in running_events:
		if ev.finished or ev.is_waiting:
			continue
		if ev.is_paused and ev.pause_reason != "dialog":
			continue
		var i: int = ev.current_index + (1 if ev.is_paused else 0)
		for k in OLHAR_A_FRENTE:
			if i >= ev.commands.size():
				break
			var c = ev.commands[i]
			var arq: String = c.get_script().resource_path.get_file() if c and c.get_script() else ""
			if arq in CMDS_DIALOGO:
				return true
			if not (arq in CMDS_INSTANTANEOS):
				break
			i += 1
	return false

func _process_event_step(event: EventInstance):
	if event.current_index >= event.commands.size():
		_finish_event(event, true)
		return
	var cmd: Comando = event.comando_atual()
	if cmd == null:
		aviso(event, "comando vazio no índice %d" % event.current_index)
		event.current_index += 1
		return
	event.falhou = false
	var resultado: int = cmd.executar(self, event)
	if not event.finished:
		command_executed.emit(cmd.nome_cmd(), not event.falhou)
	if resultado == Comando.AVANCAR and not event.finished:
		event.current_index += 1

func _finish_event(event: EventInstance, success: bool):
	if event.finished:
		return
	event.finished = true
	event.is_waiting = false
	event.pause_reason = ""
	event_completed.emit(event.name, success)
	print("[Interpreter] 🏁 Evento ", event.id, " finalizado (", event.name, ")")
	# 🔥 NOTIFICA O EVENTO QUE TERMINOU (se ele ainda existir no mapa atual)
	_notify_event_finished(event)

# ===== API USADA PELOS COMANDOS =====

## Termina o evento por erro de script (if sem end, label inexistente, etc.)
func abortar(event: EventInstance, msg: String):
	print("[Interpreter] ❌ ERRO no evento ", event.id, " (", event.name, ") índice ", event.current_index, ": ", msg)
	_finish_event(event, false)

## Comando falhou mas o evento segue (o comando devolve AVANCAR, nunca trava no mesmo índice).
func falhar(event: EventInstance, cmd: Comando, msg: String):
	event.falhou = true
	print("[Interpreter] ⚠️ ", cmd.nome_cmd() if cmd else "?", " falhou (evento ", event.name, "): ", msg)

func aviso(event: EventInstance, msg: String):
	print("[Interpreter] ⚠️ ", event.name, ": ", msg)

## ev (opcional): evento que está avaliando, para condições de self-variable.
func avaliar(cond, ev: EventInstance = null) -> bool:
	return PageSelector.evaluate(cond, game_temp, ev.chave_self if ev else "")

func enfileirar_dialogo(item: Dictionary):
	_enqueue_dialog(item)

func encontrar_evento(event_name: String):
	return _find_event_by_name(event_name)

func get_camera():
	if not game_manager:
		return null
	var player = game_manager.get_player()
	return player.get_node_or_null("Camera2D") if player else null

func get_audio_manager():
	return game_manager.get_node_or_null("AudioManager") if game_manager else null


func _notify_event_finished(event: EventInstance):
	"""Notifica o nó do evento que sua execução terminou (se ele ainda existir)"""
	var event_name: String = event.name
	var target_event = event.origem.get_ref() if event.origem else _find_event_by_name(event_name)
	if target_event and (not is_instance_valid(target_event) or not target_event.is_inside_tree()):
		target_event = null
	if target_event and target_event.has_method("on_event_finished"):
		target_event.on_event_finished()
	elif not target_event:
		# Normal quando o evento terminou em outro mapa (ex.: teleportou no meio)
		print("[Interpreter]   (nó de '", event_name, "' não está no mapa atual)")

# ===== BLOCOS (if/else/while/end/break) =====

func _build_blocks(event: EventInstance) -> void:
	"""Pré-calcula onde cada bloco começa/termina. Conta if e while juntos."""
	var stack: Array = []
	var cmds = event.commands
	for i in range(cmds.size()):
		var c = cmds[i]
		if c is CmdIf:
			stack.append({"type": "if", "start": i, "else": -1})
		elif c is CmdWhile:
			stack.append({"type": "while", "start": i, "else": -1})
		elif c is CmdElse:
			if not stack.is_empty() and stack[-1]["type"] == "if" and stack[-1]["else"] == -1:
				stack[-1]["else"] = i
				event.blocks[i] = stack[-1]
			else:
				aviso(event, "else sem if no índice %d" % i)
		elif c is CmdEnd:
			if stack.is_empty():
				aviso(event, "end sem if/while no índice %d" % i)
				continue
			var b = stack.pop_back()
			b["end"] = i
			event.blocks[b["start"]] = b
			event.blocks[i] = b
		elif c is CmdBreak:
			# o while mais interno que envolve este break
			for k in range(stack.size() - 1, -1, -1):
				if stack[k]["type"] == "while":
					event.blocks[i] = stack[k]  # dicionário compartilhado: recebe "end" depois
					break
	# Blocos sem end ficam sem a chave "end" -> erro claro quando forem executados
	for b in stack:
		event.blocks[b["start"]] = b

# ===== INICIAR EVENTO =====


func on_preparo_fechado(_resultado) -> void:
	print("[Interpreter] 🧪 Preparo fechado, retomando eventos pausados...")
	for event in running_events:
		if event.pause_reason == "preparo":
			event.resume_and_advance()
			print("[Interpreter] ▶️ Evento ", event.id, " despausado (", event.name, ")")


func select_page_index(evento: EventoData, chave_self: String = "") -> int:
	if evento == null:
		return -1
	return PageSelector.select(evento.paginas, game_temp, chave_self)


func is_page_running(event_name: String, page_index: int, chave_self: String = "") -> bool:
	"""True se esta página deste evento já está em execução.
	Com chave_self, só conta a execução DESTE nó (cópias de spawn rodam independentes)."""
	for e in running_events:
		if not e.finished and e.name == event_name and e.page_index == page_index \
				and (chave_self == "" or e.chave_self == chave_self):
			return true
	return false


func is_event_running(event_name: String) -> bool:
	for e in running_events:
		if not e.finished and e.name == event_name:
			return true
	return false


## origem: nó do evento no mapa (dá a chave das self-variables). Pode ser null.
## Roda um evento chamado por outro evento (CmdChamarEvento).
## Usa a mesma regra de página e a mesma chave de self-variables do evento que chamou.
func chamar_evento(evento: EventoData, pai: EventInstance) -> EventInstance:
	if evento == null or evento.paginas.is_empty():
		return null
	var chave_self: String = pai.chave_self if pai else ""
	var page_index := PageSelector.select(evento.paginas, game_temp, chave_self)
	if page_index < 0:
		return null
	var commands: Array = []
	for c in evento.paginas[page_index].comandos:
		if c != null:
			commands.append(c)
	var inst := EventInstance.new()
	inst.id = event_id_counter
	event_id_counter += 1
	inst.name = evento.id
	inst.page_index = page_index
	inst.chave_self = chave_self
	inst.origem = null   # roda sem nó no mapa (o nó, se existir, não é avisado)
	inst.commands = commands
	for idx in range(commands.size()):
		if commands[idx] is CmdLabel:
			inst.labels[commands[idx].nome] = idx
	_build_blocks(inst)
	running_events.append(inst)
	print("[Interpreter] 📞 Evento ", evento.id, " chamado por ", pai.name if pai else "?")
	return inst

## Usa um item do inventário (botão "Usar"): matriz A na personalidade (padrão: bruxa),
## gasta 1 unidade e roda os comandos de efeito do item como um evento.
func usar_item(id: String, personalidade: String = "bruxa") -> bool:
	var item: ItemData = database.get_item(id) if database else null
	if item == null or game_temp == null or not game_temp.has_item(id):
		return false
	if game_temp.has_personality(personalidade):
		CmdAplicarPocao.aplicar_matriz(self, game_temp, personalidade, CalculadoraPocao.matriz_do_item(item))
	game_temp.remove_item(id, 1)
	# mesmo efeito mágico de quando a poção é aplicada na princesa, agora na bruxa
	await CmdAplicarPocao.efeito_magico(self, game_manager.get_player() if game_manager else null)
	if not item.efeito.is_empty():
		var pag := PaginaData.new()
		pag.comandos = item.efeito.duplicate()
		var ev := EventoData.new()
		ev.id = "item_" + id
		ev.paginas = [pag]
		trigger_event(ev)
	return true

func trigger_event(evento: EventoData, origem: Node = null) -> bool:
	if evento == null:
		print("[Interpreter] ERRO: trigger_event sem EventoData"); return false
	var event_name: String = evento.id

	var pages: Array = evento.paginas
	if pages.is_empty():
		print("[Interpreter] ERRO: Evento sem páginas: ", event_name); return false

	var chave_self: String = origem.chave_self() if origem and origem.has_method("chave_self") else ""
	# 🔥 MESMA REGRA DE PÁGINA QUE O evento_base USA
	var page_index = PageSelector.select(pages, game_temp, chave_self)

	# 🔥 A MESMA PÁGINA NÃO RODA DUAS VEZES AO MESMO TEMPO.
	# Outra página do mesmo evento pode rodar (ex.: bos_goblin pego durante o "esperar").
	if is_page_running(event_name, page_index, chave_self):
		print("[Interpreter] ⏭️ ", event_name, " página ", page_index, " já está rodando")
		return false

	var commands: Array = []
	for c in pages[page_index].comandos:
		if c != null:
			commands.append(c)

	var event = EventInstance.new()
	event.id = event_id_counter
	event_id_counter += 1
	event.name = event_name
	event.page_index = page_index
	event.chave_self = chave_self
	event.origem = weakref(origem) if origem else null
	event.commands = commands
	event.current_index = 0

	for idx in range(commands.size()):
		if commands[idx] is CmdLabel:
			event.labels[commands[idx].nome] = idx
	_build_blocks(event)

	running_events.append(event)
	print("[Interpreter] ✅ Evento ", event.id, " iniciado: ", event_name, " pág. ", page_index, " (total: ", running_events.size(), ")")
	return true


# ===== DIÁLOGO / OPÇÕES (fila única) =====

func _enqueue_dialog(item: Dictionary):
	dialog_queue.append(item)
	if not is_dialog_active:
		_show_next_dialog()

func _show_next_dialog():
	while not dialog_queue.is_empty():
		var item = dialog_queue.pop_front()
		var event = item["event"]
		if event.finished:
			continue
		is_dialog_active = true
		current_dialog = item
		if item["kind"] == "option":
			option_requested.emit(item["question"], item["options"], item.get("falante"))
			print("[Interpreter] 📝 Opções da fila (evento ", event.id, ")")
		else:
			dialog_requested.emit(item["messages"], item.get("falante"))
			print("[Interpreter] 📝 Diálogo da fila (evento ", event.id, ")")
		return
	is_dialog_active = false
	current_dialog = null

func _on_dialog_finished():
	# 🔥 RETOMA SÓ O EVENTO DONO DESTE DIÁLOGO
	var item = current_dialog
	if item != null and item["kind"] == "msg":
		var event = item["event"]
		if not event.finished and event.pause_reason == "dialog":
			event.resume_and_advance()
	elif item == null:
		print("[Interpreter] ⚠️ dialog_finished sem diálogo ativo")
	current_dialog = null
	is_dialog_active = false
	_show_next_dialog()

func on_option_selected(index: int):
	print("[Interpreter] 🔀 Opção recebida: ", index)

	var event = null
	if current_dialog != null and current_dialog["kind"] == "option":
		event = current_dialog["event"]
	else:
		# fallback: alguém mostrou opções fora da fila
		for e in running_events:
			if e.pause_reason == "option":
				event = e
				break

	if event != null and not event.finished and event.pause_reason == "option":
		if index >= 0 and index < event.pending_option_labels.size():
			var target_label = str(event.pending_option_labels[index])
			if event.labels.has(target_label):
				event.current_index = event.labels[target_label]
			else:
				print("[Interpreter] ❌ Label não encontrado: ", target_label)
				event.current_index += 1
		else:
			print("[Interpreter] ⚠️ Sem label para opção, avançando uma linha")
			event.current_index += 1

		event.option_choice = index
		event.pause_reason = ""
		event.pending_option_labels = []
		print("[Interpreter] ▶️ Evento ", event.id, " despausado após opção")

	current_dialog = null
	is_dialog_active = false
	_show_next_dialog()

# ===== UTILITÁRIOS =====

func _find_event_by_name(event_name: String):
	var mundo = get_node_or_null("/root/Main/Mundo")
	if not mundo:
		return null

	for child in mundo.get_children():
		if child.name == "Player" or child.is_queued_for_deletion():
			continue
		var found = _find_event_recursive(child, event_name)
		if found:
			return found
	return null

func _find_event_recursive(node: Node, event_name: String):
	if node.has_method("get_event_name") and node.get_event_name() == event_name:
		return node

	for child in node.get_children():
		var found = _find_event_recursive(child, event_name)
		if found:
			return found
	return null

func is_processing_dialog() -> bool:
	# Bloqueia o input do player durante diálogo, opções, fade, preparo e movimentos com espera.
	if is_dialog_active:
		return true
	for event in running_events:
		if event.is_paused and not event.waiting_for_option:
			return true
	return false

# ===== DEBUG =====

func _status_icon(event) -> String:
	if event.finished: return "✅"
	if event.is_paused: return "⏸️(" + event.pause_reason + ")"
	if event.is_waiting: return "⏳"
	return "🏃"

func debug():
	print("\n[Interpreter] DB: ", database, " | Temp: ", game_temp)
	print("  Eventos ativos: ", running_events.size())
	for event in running_events:
		print("  ", _status_icon(event), " Evento ", event.id, ": ", event.name, " pág ", event.page_index, " (", event.current_index, "/", event.commands.size(), ")")
	if game_temp:
		print("  Variáveis: ", game_temp.get_all_vars())
		print("  Personalidades: ", game_temp.get_all_personalities())
		print("  Inventário: ", game_temp.get_inventory())

func debug_fila():
	if running_events.is_empty():
		print("\n⚠️  Nenhum evento em execução.")
		return

	print("\n  📋 EVENTOS ATIVOS (", running_events.size(), ") | diálogos na fila: ", dialog_queue.size())
	for event in running_events:
		var cmd_name = "---"
		var cmd_args = []
		if event.current_index < event.commands.size():
			var d: Dictionary = event.commands[event.current_index].to_dict()
			cmd_name = d.get("nome", "???")
			cmd_args = d.get("args", [])

		print("  ", _status_icon(event), " Evento ", event.id, ": ", event.name, " (pág ", event.page_index, ")")
		print("	 Índice: ", event.current_index, "/", event.commands.size())
		print("	 Comando: ", cmd_name, " ", str(cmd_args))
	print("")
