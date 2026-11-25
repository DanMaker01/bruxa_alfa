# Ferramenta central

Uma janela só, com abas, para editar os dados do jogo.

    python ferramentas/central/central.py      (ou abrir_central.bat)

Precisa de `pip install PySide6` (não usa matplotlib).

| Aba | O que faz |
|---|---|
| Personalidades | lista O C E A N editável (−10 a 10) e, ao lado, a mesma lista DEPOIS de uma poção ou item (doses e borda iguais ao jogo): valor novo, ▲/▼ quanto mudou e cor (verde sobe, vermelho desce, mais forte = maior). Pentagrama do escolhido. "Nova personalidade" já registra no banco. |
| Itens | campos de cada item, "no banco", matriz A, o que ela faz e o valor de troca. "Novo item" cria o .tres e registra no banco (o ícone se escolhe no Godot). |
| Catálogo | poções (proibidas no fim), matriz A ideal, efeito na personalidade de um personagem (pentagrama e em palavras) e os comandos do efeito (inserir, editar, apagar). |
| Eventos | editor de eventos próprio: lista de eventos, páginas, comandos indentados e coloridos, campos do comando ao lado. Ctrl+S, Ctrl+Z/Y, Insert, Del, Alt+↑/↓, Ctrl+D. Backup em editor_eventos/backup/. |
| Balanceamento | receita e passos editáveis, rodar (nome que o jogo daria, aproveitamento, matriz, cada ingrediente, gráfico da temperatura), Monte Carlo, Testes, Dificuldade, dose a² e cisalhamento para testar. |
| Receitas | nome, poção, descrição, duração, conhecida, ingredientes (item, quantidade, nota) e passos em texto; passos do livro coloridos; prévia em texto da página; "Abrir no Balanceamento". |
| Falas | todas as falas de um personagem juntas (e opções, legendas), na ordem dos eventos; marca travessão, vazio e espaço duplo. Duplo clique abre o evento. |
| Flags | cada variável: valor inicial, quantos lugares mudam e testam, citações em scripts e avisos (não declarada, ninguém muda, ninguém testa). |
| Onde é usado | escolha um item, evento, personagem, poção, receita, falante, variável ou mapa e veja quem cita (eventos, mapas, dados, scripts). |
| Mapas | eventos de cada mapa, áreas de spawn, passagens (para onde levam e a quantos px a bruxa chega da passagem de lá) e o desenho das ligações. |
| Mercadores | lojas (comando loja): estoque inicial com o valor de cada item para ele, ouro e margem (editáveis) e simulação da Balança e da Pechincha. |
| Chamas | estados da chama (nome, faixa de T, cor) editáveis; régua das faixas, como o caldo esquenta em cada chama e o aproveitamento de um item por chama. |
| Calibração | jogadas reais (user://jogadas/) e o que dariam hoje, parâmetros das jogadoras perfeita/calibrada/ruim, "Calibrar" e comparação real × simulada. |
| Verificação | procura problemas antes de exportar (erro / aviso / info); duplo clique abre o evento. |
| Projeto | git só para ver: o que mudou agora, últimos commits e o que mudou de uma versão até agora (arquivos, linhas e diferença). |

Organização:

- `central.py`: a janela e a lista `ABAS`.
- `nucleo/`: peças comuns. `tres_simples.py` (ler e trocar campos sem mexer no resto do arquivo), `tabela.py` (tabela genérica de .tres), `visual.py` (matriz, pentagrama, gráficos com QPainter), `motor.py` (motor do editor de eventos e do simulador), `indice.py` (lê o projeto todo: comandos, condições, mapas, variáveis, falas), `usos.py` (tabela "onde aparece"), `navegar.py` (ir de uma aba para outra), `chamas.py` (curvas por cor da chama).
- `abas/`: um arquivo por aba, com `TITULO` e `criar(raiz)`. Aba nova: um arquivo aqui e o nome em `ABAS`.

Cada aba só carrega quando é aberta; se uma der erro, as outras continuam. Salvar grava só o que mudou e pergunta se o arquivo mudou fora daqui (Godot).
As ferramentas antigas (balanceamento.py, editor_eventos.py) continuam funcionando sozinhas.
