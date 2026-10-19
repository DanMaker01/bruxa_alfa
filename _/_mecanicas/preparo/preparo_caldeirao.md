# Cena de Preparo de Poções

## Layout

```
            640
.___________________________
|              *            |
|     °    __          °    |
|       .  ||    .    .     |
|          ||°    *         |
|      .-==||==°====-.      |
|    .-'\_~~~~__;___/'-.    |
|   /                   \   |
|  |                     |  | 576
|  |                     |  |
|   \                   /   |
|    '.               .'    |
|      `-^^ _^^__^^.-'      |
|        ^^ ^^ ^^ ^^        |
|                           |
|___________________________|
|  _______________________  |
| |      __    /---\      | |
| |_    /  \__/     \_   /| | 224
| | \__/              \_/ | |
| |_______________________| |
|  __    ___________    __  |
| |()|  |  |  |  |  |  |^^| | 160
| |__|  |__|__|__|__|  |__| |
|___________________________|

 20%         60%        20%

 128         384        128
```

- Animação caldeirão
- Gráfico T(t)
- Botão ()
- Inventário
- Botão ^^

---

## Uso

Caldeirão e Fogo têm uma animação ou efeito para cada jogada.

### ^^ Botão de Fogo

| # | Estado                   | Ação                    | Comportamento | Efeito Visual               |
| :-: | ------------------------ | ------------------------- | ------------- | --------------------------- |
| 1 | **Fogo Desligado** | **Apertar** (curto) | Nada          | Faísca única              |
| 2 | **Fogo Desligado** | **Segurar** (longo) | Liga fogo     | Faíscas contínuas → Fogo |
| 3 | **Fogo Ligado**    | **Apertar** (curto) | Atiça fogo   | Chama aumenta               |
| 4 | **Fogo Ligado**    | **Segurar** (longo) | Desliga fogo  | Chama diminui até apagar   |

### () Botão de Poção

| # | Estado             | Ação                    | Comportamento    | Efeito Visual         |
| :-: | ------------------ | ------------------------- | ---------------- | --------------------- |
| 5 | **Sem Item** | **Apertar** (curto) | Sair do Preparo  | Botão Sair           |
| 6 | **Sem Item** | **Segurar** (longo) | Sair do Preparo  | Botão Sair           |
| 7 | **Com Item** | **Apertar** (curto) | Finaliza preparo | Animação de preparo |
| 8 | **Com Item** | **Segurar** (longo) | **???**    | ???                   |

---

## Modelagem

### Variáveis

```
T: Temperatura do caldeirão
F: Temperatura do fogo
k: Condutividade térmica (fogo ↔ caldeirão)
h: Perda de calor do caldeirão para o ambiente
hF: Perda de calor do fogo para o ambiente
C: Capacidade térmica do caldeirão
C_F: Capacidade térmica do fogo
P_comb: Potência de combustão (fonte de calor do fogo)
T_amb: Temperatura padrão do ambiente
F_eq: Temperatura de equilíbrio do fogo
T_eq: Temperatura de equilíbrio do caldeirão
const_a: Acréscimo de temperatura ao atiçar o fogo
const_b: Decréscimo de temperatura ao adicionar ingrediente
```

---

### Sistema de EDOs

```
dT/dt (t) = (k · (F - T) - h · (T - T_amb)) / C

dF/dt (t) = (-k · (F - T) - hF · (F - T_amb) + P_comb) / C_F   [para o fogo ligado]
```

Onde:

- `k · (F - T)` é a transferência de calor do fogo → caldeirão
- `h · (T - T_amb)` é a perda de calor do caldeirão → ambiente
- `hF · (F - T_amb)` é a perda de calor do fogo → ambiente
- `P_comb` é a potência de combustão (fonte de calor)
- `C` e `C_F` são as capacidades térmicas (inércia)

---

### Parâmetros

```
T_amb = 20
F_eq  = 800
T_eq  = 100

k     = 1
hF    = 0.01
C     = 2
C_F   = 2

h     = k · (F_eq - T_eq) / (T_eq - T_amb)       [calculado]
P_comb = k · (F_eq - T_eq) + hF · (F_eq - T_amb) [calculado]

