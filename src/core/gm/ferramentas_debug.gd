# ferramentas_debug.gd
# Atalhos de debug do jogo:
#   '  menu de debug (editar variáveis, personalidades e inventário) — DebugMenu
#   F1 GameTemp | F2 banco de dados | F3 eventos do mapa | F6 diálogo de teste
# E as ferramentas da aba "Mapa" do menu: mostrar colisões/áreas, bruxa atravessando
# tudo e evento passável.
class_name FerramentasDebug
extends Node

var gm   # GameManager
var areas: DebugAreas = null
## Caldeirão: mostra gráfico, painel "Na panela", indicadores e a área dos itens.
var caldeirao_debug: bool = false


func criar_menu() -> DebugMenu:
	var menu := DebugMenu.new()
	menu.name = "DebugMenu"
	menu.game_temp = gm.game_temp
	menu.database = gm.database
	menu.ferramentas = self
	var camada = gm.get_node_or_null("/root/Main/CanvasLayer")
	if camada:
		camada.add_child(menu)
	else:
		gm.add_child(menu)
	return menu

# =============================================================================
# ABA "MAPA"
# =============================================================================
func mundo() -> Node:
	return gm.get_node_or_null("/root/Main/Mundo")

## Eventos do mapa atual (nós EventoBase).
func eventos_do_mapa() -> Array:
	var m = mundo()
	return DebugAreas._eventos(m) if m else []

func mostrar_areas(ligar: bool) -> void:
	if ligar and not is_instance_valid(areas):
		areas = DebugAreas.new()
		areas.name = "DebugAreas"
		var main = gm.get_node_or_null("/root/Main")
		(main if main else gm).add_child(areas)
	if is_instance_valid(areas):
		areas.mundo = mundo()
		areas.visible = ligar

func areas_visiveis() -> bool:
	return is_instance_valid(areas) and areas.visible

## A bruxa deixa de colidir com tudo, mas continua sendo detectada pelas áreas.
func player_atravessa(ligar: bool) -> void:
	var p = gm.get_player()
	if p and p.has_method("set_passavel"):
		p.set_passavel(ligar)

## Bruxa com o dobro da velocidade (e da aceleração).
func player_rapido(ligar: bool) -> void:
	var p = gm.get_player()
	if p and "multiplicador_velocidade" in p:
		p.multiplicador_velocidade = 2.0 if ligar else 1.0

func player_rapido_ligado() -> bool:
	var p = gm.get_player()
	return p != null and "multiplicador_velocidade" in p and p.multiplicador_velocidade > 1.0

func player_atravessando() -> bool:
	var p = gm.get_player()
	return p != null and p.has_method("is_passavel") and p.is_passavel()

## Liga/desliga a colisão da página ativa do evento (vale até a página trocar).
func evento_passavel(ev: Node, passavel: bool) -> void:
	var pagina = ev._get_active_page_node() if is_instance_valid(ev) else null
	if pagina and pagina.has_method("set_passavel"):
		pagina.set_passavel(passavel)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed): return
	match event.keycode:
		KEY_F1: debug_game_temp()
		KEY_F2: debug_database()
		KEY_F3: listar_eventos()
		KEY_F6: gm.dialogo._on_dialog_requested(["Olá! Teste de diálogo.", "Múltiplas mensagens funcionando!"])

## Chamado quando o banco termina de carregar: imprime um resumo.
func resumo_do_banco() -> void:
	var db = gm.database
	if not db: return
	var itens = db.get_items()
	print("\n--- ITENS (", itens.size(), ") ---")
	for id in itens:
		var it = itens[id]
		print("  ", id, " (", it.get_nome(), "): m=", it.m, " s=", it.s_menos, "/", it.s_mais,
			" T=[", it.T_min, ",", it.T_max, "] t=[", it.t_min, ",", it.t_max, "]")
	var pers = db.get_personalities()
	print("\n--- PERSONALIDADES (", pers.size(), ") ---")
	for id in pers: print("  ", id, ": ", pers[id])
	var vars = db.get_initial_vars()
	print("\n--- VARIÁVEIS (", vars.size(), ") ---")
	for id in vars: print("  ", id, " = ", vars[id])
	listar_eventos()

func listar_eventos() -> void:
	# Eventos vivem nos nós dos mapas (EventoData); lista os do mapa atual.
	var no_mundo := mundo()
	if not no_mundo: return
	var eventos: Array = []
	_buscar_eventos(no_mundo, eventos)
	print("\n--- EVENTOS NO MAPA (", eventos.size(), ") ---")
	for ev in eventos:
		if ev.evento:
			print("  ", ev.name, " -> ", ev.evento.id, " (", ev.evento.paginas.size(), " páginas, trigger ", ev.get_trigger() if ev.has_method("get_trigger") else "?", ")")

func _buscar_eventos(node: Node, lista: Array) -> void:
	for child in node.get_children():
		if child.has_method("_activate"):
			lista.append(child)
		_buscar_eventos(child, lista)

func debug_game_temp() -> void:
	var gt = gm.game_temp
	print("\n=== GAME TEMP ===")
	if not gt: print("❌ GameTemp não disponível!"); return
	var vars = gt.get_all_vars()
	print("VARIÁVEIS:"); for k in vars: print("  ", k, " = ", vars[k])
	var pers = gt.get_all_personalities()
	print("\nPERSONALIDADES:"); for k in pers: print("  ", k, ": ", pers[k])
	var inv = gt.get_inventory()
	print("\nINVENTÁRIO:"); print("  ", inv if not inv.is_empty() else "(vazio)")

func debug_database() -> void:
	print("\n=== DATABASE ===")
	if gm.database: gm.database.debug()
