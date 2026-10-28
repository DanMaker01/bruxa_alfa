# Escurece (fade_out) ou clareia (fade_in) a tela.
class_name CmdFade
extends Comando

enum Tipo { FADE_OUT, FADE_IN }

@export var tipo: Tipo = Tipo.FADE_OUT
@export var tempo: float = 1.0
## Ligado: o evento espera o fade terminar. Desligado: o fade corre e os comandos seguintes
## rodam junto (ex.: guardas olhando em volta enquanto escurece).
@export var esperar: bool = true

func to_dict() -> Dictionary:
	return {"nome": "fade_out" if tipo == Tipo.FADE_OUT else "fade_in", "args": [tempo]}

func executar(interp, ev) -> int:
	var gm = interp.game_manager
	var metodo := "fade_out" if tipo == Tipo.FADE_OUT else "fade_in"
	if not gm or not gm.has_method(metodo):
		interp.falhar(ev, self, "GameManager sem " + metodo)
		return AVANCAR
	if not esperar:
		gm.call(metodo, tempo)
		return AVANCAR
	ev.pause("fade")
	gm.call(metodo, tempo)
	_esperar_fim(interp, ev, gm)
	return MANTER

# Conecta DEPOIS de chamar: o sinal do fade anterior que este interrompeu (emitido
# dentro de fade_out/fade_in) não é confundido com o nosso. Sem tween rodando
# (ex.: sem nó Fade), o fade já terminou na hora.
func _esperar_fim(interp, ev, gm) -> void:
	# índice deste comando: se o evento pular para outro lugar (ex.: toque que pula a
	# cena) enquanto espera, este fade não pode "avançar" o comando que estiver lá.
	var meu_indice: int = ev.current_index
	if gm.has_method("is_fading") and gm.is_fading():
		var fim := [false]
		var sinal: Signal = gm.fade_out_completed if tipo == Tipo.FADE_OUT else gm.fade_in_completed
		sinal.connect(func(): fim[0] = true, CONNECT_ONE_SHOT)
		while not fim[0]:
			await interp.get_tree().process_frame
	if not ev.finished and ev.pause_reason == "fade" and ev.current_index == meu_indice:
		ev.resume_and_advance()
