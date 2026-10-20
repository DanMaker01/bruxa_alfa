# =============================================================================
# cena_preparo.gd - Orquestrador do preparo de poções
# =============================================================================
# Cuida do ESTADO do preparo (simulação térmica, histórico, ingredientes no
# caldeirão, resultado) e liga os componentes de src/preparo/:
#   VisualCaldeirao  - cor, fogo, partículas, tremor, respingo
#   LancadorItem     - item voando do inventário até o caldeirão
#   IconesCaldeirao  - ingredientes flutuando dentro do caldeirão (estado no ícone)
#   PainelPanela     - coluna "Na panela" (barras, frase, tags)  ┐ só aparecem com
#   Gráfico / Indicadores (texto)                                ┘ o debug do caldeirão
#   FeedbackPreparo  - textos flutuantes, cores de estado
#   ReacaoBruxa      - retratinho da Bruxa reagindo, com balão de fala
#   SomCaldeirao     - borbulhar / chiado / estalos gerados na hora
#   JanelaResultado  - janela da poção pronta (nome, pentágono, parâmetros)
#   BotaoSegurar     - toque curto / segurar dos botões de fogo e poção
extends Control

# =============================================================================
# REFERÊNCIAS UI
# =============================================================================
@onready var caldeirao: AnimatedSprite2D = $Animações/Caldeirao
@onready var fogo: AnimatedSprite2D = $Animações/Fogo
@onready var grafico: Control = $Grafico
@onready var indicadores_label: Label = $Indicadores
@onready var lista_ingredientes: HBoxContainer = $PainelIngredientes/ScrollContainer/ListaHorizontal
@onready var botao_pocao: Button = $PainelIngredientes/Poção
@onready var botao_fogo: Button = $PainelIngredientes/BotaoFogo
@onready var bolhas: GPUParticles2D = $Animações/GPUParticles2D
@onready var brilhos: GPUParticles2D = $Animações/GPUParticles2D2

## Botão de poção vira "voltar" quando não há nada no caldeirão.
const ICONE_VOLTAR_PATH := "res://assets/game_caldeirao/botao_voltar.png"
const TEMPO_LONGO: float = 0.7
## Ingrediente com aproveitamento (o que já perdeu e não volta) abaixo disto é perdido:
## sai do caldeirão e não entra na poção.
const LIMIAR_PERDIDO: float = 0.01
## Segurar o botão de fogo APAGADO para acender (mais longo, para não acontecer sem querer).
const TEMPO_SEGURAR_FOGO: float = 1.0
## Segurar o botão de fogo ACESO: abafa (−CONST_A em F) a cada INTERVALO_ABAFAR enquanto segura.
## O fogo não desliga mais; só apaga se F cair abaixo de SistemaTermico.F_LIMIT_MIN.
const INTERVALO_ABAFAR: float = 0.3

# =============================================================================
# DEPENDÊNCIAS
# =============================================================================
var game_manager = null
var game_temp = null
var database = null

# =============================================================================
# SISTEMAS E COMPONENTES
# =============================================================================
var sistema: SistemaTermico
var indicadores: Indicadores
var visual: VisualCaldeirao
var lancador: LancadorItem
var painel: PainelPanela
var icones: IconesCaldeirao
var feedback: FeedbackPreparo
var segurar_fogo: BotaoSegurar
var segurar_pocao: BotaoSegurar
var reacao: ReacaoBruxa
var janela_resultado: JanelaResultado
var som: SomCaldeirao

# =============================================================================
# ESTADO
# =============================================================================
var preparo_ativo: bool = false
var preparo_pausado: bool = false
## Um acumulador por unidade colocada no caldeirão (CalculadoraPocao.novo_acumulador).
var ingredientes_ativos: Array = []
var historico_T: Array = []
var _tempo_desde_ultimo_ponto: float = 0.0

var _itens_cache: Dictionary = {}       # id -> ItemData
var _estados: Array = []                # estado_ao_vivo() de cada ingrediente (mesma ordem)
var _nomes_grafico: Array = []          # gráfico: nome de cada ingrediente (ordem de entrada)
var _fatias_atual: Dictionary = {}      # gráfico: idx -> cor do ingrediente neste instante
var _punindo_agora: bool = false
var _quente_agora: float = 0.0   # pior nível de "quente demais" agora (0..1), para o som
var _frio_agora: float = 0.0     # pior nível de "frio demais" agora (0..1), para o som
var _icone_pocao: Texture2D
var _icone_voltar: Texture2D

