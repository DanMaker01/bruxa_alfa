# testes_caldeirao.gd
# Testes automáticos do caldeirão (debug). Rodam numa simulação separada, sem mexer
# no caldeirão de verdade.
#   sistema():      respostas do sistema térmico (equilíbrio, abanar, abafar, esfriar...)
#   ingrediente():  para um item, procura a melhor receita simples (temperatura alvo
#                   segurada abanando/abafando como o jogador faria, quando tirar) e diz
#                   o aproveitamento que dá.
# Cada resultado: {"titulo", "linhas": [String], "ok": true / false / null (só informação)}.
class_name TestesCaldeirao
extends RefCounted

const DT_RAPIDO: float = 0.05        # passo da simulação dos ingredientes (estável para estas constantes)
const PONTO_A_CADA: float = 0.25     # amostra para o acumulador e a nota (mais leve que os 20/s do jogo)
const CONTROLE_A_CADA: float = 0.25  # o "jogador" decide a cada 0,25 s
const T_MAX_TESTE: float = 600.0
const BOM: float = 0.9
const MEDIO: float = 0.6


# =============================================================================
# SISTEMA TÉRMICO (usa o SistemaTermico de verdade)
# =============================================================================
static func sistema() -> Array:
	var r := []
	# 1. frio até o equilíbrio
	var s := SistemaTermico.new()
	s.ligar_fogo()
	var tT := -1.0
	var tF := -1.0
	while s.t_sim < 900.0 and (tT < 0.0 or tF < 0.0):
		s.step(0.1)
		if tT < 0.0 and s.esta_em_equilibrio_T():
			tT = s.t_sim
		if tF < 0.0 and s.esta_em_equilibrio_F():
			tF = s.t_sim
	r.append(_res("Frio até o equilíbrio", [
		"T chega em %d °C em %s" % [int(SistemaTermico.T_EQ), _s(tT)],
		"F chega em %d °C em %s" % [int(SistemaTermico.F_EQ), _s(tF)]], tT > 0.0 and tF > 0.0))

	# 2. abanar 1x no equilíbrio
	s = _em_equilibrio()
	var T0 := s.T
	var F0 := s.F
	s.dar_pulso_fogo()
	var pico := _acompanhar_pico(s, 300.0)
	r.append(_res("Abanar 1x (F +%d)" % int(SistemaTermico.CONST_A), [
		"pico T %+.2f °C em %.1f s" % [pico["T"] - T0, pico["tT"]],
		"pico F %+.1f °C" % (pico["F"] - F0),
		"volta ao equilíbrio em %s" % _s(pico["volta"])], pico["volta"] > 0.0))

	# 3. abanar 10x seguidas
	s = _em_equilibrio()
	T0 = s.T
	for k in 10:
		s.dar_pulso_fogo()
	pico = _acompanhar_pico(s, 400.0)
	r.append(_res("Abanar 10x seguidas", [
		"F vai a %d °C" % roundi(pico["F"]),
		"pico T %d °C (%+.1f) em %.1f s" % [roundi(pico["T"]), pico["T"] - T0, pico["tT"]],
		"volta em %s" % _s(pico["volta"])], null))

	# 4. quantas abanadas (1 por segundo) para chegar em 120 / 150 / 200 °C
	for alvo in [120.0, 150.0, 200.0]:
		s = _em_equilibrio()
		var t_ini := s.t_sim
		var n := 0
		while s.T < alvo and s.t_sim - t_ini < 300.0:
			s.dar_pulso_fogo()
			n += 1
			s.step(1.0)
		var chegou: bool = s.T >= alvo
		r.append(_res("Chegar em %d °C" % int(alvo), [
			("%d abanadas, %.0f s (1 por segundo)" % [n, s.t_sim - t_ini]) if chegou else "não chega em 300 s"], chegou))

	# 5. abafar até apagar
	s = _em_equilibrio()
	var abafadas := 0
	while s.fogo_ligado and abafadas < 200:
		s.abafar_fogo()
		abafadas += 1
	r.append(_res("Abafar até apagar", [
		"%d abafadas (F -%d cada, apaga abaixo de %d)" % [abafadas, int(SistemaTermico.CONST_C), int(SistemaTermico.F_LIMIT_MIN)]],
		not s.fogo_ligado))

	# 6. esfriar com o fogo desligado
	s = _em_equilibrio()
	s.desligar_fogo()
	var t_ini2 := s.t_sim
	var t80 := -1.0
	var t60 := -1.0
	var t40 := -1.0
	while s.t_sim - t_ini2 < 900.0 and t40 < 0.0:
		s.step(0.1)
		var dt := s.t_sim - t_ini2
		if t80 < 0.0 and s.T <= 80.0: t80 = dt
		if t60 < 0.0 and s.T <= 60.0: t60 = dt
		if t40 < 0.0 and s.T <= 40.0: t40 = dt
	r.append(_res("Esfriar (fogo desligado)", [
		"100 → 80 °C em %s" % _s(t80), "100 → 60 °C em %s" % _s(t60), "100 → 40 °C em %s" % _s(t40)], null))

	# 7. religar depois de esfriar até 60
	s = _em_equilibrio()
	s.desligar_fogo()
	while s.T > 60.0 and s.t_sim < 2000.0:
		s.step(0.1)
	s.ligar_fogo()
	var t_rel := s.t_sim
	while not s.esta_em_equilibrio_T() and s.t_sim - t_rel < 900.0:
		s.step(0.1)
	r.append(_res("Religar em 60 °C", ["volta a %d °C em %s" % [int(SistemaTermico.T_EQ), _s(s.t_sim - t_rel if s.esta_em_equilibrio_T() else -1.0)]],
		s.esta_em_equilibrio_T()))
	return r


