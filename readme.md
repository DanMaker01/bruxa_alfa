# Jogo da Bruxa

<table>
<tr><td>Engine</td><td>Godot 4</td></tr>
<tr><td>Plataforma</td><td>Android</td></tr>
<tr><td>Resolução</td><td>640 × 960 px</td></tr>
<tr><td>Gênero</td><td>Point & Click</td></tr>
<tr><td>Estilo</td><td>2D Side-scroller</td></tr>
<tr><td>Gameplay</td><td>Exploração + Crafting</td></tr>
<tr><td>Idioma</td><td>Português</td></tr>
</table>

```
Floresta    -   BruxaOut    -   BruxaIn
Bosque
Bosque
CidadeA     -   in01    -   in02    -   in03
EstradaA
Ponte
Castelo     -   in
EstradaB
```

![1788646480585](image/readme/1788646480585.png)![1788646486876](image/readme/1788646486876.png)

## Coisas a fazer

```
  ==============================
||		LEGENDA:	||
||	[ ] A fazer		||
||	[.] Em progresso	||
||	[?] Testar		||
||	[!] Finalizado		||
  ==============================
```

## Terminar logo (0)

```

[.] v3
[] mapa:
	[.] bruxa_out, mais camadas[frente,meio,fundo], animais[sapo,borboleta], etc.
[?] Parallax revisado (fundo 0.2, meio 1.0, frente 1.1; mapa_base acha os limites pela camada "Meio"):
		bosque: Fundo (chão) virou Meio 1.0; Meio (árvores na frente) virou Frente 1.1.
		bruxa_out: Fundo 0.2; casa foi para Meio; Frente2 removida.
		castelo_in03: Fundo 0.2, Frente 1.1. castelo_out: Fundo 0.2, Frente2 virou Frente 1.1.
		cidadeA, estradaA, estradaB: Fundo 0.2.
		ponte: Fundo4 céu (z -20), Fundo3 nuvens longe (z -15, pan -6), Fundo2 montanha (z -10), Fundo nuvens (z -5, pan -12) todos 0.2; Meio/Meio2/Meio3 penhasco e ponte 1.0; Frente nuvens perto (z 10, fator 1.1, pan -40, alto da tela).
		Interiores (bruxa_in, castelo_in01/02, cidadeA_in01-03): a camada "Frente+" tem a moldura escura *_fundo.png na frente: 0.9 (era 0.8).
	3 pouco efeito: "Era só isso? Água colorida?" → "Você zombou de mim e da minha filha, bruxa?!" → fuga.
	4 piorou: "Você piorou tudo!" → fuga.
	5 estereotipada: igual antes → fuga.
	A fuga (guardas chamados, fade, castelo_in02) virou o evento fuga_castelo.tres, chamado pelos três.
	Condições trocadas de "== 5" para ">= 3": castelo_in02_auto, castelo_in03_auto, guardas da ponte e da estradaB, última página do rei e da princesa (as páginas de 3 e 4 ficaram sem uso).
	1 e 2 continuam sem fuga (1 convite; 2 "Veremos no casamento. Saia.").
[?]Câmera nas bordas (simplificado):
	Câmera: usa os limites nativos do Camera2D (limit_left/right do mapa_base) + position_smoothing (4) + limit_smoothed. Saiu a borda suave própria (_x_suave, BORDA_SUAVE, troca de limites).
	Parallax: mapa_base.gd (seção PARALLAX NA BORDA) faz toda camada com fator ≠ 1 continuar andando quando a câmera para na borda, como se ainda seguisse a bruxa. Fator 1 (Meio, Eventos) para junto. Automático em todos os mapas.
	A camada nunca mostra a ponta da imagem: o deslocamento é limitado ao tamanho dela (camadas com loop não têm limite). Buracos na borda direita corrigidos esticando a imagem da Frente: castelo_in03 scale x 1.051, bosque 1.056 → 1.07. Ponte Fundo2 sem o scroll_offset 1. Regra: imagem de camada sem loop precisa ter largura ≥ 640 + fator × (largura do mapa − 640).
	Mover câmera (comando) agora parte de onde a tela está e para no limite, sem "tempo morto" no começo do pan.
	CamadaParallax: saiu continuar_na_borda/suavidade (agora é automático).
	PROBLEMA:Ainda tem algum efeito com a camera nas bordas, até no mapa_intro acontece da câmera começar no lugar errado e se acertar rapidinho. Vamos deixar sem efeito nenhum e ir avançando para entender o problema.
		Feito: desligado. camera_2d.gd SUAVIZAR = false (sem position_smoothing nem limit_smoothed: segue seco, para seco na borda, entra no mapa já no lugar). mapa_base.gd PARALLAX_NA_BORDA = false (camadas param junto). Para religar, trocar para true.

[ ] História / missão: (em ordem)
	[ ]	Verificação de diálogos e de todos os caminhos possíveis do Cap. 1 (resultados 1 a 5, com e sem poção no bolso, voltar à ponte/estradaB depois da fuga, véu pego ou não).
```