# =============================================================================
# HISTÓRICO T(t) — RING BUFFER
# =============================================================================
const INTERVALO_HISTORICO: float = 0.05   # 50ms entre amostras (20/s)
const MAX_PONTOS: int = 24_000            # ~20 min a 50ms
const BLOCO_DESCARTE: int = 1_000

# =============================================================================
# CICLO DE VIDA
# =============================================================================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sistema = SistemaTermico.new()
	indicadores = Indicadores.new()
	_buscar_dependencias()
	_criar_componentes()
	_configurar_grafico()
	_conectar_botoes()
	if game_temp and game_temp.has_signal("inventory_changed"):
		game_temp.inventory_changed.connect(_popular_inventario)
	_popular_inventario()

func _process(delta: float) -> void:
	_aplicar_debug()
	if not preparo_ativo or preparo_pausado:
		if som:
			som.silenciar()
		return   # não avança física, indicadores nem gráfico

	sistema.step(delta)

	# 🔥 HISTÓRICO (ring buffer com descarte em bloco)
	_tempo_desde_ultimo_ponto += delta
	if _tempo_desde_ultimo_ponto >= INTERVALO_HISTORICO:
		historico_T.append({"t": sistema.t_sim, "T": sistema.T, "F": sistema.F})
		_tempo_desde_ultimo_ponto = 0.0
		_acumular_ingredientes(historico_T[-1])
		if historico_T.size() > MAX_PONTOS + BLOCO_DESCARTE:
			historico_T = historico_T.slice(BLOCO_DESCARTE)

	indicadores.update(sistema, sistema.dt_step_atual)
	if grafico and grafico.has_method("adicionar_ponto"):
		grafico.adicionar_ponto(sistema.t_sim, sistema.T, sistema.F, _punindo_agora, _fatias_atual.duplicate())
	if indicadores_label:
		indicadores_label.text = "\n".join(indicadores.get_linhas_ui(sistema))
	visual.atualizar(sistema, delta, _perda_media(), _punindo_agora)
	if som:
		som.definir(sistema.T, _quente_agora, _frio_agora)
		som.definir_fogo(sistema.F, sistema.fogo_ligado)

# =============================================================================
# INICIALIZAÇÃO
# =============================================================================
func _buscar_dependencias() -> void:
	var main = get_tree().current_scene
	if not main:
		return
	game_manager = main.get_node_or_null("GameManager")
	if not game_manager:
		return
	game_temp = game_manager.get_node_or_null("GameTemp")
	database = game_manager.get_node_or_null("DatabaseManager")

func _criar_componentes() -> void:
	visual = VisualCaldeirao.new()
	visual.name = "VisualCaldeirao"
	add_child(visual)
	visual.configurar(caldeirao, fogo, bolhas, brilhos)

	lancador = LancadorItem.new()
	lancador.name = "LancadorItem"
	add_child(lancador)
	lancador.caiu.connect(_on_item_caiu)

	feedback = FeedbackPreparo.new()
	feedback.name = "FeedbackPreparo"
	feedback.alvo = self
	add_child(feedback)
	feedback.marcador.connect(func(cor: Color):
		if grafico and grafico.has_method("adicionar_marcador"):
			grafico.adicionar_marcador(sistema.t_sim, cor, ""))

	painel = PainelPanela.new()
	add_child(painel)

	icones = IconesCaldeirao.new()
	icones.name = "IconesCaldeirao"
	icones.caldeirao = caldeirao
	icones.z_index = 5   # na frente do caldeirão, atrás das bolhas
	$Animações.add_child(icones)

	reacao = ReacaoBruxa.new()
	reacao.name = "ReacaoBruxa"
	reacao.z_index = 6
	$Animações.add_child(reacao)

	som = SomCaldeirao.new()
	som.name = "SomCaldeirao"
	add_child(som)

	janela_resultado = JanelaResultado.new()
	janela_resultado.name = "JanelaResultado"
	add_child(janela_resultado)
	janela_resultado.fechou.connect(_on_resultado_fechado)
	_aplicar_debug()

## Gráfico, painel "Na panela", texto dos indicadores e a área da bola só aparecem
## com "Caldeirão (debug)" ligado no menu de debug (aba Mapa).
func _aplicar_debug() -> void:
	var dbg: bool = _debug_caldeirao()
	if grafico: grafico.visible = dbg
	if indicadores_label: indicadores_label.visible = dbg
	if painel: painel.visible = dbg
	if icones and icones.mostrar_area != dbg: icones.mostrar_area = dbg

