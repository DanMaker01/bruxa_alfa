# balanceamento.py - aba Balanceamento (própria da central, sem matplotlib; o motor é o
# simulador_caldeirao.py e as análises do balanceamento.py antigo, as mesmas contas do jogo).
#   Esquerda: receita e os passos (chama / ingrediente, quantidade, segundos), editáveis;
#             "Salvar passos" grava o passos_livro da receita.
#   Direita:  Resultado (nome que o jogo daria, aproveitamento, efeito, poções mais perto,
#             matriz, cada ingrediente, gráfico da temperatura), Monte Carlo (jogadora calibrada),
#             Testes automáticos, Dificuldade, Chamas (aproveitamento trocando a chama de cada passo)
#             e Chama × tempo (curvas: segundos de um ingrediente × cor da chama antes dele).
#   Jogadora: perfeita, calibrada ou ruim (com o número da jogada).
#   Opções de teste: dose a² e cisalhamento (ruído fora da diagonal) - só aqui, o jogo não muda.
import copy
import json
import re

from PySide6 import QtCore, QtGui, QtWidgets as W

from nucleo import chamas as chm, motor
from nucleo import tres_simples as ts
from nucleo.visual import GraficoLinhas, Histograma, MatrizGrade, VERDE, VERMELHO

TITULO = "Balanceamento"
## Jogadora ruim: reage devagar, lê mal a chama, deixa passar muito e erra bastante o tempo.
JOGADORA_RUIM = {"cliques_s": 2.0, "reacao": 0.5, "ruido": 0.12, "folga": 5.0, "sigma_seg": 6.0, "vies_seg": 2.0}
NIVEIS_CIS = [("sem cisalhamento", 0.0, 0.0), ("cisalhamento ±1%", 0.005, 0.01),
              ("cisalhamento ±2%", 0.01, 0.02), ("cisalhamento ±4%", 0.02, 0.04)]


def _cor(c):
    if isinstance(c, (tuple, list)):
        q = QtGui.QColor.fromRgbF(*[float(x) for x in c[:3]])
    else:
        q = QtGui.QColor(str(c))
    q.setAlpha(45)
    return q