## Terminar até o Cap. 1 (1)

```

[ ] BETA / DEMO:
[ ]		Caldeirão 100%
[ ]		Diálogos 100%
[ ]		Sprites 100%
[ ]		Audio 100%
[ ]		Menus 100%

[] 2ª receita:  - desenvoltura
	Ajustado: musgo t_max 12 → 35 (aguenta os ~30 s finais); flor m 2400 → 5000, s−/s+ 900/1400 → 1900/2900 (Q de 60 s a ~85 °C ≈ 5100). Juntos dão diag(1,1,1.4,1,1) se o musgo entra depois.
	balanceat tempo, u,s-,s+, Tmin,Tmax,tmin,tmax, etc de cada item. infusao


[.]Database (nomes das proibidas ficam para o Cap. 2): Nomear as poções de referência no catálogo (PocaoReferencia: nome, descrição, A). Poção da Calma Profunda. Poção #2. Poções proíbidas. 
	Poção #2 = Poção da Desenvoltura (definir bem antes do Cap. 1; só usada no Cap. X).
	Poções proibidas: as que têm algum autovalor 0 (2^5 − 1 = 31 combinações de traços zerados). Ainda sem nome. (feito: 31 no catálogo como "Poção Proibida (sem O, C...)", nomes provisórios)
	Poção de Pó de Retorno Concentrada no catálogo, com efeito (teleporte para bruxa_in). Pó: diag(0.97,1,1,1,1.03), cozimento leniente (m 3000, T 60–170, t 10–150, folgas 0,4/0,6).
	Nome: poção de um item só agora usa "Poção de [item] [qualidade]" antes de procurar no catálogo (senão um pó mal cozido virava "Concentrada").


[ ] Bugs/Revisão:
[ ]		Tutorial do caldeirão na 1ª vez.
[ ]		Fazer faces tbm terem seu .tres
[ ]		Variações no flip card. (depois) Sorteadas: normal = 1 flip diagonal; variações no mesmo tempo: 5 flips com velocidade decrescente; flip mudando a dimensão horizontal, com 1 ou 5 flips.


[ ]	Representação de poções visual com matriz/grafo. (feito, versão simples: no pentágono cada ponta sai do traço que mais contribui e gira até a sua; diagonal = só escala com um pulo)
[ ]		(Cap. 2) Mostrar o pentagrama, cada aresta representa um componente. Pensei em relacionar as arestas com a_ij e criar um feedback útil visualmente.
[x] 	Na hora da aplicar a poção, inventário, resultado do preparo, sempre mostra o pentagrama e a matriz.
[ ]		(Cap. 2) O pentagrama deve ter animações a depender da matriz. Por exemplo, matriz diagonal (ou próxima de diagonal a menos de ruído) só escala, então a animação do pentagram é escalar. Matriz que troca dois componentes deve trocar duas pontas do pentagrama suavemente, como uma permutação ou rotação.


[ ]	Escrita/Estilo:
[ ]		Diálogos devem condizer com a época
[ ]		Cada personagem tem seu linguajar próprio e manias.

[ ]	Cena Livro de Receitas: (DEPOIS DO CAP. 1)
[ ]		Ao criar uma poção nova a bruxa tem opção de anotar a receita no livro. Caso escolha anotar: Abre a cena do livro de receitas já anotando.
[ ]		Iniciar o livro de receitas, cena com janela que inicia após uma nova receita. A cena de livro abre e é escrita uma nova receita.
[ ]		Pensar no Layout
[ ]		Uma receita por página, 2 páginas por folha, mostra o livro aberto e tem opção de controlar com clique ou arrastando, é redundante para melhor UX.
[ ]		Ao clicar numa página mostra seus ingredientes e tempo relacionado com seu gráfico, seu resultado.
[ ]		Fazer tudo bem animado e temático de bruxaria.


[.] Itens:
[?]		Matriz A aceita poucas casas decimais no Inspector, ainda está arredondando para 2 casas. quero no mínimo 5. Por enquanto tenho que editar diretamente o .tras
				Passo do Inspector agora é 0.00001 (item_data.gd). Conferir no editor.



[ ]	Caldeirão:
[.]		Labaredas (faíscas laranja subindo) ao abanar o fogo.
[ ]		Tutorial(leve) na primeira vez. (DEPOIS DO CAP. 1)

[ ] Mapa:
[.]         Remover todos eventos placeholders de item dos mapas
				Removidos os 6 cogumelos de teste (teste_magia) de bruxa_out e castelo_out. Fica só o da história (estradaA). teste_magia.tres sem uso.
[.]     Resolver problema de área de colisão, verificar cada evento, posição, etc.
[?]		Quando chego perto de uma borda o paralax age parando bruscamente, quero que ele não fique limitado à tela, talvez tenho que mudar o tamanho dos cenários? (câmera com borda suave; CamadaParallax na ponte)
[.]		Padronizar parallaxes em cada mapa: ...,Fundo2,Fundo,Meio,Frente,Frente2... (meio é onde ficam os eventos também)
[?]		Testar loop de bgm, loop de bgs. (floresta.mp3 já está com loop=true no import)
[?]		cada mapa tocando BGM da fase em loop. (verificar mapa_base)
			Feito: mapa_base tem bgm/bgm_volume no Inspector. Mesmo bgm = continua; outro = troca; vazio = para. Só a floresta tem bgm (floresta.mp3).
[ ]		SE nos teleport (depois: som de passos na transição)
[?]		Tela preta das passagens mais curta: "esperar" depois do teleporte baixado de 0.4 para 0.2
[ ]	Verificar todos os parallaxes (valores, direção, bordas).

[.]	HUD/inventário:
		Feito (1ª versão): src/ui/carta.gd + hud.tscn refeito. Duas cartas: CartaInventario (Verso/Inventario/Dialogo) e CartaStatus (Verso/Status/Opcoes).
		Toque no verso abre; 4 s sem tocar na carta (nem popup do item aberto) desvira. Independentes. Fechada ocupa o mesmo espaço.
		Diálogo/opções: DialogBox e OptionBox vão para dentro das cartas (face de prioridade); a carta vira sozinha e volta para onde estava.
		mostrar_hud/sumir_hud: ativa/desativa as cartas (inativas somem, mas aparecem no diálogo).
		Virada na diagonal (angulo_diagonal 45°), sem pulinho. Conteúdo vai para um Node2D "Giro" no _ready: use carta.face("Nome").
		Margens (hud.gd): MARGEM_CARTA = 14 entre a carta e a caixa preta (painel do diálogo, botões das opções e avançar, todos iguais); MARGEM_CONTEUDO = 20 entre a caixa preta e o texto.
		Foto e nome do falante ficam fora da carta (CanvasLayer): não giram, fade só quando mudam.
		Ajustar: tempo_aberta, tempo_virar, angulo_diagonal (Inspector da carta).
		Verso provisório: pentagrama desenhado (src/ui/pentagrama_verso.gd, gira devagar; cor/espessura/raio/giro no Inspector). Trocar pela arte quando existir.



[ ]     Fazer sprite:
[ ]         inventário e status de costas (card que gira)


[ ] Audio:
[ ]     Fazer músicas: 
[ ]         intro, 
[ ]         casa bruxa, 
[?]         floresta, 
[ ]         estradas, 
[ ]			ponte (ouvir ost: ragnarok, pokemon, nobuo uematsu)
[ ]         castelo, 
[ ]         ...
[ ]	Fazer sons:
[ ]		Teleport entre mapas
[ ]		Flip card
[ ]		Efeitos (...)

[ ]	Animações:
[ ]


[ ] Estilo:
[ ] 	organizar o layout e textura dialogo/opções
[ ]		Ajuste estético, borda, cor, fonte, etc.
[ ]		Criação de estilos padronizados para cada coisa. (?) tipo estilo texto, estilo menu, ...?
[ ]


[ ]	Estudar se vale:
[ ]		- Definir posição dos eventos no mapa, tudo por código


[ ]	Menu Principal e Pausa (DEPOIS DO CAP. 1)
[ ]	Save/Load (DEPOIS: muita coisa ainda pode mudar)
[ ]		Game_Temp deve ter save e load de arquivo_unico de titulo "save"+time_stamp
[ ]		GameTemp, posição player, mapa
[?]	Animações do player e eventos melhor organizada e testes.

[ ]	Core:
[ ]		Modularizar evento_base (ainda precisa?)
[ ]   Melhorias estruturais no sistema.
```

## Terminar até o Cap. 2 (2)

```
[ ] Sistema de clima
[ ]	Sistema de mercado/valor dinâmico
[ ]	Sistema de fama
[ ]	Sistema de compra/venda
```
