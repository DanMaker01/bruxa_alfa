# =============================================================================
# indicadores.gd - Idêntico ao Python
# =============================================================================
class_name Indicadores
extends RefCounted

# =============================================================================
# TOLERÂNCIAS (idênticas ao Python)
# =============================================================================
const TOL_T: float = 0.5
const TOL_F: float = 4.0	# TOL_T * 8

# =============================================================================
# EQUILÍBRIO (idênticas ao Python)
# =============================================================================
var t_star_T: float = -1.0
var t_star_T_done: bool = false
var t_star_F: float = -1.0
var t_star_F_done: bool = false

# =============================================================================
# AÇÃO ADICIONAR (A) - idênticas ao Python
# =============================================================================
var t_A0: float = -1.0
var t_A_star: float = -1.0
var T_base_A: float = 0.0
var F_base_A: float = 0.0
var T_max_A: float = -INF
var T_max_A_t: float = -1.0
var T_max_A_done: bool = false
var F_max_A: float = -INF
var F_max_A_t: float = -1.0
var F_max_A_done: bool = false

# =============================================================================
# AÇÃO MEXER (ESPAÇO) - idênticas ao Python
# =============================================================================
var t_I0: float = -1.0
var t_I_star: float = -1.0
var T_base_I: float = 0.0
var F_base_I: float = 0.0
var T_min_I: float = INF
var T_min_I_t: float = -1.0
var T_min_I_done: bool = false
var F_min_I: float = INF
var F_min_I_t: float = -1.0
var F_min_I_done: bool = false

# =============================================================================
# UPDATE (idêntico ao Python)
# =============================================================================
func update(sis: SistemaTermico, dt_step: float) -> void:
	# ---------- EQUILÍBRIO (só conta com fogo ligado, a partir do último ligar_fogo) ----------
	if not t_star_T_done \
			and sis.fogo_ligado \
			and sis.t_fogo_ligado >= 0.0 \
			and abs(sis.T - SistemaTermico.T_EQ) < TOL_T:
		t_star_T = sis.t_sim - sis.t_fogo_ligado
		t_star_T_done = true

	if not t_star_F_done \
			and sis.fogo_ligado \
			and sis.t_fogo_ligado >= 0.0 \
			and abs(sis.F - SistemaTermico.F_EQ) < TOL_F:
		t_star_F = sis.t_sim - sis.t_fogo_ligado
		t_star_F_done = true
	
	# ---------- APÓS MEXER (I) ----------
	if t_I0 >= 0.0 and t_I_star < 0.0 and sis.t_sim > t_I0 + dt_step:
		if abs(sis.T - SistemaTermico.T_EQ) < TOL_T:
			t_I_star = sis.t_sim
	
	# ---------- APÓS ADICIONAR (A) ----------
	if t_A0 >= 0.0 and t_A_star < 0.0 and sis.t_sim > t_A0 + dt_step:
		if abs(sis.F - SistemaTermico.F_EQ) < TOL_F:
			t_A_star = sis.t_sim
	
	# ---------- PICO T_max após A ----------
	if T_max_A != -INF:
		if sis.T > T_max_A:
			T_max_A = sis.T
			T_max_A_t = sis.t_sim
		if not T_max_A_done and abs(sis.T - SistemaTermico.T_EQ) < TOL_T and sis.t_sim > t_A0 + 0.5:
			T_max_A_done = true
	
	# ---------- PICO F_max após A ----------
	if F_max_A != -INF:
		if sis.F > F_max_A:
			F_max_A = sis.F
			F_max_A_t = sis.t_sim
		if not F_max_A_done and abs(sis.F - SistemaTermico.F_EQ) < TOL_F and sis.t_sim > t_A0 + 0.5:
			F_max_A_done = true
	
	# ---------- VALE T_min após I ----------
	if T_min_I != INF:
		if sis.T < T_min_I:
			T_min_I = sis.T
			T_min_I_t = sis.t_sim
		if not T_min_I_done and abs(sis.T - SistemaTermico.T_EQ) < TOL_T and sis.t_sim > t_I0 + 0.5:
			T_min_I_done = true
	
	# ---------- VALE F_min após I ----------
	if F_min_I != INF:
		if sis.F < F_min_I:
			F_min_I = sis.F
			F_min_I_t = sis.t_sim
		if not F_min_I_done and abs(sis.F - SistemaTermico.F_EQ) < TOL_F and sis.t_sim > t_I0 + 0.5:
			F_min_I_done = true