const_a = 70    (atiçar fogo: F += 70)
const_b = 10    (adicionar ingrediente: T -= 10)
```

---

## Preparo

O preparo se dá ao colocar os itens em ordem e controlar a temperatura T(t), para o melhor aproveitamento de cada item.

### Item:

Para preparar a poção são colocados itens no caldeirão ao longo do tempo.  Cada item tem sua forma:

$I = (A,I_T,I_t,N(m,s))$

e seu tempo $t_0$, quando foi adicionado ao caldeirão. Então uma ingrediente adicionado é da forma $J=(t_0, I)$.

Onde:

- A pertence à $M_5(R)$
- $I_T = [Tmin,Tmax]$
- $I_t = [tmin,tmax]$
- $N(m,s)$ é a distribuição normal. (depois considerar a e torção) ***

### Cálculo da Poção após o Preparo:

O resultado do preparo também é um item $I=(A,I_T, I_t, N(m,s))$. E cada componente do item é gerado da seguinte forma:

A é a matriz de propriedades:

$$
A = [a_1 A_1 + (1-a_1)I] \cdot \ldots \cdot [a_n A_n + (1-a_n)I]
$$

$$
B_i = a_i A_i + (1-a_i) I
$$

$$
A = \prod B_i
$$

Onde:

- $A_i$: Matriz do ingrediente $i$
- $B_i$: é a interpolação entre o ingredente $i$ e o ingrediente neutro (matriz identidade).
- $a_i$: Aproveitamento do ingrediente $i$ ($a_i \in [0, 1]$)
- $I$: Matriz identidade

I_T é calculado por: ...................combinação linear? aleatório baseado nos ingredientes? aumentar máximo, diminuir min?

I_t é calculado por: ................... (idem)

N(m,s) .................................. combinação linear? são 2 parametros

Obs:

```
A poção deve multiplicar cada componente por um valor entre $[0.8, 1.2]$.
Fora desse intervalo têm um poder muito intenso.
Seria possível duplicar um atributo com só 2 ingredientes, ou cortar na metade.
```

### Aproveitamento do Item

Num dado ingrediente $i$, o aproveitamento $a$ é calculado pela fórmula:

$$
a = a_Q \cdot a_{T_{max}} \cdot a_{T_{min}} \cdot a_{t_{min}} \cdot a_{t_{max}}
$$

Onde:

$$
a_{(\ldots)} = f(x)
$$

---

#### Aproveitamento de cozimento $a_Q$

O aproveitamento é dado pela Normal (normal com torção): *** (finalizar)

$$
a_Q = f(Q)
$$

$$
f(x) = 1 - \frac{2}{\sqrt{2\pi}} e^{-\frac{x^2}{2}} \cdot \left[ \int_{-\infty}^{\alpha x} \frac{1}{\sqrt{2\pi}} e^{-\frac{u^2}{2}} \, du \right]
$$

#### Aproveitamento `Tmax` (temperatura máxima)

O aproveitamento é máximo quando a temperatura máxima atingida não ultrapassa a temperatura máxima ideal. Ao ultrapassar o ideal, o aproveitamento diminui gradualmente.

$$
a_{T_{max}} = f(\hat{T}_{max}) =
\begin{cases}
1 & \text{se } \hat{T}_{max} \leq T_{max} \\[6pt]
\dfrac{1}{1 + e^{R(\hat{T}_{max}-x_m)}} & \text{c.c.}
\end{cases}
$$

Onde:

* $\hat{T}_{max}$ = temperatura máxima atingida durante o processo
* $T_{max}$ = temperatura máxima ideal do ingrediente
* $x_m$ = temperatura em que o aproveitamento é 50%
* $R$ = rigidez da queda

Os parâmetros podem ser definidos a partir de dois pontos desejados $(T_0,p_0)$ e $(T_f,p_f)$:

$$
R =
\frac{
\ln\left(\frac{1-p_0}{p_0}\right)
+
\ln\left(\frac{p_f}{1-p_f}\right)
}{
T_f-T_0
}
$$

$$
x_m =
T_0-\frac{1}{R}
\ln\left(\frac{1-p_0}{p_0}\right)
$$

##### Aproveitamento `Tmin` (temperatura mínima)

(análogo)

#### Aproveitamento `tmin` (tempo mínimo)

(análogo)

#### Aproveitamento `tmax` (tempo máximo)

(análogo)

## Aplicação da Poção

Ao aplicar uma poção numa personalidade, o resultado preserva sua característica mais forte, enquanto as outras diminuem proporcionalmente.

$$
x \rightarrow Ax \rightarrow \frac{Ax}{|Ax|}
$$

Onde:

- $x$: vetor personalidade
- $A$: matriz da poção
- $|x|$: norma infinito
