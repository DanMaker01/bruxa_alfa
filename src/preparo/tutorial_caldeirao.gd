# tutorial_caldeirao.gd
# Tutorial do caldeirão: a Poção do Retorno (chama amarela, 3 pós de retorno, 25 s).
# Começa quando o preparo abre com a variável tutorial_caldeirao = 1 (o evento bruxa_in_auto
# liga a variável e abre o caldeirão). No fim (Finalizar) a variável vira 2.
# A bruxa fala pelo balãozinho do retrato (ReacaoBruxa.dizer). Nas pausas o caldeirão para,
# a tela escurece e só o botão certo fica aceso (os outros toques não passam).
#   1. pausa: acender o fogo
#   2. esquentar até a chama amarela (o +Fogo pisca, sem pausa; passou: o −Fogo pisca)
#   3. amarela: pausa e espera jogar os 3 pós
#   4. 25 s: se a temperatura vai sair do amarelo, pausa e mostra o +Fogo (esfriando) ou
#      o −Fogo (esquentando demais); fogo apagou: pausa e mostra o Acender
#   5. o tempo da receita acabou: pausa e mostra o Finalizar
class_name TutorialCaldeirao
extends Control

const VARIAVEL := "tutorial_caldeirao"
const RECEITA := "res://dados/receitas/retorno.tres"
const ITEM := "po_retorno"
const QTD: int = 3
const ESTADO := "amarelo"
## Margem (°C) da borda da faixa em que já pausa se a temperatura estiver indo para fora.
const MARGEM_T: float = 3.0
## Depois de uma correção, espera isto (s de jogo) antes de pausar de novo pelo mesmo lado.
const ESPERA_CORRECAO: float = 1.5
const ALFA_ESCURO: float = 0.55
const COR_MOLDURA := Color(1.0, 0.85, 0.3)

enum Etapa { NADA, ACENDER, ESQUENTAR, POS, COZINHAR, FINALIZAR, FIM }

var cena = null
var etapa: int = Etapa.NADA
var _alvo: Callable = Callable()   # devolve o Control a mostrar (os botões do inventário são recriados)
var _bloqueando: bool = false
var _escuros: Array[ColorRect] = []
var _moldura: Control
var _t: float = 0.0
var _T_antes: float = 0.0
var _dTdt: float = 0.0
var _F_pausa: float = 0.0
var _corrigindo: String = ""       # "frio" / "quente" / "apagou" enquanto pausado para corrigir
var _espera: float = 0.0           # s de jogo até poder pausar de novo
var _dica: String = ""             # dica sem pausa mostrada agora (esquentar)
var _t_min: float = 122.0
var _t_max: float = 145.0


func _ready() -> void:
	name = "TutorialCaldeirao"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 5   # acima dos botões; a bruxinha (6) e o resultado (8) ficam por cima
	for k in 4:
		var r := ColorRect.new()
		r.color = Color(0, 0, 0, ALFA_ESCURO)
		r.mouse_filter = Control.MOUSE_FILTER_STOP
		r.visible = false
		r.gui_input.connect(_toque_fora)
		add_child(r)
		_escuros.append(r)
	_moldura = Control.new()
	_moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_moldura.visible = false
	_moldura.draw.connect(_desenhar_moldura)
	add_child(_moldura)
	for e in EstadosChama.LISTA:
		if e["id"] == ESTADO:
			_t_min = e["T_min"]
			_t_max = e["T_max"]
	visible = false

var ativo: bool:
	get:
		return etapa != Etapa.NADA and etapa != Etapa.FIM


# =============================================================================
# COMEÇO / FIM
# =============================================================================
## Chamado quando o preparo começa: se a variável pede, começa o tutorial.
func comecar_se_preciso() -> void:
	etapa = Etapa.NADA
	_esconder()
	visible = false
	if cena and cena.layout:
		cena.layout._b_sair.visible = true   # fora do tutorial o Voltar sempre aparece
	var gt = cena.game_temp if cena else null
	if gt == null or float(gt.get_var(VARIAVEL)) != 1.0:
		return
	# garante os 3 pós (o evento já dá; isto é só por segurança)
	var tem: int = int(gt.get_inventory().get(ITEM, 0))
	if tem < QTD:
		gt.add_item(ITEM, QTD - tem)
	# a guia mostra a receita do Retorno, memorizada ou não
	var rec = load(RECEITA) if ResourceLoader.exists(RECEITA) else null
	if rec is ReceitaData and cena.layout:
		cena.layout.guia.pagina = {"nome": rec.nome, "passos": rec.passos_livro.duplicate(true)}
		cena.layout.guia.reiniciar()
	visible = true
	if cena.layout:
		cena.layout._b_sair.visible = false
	_ir(Etapa.ACENDER)