static func _em_equilibrio() -> SistemaTermico:
	var s := SistemaTermico.new()
	s.ligar_fogo()
	while s.t_sim < 900.0 and not (s.esta_em_equilibrio_T() and s.esta_em_equilibrio_F()):
		s.step(0.1)
	return s

## Acompanha depois de uma ação: maior T e F, quando foi o pico de T e quando voltou ao equilíbrio.
static func _acompanhar_pico(s: SistemaTermico, limite: float) -> Dictionary:
	var t_ini := s.t_sim
	var d := {"T": s.T, "F": s.F, "tT": 0.0, "volta": -1.0}
	while s.t_sim - t_ini < limite:
		s.step(0.1)
		if s.T > d["T"]:
			d["T"] = s.T
			d["tT"] = s.t_sim - t_ini
		d["F"] = maxf(d["F"], s.F)
		if s.t_sim - t_ini > 1.0 and s.esta_em_equilibrio_T() and s.esta_em_equilibrio_F():
			d["volta"] = s.t_sim - t_ini
			break
	return d


# =============================================================================
# INGREDIENTES (simulação rápida com as mesmas equações)
# =============================================================================
## É ingrediente de cozinhar? (tem alguma exigência de cozimento, temperatura ou tempo)
static func eh_ingrediente(it: ItemData) -> bool:
	return it != null and (it.m > 0.0 or it.T_min > 0.0 or it.T_max > 0.0 or it.t_min > 0.0 or it.t_max > 0.0)

static func ingrediente(it: ItemData) -> Dictionary:
	var melhor := {"a": -1.0}
	for alvo in _alvos(it):
		var tent := _simular(it, alvo)
		if tent["a"] > melhor["a"]:
			melhor = tent
	var linhas: Array = []
	var a: float = melhor["a"]
	linhas.append("melhor: %d%% segurando %d °C" % [roundi(a * 100.0), roundi(melhor["alvo"])])
	linhas.append("tirar com %.0f s  (Q %d)" % [melhor["t"], roundi(melhor["Q"])])
	linhas.append("partes: Q %d%%  T %d%%  t %d%%" % [roundi(melhor["aQ"] * 100.0), roundi(melhor["aT"] * 100.0), roundi(melhor["at"] * 100.0)])
	if melhor["abanadas"] > 0 or melhor["abafadas"] > 0:
		linhas.append("abanou %d, abafou %d" % [melhor["abanadas"], melhor["abafadas"]])
	# avisos de gabarito impossível
	if it.T_min > 0.0 and it.T_max > 0.0 and it.T_min >= it.T_max:
		linhas.append("! Tmin >= Tmax")
	if it.m > 0.0 and it.t_max > 0.0 and it.T_max > 0.0 and it.m / it.T_max > it.t_max:
		linhas.append("! nem em Tmax dá Q=m antes de t_max")
	if it.m > 0.0 and it.t_min > 0.0 and it.T_min > 0.0 and it.m / it.T_min < it.t_min:
		linhas.append("! até em Tmin passa do ponto antes de t_min")
	var ok = true if a >= BOM else (null if a >= MEDIO else false)
	return {"titulo": it.get_nome(), "linhas": linhas, "ok": ok, "a": a}