class Aba(W.QWidget):
    def __init__(self, raiz):
        super().__init__()
        self.raiz = raiz
        self.sim, self.bal = motor.balanceamento()
        self.dados = self.bal.Dados()
        self.params = self.bal.ler_calibracao()
        self.rc = None
        lay = W.QVBoxLayout(self)
        lay.setContentsMargins(6, 6, 6, 6)
        lay.addLayout(self._barra())
        split = W.QSplitter(QtCore.Qt.Horizontal)
        split.addWidget(self._lado_receita())
        split.addWidget(self._lado_resultado())
        split.setSizes([420, 860])
        lay.addWidget(split, 1)
        self.status = W.QLabel()
        lay.addWidget(self.status)
        self._carregar_receitas()

    # ================================================================ barra
    def _barra(self):
        h = W.QHBoxLayout()
        h.addWidget(W.QLabel("Receita:"))
        self.combo = W.QComboBox()
        self.combo.currentIndexChanged.connect(self._receita_escolhida)
        h.addWidget(self.combo)
        for txt, fn in (("Rodar", self.rodar), ("Monte Carlo", self.monte), ("Testes", self.testes),
                        ("Dificuldade", self.dificuldade), ("Recarregar dados", self.recarregar)):
            b = W.QPushButton(txt)
            b.clicked.connect(fn)
            h.addWidget(b)
        h.addStretch(1)
        self.jog = W.QComboBox()
        self.jog.addItems(["jogadora perfeita", "jogadora calibrada", "jogadora ruim"])
        self.jog.setToolTip("perfeita: faz tudo no tempo e na chama certos\ncalibrada: erra como a jogadora medida (reação, ruído na chama, tempo)\n"
                            "ruim: reage devagar (0,5 s), lê mal a chama (±12%), deixa passar 5 °C, erra o tempo (±6 s, atrasa 2 s)")
        self.jog.currentIndexChanged.connect(self.rodar)
        h.addWidget(self.jog)
        self.semente = W.QSpinBox(minimum=1, maximum=9999, value=1, prefix="jogada nº ")
        self.semente.setToolTip("cada número é uma jogada diferente da jogadora calibrada")
        self.semente.valueChanged.connect(self.rodar)
        h.addWidget(self.semente)
        self.n_mc = W.QSpinBox(minimum=20, maximum=2000, value=200, singleStep=50, prefix="MC: ", suffix=" jogadas")
        h.addWidget(self.n_mc)
        self.quad = W.QCheckBox("dose a²")
        self.quad.setToolTip("teste: cada ingrediente conta como a² em vez de a")
        self.quad.toggled.connect(self._opcoes)
        h.addWidget(self.quad)
        self.cis = W.QComboBox()
        self.cis.addItems([n[0] for n in NIVEIS_CIS])
        self.cis.setCurrentIndex(1 if self.sim.CISALHAMENTO else 0)
        self.cis.setToolTip("teste do problema do zero: ruído fixo por item fora da diagonal (o catálogo segue o ruído)")
        self.cis.currentIndexChanged.connect(self._opcoes)
        h.addWidget(self.cis)
        return h

    def _opcoes(self, *_):
        self.sim.EXPOENTE_DOSE = 2.0 if self.quad.isChecked() else 1.0
        _, s, c = NIVEIS_CIS[self.cis.currentIndex()]
        self.sim.CISALHAMENTO, self.sim.CISALHAMENTO_SIGMA, self.sim.CISALHAMENTO_MAX = s > 0, s, c
        self.sim._cache_cis.clear()
        self.sim.ajustar_catalogo_ao_ruido(self.dados.itens, self.dados.receitas, self.dados.catalogo)
        self.rodar()

    # ================================================================ receita
    def _lado_receita(self):
        w = W.QWidget()
        v = W.QVBoxLayout(w)
        v.setContentsMargins(0, 0, 0, 0)
        self.passos = W.QTableWidget(0, 4)
        self.passos.setHorizontalHeaderLabels(["tipo", "chama / item", "qtd", "segundos"])
        self.passos.verticalHeader().setVisible(False)
        self.passos.horizontalHeader().setSectionResizeMode(1, W.QHeaderView.Stretch)
        self.passos.itemChanged.connect(self._passo_mudou)
        v.addWidget(self.passos, 1)
        h = W.QHBoxLayout()
        for txt, fn in (("+ chama", lambda: self._novo_passo("chama")), ("+ ingrediente", lambda: self._novo_passo("ingrediente")),
                        ("− passo", self._apagar_passo), ("↑", lambda: self._mover_passo(-1)), ("↓", lambda: self._mover_passo(1))):
            b = W.QPushButton(txt)
            b.clicked.connect(fn)
            h.addWidget(b)
        v.addLayout(h)
        h = W.QHBoxLayout()
        b = W.QPushButton("Voltar ao arquivo")
        b.clicked.connect(lambda: self._receita_escolhida(self.combo.currentIndex()))
        h.addWidget(b)
        b = W.QPushButton("Salvar passos na receita")
        b.clicked.connect(self.salvar_passos)
        h.addWidget(b)
        v.addLayout(h)
        return w

    def _carregar_receitas(self):
        self.combo.blockSignals(True)
        self.combo.clear()
        self.combo.addItems(sorted(self.dados.receitas))
        self.combo.blockSignals(False)
        self._receita_escolhida(0)

    def _receita_escolhida(self, i):
        chave = self.combo.itemText(i)
        if chave not in self.dados.receitas:
            return
        self.rc = copy.deepcopy(self.dados.receitas[chave])
        self._mostrar_passos()
        self.rodar()

    def _mostrar_passos(self):
        self.passos.blockSignals(True)
        self.passos.setRowCount(len(self.rc["passos"]))
        for r, p in enumerate(self.rc["passos"]):
            ing = p["tipo"] == "ingrediente"
            vals = [p["tipo"], "", str(p.get("qtd", "")) if ing else "", ("%g" % p.get("seg", 0)) if ing else ""]
            for c, txt in enumerate(vals):
                it = W.QTableWidgetItem(txt)
                if c in (0, 1) or (not ing and c >= 2):
                    it.setFlags(it.flags() & ~QtCore.Qt.ItemIsEditable)
                if not ing and c in (0, 2, 3):
                    self._pintar_chama(it, p.get("estado", ""))
                self.passos.setItem(r, c, it)
            self.passos.setCellWidget(r, 1, self._combo_passo(r, p))
        self.passos.blockSignals(False)
        self.passos.resizeColumnToContents(0)
        self.passos.setColumnWidth(1, max(self.passos.columnWidth(1), 150))
        self._encher_ct()

    def _combo_passo(self, r, p):
        """Escolher a chama (com a cor dela) ou o item, sem digitar."""
        c = W.QComboBox()
        if p["tipo"] == "chama":
            for e in self.sim.ESTADOS:
                c.addItem(e["nome"], e["id"])
                q = _cor(e["cor"])
                q.setAlpha(255)
                c.setItemData(c.count() - 1, q, QtCore.Qt.BackgroundRole)
                c.setItemData(c.count() - 1, QtGui.QColor("black" if q.lightness() > 140 else "white"), QtCore.Qt.ForegroundRole)
            i = c.findData(p.get("estado", ""))
            c.setCurrentIndex(max(0, i))
            self._estilo_combo(c, p.get("estado", ""))
        else:
            for iid in sorted(self.dados.itens):
                c.addItem(self.dados.itens[iid]["nome"], iid)
            c.setCurrentIndex(max(0, c.findData(p.get("item", ""))))
        c.currentIndexChanged.connect(lambda _i, r=r, c=c: self._combo_mudou(r, c))
        return c

    def _estilo_combo(self, c, estado):
        e = self.sim.ESTADO.get(estado)
        if e:
            q = _cor(e["cor"])
            q.setAlpha(255)
            c.setStyleSheet("QComboBox { background: %s; color: %s; }" % (q.name(), "black" if q.lightness() > 140 else "white"))

    def _combo_mudou(self, r, c):
        p = self.rc["passos"][r]
        p["estado" if p["tipo"] == "chama" else "item"] = c.currentData()
        # refaz a tabela depois de sair do sinal (o combo que avisou é trocado)
        QtCore.QTimer.singleShot(0, lambda: (self._mostrar_passos(), self.rodar()))

    def _pintar_chama(self, it, estado):
        e = self.sim.ESTADO.get(estado)
        if not e:
            return
        cor = _cor(e["cor"])
        cor.setAlpha(255)
        it.setBackground(cor)
        it.setForeground(QtGui.QColor("black" if cor.lightness() > 140 else "white"))
        it.setToolTip("%s: caldo %.0f a %.0f °C" % (e["nome"], e["T_min"], e["T_max"]))

    def _passo_mudou(self, it):
        p = self.rc["passos"][it.row()]
        txt = it.text().strip()
        try:
            if it.column() == 2:
                p["qtd"] = max(1, int(float(txt)))
            elif it.column() == 3:
                p["seg"] = max(0.0, float(txt.replace(",", ".")))
        except ValueError:
            pass
        self._mostrar_passos()
        self.rodar()

    def _novo_passo(self, tipo):
        r = self.passos.currentRow() + 1 if self.passos.currentRow() >= 0 else len(self.rc["passos"])
        p = {"tipo": "chama", "estado": "normal"} if tipo == "chama" else {"tipo": "ingrediente", "item": sorted(self.dados.itens)[0], "qtd": 1, "seg": 10.0}
        self.rc["passos"].insert(r, p)
        self._mostrar_passos()
        self.passos.setCurrentCell(r, 1)
        self.rodar()

    def _apagar_passo(self):
        r = self.passos.currentRow()
        if 0 <= r < len(self.rc["passos"]):
            del self.rc["passos"][r]
            self._mostrar_passos()
            self.rodar()

    def _mover_passo(self, d):
        r = self.passos.currentRow()
        ps = self.rc["passos"]
        if 0 <= r < len(ps) and 0 <= r + d < len(ps):
            ps[r], ps[r + d] = ps[r + d], ps[r]
            self._mostrar_passos()
            self.passos.setCurrentCell(r + d, 1)
            self.rodar()

    def salvar_passos(self):
        arq = self.rc.get("arquivo")
        if not arq:
            return
        t = ts.ler(arq)
        linha = "passos_livro = Array[Dictionary]([%s])" % ", ".join(
            "{" + ", ".join('"%s": %s' % (k, json.dumps(v, ensure_ascii=False) if not isinstance(v, float) else ("%g" % v if v != int(v) else "%d.0" % v))
                            for k, v in p.items()) + "}" for p in self.rc["passos"])
        if not re.search(r"^passos_livro = ", t, re.M):
            W.QMessageBox.warning(self, "Não achei", "A receita não tem passos_livro no .tres.")
            return
        t = re.sub(r"^passos_livro = .*$", lambda m: linha, t, count=1, flags=re.M)
        ts.escrever(arq, t)
        self.dados.recarregar()
        self.status.setText("passos salvos em %s" % arq)

    # ================================================================ resultado
    def _lado_resultado(self):
        self.abas = W.QTabWidget()
        # Resultado
        w = W.QWidget()
        v = W.QVBoxLayout(w)
        topo = W.QHBoxLayout()
        self.resumo = W.QLabel(wordWrap=True)
        self.resumo.setTextFormat(QtCore.Qt.RichText)
        topo.addWidget(self.resumo, 1)
        self.matriz = MatrizGrade(editavel=False, largura=70)
        topo.addWidget(self.matriz)
        v.addLayout(topo)
        self.ingr = W.QTableWidget(0, 9)
        self.ingr.setHorizontalHeaderLabels(["item", "entrou (s)", "tempo (s)", "Q", "T máx", "a total", "a cozimento", "a temperatura", "a tempo"])
        self.ingr.verticalHeader().setVisible(False)
        self.ingr.setEditTriggers(W.QAbstractItemView.NoEditTriggers)
        v.addWidget(self.ingr, 1)
        self.grafico = GraficoLinhas()
        v.addWidget(self.grafico, 2)
        self.abas.addTab(w, "Resultado")
        # Monte Carlo
        w = W.QWidget()
        v = W.QVBoxLayout(w)
        self.mc_txt = W.QLabel("Monte Carlo: muitas jogadas com a jogadora calibrada (erros de tempo e de leitura da chama).", wordWrap=True)
        v.addWidget(self.mc_txt)
        self.hist = Histograma()
        v.addWidget(self.hist, 1)
        self.abas.addTab(w, "Monte Carlo")
        # Testes e dificuldade
        self.txt_testes = W.QPlainTextEdit(readOnly=True)
        self.txt_testes.setFont(QtGui.QFont("Consolas", 10))
        self.abas.addTab(self.txt_testes, "Testes")
        self.dif = W.QTableWidget(0, 6)
        self.dif.setHorizontalHeaderLabels(["receita", "nota", "chance", "critério", "janelas de tempo", "chamas que servem"])
        self.dif.verticalHeader().setVisible(False)
        self.dif.setEditTriggers(W.QAbstractItemView.NoEditTriggers)
        self.abas.addTab(self.dif, "Dificuldade")
        w = W.QWidget()
        v = W.QVBoxLayout(w)
        h = W.QHBoxLayout()
        b = W.QPushButton("Calcular")
        b.clicked.connect(self.chamas)
        h.addWidget(b)
        h.addWidget(W.QLabel("aproveitamento médio da poção trocando a chama de UM passo (o resto como na receita, jogadora perfeita)"), 1)
        v.addLayout(h)
        self.tab_chamas = W.QTableWidget(0, 0)
        self.tab_chamas.setEditTriggers(W.QAbstractItemView.NoEditTriggers)
        v.addWidget(self.tab_chamas, 1)
        self.abas.addTab(w, "Chamas")
        # chama × tempo
        w = W.QWidget()
        v = W.QVBoxLayout(w)
        h = W.QHBoxLayout()
        h.addWidget(W.QLabel("Ingrediente:"))
        self.ct_passo = W.QComboBox()
        self.ct_passo.setMinimumWidth(220)
        h.addWidget(self.ct_passo)
        b = W.QPushButton("Calcular")
        b.clicked.connect(self.chama_tempo)
        h.addWidget(b)
        h.addWidget(W.QLabel("x = segundos desse passo · uma linha por cor da chama pedida antes dele (jogadora perfeita)"), 1)
        v.addLayout(h)
        self.g_ct_pocao, self.g_ct_ing = GraficoLinhas(), GraficoLinhas()
        v.addWidget(self.g_ct_pocao, 1)
        v.addWidget(self.g_ct_ing, 1)
        self.abas.addTab(w, "Chama × tempo")
        return self.abas

    def _ocupado(self, fn):
        W.QApplication.setOverrideCursor(QtCore.Qt.WaitCursor)
        try:
            return fn()
        except Exception as e:  # noqa: BLE001
            self.status.setText("erro: %s" % e)
        finally:
            W.QApplication.restoreOverrideCursor()

    def rodar(self, *_):
        if not self.rc:
            return
        self.semente.setEnabled(self.jog.currentIndex() > 0)
        jog = self.jogadora(self.semente.value())
        r = self._ocupado(lambda: self.sim.simular(self.rc, self.dados.itens, jog, self.dados.catalogo))
        if not r:
            return
        nome, porque = self.bal.nome_como_jogo(self.dados, r)
        perto = self.bal.proximas(self.dados, r["A"], 3)
        cor_a = VERDE.name() if r["a"] >= 0.95 else ("#f2c14e" if r["a"] >= 0.8 else VERMELHO.name())
        self.resumo.setText(
            "<h3>%s</h3><i>%s</i><br>aproveitamento médio <b style='color:%s'>%.1f%%</b> · pior ingrediente %.1f%% · %s<br>"
            "duração %.1f s<br><br><b>Mais perto no catálogo</b><br>%s<br><br><b>O que a matriz faz</b><br>%s" % (
                nome, porque, cor_a, 100 * r["a"], 100 * r["a_min_item"],
                "<b style='color:%s'>ganha o efeito</b>" % VERDE.name() if r.get("efeito") else "sem efeito extra",
                r["t_final"],
                "<br>".join("%s: dist. %.3f (tol. %.3f) %s" % (n, d, t, "✔" if d <= t else "") for n, d, t in perto),
                "; ".join(ts.descrever_matriz(r["A"]))))
        self.matriz.definir(r["A"])
        self.ingr.setRowCount(len(r["diags"]))
        for k, d in enumerate(r["diags"]):
            vals = [d["item"], "%.1f" % d["t0"], "%.1f" % d["dur"], "%.0f" % d["Q"], "%.0f" % d["T_max"],
                    d["a"], d["a_Q"], d["a_Tmax"] * d["a_Tmin"], d["a_tmin"] * d["a_tmax"]]
            for c, v in enumerate(vals):
                it = W.QTableWidgetItem(("%.0f%%" % (100 * v)) if isinstance(v, float) else str(v))
                if isinstance(v, float):
                    it.setTextAlignment(QtCore.Qt.AlignRight | QtCore.Qt.AlignVCenter)
                    if v < 0.95:
                        q = QtGui.QColor(VERMELHO)
                        q.setAlpha(int(40 + 160 * min(1, (0.95 - v) / 0.5)))
                        it.setBackground(q)
                self.ingr.setItem(k, c, it)
        self.ingr.resizeColumnsToContents()
        hist = r.get("hist", [])
        faixas = [(max(e["T_min"], 0), min(e["T_max"], 260), _cor(e["cor"])) for e in self.sim.ESTADOS if "cor" in e]
        marcas, vistos = [], set()
        for t0, iid in r.get("entradas", []):
            chave = (round(t0), iid)
            if chave not in vistos:
                vistos.add(chave)
                marcas.append((t0, self.dados.itens[iid]["nome"] if iid in self.dados.itens else iid))
        self.grafico.definir([([(h[0], h[1]) for h in hist], QtGui.QColor("#e8eaed"), "caldo"),
                              ([(h[0], min(h[2], 260)) for h in hist], QtGui.QColor("#ff8a3d"), "fogo")],
                             faixas, marcas[:12], "°C  (branco = caldo, laranja = fogo)")
        self.status.setText("rodado: %s" % self.rc["chave"])

    def _params_jogadora(self):
        return JOGADORA_RUIM if self.jog.currentIndex() == 2 else self.params

    def jogadora(self, seed):
        if self.jog.currentIndex() == 0:
            return self.sim.Jogadora()
        return self.bal.jogadora(self._params_jogadora(), seed=seed)

    def monte(self):
        if not self.rc:
            return
        params = self._params_jogadora() if self.jog.currentIndex() > 0 else self.params
        res = self._ocupado(lambda: self.bal.monte_carlo(self.dados, self.rc, params, self.n_mc.value()))
        if not res:
            return
        a = [r["a"] for r in res]
        ok = sum(1 for x in a if x >= 0.95) / len(a)
        ef = sum(1 for r in res if r.get("efeito")) / len(res)
        self.hist.definir(a)
        self.mc_txt.setText(("jogadora ruim · " if self.jog.currentIndex() == 2 else "jogadora calibrada · ") + "%d jogadas · média %.1f%% · chegam a 95%%: %.0f%% · ganham o efeito: %.0f%%" % (
            len(a), 100 * sum(a) / len(a), 100 * ok, 100 * ef))
        self.abas.setCurrentIndex(1)

    def testes(self):
        res = self._ocupado(lambda: self.bal.testes(self.dados, self.params))
        if res is None:
            return
        marca = {"ok": "  ok   ", "aviso": "  AVISO", "falha": "  FALHA"}
        falhas = sum(1 for n, _ in res if n == "falha")
        self.txt_testes.setPlainText("\n".join("%s %s" % (marca.get(n, n), t) for n, t in res)
                                     + "\n\n%d falha(s), %d aviso(s)" % (falhas, sum(1 for n, _ in res if n == "aviso")))
        self.abas.setCurrentIndex(2)

    def dificuldade(self):
        def fazer():
            return [self.bal.dificuldade(self.dados, rc, self.params) for rc in self.dados.receitas.values()]
        res = self._ocupado(fazer)
        if not res:
            return
        self.dif.setRowCount(len(res))
        for k, d in enumerate(res):
            vals = [d["receita"], "%d (%s)" % (d["nota"], d["nota_txt"]), "%.0f%%" % (100 * d["chance"]), d["criterio"],
                    ", ".join("passo %d: %.1fs" % (p, s) for p, s in d["janelas"].items()),
                    "; ".join("passo %d: %s" % (p, ", ".join(c) or "nenhuma") for p, c in d["chamas"].items())]
            for c, v in enumerate(vals):
                self.dif.setItem(k, c, W.QTableWidgetItem(str(v)))
        self.dif.resizeColumnsToContents()
        self.abas.setCurrentIndex(3)

    def chamas(self):
        if not self.rc:
            return
        passos = [k for k, p in enumerate(self.rc["passos"]) if p["tipo"] == "chama"]
        estados = [e for e in self.sim.ESTADOS if e["id"] not in ("apagado",)]

        def fazer():
            out = {}
            for k in passos:
                for e in estados:
                    r = self.sim.simular(self.rc, self.dados.itens, self.sim.Jogadora(chama={k: e["id"]}), self.dados.catalogo, guardar_hist=False)
                    out[(k, e["id"])] = (r["a"], r.get("perto"), r.get("efeito"))
            return out
        res = self._ocupado(fazer)
        if res is None:
            return
        t = self.tab_chamas
        t.setColumnCount(len(passos))
        t.setRowCount(len(estados))
        t.setHorizontalHeaderLabels(["passo %d (receita: %s)" % (k + 1, self.rc["passos"][k].get("estado", "")) for k in passos])
        for r, e in enumerate(estados):
            cab = W.QTableWidgetItem(e["nome"])
            self._pintar_chama(cab, e["id"])
            t.setVerticalHeaderItem(r, cab)
            for c, k in enumerate(passos):
                a, perto, efeito = res[(k, e["id"])]
                it = W.QTableWidgetItem("%.1f%%%s%s" % (100 * a, "  ✔nome" if perto else "", "  ★" if efeito else ""))
                it.setTextAlignment(QtCore.Qt.AlignCenter)
                q = QtGui.QColor(VERDE if a >= 0.95 else ("#f2c14e" if a >= 0.8 else VERMELHO))
                q.setAlpha(int(60 + 150 * (a if a >= 0.95 else (1 - a))))
                it.setBackground(q)
                if self.rc["passos"][k].get("estado") == e["id"]:
                    f = it.font()
                    f.setBold(True)
                    it.setFont(f)
                    it.setToolTip("chama da receita")
                t.setItem(r, c, it)
        t.resizeColumnsToContents()
        self.abas.setCurrentIndex(4)

    def _passos_ingrediente(self):
        return [k for k, p in enumerate(self.rc["passos"]) if p["tipo"] == "ingrediente"] if self.rc else []

    def _encher_ct(self):
        if not hasattr(self, "ct_passo"):
            return
        i = self.ct_passo.currentIndex()
        self.ct_passo.blockSignals(True)
        self.ct_passo.clear()
        for k in self._passos_ingrediente():
            p = self.rc["passos"][k]
            nome = self.dados.itens.get(p.get("item", ""), {}).get("nome", p.get("item", ""))
            self.ct_passo.addItem("passo %d: %s ×%s (%gs)" % (k + 1, nome, p.get("qtd", 1), p.get("seg", 0)), k)
        self.ct_passo.setCurrentIndex(max(0, min(i, self.ct_passo.count() - 1)))
        self.ct_passo.blockSignals(False)

    def chama_tempo(self):
        ki = self.ct_passo.currentData()
        if not self.rc or ki is None:
            return
        passos = self.rc["passos"]
        kc = max((k for k in range(ki) if passos[k]["tipo"] == "chama"), default=None)
        seg0 = float(passos[ki].get("seg", 0))
        lim = max(2 * seg0, 60.0)
        segs = [lim * j / 24 for j in range(25)]
        # posição dos itens desse passo na lista de entradas
        ini = sum(int(passos[k].get("qtd", 1)) for k in range(ki) if passos[k]["tipo"] == "ingrediente")
        n = int(passos[ki].get("qtd", 1))
        estados = chm.estados(self.sim) if kc is not None else [self.sim.ESTADO.get("normal") or self.sim.ESTADOS[0]]

        def fazer():
            out = {}
            rc = copy.deepcopy(self.rc)
            for e in estados:
                jog_ch = {kc: e["id"]} if kc is not None else {}
                lp, li = [], []
                for sg in segs:
                    rc["passos"][ki]["seg"] = sg
                    r = self.sim.simular(rc, self.dados.itens, self.sim.Jogadora(chama=jog_ch), None, guardar_hist=False)
                    lp.append((sg, r["a"]))
                    ds = r["diags"][ini:ini + n]
                    li.append((sg, sum(d["a"] for d in ds) / len(ds) if ds else 0.0))
                out[e["id"]] = (lp, li)
            return out
        res = self._ocupado(fazer)
        if res is None:
            return
        sp, si = [], []
        for e in estados:
            lp, li = res[e["id"]]
            if max(a for _, a in lp) < 0.001 and max(a for _, a in li) < 0.001:
                continue
            nome = e["nome"] + (" (receita)" if kc is not None and passos[kc].get("estado") == e["id"] else "")
            sp.append((lp, chm.cor(self.sim, e["id"]), nome))
            si.append((li, chm.cor(self.sim, e["id"]), nome))
        marca = [(seg0, "receita")]
        cab = "chama do passo %d" % (kc + 1) if kc is not None else "sem passo de chama antes"
        self.g_ct_pocao.definir(sp, marcas=marca, faixa_y=(0, 1), titulo_y="poção (média de todos os itens) · " + cab)
        self.g_ct_ing.definir(si, marcas=marca, faixa_y=(0, 1), titulo_y="só os itens do passo %d" % (ki + 1))
        self.abas.setCurrentIndex(5)

    def recarregar(self):
        self.dados.recarregar()
        self.params = self.bal.ler_calibracao()
        self._opcoes()
        self._carregar_receitas()


def criar(raiz):
    return Aba(raiz)