func _terminar() -> void:
	etapa = Etapa.FIM
	_esconder()
	_pausar(false)
	cena.reacao.calar()
	var gt = cena.game_temp if cena else null
	if gt:
		gt.set_var(VARIAVEL, 2.0)
	if cena.layout:
		cena.layout._b_sair.visible = true
	visible = false


# =============================================================================
# ETAPAS
# =============================================================================
func _ir(e: int) -> void:
	etapa = e
	_esconder()
	match e:
		Etapa.ACENDER:
			_pausar(true)
			_falar("Primeiro, acenda o fogo.")
			_mostrar(func(): return cena.layout._b_acender, true)
		Etapa.ESQUENTAR:
			_pausar(false)
			_dica = ""
			_falar("A receita pede chama amarela. Toque no +Fogo até a chama ficar amarela.")
		Etapa.POS:
			_pausar(true)
			Vibrar.media()
			_falar("Amarela! Agora jogue os três pós de retorno. Segure para jogar todos de uma vez.")
			_mostrar(_botao_do_item, true)
		Etapa.COZINHAR:
			_pausar(false)
			_espera = ESPERA_CORRECAO
			_falar("Agora são 25 segundos. Não deixe a chama sair do amarelo.", 4.0)
		Etapa.FINALIZAR:
			_pausar(true)
			Vibrar.media()
			_falar("Pronto! Toque em Finalizar.")
			_mostrar(func(): return cena.layout._b_pocao, true)

## A cena pergunta antes de jogar um item. false = não deixa (e a bruxa explica).
func pode_jogar(id: String) -> bool:
	if not ativo:
		return true
	if id != ITEM:
		_falar("Hoje é só o pó de retorno.", 2.5)
		return false
	if etapa == Etapa.POS:
		return true
	if etapa == Etapa.ACENDER or etapa == Etapa.ESQUENTAR:
		_falar("Ainda não! Espere a chama ficar amarela.", 2.5)
	return false

## A cena pergunta antes de finalizar. true = finaliza direto (sem a confirmação).
func pode_finalizar() -> bool:
	if not ativo:
		return true
	if etapa != Etapa.FINALIZAR:
		_falar("Ainda não! Espere o tempo da receita.", 2.5)
		return false
	_terminar()
	return true


func _process(delta: float) -> void:
	if not ativo or cena == null:
		return
	_t += delta
	if cena.layout and cena.layout._b_sair.visible:
		cena.layout._b_sair.visible = false   # sem Voltar só no tutorial
	var sis = cena.sistema
	if not cena.preparo_pausado:
		_dTdt = (sis.T - _T_antes) / maxf(delta, 0.001)
		_espera = maxf(0.0, _espera - delta)
	_T_antes = sis.T
	_atualizar_alvo()
	match etapa:
		Etapa.ACENDER:
			if sis.fogo_ligado:
				_ir(Etapa.ESQUENTAR)
		Etapa.ESQUENTAR:
			_esquentar(sis)
		Etapa.POS:
			if _pos_no_caldeirao() >= QTD:
				_ir(Etapa.COZINHAR)
		Etapa.COZINHAR:
			_cozinhar(sis)

func _esquentar(sis) -> void:
	if not sis.fogo_ligado:
		_pausar(true)
		_falar("O fogo apagou! Acenda de novo.")
		_mostrar(func(): return cena.layout._b_acender, true)
		etapa = Etapa.ACENDER
		return
	var guia = cena.layout.guia
	if guia.passo_atual() >= 1:   # chama amarela estável (a guia conta 1 s)
		_ir(Etapa.POS)
		return
	var dica := "quente" if sis.T >= _t_max else "frio"
	if dica != _dica:
		_dica = dica
		if dica == "quente":
			_falar("Passou do amarelo! Toque no −Fogo para baixar um pouco.")
			_mostrar(func(): return cena.layout._b_abaixar, false)
		else:
			_falar("A receita pede chama amarela. Toque no +Fogo até a chama ficar amarela.")
			_mostrar(func(): return cena.layout._b_fogo, false)

