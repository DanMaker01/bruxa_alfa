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
||	[?] Conferir		||
||	[!] Finalizado		||
  ==============================
```

## Terminar logo (0)

```
[ ] Caldeirão:
[?]	Se segurar o botão de fogo quero que retire const_A a cada 0.3seg ao invés de desligar o fogo. Como não há como desligar mais o fogo, caso a temperatura do fogo fique abaixo de F_LIMIT_MIN ele faz um efeito e apaga.
		Feito: segurar com o fogo aceso abafa (−CONST_A a cada 0,3 s); F < F_LIMIT_MIN (600, em sistema_termico) → fumaça e apaga. Apagado: segurar 1 s acende.
		Calibrar: CONST_A, F_LIMIT_MIN, de resto ok.
[?]	receita1 testar replicabilidade (depende dos atributos dos itens)
[ ]	balancear, pq usar a poção como ingrediente deve ser dificil, sensível. e deve ser cosistente a depender dos ingredientes.
[?] 	Caldeirão não deve tremer quando está com problemas na poção. Ele deve tremever levemente quando está com temperatura em 100 graus. e acima disso ele deve ir ficando avermelhado.
		Feito (visual_caldeirao): treme de 95 °C (0 px) → 100 °C (1,5 px) → 200 °C (3,5 px); acima de 100 °C avermelha até 200 °C. Perda de aproveitamento não treme mais (só o caldo turvo).
		Calibrar: T_TREMOR_INICIO, TREMOR_LEVE_PX, TREMOR_MAX_PX, T_VERMELHO_MAX, VERMELHO_MAX.


