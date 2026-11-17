# Tutorial do livro de receitas (fim da intro, depois do tutorial do caldeirão).
# O evento espera o tutorial acabar. Passos:
#   1. tocar no evento do livro no mapa (a tela escurece; só o livro responde)
#   2. o livro abre fechado: tocar na capa (tocar fora ou no ✕ fecha e volta ao passo 1)
#   3. a bruxa anota o rascunho da Poção do Retorno (animação de escrever)
#   4. Passar a limpo (obrigatório): a página vira "ensinada" (fitinha) com a receita certa
#   5. volta à 1ª página e mostra o Memorizar (tocar é opcional)
#   6. ✕ fecha o livro (fica a capa) e 7. ✕ da capa (ou tocar fora) sai
# Sem textos por cima: só a moldura piscando onde tocar (e a tela escura quando é obrigatório).
class_name CmdTutorialLivro
extends Comando

## id do evento do livro no mapa (bruxa_in).
@export var evento_livro: String = "bruxa_in_livro"

const CENA_LIVRO := "res://scenes/cena_livro.tscn"
const RECEITA := "res://dados/receitas/retorno.tres"
const CAMADA_MAPA: int = 6
const CAMADA_LIVRO: int = 5

func to_dict() -> Dictionary:
	return {"nome": "tutorial_livro", "args": [evento_livro]}

func executar(interp, ev) -> int:
	var t := _Tutorial.new()
	t.interp = interp
	t.ev = ev
	t.evento_livro = evento_livro
	t.process_mode = Node.PROCESS_MODE_ALWAYS
	ev.pause("tutorial_livro")
	interp.get_tree().root.add_child(t)
	return MANTER