func _cozinhar(sis) -> void:
	var guia = cena.layout.guia
	if cena.preparo_pausado:
		# pausado esperando a correção
		match _corrigindo:
			"frio":
				if sis.F > _F_pausa + 1.0:
					_retomar()
			"quente":
				if sis.F < _F_pausa - 1.0 or not sis.fogo_ligado:
					_retomar()
			"apagou":
				if sis.fogo_ligado:
					_retomar()
		return
	if guia.passo_atual() >= guia.pagina["passos"].size():
		_ir(Etapa.FINALIZAR)
		return
	if not sis.fogo_ligado:
		_corrigir("apagou", "O fogo apagou! Acenda de novo.", func(): return cena.layout._b_acender)
		return
	if _espera > 0.0:
		return
	var frio: bool = sis.T < _t_min or (sis.T < _t_min + MARGEM_T and _dTdt < 0.0)
	var quente: bool = sis.T >= _t_max or (sis.T > _t_max - MARGEM_T and _dTdt > 0.0)
	if frio:
		_corrigir("frio", "Está esfriando! Toque no +Fogo.", func(): return cena.layout._b_fogo)
	elif quente:
		_corrigir("quente", "Está esquentando demais! Toque no −Fogo.", func(): return cena.layout._b_abaixar)

func _corrigir(tipo: String, texto: String, alvo: Callable) -> void:
	_corrigindo = tipo
	_F_pausa = cena.sistema.F
	_pausar(true)
	Vibrar.media()
	_falar(texto)
	_mostrar(alvo, true)

func _retomar() -> void:
	_corrigindo = ""
	_espera = ESPERA_CORRECAO
	_esconder()
	_pausar(false)
	_falar("Isso! Continue de olho na chama.", 2.0)

func _pos_no_caldeirao() -> int:
	var n := 0
	for ing in cena.ingredientes_ativos:
		if str(ing.get("nome", "")) == ITEM:
			n += 1
	return n

func _botao_do_item() -> Control:
	var lista = cena.lista_ingredientes
	if lista == null:
		return null
	for b in lista.get_children():
		if b.has_meta("item") and b.get_meta("item") == ITEM and not b.is_queued_for_deletion():
			return b
	return null


# =============================================================================
# PAUSA, FALA E DESTAQUE
# =============================================================================
func _pausar(p: bool) -> void:
	cena.preparo_pausado = p

func _falar(texto: String, segundos: float = 0.0) -> void:
	cena.reacao.dizer(texto, segundos, segundos <= 0.0)

## Destaca um botão. bloquear: escurece o resto e só ele recebe toques.
func _mostrar(alvo: Callable, bloquear: bool) -> void:
	_alvo = alvo
	_bloqueando = bloquear
	_atualizar_alvo()

func _esconder() -> void:
	_alvo = Callable()
	_bloqueando = false
	for r in _escuros:
		r.visible = false
	_moldura.visible = false

func _atualizar_alvo() -> void:
	var c = _alvo.call() if _alvo.is_valid() else null
	if not (c is Control) or not is_instance_valid(c) or not c.is_visible_in_tree():
		for r in _escuros:
			r.visible = false
		_moldura.visible = false
		return
	var ret: Rect2 = c.get_global_rect().grow(6.0)
	var tela := get_viewport_rect().size
	# 4 faixas escuras em volta do buraco (o buraco deixa o toque passar para o botão)
	var faixas := [
		Rect2(0, 0, tela.x, ret.position.y),
		Rect2(0, ret.end.y, tela.x, tela.y - ret.end.y),
		Rect2(0, ret.position.y, ret.position.x, ret.size.y),
		Rect2(ret.end.x, ret.position.y, tela.x - ret.end.x, ret.size.y),
	]
	for k in 4:
		_escuros[k].visible = _bloqueando
		_escuros[k].global_position = faixas[k].position
		_escuros[k].size = faixas[k].size.max(Vector2.ZERO)
	_moldura.visible = true
	_moldura.global_position = ret.position
	_moldura.size = ret.size
	_moldura.queue_redraw()

func _desenhar_moldura() -> void:
	var pulso: float = 0.5 + 0.5 * sin(_t * 6.0)
	var r := Rect2(Vector2.ZERO, _moldura.size)
	_moldura.draw_rect(r, Color(COR_MOLDURA, 0.5 + 0.5 * pulso), false, 4.0 + 3.0 * pulso)
	# setinha em cima, apontando para o botão
	var cx: float = _moldura.size.x * 0.5
	var y: float = -14.0 - 8.0 * pulso
	_moldura.draw_colored_polygon(PackedVector2Array([Vector2(cx - 16, y - 22), Vector2(cx + 16, y - 22), Vector2(cx, y)]), COR_MOLDURA)

## Toque fora do botão destacado durante a pausa: não faz nada (só não deixa passar).
func _toque_fora(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton or ev is InputEventScreenTouch) and ev.pressed:
		accept_event()
