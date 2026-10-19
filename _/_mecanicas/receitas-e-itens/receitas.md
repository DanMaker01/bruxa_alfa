# Receitas

## Arroz cozido

| T (°C) | t_i (s) | Nome   |
| ------: | ----: | ------ |
|     180 |    10 | Cebola |
|     180 |    10 | Alho   |
|     180 |    10 | Óleo  |
|     100 |    25 | Arroz  |
|     100 |    25 | Água  |

## Poção do amor

| T   | t_i  | Nome |
| --- | -- | ---- |
| 100 | 20 |      |

# Tabela de ingredientes

| Δt (s) | Nome   | t_min (s) | t_max (s) | T_min (°C) | T_max (°C) | Cozimento (Q) | Precisão (S) |
| ------: | ------ | --------: | --------: | ----------: | ----------: | ------------: | ------------: |
|      41 | Cebola |         0 |        50 |           0 |         180 |          4300 |          1000 |
|      40 | Alho   |         5 |        40 |           0 |         180 |          2800 |             ? |
|      43 | Óleo  |         0 |       100 |           0 |         200 |          4000 |             ? |
|      27 | Arroz  |        20 |        40 |           0 |         110 |          3000 |               |
|      26 | Água  |         0 |      9999 |           0 |         200 |          3000 |         10000 |
|      10 | Cogumelo Brilhante  |        1 |      30 |           110 |         200 |       3000 |         10000 |

# Manual de Poções

- Controle a temperatura
- Coloque os ingredientes
- Deixe o tempo certo

## Aproveitamento e Punições

O aproveitamento diz quanto dos atributos do ingrediente será passado para a poção.
O aproveitamento do ingrediente é calculado com base no tempo de cozimento e temperatura

Uma punição pode ter duas formas, gaussiana:

$$
f(x)= e^{-\frac{1}{2 \sigma ²} (x-\mu)²}
$$

Ou discreta:
												$f(x) = 1$, se $x \in [m,M]$
												$f(x)=0$, caso contrário

## Precisão (nas Punições Gaussianas)

Se $\mu = 4300$ então:

Com $\sigma=1000$ e $T=100$ temos:

| tempo (s)  | Q    | a     |
| ---------- | ---- | ----- |
| 38         | 3800 | 0,882 |
| 39         | 3900 | 0,923 |
| 40         | 4000 | 0,956 |
| 41         | 4100 | 0,980 |
| 42         | 4200 | 0,995 |
| 43 (ideal) | 4300 | 1,000 |
| 44         | 4400 | 0,995 |

Com $\sigma=1000$ e $T=180$ temos:

| tempo (s)  | Q    | a     |
| ---------- | ---- | ----- |
| 21         | 3780 | 0,874 |
| 22         | 3960 | 0,944 |
| 23         | 4140 | 0,987 |
| 24 (ideal) | 4320 | 0,999 |
| 25         | 4500 | 0,980 |
