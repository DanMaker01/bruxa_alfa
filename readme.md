# Jogo da Bruxa

![1793375384971](image/readme/1793375384971.png)

![1793377160839](image/readme/1793377160839.png)

![1793375398241](image/readme/1793375398241.png)

MAPA: https://miro.com/app/board/uXjVHHRQsyM=/

# Coisas a fazer

```
  ==============================
||		LEGENDA:	||
||	[ ] A fazer		||
||	[.] Em progresso	||
||	[?] Testar		||
||	[!] Finalizado		||
  ==============================
```

## Terminar até o Cap. 1 (1)

```

[ ] Arte Visual 100% 	(arquivos .png estão na pasta /assets/)

	[ ] Faces	(422x908 hoje, porém a parte de baixo fica escondida atrás da caixa de diálogo. pode mudar para 420x740 ou outro tamanho)
		[ ] Bruxa
			[ ] neutro
			[ ] pensando
		[ ] Rei
			[ ] neutro
			[ ] furioso
		[ ] Princesa
			[ ] neutro
		[ ] Guarda1
		[ ] Guarda2
		[ ] NPC1 - Criança
			[ ] neutro
		[ ] NPC2 - Criança
			[ ] neutro
		[ ] NPC3 - Adulto
			[ ] neutro
		[ ] Goblin
			[ ] neutro
		[ ] Padre
			[ ] neutro

	[ ] Sprites		(tamanhos variados) (a âncora do sprite é o CENTRO-INFERIOR) (pode mudar as larg/alt se quiser)
		[ ] Bruxa
			[ ] parada		(80x252)
			[ ] andando		(126x252)
			[ ] correndo	(126x252)
		[ ] Rei				(105x200)
		[ ] Princesa		(105x200)
		[ ] Guarda1			(105x200)
			[ ] parado
			[ ] andando
		[ ] Guarda2			(105x200)
			[ ] parado
			[ ] andando
		[ ] NPC1 - Criança	(105x145)
			[ ] parado
			[ ] andando
		[ ] NPC2 - Criança	(105x145)
			[ ] parado
			[ ] andando
		[ ] NPC3 - Adulto	(105x200)
			[ ] parado
		[ ] Mercador pai	(105x200)
			[ ] parado
		[ ] Mercador filho	(105x200)
			[ ] parado
		[ ] Padre			(105x200)
			[ ] parado
		[ ] Portas
			[ ] porta padrão (90x180)
			[ ] porta bruxa
			[ ] portão castelo
		[ ] Objetos
			[ ] Livro de Receitas (69x69)
			[ ] ...

	[ ] Cenários		(largura variada, altura: 640px)
		[ ] floresta		(6000x640)
		[ ] bruxa_in		(1280x640)
		[ ] bruxa_out1		(1280x640)
		[ ] bruxa_out2		(1280x640)
		[ ] bruxa_out3		(1280x640)
		[ ] bosque			(2000x640)
		[ ] cidade			(4000x640)
		[ ] cidade_in01		(1280x640)
		[ ] cidade_in02		(1280x640)
		[ ] cidade_in03		(2000x640)
		[ ] estrada_a		(2000x640)
		[ ] ponte			(2000x640)
		[ ] castelo			(3000x640)
		[ ] castelo_in01	(2500x640)
		[ ] castelo_in02	(1280x640)
		[ ] castelo_in03	(1280x640)
		[ ] estrada_b		(2000x640)

[ ]	Audio 100%
	[ ] BGM:
		[ ] intro 			(xxxHolic opening)
		[ ] floresta		(remix da que já tem)
		[ ] bruxa_out
			[ ] bruxa_out1	(só BGS de natureza)
			[ ] bruxa_out2	(só BGS de natureza) (variação)
			[ ] bruxa_out3	(só BGS de natureza) (variação2)
		[ ] bruxa_in 		(sem bgm, talvez bgs)
		[ ] bosque			(mágico, bem curto)
		[ ] cidade, _in01, _in02 (+ harpa, - volume, +palmas)
		[ ] cidade_in03
		[ ] estrada_a
		[ ] ponte
		[ ] castelo
		[ ] castelo_in01, castelo_in02
		[ ] castelo_in03
		[ ] estrada_b
		[ ] menu inicial
		[ ] ???
	[ ] BGS:
		[ ] sapos (bruxa_out1)
		[ ] tremor
		[ ] passaros
		[ ] som floresta
		[ ] vento
		[ ] água correndo
		[ ] (metal?)
	[ ] SE:
		[ ] magia01
		[ ] magia02 
		[ ] magia03
		[ ] pancada01
		[ ] pancada02
		[ ] corte
		[ ] vidro01
		[ ] vidro02

[ ]	Menus 100%
	[ ] Estilo de cartas
		[ ] definir carta para cada clicável. o que falta?
	[.] menu inicial
		[ ] bg
    [?] hud, falta algo? rever.
		Revisado: o popup do item fecha sozinho quando chega um diálogo ou o HUD some; o Desistir (aplicar poção) some enquanto o popup está aberto e ganhou o estilo dos botões das opções; vibração ao tocar num item, abrir a carta, nos botões do popup, no Desistir e nos ícones do Status; fonte do inventário igual à do diálogo (28, branca); limpeza de código sem uso e prints.

[ ] Caldeirão 100%
	[?] Fogo frio: 3 cores de 400 a 800 (transparente 400, azul pálido 600, normal vermelho 800; no livro "Transparente grande" virou "Azul pálido"). Aceso fica opaco (alfa 0,8); só abaixo de 400 (apagando) vai sumindo até F = 0. (sistema_termico.gd CORES_FOGO)
		Definir melhor: as cores infra. as cores ultra 400° já estão um pouco melhores. Por exemplo, não gostei que tem outro tom de azul na chama fraca, pois já tem azul sendo usado. talvez rosa seria melhor. 
	[ ] Layout
		[ ] Reformular Layout (pensar em celular). 
			[?] Layout escolhido: Caldeirão grande (caldeirão 1,2×, itens menores, controles na faixa de baixo). As outras alternativas e a tecla L foram removidas. Valores em LayoutPreparo.LAYOUT.
			REMOVER: estilo de layout lateral
			Tamanhos: Menus, botões, Bruxa_chibi, caldeirão 
		[?] texto em cima do caldeirão -> passar para falas da bruxa, feedback rápido da bruxa? multi balões?
			Feito: os textos do caldeirão (fogo aceso/apagou, item se perdeu, já misturou, tirei, item no ponto, avisos de nível) viraram falas no balão da bruxinha. Avisos importantes entram na fila (até 3); os rápidos só aparecem se ela estiver calada. Os textos flutuantes ficaram só para as teclas de debug.
		[ ] Dúvida: Usar cartas tbm na cena do caldeirão, para botões, etc? testar como ficaria. 
			Carta comprida é meio estranho. O que usar então? Mudança de layout afeta?
	[ ] Feedback audiovisual pra temperatura do caldeirão e tbm dos itens, tanto frio quanto quente
		[?] TESTE de P e C:
			P = anel completo, faixa vermelho -> ...
				testei com a erva: quando o anel finaliza ele ainda está verde e fica no caldeirão ainda um bom tempo antes de sumir. 
				acho que a erva está com tempo e cozimento maior que o máximo do anel. 
			C = o anel já é colorido, mas vai sendo revelado.

	[ ] Catálogo e poções
		[?] Catálogo de poções (dados/pocoes): qualquer poção com a matriz perto de uma do catálogo recebe o nome dela e, se ela tiver, o efeito (com aproveitamento >= aproveitamento_min_efeito; evita 4 mal cozidos = 3 bem cozidos). Sem quantidades nem "Dobrada" (não serve para receitas não comutativas).
			[?] Tolerância por poção (PocaoReferencia.distancia_max; 0 = a do catálogo, 0,05). Retorno: 0,02 → 2 ou 4 pós bem cozidos não viram mais Poção do Retorno nem ganham o efeito (simulador: experimento quantidade). 
			[ ] PROBLEMA a tratar: quantidades diferentes podem chegar na mesma matriz (ex.: 4 mal cozidos ≈ 3 bem cozidos). Hoje só o aproveitamento mínimo segura. Já é o suficiente, mas tem algo mais geral?

[ ] Livro de Receitas:
	[ ] Cena do Livro:
		[?] Livro fechado (capa ou verso): arrastar para qualquer lado sai da cena; tocar na capa abre, tocar fora sai.
		[ ] Pensar em fazer um auto-cozinhar seguindo uma receita?... (pensar)
		[?] no tutorial, na hora do rascunho não deve estar escuriceido, só quando aparecer a indicação no botão. (feito: enquanto ela escreve, sem escuro)
	[ ] Receitas:
		[ ] Balanceamento de Receitas:
			[.] Criar mais receitas:
				Receita que é muito rápida , 
				receita que é muito demorada. 
				Receita muito quente, com fogo negro. 
				Receita muito fria, quase desligando. 
			[ ] Perguntas: 
				[ ] Dois pontos de cozimento diferentes para o mesmo item podem gerar poções diferentes? 
				[ ] Faz sentido uma receita que leva o mesmo ingrediente 2x em tempos diferentes? I_tempo, I_Temper, Q, como conseguir aprovetar duas vezes um mesmo tipo de item numa mesma receita?
				[ ] E se eu dobrar a poção? Testar com as não comutativas: Fazer receita dobrada tem efeito de potencializar (escalar) a matriz resultante. por exemplo se fizer uma poção da calma profunda dobrada, 
				[ ] dificuldade, medir peso de cada erro: tempo, temp, cozimento, 
				[ ] explorar os TIPOS de matrizes. explorar o que é posível nesse sistema térmico
		[.] Ver tipos de poções e dar nomes: 
			Database (nomes das proibidas ficam para o Cap. 2): 
				Nomear as poções de referência no catálogo (PocaoReferencia: nome, descrição, A). 
				Poção da Calma Profunda. Poção #2. Poções proíbidas. 
				Poção #2 = Poção da Desenvoltura (definir bem antes do Cap. 1; só usada no Cap. X).
				Poções proibidas: as que têm algum autovalor 0 (2^5 − 1 = 31 combinações de traços zerados). Ainda sem nome. (feito: 31 no catálogo como "Poção Proibida (sem O, C...)", nomes provisórios)
		[?] Nome: poção de um item só agora usa "Poção de [item] [qualidade]" antes de procurar no catálogo (senão um pó mal cozido virava "Concentrada").


[ ] Diálogos 100%
	[ ] Intro : revisar texto (tempo e ritmo). ultimas frases da intro estão pequenas em comparação.
		[?] Feito (sem mudar o texto): as duas últimas frases ("No segundo..." e "No terceiro...") viraram uma legenda só, em dois parágrafos, como as outras.
		[?] Pausas da pontuação dobradas de novo: "." 28, "…" 16, "!" 14, "?" 7, ";" e ":" 6 (em letras). Vírgula sem pausa.
	[ ] Cap. 1: Revisão de cada evento.
	[ ] Sprites do  Balão de expressão: precisa da arte (1 sprite de balão, se der pra fazer sem deformar as quinas seria ideal) (talvez 9 blocos)
	[ ] Estilo visual:
		[ ] organizar o layout e textura dialogo/opções
		[ ]	Ajuste estético, borda, cor, fonte, etc.
		[?]	Criação de estilos padronizados para cada coisa. 
			Feito (1ª etapa, visual igual): src/ui/estilo.gd (Estilo) com tamanhos de fonte, cores e caixas (caixa_preta, caixa_menu, caixa_popup, caixa_nome, caixa_balao, botao_preto). Já usam: diálogo, opções, HUD, popup do item, Status, menus (painel, principal), legenda, destaque do tutorial e balão da bruxinha. Faltam: livro e caldeirão (cena_livro, detalhe/editor de receita, janela de resultado, painel da panela). Debug fica de fora.
        	[ ] estilo de texto
        	[ ] estilo de janela, paleta de cores, animação coerente, etc...
		[?] Efeito escuro do diálogo tbm deve esperar se o próximo evento é diálogo, para não ficar alternando a transparência toda hora (feito: se vem outra fala ou pergunta logo depois, a tela escura fica; some se não vier em 1,5 s)
		[?] e a face em mostrar opções e a face em mostrar diálogo tbm deve se manter, se ela for aparecer novamente em breve. (feito: foto e nome esperam até 1,5 s se vem outra fala/pergunta)

[ ] História/Roteiro
	[ ]	Diálogos devem condizer com a época
		[ ] Cap. 1 (-N)
			[?] intro-Campones
			[.] Guardas
			[ ] Bosque NPC
			[.] Cidade 
			[.] Castelo
		[ ] Cap. 2
        	[ ] Qual traço? 
            [ ] Qual quest?
	>>> Usar traços na história: 
		O,(conservador com pouca abertura)
		C (consequencialidade, prudencia, preguiçoso),
		A (amabilidade, aumentar ou diminuir?)
	[ ] Usar permutação de traços em alguma quest, receita, mas que seja visto esse efeito.
	[ ] Poções proibidas numa quest


[ ] Quests
	[ ] Quest Zigmund
		[ ] personalidade
		[ ] situação
			[ ] problema
			[ ] objetivo
			[ ] plano
			[!] sumiu na floresta
			[!] pediu para a bruxa ajudar a princesa
			[!] casamento
	[ ] Quest Bosque Goblin
		[ ] ???
	[ ] Cap. 1 Casamento
		[ ] cidadeA_in01 não tem quest?
	[.] Mercador
		[ ] Inventário de cada, personalidade de cada?
		[ ] Comprar e Vender? 
			[ ] 2 inventários e você pode trocar/negociar?


[ ] Personagens
	[ ] Fazer uma ficha de personagem 
	[ ] Criar personalidades big five
	[ ] Cada personagem tem seu linguajar próprio e manias.
		[ ] Bruxa
		[ ] Campones
		[ ] Guarda1
		[ ] Guarda2
		[ ] bosque_npc
		[ ] Cidade
			[ ] NPC Adulto
			[ ] NPC Criança 1 
			[ ] NPC Criança 2
			[ ] Casa 1
				[ ] NPC 
			[ ] Casa 2
				[ ] Mercador Pai
				[ ] Mercador Filho
			[ ] Igreja
				[ ] Padre


[ ] Documentação e Organização
	[ ] organização da pasta Graphics(está sendo chamada de assets neste projeto) estilo rpgmaker:
		Animations (efeitos especiais, magias, etc)
		Characters (eventos)
		Icons
		Panoramas (imagens para cenário)
		Pictures (sprites para controlar na tela)
		Transitions
		Windowskins (janelas, etc)
	[ ] Debug e ferramentas
		[?] Debug, aba Poções: histograma do aproveitamento de cada poção feita (user://estatisticas_pocoes.txt; só em build de debug), zerar, e botões para dar qualquer poção do catálogo pronta (★ = tem efeito).
		[?] Jogadas gravadas (só em build de debug): user://jogadas/<data>.json com histórico T/F, entradas, ações (+Fogo, −Fogo, acender, jogar), receita memorizada e aproveitamento. Usadas pela ferramenta de balanceamento.
	[ ] GDD
		[!] v1
		[!] v2
		[!] v3.3
    
	>>> Referência (já feito, fica para consulta):
		Simulador do caldeirão (ferramentas/simulador_caldeirao.py, Python 3; gráficos com matplotlib): mesmas contas do jogo, lidas dos .gd/.tres. Experimentos: receitas, rodar, tempo, chama, mapa, monte (Monte Carlo), janelas, quantidade, otimizar, relatorio. Saída em ferramentas/sim_saida/. Ex.: python ferramentas/simulador_caldeirao.py tempo retorno
		Ferramenta de balanceamento (ferramentas/balanceamento.py; PySide6 + matplotlib; usa o simulador): abas Receita (editar passos, rodar, comparar com a anterior), Sensibilidade, Monte Carlo, Itens (mexer nos parâmetros ao vivo e salvar no .tres), Testes, Dificuldade (nota 1 a 5) e Jogadas reais (reavaliar e calibrar a jogadora simulada; grava ferramentas/calibracao.json). Linha de comando: --testes, --dificuldade, --calibrar [pasta].
			Aba Receita: escolher receita ou "(receita nova)", mudar chama, item, quantidade e segundos, + chama / + ingrediente / remover / subir / descer, rodar sozinho a cada mudança. Mostra o nome que o jogo daria (água, catálogo, um item só, parecida com ingrediente, desconhecida) e o porquê, o efeito, a diagonal da matriz e as 3 poções mais perto (distância / tolerância). Simulador: receita que termina num passo de chama finaliza quando a chama chega nele.
		Editor de eventos em Python (_/editor_eventos, abrir com abrir_editor.bat; precisa de PySide6): páginas, condições, comandos, diálogo em texto (Ctrl+T), labels (F12), várias páginas/eventos de uma vez, buscar/substituir, desfazer, backup ao salvar. Ver _/editor_eventos/README.md.
		Parallax e câmera nas bordas: na borda a câmera para e todas as camadas param junto (fatores: fundo 0.2, meio 1.0, frente 1.1, interiores "Frente+" 0.9).
		Regra das imagens (para não aparecer cinza): camada sem loop precisa de largura ≥ 640 + fator × (largura do mapa − 640). Ex.: Frente 1.1 em mapa de 6000 px = 6536 px (ou scale x 1.09). Mapas maiores não são necessários.
		Por camada: bosque (Meio chão 1.0, Frente árvores 1.1, scale 1.07); bruxa_out (Fundo 0.2, casa no Meio); castelo_in03 (Fundo 0.2, Frente 1.1, scale 1.051); castelo_out (Fundo 0.2, Frente 1.1); cidadeA, estradaA, estradaB (Fundo 0.2); ponte (Fundo4 céu, Fundo3 nuvens longe pan -6, Fundo2 montanha, Fundo nuvens pan -12, todos 0.2; Meio/Meio2/Meio3 1.0; Frente nuvens 1.1 pan -40).


[ ] Decisões menores:
	[ ] (fazer depois) Personalidade do alvo na hora de aplicar a poção.
	[ ] (fazer depois) A ação da poção deve mostrar a personalidade mudando.
		Ideia: um pequeno menu com a face da pessoa e a personalidade dela mudando; a personalidade fica na carta Status. Layout ainda a definir.
	[ ] (fazer depois) Logo: diminuir o caldeirão e deixar mono tom, sem efeitos.
	[ ] Representação de poções visual com matriz/grafo. (feito, versão simples: no pentágono cada ponta sai do traço que mais contribui e gira até a sua; diagonal = só escala com um pulo)
		[ ] (Cap. 2) Mostrar o pentagrama, cada aresta representa um componente. Pensei em relacionar as arestas com a_ij e criar um feedback útil visualmente.
		[ ] (Cap. 2) O pentagrama deve ter animações a depender da matriz. Por exemplo, matriz diagonal (ou próxima de diagonal a menos de ruído) só escala, então a animação do pentagram é escalar. Matriz que troca dois componentes deve trocar duas pontas do pentagrama suavemente, como uma permutação ou rotação.

[ ] Bugs/Revisão:
	[ ] missao01_convite é gravada e nunca lida: fica para o Cap. 2 (convite do casamento).
```