[ ] Cena de poção preparada:
[?]	Layout deve ser: uma janela com fundo escuro e leve transparencia. A poção surge no meio. Uma mensagem de texto é mostrada (identificação da poção, depois vamos verificar se ela ficou parecida suficiente com alguma poção que tem nome. Senão, pode dar nome. Mas é uma mecânica futura. Depois do texto a imagem da poção deve transladar para a esquerda e no espaço que ficou à direita deve aparecem os parametros dessa poção criada. Depois dos parametros, ao clicar em qualquer lugar a janela dá fade e fecha. 
[.]	Indicador da matriz: pentágono O-C-E-A-N (personalidade neutra antes/depois, com ↑/↓ %) + grade 5x5 pequena (dourado aumenta, vermelho diminui)
[?]	Nome da poção: se a matriz ficar perto (distância de Frobenius <= distancia_max) de uma poção do catálogo (dados/pocoes/catalogo_pocoes.tres) ou de uma já nomeada pelo jogador (user://pocoes_nomeadas.tres), recebe o mesmo nome; senão o jogador dá um nome, que fica registrado. Se a poção só foi de 1 item, ela recebe o nome Poção de [nome item] [adjetivo], onde adjetivo diz sobre a qualidade dela.
		Corrigido: Adjetivos (aproveitamento médio): ≥95% Concentrada, ≥80% Refinada, ≥60% (sem adjetivo), ≥40% Rala, ≥20% Aguada, abaixo Estragada (CalculadoraPocao.ADJETIVOS_QUALIDADE).
[?]	Não mostrar mais o cozimento, tempo ideal e Temp ideal de poções criadas. Só quero o pentagrama e a matriz.
[ ]	Nomear as poções de referência no catálogo (PocaoReferencia: nome, descrição, A)

[ ]UI - notificação está estranha, tenho que ver se ela fica com uma fução mais bem definida, com multiplas notificações ou senão só tiro as notificações.

[ ] História / missão: (em ordem)
[ ]	Diálogos devem condizer com a época
[ ]	Cada personagem tem seu linguajar próprio e manias.
[?]	Camponês bate na porta (TOC! TOC! TOC!), opção Deixar entrar / Ignorar. Ele pede ajuda para a irmã que vai casar → Poção da Calma Lúcida. Guardas ainda não deixam passar.
[ ]		Corrigir fala: "E uma folha que posso , onde as árvores acabam." (bruxa_in_auto / bruxa_in_passagem). ("depoisé" já corrigido)
				A Bruxa diz que o cogumelo cresce "onde a floresta acaba", mas ele está na estradaA.
[.]		fazer área de spawn de evento no fim da floresta, outro na estradaA. Fazer farm com qtd na tela. (3 cogu, 3 erva) 
				Hoje: 1 cogumelo (estradaA) + 1 erva (floresta), coleta única por variável. Fazer o spawn de eventos, nas páginas vai ter uma também uma nova condição de self-variable, valores 0 e 1; e no interprete quero um comando de ativar/desativar self-variable de um evento.
[?]		A bruxa diz quais & qtos itens tem que pegar e libera controle na primeira missão.
[ ]		com ingredientes na mão, interagir com o caldeirão, ela explica como usar a 1ª vez.
				Evento bruxa_in_caldeirao ainda é só "caldeirão (em construção)".
[ ]		após criar, vem cena NPC, basta ir no castelo, guardas deixam passar agora.
				ponte_guarda e estradaB_guarda só bloqueiam, sem condição.
[ ]		finalização, entrega poção e resultados possíveis.
				castelo_in só tem a passagem.


[ ] Bugs que atrapalham a missão:
[?]	Se segurar o botão de fogo quero que retire const_A a cada 0.3seg ao invés de desligar o fogo. Como não há como desligar mais o fogo, caso a temperatura do fogo fique abaixo de F_LIMIT_MIN ele faz um efeito e apaga.
		Feito: segurar com o fogo aceso abafa (−CONST_A a cada 0,3 s); F < F_LIMIT_MIN (600, em sistema_termico) → fumaça e apaga. Apagado: segurar 1 s acende.
[?]	Variáveis só número (sem booleano; use 0 e 1). var02 do banco virou 1.0
[?]	Página com várias condições (todas precisam valer): variável, item, personalidade, posição, direção
[?]	Página reavalia ao ganhar/perder item e ao mudar personalidade
[?]	Notificação de item nunca aparece (NotificacaoItem sem Label em main.tscn)
		Label já existe; agora o painel começa escondido e uma notificação nova não é mais apagada pelo timer da anterior.
[?]	Segurar o botão de poção para sair agora é 0,7 s (TEMPO_LONGO)
```

## Terminar até o Cap. 1 (1)

```


[.] Itens:
[?]		Matriz A aceita poucas casas decimais no Inspector, ainda está arredondando para 2 casas. quero no mínimo 5. Por enquanto tenho que editar diretamente o .tras
				Passo do Inspector agora é 0.00001 (item_data.gd). Conferir no editor.


[ ] Intro:
[ ]		Melhorar texto: reduzir? etc...
[ ]		Melhorar representação do texto subindo.

[.] Interprete:
[?]	    comando if para verificar, além de variaveis; itens ou personalidade (GameTemp)
				Feito: Condicao.tipo = variável, item, personalidade, posição X/Y da bruxa, direção da bruxa (vale p/ if, while e páginas)
[?]     comando mudar direção player (CmdDirecaoPlayer: esq, dir, inverter, para evento)
[?]	    comando mover player (CmdMoverPlayer: para X, para evento, deslocar; esperar; direção final)
[?]     comando deixar evento passavel ou ativar/desativar colisão do player (CmdEventoPassavel)
[?]			colisão do player: CmdPlayerPassavel
[?]     comando mudar direção evento (CmdDirecaoEvento: centro, esq, dir, inverter, para o player; diferente de trocar animação)



[ ]	Caldeirão:
[ ]		Ajustes mínimos: cor, shake, efeitos, aparar para a versão final.
[ ]		Tutorial(leve) na primeira vez.

[ ] Mapa:
[ ]     Spawn de itens: existem as áreas de spawn, que invocam um tipo de evento, limitados por qtd de invocações no mapa.  
[.]         Remover todos eventos placeholders de item dos mapas
				Removidos os 6 cogumelos de teste (teste_magia) de bruxa_out e castelo_out. Fica só o da história (estradaA). teste_magia.tres sem uso.
[ ]         Adicionar o floresta_erva oficial
[ ]         Adicionar o bosque_cogumelo oficial
[.]     Resolver problema de área de colisão, verificar cada evento, posição, etc.
[ ]		Quando chego perto de uma borda o paralax age parando bruscamente, quero que ele não fique limitado à tela, talvez tenho que mudar o tamanho dos cenários?
[.]		Padronizar parallaxes em cada mapa: ...,Fundo2,Fundo,Meio,Frente,Frente2... (meio é onde ficam os eventos também)
[ ]		Testar loop de bgm, loop de bgs.
[ ]		cada mapa tocando BGM da fase em loop. (verificar mapa_base)
[ ]		SE nos teleport
[?]		Tela preta das passagens mais curta: "esperar" depois do teleporte baixado de 0.4 para 0.2


[ ]	HUD/inventário:
[ ]     Separar o Inventário do HUD. O HUD deve fazer o esquema de carta que vira ao clicar em um de seus componentes (inventário ou status), pensar como vai ser a dinâmica da carta girando, ativação, desativação, etc. Um clique em cima para mostrar, e se ficar alguns segundos sem interação ele desvira.
[ ]		Animar o inventário e o status como um card que gira/abre ou algo assim. 
[ ]		Fazer uma animação de carta virando para os diálogos, opções, inventário e status. 



[ ]	Arte Visual
[ ]     como fazer imagem ficar fazendo pan infinito? usar nas núvens
[ ]     Fazer sprite:
[ ]         mapa floresta de 6000px (talvez diminua), com paralax, provisório.
[ ]         inventário e status de costas (card que gira)


[ ]	Audio:
[ ]     Fazer músicas: 
[ ]         intro, 
[ ]         casa bruxa, 
[?]         floresta, 
[ ]         estradas, 
[ ]			ponte (ouvir ost: ragnarok, pokemon, nobuo uematsu)
[ ]         castelo, 
[ ]         ...

[ ]	Animações:
[ ]		

[ ] Estilo:
[ ] 	organizar o layout e textura dialogo/opções
[ ]		Ajuste estético, borda, cor, fonte, etc.
[ ]		Criação de estilos padronizados para cada coisa. (?) tipo estilo texto, estilo menu, ...?
[ ]


[ ]	Estudar se vale:
[ ]		- Não precisa mais ser CharacterBody2D?. (problema de falta de collision shape foi resolvido para os eventos, agora usa o da página)
[ ]		- Definir posição dos eventos no mapa, tudo por código


[ ]	Status: ()
[ ]		popup do nome da característica quando hover ou click. ou algo legal.
[ ]		Animação de aparição. (como se virasse uma carta, etc) 


[ ]	Menu Principal e Pausa
[ ]	Save/Load
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

## Game Design Document

[_gdd/v1.3.11/main.pdf](https://github.com/DanMaker01/bruxa-v-0.1/blob/main/_gdd/v1.3.11/main.pdf)
