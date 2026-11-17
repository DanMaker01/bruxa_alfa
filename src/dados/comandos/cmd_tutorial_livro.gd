# Tutorial do livro de receitas (fim da intro, depois do tutorial do caldeirão).
# O evento espera o tutorial acabar. Passos:
#   1. tocar no evento do livro no mapa (a tela escurece; só o livro responde)
#   2. o livro abre fechado: tocar na capa (tocar fora ou no ✕ fecha e volta ao passo 1)
#   3. a bruxa anota o rascunho da Poção do Retorno (animação de escrever)
#   4. Passar a limpo (obrigatório): a página vira "ensinada" (fitinha) com a receita certa
#   5. Memorizar (explica; tocar é opcional, "Continuar" segue)
#   6. fechar o livro (arrastar para o lado) e 7. sair (tocar fora ou no ✕)
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
		_destaque_mapa.dica("Este é o meu livro de receitas. Toque nele.")

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
		return etapa == Etapa.FECHAR

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
				_destaque.dica("Toque na capa para abrir o livro.")
			Etapa.ESCREVER:
				_destaque.alvo(Callable(), true)
				_destaque.dica("Toda poção que eu faço fica anotada como rascunho...")
			Etapa.LIMPO:
				_destaque.alvo(_rect_botao.bind("Passar a limpo"), true)
				_destaque.dica("Rascunho é anotação solta. Toque em Passar a limpo para guardar a receita no livro.")
			Etapa.MEMORIZAR:
				_destaque.alvo(_rect_botao.bind("Memorizar"), true)
				_destaque.dica("Memorizar leva a receita para o caldeirão: ela aparece lá enquanto eu cozinho. Toque se quiser.", "Continuar", func(): _ir(Etapa.FECHAR))
			Etapa.FECHAR:
				_destaque.alvo(Callable(), false)
				_destaque.dica("Para fechar o livro, arraste a página para o lado.")
			Etapa.SAIR:
				_destaque.alvo(Callable(), false)
				_destaque.dica("Para sair, toque fora do livro ou no ✕.")

	func _rect_botao(texto: String) -> Rect2:
		if livro == null or livro._animando:
			return Rect2()
		var b := livro.botao_da_pagina(_pagina_id, texto)
		return b.get_global_rect().grow(6.0) if b else Rect2()

	func _process(_d: float) -> void:
		if livro == null or not is_instance_valid(livro):
			return
		match etapa:
			Etapa.CAPA:
				if not livro._fechado:
					_ir(Etapa.ESCREVER)
			Etapa.ESCREVER:
				var p := _pagina()
				if not p.is_empty() and not p.get("escrever", false) and not livro._animando and livro._lado_de(_pagina_id) >= 0:
					_ir(Etapa.LIMPO if p.get("tipo") == "rascunho" else Etapa.MEMORIZAR)
			Etapa.LIMPO:
				var p := _pagina()
				if not p.is_empty() and p.get("tipo") != "rascunho" and not livro._animando:
					_ir(Etapa.MEMORIZAR)
			Etapa.MEMORIZAR:
				if int(livro.livro.get("memorizada", -1)) == _pagina_id:
					_ir(Etapa.FECHAR)   # memorizou: segue sozinho
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