func _debug_caldeirao() -> bool:
	var ft = game_manager.get("debug_tools") if game_manager else null
	return ft != null and bool(ft.get("caldeirao_debug"))

func _configurar_grafico() -> void:
	if grafico and grafico.has_method("configurar"):
		grafico.configurar({"y_max_T": 250.0, "y_max_F": 1200.0, "t_janela": 30.0})

func _conectar_botoes() -> void:
	if botao_fogo:
		segurar_fogo = BotaoSegurar.anexar(botao_fogo, TEMPO_SEGURAR_FOGO)
		segurar_fogo.toque_curto.connect(_fogo_clique_curto)
		segurar_fogo.segurou.connect(_fogo_segurar)
		segurar_fogo.repetiu.connect(_abafar_fogo)
		segurar_fogo.carregando.connect(func(p): visual.carregando_fogo(botao_fogo, p, sistema.fogo_ligado))
		segurar_fogo.soltou.connect(func():
			botao_fogo.rotation = 0.0
			if sistema.fogo_ligado:   # parou de abafar: volta à cor de aceso
				botao_fogo.create_tween().tween_property(botao_fogo, "modulate", VisualCaldeirao.COR_FOGO_LIGA, 0.2))
		botao_fogo.button_down.connect(func():
			# aceso: segurar abafa, repetindo; apagado: segurar (mais tempo) acende
			segurar_fogo.tempo_longo = INTERVALO_ABAFAR if sistema.fogo_ligado else TEMPO_SEGURAR_FOGO
			segurar_fogo.intervalo_repeticao = INTERVALO_ABAFAR if sistema.fogo_ligado else 0.0
			if not sistema.fogo_ligado:
				visual.faisca_inicial())
	if botao_pocao:
		_icone_pocao = botao_pocao.icon
		segurar_pocao = BotaoSegurar.anexar(botao_pocao, TEMPO_LONGO)
		segurar_pocao.toque_curto.connect(_pocao_clique_curto)
		segurar_pocao.segurou.connect(_sair_do_preparo)   # segurou → sai sem finalizar
	if ResourceLoader.exists(ICONE_VOLTAR_PATH):
		_icone_voltar = load(ICONE_VOLTAR_PATH)
	else:
		push_warning("[CenaPreparo] Ícone não encontrado: " + ICONE_VOLTAR_PATH)

# =============================================================================
# INVENTÁRIO
# =============================================================================
func _popular_inventario() -> void:
	if not game_temp or not database or not lista_ingredientes:
		return
	for child in lista_ingredientes.get_children():
		child.queue_free()
	var inventario = game_temp.get_inventory()
	if inventario.is_empty():
		var label = Label.new()
		label.text = "(Inventário vazio)"
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7))
		lista_ingredientes.add_child(label)
		return
	for item_name in inventario:
		lista_ingredientes.add_child(_criar_botao_item(item_name, database.get_item(item_name), inventario[item_name]))

func _criar_botao_item(item_name: String, item: ItemData, quantidade: int) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(80, 80)
	btn.text = (item.get_nome() if item else item_name) + "\nx" + str(quantidade)
	btn.add_theme_font_size_override("font_size", 12)
	if item and item.icone:
		btn.icon = item.icone
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.add_theme_stylebox_override("normal", _estilo(Color(0.2, 0.2, 0.3, 0.9)))
	btn.add_theme_stylebox_override("hover", _estilo(Color(0.3, 0.3, 0.5, 0.9)))
	btn.add_theme_stylebox_override("pressed", _estilo(Color(0.4, 0.4, 0.6, 0.9)))
	btn.pressed.connect(_on_item_selecionado.bind(item_name, btn))
	BotaoSegurar.efeito_clique(btn)
	return btn