class _Tutorial extends Node:
	enum Etapa { MAPA, CAPA, ESCREVER, LIMPO, MEMORIZAR, FECHAR, SAIR }
	var interp
	var ev
	var evento_livro: String
	var etapa: int = Etapa.MAPA
	var _camada_mapa: CanvasLayer
	var _destaque_mapa: DestaqueTutorial
	var _camada_livro: CanvasLayer
	var livro: CenaLivro
	var _destaque: DestaqueTutorial
	var _pagina_id: int = -1
	var _nome_pocao: String = "Poção do Retorno"
	var _id_memorizar: int = -1
	var _t_memorizar: float = 0.0
	var _t_escrito: float = 0.0
	## Depois de escrever o rascunho, espera isto (s) antes de acender o Passar a limpo.
	const ESPERA_DEPOIS_ESCREVER: float = 0.5
	## O Memorizar fica piscando por este tempo; depois o ✕ também pisca (memorizar é opcional).
	const TEMPO_MEMORIZAR: float = 4.0

	func _ready() -> void:
		_preparar_pagina()
		_ir_mapa()

	## O rascunho da Poção do Retorno (feito no tutorial do caldeirão). Se não houver, cria.
	func _preparar_pagina() -> void:
		var gt = interp.game_temp
		if gt == null or not ("livro" in gt):
			return
		if gt.livro.is_empty():
			gt.livro = LivroReceitas.novo(LivroReceitas.receitas_conhecidas())
		var rec = load(RECEITA) if ResourceLoader.exists(RECEITA) else null
		if rec is ReceitaData:
			_nome_pocao = _nome_da_pocao(rec)
		var l: Dictionary = gt.livro
		for k in range(l["rascunhos"].size() - 1, -1, -1):
			var p: Dictionary = l["rascunhos"][k]
			if str(p.get("resultado", {}).get("pocao", "")) == _nome_pocao or str(p.get("nome", "")) == _nome_pocao:
				_pagina_id = int(p["id"])
				return
		if rec is ReceitaData:
			var p := LivroReceitas.adicionar_rascunho(l, rec.passos_livro.duplicate(true), {"pocao": _nome_pocao, "a": 1.0, "vezes": 1})
			p["escrever"] = true
			p["nome"] = _nome_pocao
			_pagina_id = int(p["id"])

	func _nome_da_pocao(rec) -> String:
		var pocao = rec.get("pocao")
		if pocao and "nome" in pocao and str(pocao.nome) != "":
			return str(pocao.nome)
		return "Poção do Retorno"

	# ------------------------------------------------------------------ mapa
	func _ir_mapa() -> void:
		etapa = Etapa.MAPA
		if _camada_mapa == null:
			_camada_mapa = CanvasLayer.new()
			_camada_mapa.layer = CAMADA_MAPA
			_camada_mapa.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(_camada_mapa)
			_destaque_mapa = DestaqueTutorial.new()
			_camada_mapa.add_child(_destaque_mapa)
			_destaque_mapa.tocou_alvo.connect(_abrir_livro)
		_camada_mapa.visible = true
		_destaque_mapa.alvo(_rect_evento_livro, true, false)

	## Retângulo do sprite do livro na tela.
	func _rect_evento_livro() -> Rect2:
		var no = interp.encontrar_evento(evento_livro)
		if not (no is Node2D):
			return Rect2()
		var pag = no._get_active_page_node() if no.has_method("_get_active_page_node") else null
		var spr: AnimatedSprite2D = pag.get("animated_sprite") if pag else null
		if spr and spr.sprite_frames and spr.sprite_frames.has_animation(spr.animation):
			var tex := spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
			if tex:
				var tam := tex.get_size()
				var local := Rect2((-tam * 0.5 if spr.centered else Vector2.ZERO) + spr.offset, tam)
				var xf := spr.get_global_transform_with_canvas()
				var a: Vector2 = xf * local.position
				var b: Vector2 = xf * local.end
				return Rect2(a.min(b), (b - a).abs()).grow(14.0)
		var c: Vector2 = no.get_global_transform_with_canvas().origin
		return Rect2(c - Vector2(60, 110), Vector2(120, 120))

	func _abrir_livro() -> void:
		if etapa != Etapa.MAPA:
			return
		_camada_mapa.visible = false
		_destaque_mapa.esconder()
		var cena: PackedScene = load(CENA_LIVRO)
		_camada_livro = CanvasLayer.new()
		_camada_livro.layer = CAMADA_LIVRO
		_camada_livro.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child(_camada_livro)
		livro = cena.instantiate() as CenaLivro
		livro.process_mode = Node.PROCESS_MODE_ALWAYS
		livro.comecar_fechado = true
		livro.tutorial = self
		_camada_livro.add_child(livro)
		livro.fechou.connect(_livro_fechou)
		_destaque = DestaqueTutorial.new()
		livro.add_child(_destaque)
		_ir(Etapa.CAPA)

	func _livro_fechou() -> void:
		if is_instance_valid(_camada_livro):
			_camada_livro.queue_free()
		livro = null
		if etapa == Etapa.SAIR:
			_fim()
		else:
			_ir_mapa()   # saiu antes de abrir: pede para tocar no livro de novo

	# ------------------------------------------------------------------ livro
	func pode_sair() -> bool:
		return etapa == Etapa.CAPA or etapa == Etapa.SAIR

	func pode_virar() -> bool:
		return etapa == Etapa.MEMORIZAR or etapa == Etapa.FECHAR

	## A página do tutorial foi passada a limpo: vira receita ensinada, com os passos certos.
	func ao_passar_a_limpo(p: Dictionary) -> void:
		if int(p["id"]) != _pagina_id:
			return
		p["tipo"] = "npc"
		p["nome"] = _nome_pocao
		var rec = load(RECEITA) if ResourceLoader.exists(RECEITA) else null
		if rec is ReceitaData:
			p["passos"] = rec.passos_livro.duplicate(true)

	func _ir(e: int) -> void:
		etapa = e
		if not is_instance_valid(_destaque):
			return
		match e:
			Etapa.CAPA:
				_destaque.alvo(func(): return livro._capa_fechada.get_global_rect() if livro and livro._fechado else Rect2(), false)
			Etapa.ESCREVER:
				_destaque.alvo(Callable(), true)   # escuro: espera ela escrever
			Etapa.LIMPO:
				_destaque.alvo(_rect_botao.bind(_pagina_id, "Passar a limpo"), true)
			Etapa.MEMORIZAR:
				_destaque.alvo(Callable(), true)
				_mostrar_memorizar()
			Etapa.FECHAR:
				_destaque.alvo(_rect_x_aberto, false)
			Etapa.SAIR:
				_destaque.alvo(_rect_x_capa, false)

	## Volta à 1ª página do livro e mostra o Memorizar dela (opcional).
	func _mostrar_memorizar() -> void:
		livro._montar_lista()
		var primeira := -1
		for f in livro._folhas:
			if f is Dictionary and f.has("id"):
				primeira = int(f["id"])
				break
		_id_memorizar = primeira
		if primeira >= 0:
			await livro.ir_para(primeira)
		if etapa == Etapa.MEMORIZAR and is_instance_valid(_destaque):
			_destaque.alvo(_rect_botao.bind(_id_memorizar, "Memorizar"), false)
			_t_memorizar = 0.0

	func _rect_x_aberto() -> Rect2:
		return livro._x_aberto.get_global_rect() if livro and not livro._fechado and livro._x_aberto else Rect2()

	func _rect_x_capa() -> Rect2:
		if livro == null or not livro._fechado:
			return Rect2()
		var x = livro._capa_fechada.get_node_or_null("X")
		return x.get_global_rect() if x else Rect2()

	func _rect_botao(id: int, texto: String) -> Rect2:
		if livro == null or livro._animando:
			return Rect2()
		var b := livro.botao_da_pagina(id, texto)
		return b.get_global_rect().grow(6.0) if b else Rect2()

	func _process(delta: float) -> void:
		if livro == null or not is_instance_valid(livro):
			return
		match etapa:
			Etapa.CAPA:
				if not livro._fechado:
					_ir(Etapa.ESCREVER)
			Etapa.ESCREVER:
				var p := _pagina()
				if not p.is_empty() and not p.get("escrever", false) and not livro._animando and livro._lado_de(_pagina_id) >= 0:
					_t_escrito += delta
					if _t_escrito >= ESPERA_DEPOIS_ESCREVER:
						_ir(Etapa.LIMPO if p.get("tipo") == "rascunho" else Etapa.MEMORIZAR)
				else:
					_t_escrito = 0.0
			Etapa.LIMPO:
				var p := _pagina()
				if not p.is_empty() and p.get("tipo") != "rascunho" and not livro._animando:
					_ir(Etapa.MEMORIZAR)
			Etapa.MEMORIZAR:
				_t_memorizar += delta
				if _id_memorizar >= 0 and int(livro.livro.get("memorizada", -1)) == _id_memorizar:
					_ir(Etapa.FECHAR)   # memorizou: segue
				elif _t_memorizar >= TEMPO_MEMORIZAR and not livro._animando:
					_ir(Etapa.FECHAR)   # não é obrigatório: depois de um tempo mostra o ✕
				elif livro._fechado:
					_ir(Etapa.SAIR)     # fechou pelo ✕
			Etapa.FECHAR:
				if livro._fechado:
					_ir(Etapa.SAIR)
			Etapa.SAIR:
				if not livro._fechado:
					_ir(Etapa.FECHAR)   # abriu de novo pela capa

	func _pagina() -> Dictionary:
		var l: Dictionary = livro.livro
		for p in l["paginas"] + l["rascunhos"]:
			if int(p["id"]) == _pagina_id:
				return p
		return {}

	func _fim() -> void:
		if not ev.finished and ev.pause_reason == "tutorial_livro":
			ev.resume_and_advance()
		queue_free()