# =============================================================================
# REGISTRAR AÇÕES (idêntico ao Python)
# =============================================================================
func registrar_acao_adicionar(sis: SistemaTermico) -> void:
	T_base_A = sis.T
	F_base_A = sis.F
	t_A0 = sis.t_sim
	t_A_star = -1.0
	T_max_A = sis.T
	T_max_A_t = sis.t_sim
	T_max_A_done = false
	F_max_A = sis.F
	F_max_A_t = sis.t_sim
	F_max_A_done = false

func registrar_acao_mexer(sis: SistemaTermico) -> void:
	T_base_I = sis.T
	F_base_I = sis.F
	t_I0 = sis.t_sim
	t_I_star = -1.0
	T_min_I = sis.T
	T_min_I_t = sis.t_sim
	T_min_I_done = false
	F_min_I = sis.F
	F_min_I_t = sis.t_sim
	F_min_I_done = false

# =============================================================================
# RESET
# =============================================================================
func reset() -> void:
	t_star_T = -1.0
	t_star_T_done = false
	t_star_F = -1.0
	t_star_F_done = false
	t_A0 = -1.0
	t_A_star = -1.0
	t_I0 = -1.0
	t_I_star = -1.0
	T_max_A = -INF
	F_max_A = -INF
	T_min_I = INF
	F_min_I = INF
	T_max_A_t = -1.0
	F_max_A_t = -1.0
	T_min_I_t = -1.0
	F_min_I_t = -1.0
	T_max_A_done = false
	F_max_A_done = false
	T_min_I_done = false
	F_min_I_done = false

# =============================================================================
# UI (idêntico ao Python)
# =============================================================================
func fmt_t(v: float) -> String:
	return "%.2f s" % v if v >= 0.0 else "—"

func fmt_C(v: float) -> String:
	if v == -INF or v == INF:
		return "—"
	return "%.2f" % v

func fmt_d(base: float, ext: float) -> String:
	if ext == -INF or ext == INF:
		return "—"
	return "%+.2f" % (ext - base)

func get_linhas_ui(sis: SistemaTermico) -> Array:
	var delta_I = (t_I_star - t_I0) if (t_I0 >= 0.0 and t_I_star >= 0.0) else -1.0
	var delta_A = (t_A_star - t_A0) if (t_A0 >= 0.0 and t_A_star >= 0.0) else -1.0
	
	return [
		"t	  = %.2f s" % sis.t_sim,
		"T	  = %.2f °C" % sis.T,
		"F	  = %.2f °C" % sis.F,
		"h	  = %.3f" % sis.h,
		"P_comb = %.3f" % sis.P_comb,
		"─── t* ───",
		"t*T	= " + fmt_t(t_star_T),
		"t*F	= " + fmt_t(t_star_F),
		"─── delta I (ESPAÇO) ───",
		"dI	 = " + fmt_t(delta_I),
		"─── delta A (A) ───",
		"dA	 = " + fmt_t(delta_A),
		"─── APÓS A (F +) ───",
		"T_max  = " + fmt_C(T_max_A) + " °C",
		"ΔT_max = " + fmt_d(T_base_A, T_max_A) + " °C",
		"t_TpA  = " + fmt_t(T_max_A_t),
		"F_max  = " + fmt_C(F_max_A) + " °C",
		"ΔF_max = " + fmt_d(F_base_A, F_max_A) + " °C",
		"t_FpA  = " + fmt_t(F_max_A_t),
		"─── APÓS ESPAÇO (T −) ───",
		"T_min  = " + fmt_C(T_min_I) + " °C",
		"ΔT_min = " + fmt_d(T_base_I, T_min_I) + " °C",
		"t_TvI  = " + fmt_t(T_min_I_t),
		"F_min  = " + fmt_C(F_min_I) + " °C",
		"ΔF_min = " + fmt_d(F_base_I, F_min_I) + " °C",
		"t_FvI  = " + fmt_t(F_min_I_t),
	]