## Ideias guardadas: traços e próximas poções

```
Ideia geral: o jeito de cozinhar o ingrediente imita o traço que ele mexe.
Matriz: O C E A N. "×1,12" = o traço sobe 12%. "E ← +0,08·N" = 8% do N passa a somar no E.

C (disciplina, ordem, dever)
	Pouco C querendo subir: filho do mercador, guarda que dorme, Zigmund que largou as obrigações.
		Poção da Disciplina (C ×1,2). Ingredientes demorados e de faixa estreita (paciência e precisão).
	Muito C querendo baixar: noivo perfeccionista que adia o casamento, padre preso às regras.
		Poção do Desapego (C ×0,8). Ingredientes rápidos e de fogo forte (impulso).
	Troca: C ← N (a ansiedade vira cuidado).
A (confiança, gentileza, cooperação)
	Subir: rei furioso, guarda grosso, goblin. Poção da Brandura (A ×1,15). Ingredientes frios e delicados.
	Baixar: quem não sabe dizer não (princesa? mercador que dá fiado). Poção da Firmeza (A ×0,85). Chama negra.
	Dilema: baixar a amabilidade de alguém é ajudar ou estragar? ("tudo tem seu preço")
O (curiosidade, imaginação, aceitar o novo; o traço mais ligado ao véu e à inquisição)
	Pouco O (velho cabeça fechada): mercador pai, padre. Poção da Visão (O ×1,2): enxerga o véu ou aceita o
		diferente; em 1484, aberto demais vira suspeito de heresia. Ingredientes estranhos, com troca de
		traços; receitas fora do padrão (chama fria e depois quente, mesmo item em dois tempos).
	Baixar O: quem viu demais através do véu, criança que vê fantasmas, ou a inquisição pedindo para
		"curar" a magia. Poção do Esquecimento (O ×0,8). Ingredientes comuns, cozimento longo e monótono.
N e E (o outro lado)
	Subir N: poção de medo (afastar a inquisição, guarda nervoso larga o posto). Primeira poção "ofensiva".
	Baixar E: bobo da corte, alguém que fala demais da bruxa. Poção do silêncio.
Matriz: diagonal pura = poções simples (começo); com troca = avançadas (transformam um traço em outro);
	proibidas (traço vai a zero) = o que a inquisição acha que a bruxa faz.
Sequência possível: Cap. 2 C alto (Zigmund/guarda) e A alto (rei); Cap. 3 O alto (mercador pai/padre,
	risco de heresia); depois A baixo, O baixo, N alto, E baixo, com escolhas morais.

Itens possíveis (receitas: rápida, demorada de faixa estreita, chama negra, fria)
	Rápida (fogo forte, poucos segundos):
		Pimenta-de-dragão: E ×1,12, A ×0,97, N ×1,05 (agitação, ousadia). Branco, 4 a 8 s.
		Faísca-de-vagalume: O ×1,10, C ×0,95 (curiosidade, impulso). Amarelo ou branco, 3 a 6 s.
		Pétala-de-relâmpago: E ← +0,08·N, N ×0,92 (nervosismo vira energia). Branco, 5 a 9 s.
	Demorada (faixa estreita, não dá para acelerar com fogo alto):
		Raiz-de-teixo: C ×1,15, O ×0,95 (prudência, tradição). Só normal (95 a 105 °C), 100 a 160 s.
		Casca-de-carvalho-velho: A ×1,12, N ×0,90 (paciência, serenidade). Só laranja, 90 a 140 s.
		Âmbar-de-resina: C ← +0,06·N, N ×0,94 (ansiedade vira cuidado). Só normal, 120 a 180 s.
	Muito quente (chama negra, 195 °C ou mais; precisa F perto de 1730, testar se não cansa):
		Escama-de-salamandra: E ×1,20, A ×0,90 (coragem, menos gentileza). 10 a 25 s.
		Carvão-de-sabá: O ×1,15, A ×0,85, N ×1,10 (rebeldia, inquietação). 15 a 30 s.
		Pena-de-fênix: E ×0,90, N ×0,90, E ← +0,10·N, N ← +0,10·E (troca parte do E com o N). 8 a 20 s.
	Muito fria (transparente, estraga acima de ~78 °C):
		Orvalho-da-lua: N ×0,85, E ×0,95 (calma, recolhimento). 30 a 60 s.
		Flor-de-gelo: A ×1,10, O ×0,95 (doçura, conformidade). 25 a 50 s.
		Lágrima-de-fantasma: O ×1,12, N ×1,05 (sensibilidade ao véu). 40 a 70 s.
```

## Possíveis expansões (futuras)

```
[ ] Sistema de clima
[ ]	Sistema de fama
[ ]	Sistema de compra/venda
[ ]	Sistema de mercado/valor dinâmico

```