func _estilo(cor: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = cor
	s.set_corner_radius_all(10)
	return s

# =============================================================================
# INGREDIENTES
# =============================================================================
## Toque num item: ele sai do inventário na hora (reservado) e voa até o caldeirão.
## Só entra no preparo (t0, queda de T, painel...) quando cai dentro.
func _on_item_selecionado(item_name: String, btn: Control = null) -> void:
	if not preparo_ativo:
		_iniciar_preparo()
	if not game_temp or not game_temp.has_item(item_name):
		return
	var origem: Vector2 = btn.global_position + btn.size * 0.5 if is_instance_valid(btn) else Vector2(320, 860)
	game_temp.remove_item(item_name, 1)
	lancador.lancar(self, item_name, _item_de(item_name), _nome_exibicao(item_name), origem, visual.boca())

func _on_item_caiu(item_name: String) -> void:
	if not preparo_ativo:
		# a poção foi finalizada/cancelada com o item no ar: devolve ao inventário
		if game_temp:
			game_temp.add_item(item_name, 1)
		return
	_registrar_ingrediente(item_name)
	visual.respingo(self)

## Coloca o ingrediente direto (sem animação). Usado por testes/scripts.
func _adicionar_ingrediente(item_name: String) -> void:
	if not preparo_ativo:
		_iniciar_preparo()
	if not game_temp.has_item(item_name):
		return
	game_temp.remove_item(item_name, 1)
	_registrar_ingrediente(item_name)

## O ingrediente entrou no caldeirão.
func _registrar_ingrediente(item_name: String) -> void:
	# 🔥 REGISTRA O t0 (acumulador usado ao vivo e no cálculo final)
	ingredientes_ativos.append(CalculadoraPocao.novo_acumulador(item_name, sistema.t_sim))
	_estados.append({})
	feedback.novo_ingrediente()
	painel.adicionar(_nome_exibicao(item_name))
	icones.adicionar(_item_de(item_name), _nome_exibicao(item_name), visual.boca())
	reacao.novo_ingrediente()
	_atualizar_botao_pocao()
	_nomes_grafico.append(_nome_exibicao(item_name))
	if grafico and grafico.has_method("set_ingredientes"):
		grafico.set_ingredientes(_nomes_grafico)
	if grafico and grafico.has_method("adicionar_marcador"):
		grafico.adicionar_marcador(sistema.t_sim, Color(0.85, 0.85, 0.95), _nome_exibicao(item_name).left(6))
	indicadores.registrar_acao_adicionar(sistema)
	indicadores.registrar_acao_mexer(sistema)
	sistema.adicionar_ingrediente(item_name)

func _item_de(nome: String) -> ItemData:
	if not _itens_cache.has(nome):
		_itens_cache[nome] = database.get_item(nome) if database else null
	return _itens_cache[nome]

func _nome_exibicao(id: String) -> String:
	var item: ItemData = _item_de(id)
	return item.get_nome() if item else id

# =============================================================================
# ACOMPANHAMENTO AO VIVO
# =============================================================================
## Chamado a cada ponto novo do histórico (20/s): soma nos acumuladores,
## recalcula o estado de cada ingrediente e atualiza painel, avisos e gráfico.
func _acumular_ingredientes(ponto: Dictionary) -> void:
	var limites := {}
	var punindo := false
	var quente := 0.0
	var frio := 0.0
	for i in ingredientes_ativos.size():
		var acc: Dictionary = ingredientes_ativos[i]
		if acc.get("perdido", false):
			continue
		var item: ItemData = _item_de(acc["nome"])
		CalculadoraPocao.acumular(acc, ponto, item)
		var est = CalculadoraPocao.estado_ao_vivo(acc, item, sistema.t_sim, sistema.T)
		_estados[i] = est
		if item and float(est.get("perda", 1.0)) <= LIMIAR_PERDIDO:
			_perder_ingrediente(i)
			continue
		feedback.avisar_mudancas(i, _nome_exibicao(acc["nome"]), est, sistema.t_sim)
		painel.atualizar(i, est)
		icones.atualizar(i, est)
		_fatias_atual[i] = FeedbackPreparo.cor_do_estado(est, item)
		for k in est["niveis"]:
			if est["niveis"][k] == 2:
				punindo = true
		quente = maxf(quente, float(est["niveis"].get("quente", 0)) / 2.0)
		frio = maxf(frio, float(est["niveis"].get("frio", 0)) / 2.0)
		if item:
			_juntar_limite(limites, "max", item.T_max, sistema.T > item.T_max)
			_juntar_limite(limites, "min", item.T_min, sistema.T < item.T_min)
	_punindo_agora = punindo
	_quente_agora = quente
	_frio_agora = frio
	reacao.atualizar(_estados.filter(func(e): return not e.is_empty()))
	if grafico and grafico.has_method("set_limites"):
		grafico.set_limites(limites.values())

## O ingrediente chegou a aproveitamento zero: some do caldeirão e fica fora da poção.
## (continua na lista, marcado "perdido", para os índices de ícones/painel não mudarem)
func _perder_ingrediente(i: int) -> void:
	var acc: Dictionary = ingredientes_ativos[i]
	acc["perdido"] = true
	_estados[i] = {}
	_fatias_atual.erase(i)
	icones.perder(i)
	feedback.texto_flutuante(_nome_exibicao(acc["nome"]) + " se perdeu!", FeedbackPreparo.COR_PUNICAO)
	_atualizar_botao_pocao()

## Ingredientes que ainda estão no caldeirão (sem os perdidos).
func _ingredientes_validos() -> Array:
	return ingredientes_ativos.filter(func(a): return not a.get("perdido", false))

func _juntar_limite(limites: Dictionary, tipo: String, T: float, passando: bool) -> void:
	if T <= 0.0:
		return
	var chave := "%s%d" % [tipo, int(T)]
	limites[chave] = {"T": T, "tipo": tipo, "ativo": limites.get(chave, {}).get("ativo", false) or passando}

## Média do que já foi perdido (0 = nada, 1 = tudo) dos ingredientes reconhecidos.
func _perda_media() -> float:
	var soma := 0.0
	var n := 0
	for est in _estados:
		if not est.is_empty() and est.get("reconhecido", true):
			soma += 1.0 - float(est.get("perda", 1.0))
			n += 1
	return soma / n if n > 0 else 0.0

# =============================================================================
# BOTÕES
# =============================================================================
func _fogo_clique_curto() -> void:
	# Clique curto no [F] → pulso de fogo (F += CONST_A), só com o fogo aceso
	if not sistema.fogo_ligado:
		feedback.texto_flutuante("fogo apagado (segure para acender)", VisualCaldeirao.COR_FOGO_DESLIGA)
		return
	indicadores.registrar_acao_adicionar(sistema)
	sistema.dar_pulso_fogo()
	visual.aticar()

func _fogo_segurar() -> void:
	if sistema.fogo_ligado:
		_abafar_fogo()   # aceso: primeiro passo do abafar (os próximos vêm pelo repetiu)
		return
	sistema.ligar_fogo()
	var cor := visual.liga_desliga(botao_fogo, true)
	feedback.texto_flutuante("fogo aceso!", cor)

## Segurando com o fogo aceso: tira CONST_A de F; fraco demais → apaga.
func _abafar_fogo() -> void:
	if not sistema.fogo_ligado:
		return
	if sistema.abafar_fogo():
		var cor := visual.apagou(botao_fogo)
		feedback.texto_flutuante("o fogo apagou!", cor)
		segurar_fogo.intervalo_repeticao = 0.0
	else:
		visual.abafar(botao_fogo)

func _pocao_clique_curto() -> void:
	if _ingredientes_validos().is_empty():
		_sair_do_preparo()   # sem ingredientes → só sai
	else:
		_mostrar_confirmacao_finalizar()

## Sem ingredientes no caldeirão o botão de poção só sai, então mostra "voltar".
func _atualizar_botao_pocao() -> void:
	if not botao_pocao:
		return
	var vazio: bool = _ingredientes_validos().is_empty()
	var icone: Texture2D = _icone_voltar if vazio and _icone_voltar else _icone_pocao
	if botao_pocao.icon != icone:
		botao_pocao.icon = icone
		botao_pocao.tooltip_text = "Voltar" if vazio else "Finalizar poção"
		botao_pocao.pivot_offset = botao_pocao.size * 0.5
		botao_pocao.scale = Vector2(0.7, 0.7)   # pequeno "pop" na troca
		botao_pocao.create_tween().tween_property(botao_pocao, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# =============================================================================
# CICLO DO PREPARO
# =============================================================================
func _iniciar_preparo() -> void:
	# Sempre reseta (é chamado quando a cena abre)
	preparo_ativo = true
	preparo_pausado = false
	sistema.reset()
	indicadores.reset()
	ingredientes_ativos.clear()
	historico_T.clear()
	_tempo_desde_ultimo_ponto = 0.0
	if grafico and grafico.has_method("reset"):
		grafico.reset()
	_estados.clear()
	_nomes_grafico = []
	_fatias_atual = {}
	_itens_cache.clear()
	_punindo_agora = false
	_quente_agora = 0.0
	_frio_agora = 0.0
	feedback.resetar()
	reacao.resetar()
	painel.limpar()
	icones.limpar()
	visual.resetar()
	_atualizar_botao_pocao()

func _finalizar_preparo() -> void:
	if not preparo_ativo:
		return
	preparo_ativo = false
	# 🔥 FASE 1 (diagnóstico) + FASE 2 (aproveitamento) + MATRIZ DA POÇÃO
	var resultado = CalculadoraPocao.calcular(_calcular_resultado(), database)
	CalculadoraPocao.imprimir_relatorio(resultado)   # debug
	# 🧪 A POÇÃO VIRA UM ITEM COMUM (o GameManager coloca no inventário)
	if not _ingredientes_validos().is_empty() and database and database.has_method("registrar_item"):
		var id: String = database.novo_id("pocao")
		var pocao: ItemData = CalculadoraPocao.criar_pocao(resultado, id, "Poção #" + id.get_slice("_", 1))
		database.registrar_item(pocao)
		resultado["pocao"] = pocao
		resultado["item"] = pocao.id
		resultado["quantidade"] = 1
		# mostra a janela da poção pronta; ela chama _on_resultado_fechado ao fechar
		janela_resultado.abrir(resultado)
		return
	_on_resultado_fechado(resultado)

## A janela do resultado fechou (ou não havia poção): fecha o preparo e entrega a poção.
func _on_resultado_fechado(resultado: Dictionary) -> void:
	if game_manager and game_manager.has_method("fechar_preparo"):
		game_manager.fechar_preparo(resultado)
	else:
		encerrar()

func _calcular_resultado() -> Dictionary:
	return {
		"ingredientes": _ingredientes_validos().duplicate(true),   # perdidos não entram
		"t_final": sistema.t_sim,
		"historico_T": historico_T.duplicate(true),
		"temperatura_final": sistema.T,
		"tempo_total": sistema.t_sim,
		"indicadores": {
			"t_star_T": indicadores.t_star_T,
			"t_star_F": indicadores.t_star_F,
			"T_max_A": indicadores.T_max_A,
			"F_max_A": indicadores.F_max_A,
			"T_min_I": indicadores.T_min_I,
			"F_min_I": indicadores.F_min_I,
		},
		"sucesso": true,
	}

func _sair_do_preparo() -> void:
	if game_manager and game_manager.has_method("fechar_preparo"):
		game_manager.fechar_preparo({"cancelado": true})
	else:
		encerrar()

func _mostrar_confirmacao_finalizar() -> void:
	preparo_pausado = true   # pausa a simulação enquanto pergunta
	var dlg = ConfirmationDialog.new()
	dlg.dialog_text = "Deseja finalizar a poção?"
	dlg.title = "Confirmar"
	dlg.ok_button_text = "Sim"
	dlg.cancel_button_text = "Não"
	dlg.process_mode = Node.PROCESS_MODE_ALWAYS
	dlg.confirmed.connect(func():
		preparo_pausado = false
		_finalizar_preparo())
	dlg.canceled.connect(func(): preparo_pausado = false)
	dlg.close_requested.connect(func(): preparo_pausado = false)
	add_child(dlg)
	dlg.popup_centered()

# =============================================================================
# API PÚBLICA
# =============================================================================
func iniciar() -> void:
	_iniciar_preparo()
	show()

func encerrar() -> void:
	preparo_ativo = false
	preparo_pausado = false
	if som:
		som.silenciar()
	hide()

func get_temperatura() -> float:
	return sistema.T if sistema else 0.0

func get_ingredientes() -> Array:
	return ingredientes_ativos.duplicate()

func is_preparando() -> bool:
	return preparo_ativo

## TESTE da régua do anel/vela: tecla M troca o modo (punição / proporcional / absoluto).
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_M:
		IconesCaldeirao.modo = (IconesCaldeirao.modo + 1) % IconesCaldeirao.ModoRegua.size()
		feedback.texto_flutuante("régua: " + IconesCaldeirao.NOMES_MODO[IconesCaldeirao.modo], Color(0.85, 0.85, 1.0))
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_tempo_desde_ultimo_ponto = 0.0

func _debug() -> void:
	print("\n=== CENA PREPARO DEBUG ===")
	print("  preparo_ativo: ", preparo_ativo, " | T: ", sistema.T, " | F: ", sistema.F, " | t: ", sistema.t_sim)
	print("  fogo_ligado: ", sistema.fogo_ligado, " | ingredientes: ", ingredientes_ativos.size())