## Temperaturas para tentar: meio da janela, perto das bordas e o equilíbrio natural (100).
static func _alvos(it: ItemData) -> Array:
	var lo: float = it.T_min if it.T_min > 0.0 else 40.0
	var hi: float = it.T_max if it.T_max > 0.0 else 200.0
	var c := [SistemaTermico.T_EQ, (lo + hi) * 0.5, lo + 3.0, hi - 3.0]
	if it.m > 0.0 and it.t_min > 0.0 and it.t_max > 0.0:
		c.append(it.m / ((it.t_min + it.t_max) * 0.5))   # T que dá Q=m no meio da janela de tempo
	var r := []
	for v in c:
		var x := clampf(v, 35.0, 240.0)
		var repetido := false
		for y in r:
			if absf(y - x) < 2.0:
				repetido = true
		if not repetido:
			r.append(x)
	return r

## Esquenta até o alvo, coloca o item, segura o alvo e guarda o melhor momento de tirar.
static func _simular(it: ItemData, alvo: float) -> Dictionary:
	var s := SistemaTermico.new()   # só para h e P_comb
	var T := SistemaTermico.T_AMB
	var F := SistemaTermico.T_AMB
	var fogo := true
	var t := 0.0
	var prox_controle := 0.0
	var prox_ponto := 0.0
	var dentro := false
	var acc: Dictionary = {}
	var melhor := {"a": 0.0, "t": 0.0, "Q": 0.0, "alvo": alvo, "aQ": 0.0, "aT": 0.0, "at": 0.0, "abanadas": 0, "abafadas": 0}
	var abanadas := 0
	var abafadas := 0
	var t_lim: float = T_MAX_TESTE
	while t < t_lim:
		# "jogador": abana se está frio, abafa (ou desliga) se está quente
		if t >= prox_controle:
			prox_controle += CONTROLE_A_CADA
			var e := alvo - T
			if e > 1.5:
				if not fogo:
					fogo = true
				elif F < 2000.0 and (alvo > SistemaTermico.T_EQ or F < SistemaTermico.F_EQ):
					F += SistemaTermico.CONST_A
					if dentro: abanadas += 1
			elif e < -1.5 and fogo:
				F = maxf(F - SistemaTermico.CONST_C, SistemaTermico.T_AMB)
				if dentro: abafadas += 1
				if F < SistemaTermico.F_LIMIT_MIN:
					fogo = false
		# física (mesmas equações do SistemaTermico.step)
		var dT := (SistemaTermico.K * (F - T) - s.h * (T - SistemaTermico.T_AMB)) / SistemaTermico.C
		var dF := (-SistemaTermico.K * (F - T) - SistemaTermico.HF * (F - SistemaTermico.T_AMB) + (s.P_comb if fogo else 0.0)) / SistemaTermico.C_F
		T += dT * DT_RAPIDO
		F += dF * DT_RAPIDO
		t += DT_RAPIDO
		# entra quando chegou perto do alvo (ou depois de 300 s esquentando)
		if not dentro and (absf(T - alvo) < 2.0 or t > 300.0):
			dentro = true
			acc = CalculadoraPocao.novo_acumulador(it.id, t)
			prox_ponto = t
			t_lim = t + maxf(it.t_max * (1.0 + it.h_max), 0.0) + 30.0 if it.t_max > 0.0 else t + T_MAX_TESTE
		if dentro and t >= prox_ponto:
			prox_ponto += PONTO_A_CADA
			CalculadoraPocao.acumular(acc, {"t": t, "T": T}, it)
			var d := CalculadoraPocao.diagnostico_do_acumulador(acc, t)
			CalculadoraPocao._aproveitamento(d, it)
			if float(d["a"]) > melhor["a"]:
				melhor = {"a": float(d["a"]), "t": t - float(acc["t0"]), "Q": float(d["Q"]), "alvo": alvo,
					"aQ": float(d["a_Q"]), "aT": float(d["a_T_max"]) * float(d["a_T_min"]),
					"at": float(d["a_t_min"]) * float(d["a_t_max"]), "abanadas": abanadas, "abafadas": abafadas}
	return melhor


# ---------------------------------------------------------------------------
static func _res(titulo: String, linhas: Array, ok) -> Dictionary:
	return {"titulo": titulo, "linhas": linhas, "ok": ok}

static func _s(v: float) -> String:
	return "%.1f s" % v if v >= 0.0 else "nunca"
