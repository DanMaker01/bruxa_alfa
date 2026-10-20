# som_caldeirao.gd
# Som do caldeirão gerado na hora (sem arquivos de áudio):
#   borbulhar  → "ploc"s cujo ritmo e tom sobem com a temperatura
#   chiado     → ruído agudo quando algum ingrediente está QUENTE DEMAIS
#   estalos    → cliques secos de gelo quando algum ingrediente está FRIO DEMAIS
#   lenha      → estalar do fogo: mais rápido e mais agudo conforme a faixa de cor da chama
#                (brasa: poucos estalos graves; branco/azul: crepitar rápido e brilhante)
# A cena chama definir() a cada frame e silenciar() quando o preparo pausa/fecha.
class_name SomCaldeirao
extends AudioStreamPlayer

# ---- ajuste aqui ----
const TAXA: float = 22050.0           # amostras por segundo (baixo = mais leve no celular)
const VOLUME_GERAL: float = 0.6
const PLOCS_MIN: float = 0.6          # plocs/s no frio
const PLOCS_MAX: float = 14.0         # plocs/s fervendo
const TOM_MIN: float = 220.0          # Hz do ploc no frio
const TOM_MAX: float = 620.0          # Hz do ploc fervendo
const PLOC_DURACAO: float = 0.045     # s
const CHIADO_VOLUME: float = 0.10
const ESTALOS_POR_SEG: float = 4.0    # no frio máximo
const T_FRIO: float = 20.0            # T (°C) sem borbulhar
const T_FERVENDO: float = 200.0       # T (°C) no máximo
# ---- lenha (pelo F do fogo; mesmas faixas de CORES_FOGO) ----
const LENHA_F_MIN: float = 600.0      # F da brasa (estalo raro e grave)
const LENHA_F_MAX: float = 1180.0     # F do fogo azul (crepitar no máximo)
const LENHA_POR_SEG_MIN: float = 1.5
const LENHA_POR_SEG_MAX: float = 22.0
const LENHA_VOLUME: float = 0.45

var _playback: AudioStreamGeneratorPlayback
var _ativo: bool = false
var _tn: float = 0.0          # temperatura normalizada 0..1
var _quente: float = 0.0      # 0..1
var _frio: float = 0.0        # 0..1
var _vol: float = 0.0         # volume suavizado (entra/sai sem estalo)
var _plocs: Array = []        # {f, fase, t}
var _estalo: float = 0.0      # tempo restante do estalo atual (s)
var _ruido_ant: float = 0.0
var _fn: float = -1.0        # fogo normalizado 0..1 (-1 = apagado)
var _lenha_t: float = 0.0    # tempo restante do estalo de lenha
var _lenha_dur: float = 0.0
var _lenha_amp: float = 0.0
var _lenha_grave: float = 0.0   # ruído filtrado (corpo grave do estalo)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = TAXA
	gen.buffer_length = 0.1
	stream = gen
	if AudioServer.get_bus_index("SFX") != -1:
		bus = "SFX"
	play()
	_playback = get_stream_playback()

## T: temperatura do caldeirão; quente/frio: 0..1 (o pior ingrediente agora).
func definir(T: float, quente: float, frio: float) -> void:
	_ativo = true
	_tn = clampf((T - T_FRIO) / (T_FERVENDO - T_FRIO), 0.0, 1.0)
	_quente = clampf(quente, 0.0, 1.0)
	_frio = clampf(frio, 0.0, 1.0)

## Fogo: F e se está aceso (apagado = sem estalos de lenha).
func definir_fogo(F: float, aceso: bool) -> void:
	_fn = clampf((F - LENHA_F_MIN) / (LENHA_F_MAX - LENHA_F_MIN), 0.0, 1.0) if aceso else -1.0

func silenciar() -> void:
	_ativo = false

func _process(_delta: float) -> void:
	if _playback == null:
		return
	var n := _playback.get_frames_available()
	if n <= 0:
		return
	var dt := 1.0 / TAXA
	var taxa_ploc: float = lerpf(PLOCS_MIN, PLOCS_MAX, _tn) * dt
	var vol_alvo: float = VOLUME_GERAL if _ativo else 0.0
	for i in n:
		_vol += (vol_alvo - _vol) * 0.0005
		var s := 0.0
		if _vol > 0.0005:
			# nasce um ploc?
			if _tn > 0.02 and randf() < taxa_ploc:
				_plocs.append({"f": lerpf(TOM_MIN, TOM_MAX, _tn) * randf_range(0.8, 1.25), "fase": 0.0, "t": 0.0})
			# plocs: seno subindo de tom e sumindo rápido
			for j in range(_plocs.size() - 1, -1, -1):
				var p: Dictionary = _plocs[j]
				p["t"] += dt
				var x: float = p["t"] / PLOC_DURACAO
				if x >= 1.0:
					_plocs.remove_at(j)
					continue
				p["fase"] += TAU * p["f"] * (1.0 + x * 0.8) * dt
				s += sin(p["fase"]) * exp(-x * 5.0) * 0.35
			# chiado (quente demais): ruído com agudo realçado
			var r := randf_range(-1.0, 1.0)
			if _quente > 0.01:
				s += (r - _ruido_ant) * 0.5 * CHIADO_VOLUME * _quente
			_ruido_ant = r
			# estalos de gelo (frio demais)
			if _frio > 0.01 and _estalo <= 0.0 and randf() < ESTALOS_POR_SEG * _frio * dt:
				_estalo = 0.006
			if _estalo > 0.0:
				_estalo -= dt
				s += r * 0.5 * (_estalo / 0.006)
			# lenha: estalos curtos de ruído; no fogo forte, mais frequentes, curtos e agudos
			if _fn >= 0.0:
				if _lenha_t <= 0.0 and randf() < lerpf(LENHA_POR_SEG_MIN, LENHA_POR_SEG_MAX, _fn * _fn) * dt:
					_lenha_dur = lerpf(0.012, 0.003, _fn) * randf_range(0.6, 1.4)
					_lenha_t = _lenha_dur
					_lenha_amp = randf_range(0.4, 1.0)
				if _lenha_t > 0.0:
					_lenha_t -= dt
					var env: float = _lenha_t / _lenha_dur
					_lenha_grave += (r - _lenha_grave) * lerpf(0.08, 0.6, _fn)
					var agudo: float = r - _lenha_grave
					s += lerpf(_lenha_grave * 2.0, agudo, _fn) * env * env * _lenha_amp * LENHA_VOLUME
		_playback.push_frame(Vector2.ONE * clampf(s * _vol, -1.0, 1.0))
