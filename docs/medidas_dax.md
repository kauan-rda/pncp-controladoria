# Medidas DAX do dashboard — Controladoria PNCP

Este arquivo reúne o **Calendário** e as **medidas** do Power BI, uma por bloco de código, para você copiar e colar.
Também serve como documentação no repositório (critério 07 e 13 da avaliação).

## Como usar

1. Os nomes de tabelas e colunas abaixo são os do banco (`fato_item_contratado`, `dim_orgao`, `dim_fornecedor`, `dim_modalidade`, `dim_localidade`). Se o seu Power BI mostrar outros nomes, ajuste nas fórmulas.
2. **Tabela de medidas:** Página Inicial → **Inserir dados** → deixe uma coluna vazia → nome da tabela `_Medidas` → **Carregar**. Depois exclua a coluna vazia (visão de Dados → botão direito na coluna → *Excluir do modelo*) para sobrar só as medidas.
3. **Nova medida:** selecione a tabela `_Medidas` → Modelagem → **Nova medida** → cole **uma** medida por vez (apague o texto que o Power BI sugere).
4. **Pasta de exibição:** visão de Modelo → clique na medida → painel Propriedades → *Pasta de exibição* → digite o nome da pasta (coluna "Pasta" abaixo). Uma pasta por pergunta.
5. **Formato:** Ferramentas de medida → Formato (coluna "Formato" abaixo).
6. **Separador de argumentos (muito comum dar erro aqui):** as fórmulas deste arquivo usam **vírgula** entre os argumentos, como no Power BI em inglês. Se o seu Power BI estiver em português (Brasil), o editor costuma exigir **ponto e vírgula** (`;`). Se aparecer erro de sintaxe ao colar, troque cada vírgula que separa argumentos por `;`. Exemplo: `DIVIDE ( [A], [B] )` vira `DIVIDE ( [A]; [B] )`. Não troque as vírgulas que estejam dentro de textos entre aspas. O argumento vazio do `RANKX` (`, ,`) vira `; ;`.

> Defesa no vídeo: escolha 2 ou 3 medidas e explique **linha a linha**. Sugestão: *Economia %*, *Concentração Top 10 %* e *Qtd Unidades Compradoras* (a explicação de cada uma está logo abaixo da fórmula).

---

## 0. Calendário (Modelagem → Nova tabela)

Limites **vindos dos dados** (não digitados). Usa as duas datas da fato: a menor publicação e a maior data entre publicação e homologação.

```dax
Calendario =
VAR _primeiraData =
    MIN (
        MIN ( fato_item_contratado[data_publicacao] ),
        MIN ( fato_item_contratado[data_homologacao] )
    )
VAR _ultimaData =
    MAX (
        MAX ( fato_item_contratado[data_publicacao] ),
        MAX ( fato_item_contratado[data_homologacao] )
    )
VAR _inicio = DATE ( YEAR ( _primeiraData ), 1, 1 )
VAR _fim    = DATE ( YEAR ( _ultimaData ), 12, 31 )
RETURN
    ADDCOLUMNS (
        CALENDAR ( _inicio, _fim ),
        "Ano", YEAR ( [Date] ),
        "MesNum", MONTH ( [Date] ),
        "Mes", FORMAT ( [Date], "mmm", "pt-BR" ),
        "AnoMesNum", YEAR ( [Date] ) * 100 + MONTH ( [Date] ),
        "AnoMes", FORMAT ( [Date], "mmm/yy", "pt-BR" )
    )
```

**Depois de criar (visão de Modelo ou Dados):**

| Passo | Como |
|---|---|
| Renomear `Date` para `Data` | Clique na coluna → Propriedades → Nome. (O `CALENDAR` sempre cria a coluna com o nome `Date`.) |
| Ordenar `Mes` pelo número | Clique em `Mes` → Ferramentas de coluna → **Classificar por coluna** → `MesNum` |
| Ordenar `AnoMes` pelo número | Clique em `AnoMes` → **Classificar por coluna** → `AnoMesNum` |
| Marcar como tabela de datas | Ferramentas de tabela → **Marcar como tabela de datas** → coluna `Data` |
| Esconder colunas técnicas | Esconda `MesNum` e `AnoMesNum` |
| Relacionamentos | `Calendario[Data]` → `fato_item_contratado[data_publicacao]` (**ativo**) e `Calendario[Data]` → `fato_item_contratado[data_homologacao]` (fica **inativo**: só um pode ser ativo) |
| Desligar a hierarquia automática | Arquivo → Opções e configurações → Opções → **Arquivo atual** → Carregamento de dados → desmarque *Hora/data automática* |

---

## 1. As 15 medidas obrigatórias

### P1 — Economia (pasta: `P1 Economia`)

**1) Valor Estimado Comparável** — formato: Moeda R$

```dax
Valor Estimado Comparável =
VAR _estimadoComparavel =
    CALCULATE (
        SUM ( fato_item_contratado[valor_total_estimado] ),
        fato_item_contratado[comparavel] = 1
    )
RETURN
    _estimadoComparavel
```

**2) Volume Homologado** — formato: Moeda R$

```dax
Volume Homologado =
SUM ( fato_item_contratado[valor_total_homologado] )
```

**3) Economia (R$)** — formato: Moeda R$

```dax
Economia (R$) =
VAR _estimado   = [Valor Estimado Comparável]
VAR _homologado =
    CALCULATE (
        [Volume Homologado],
        fato_item_contratado[comparavel] = 1
    )
RETURN
    _estimado - _homologado
```

**4) Economia %** — formato: Porcentagem, 2 casas

```dax
Economia % =
DIVIDE ( [Economia (R$)], [Valor Estimado Comparável] )
```

> **Explicação (soma ÷ soma):** o percentual é a economia total dividida pelo estimado comparável total. Não é a média dos percentuais de cada item, porque um item de R$ 10 mil pesaria o mesmo que um de R$ 100 milhões. O `DIVIDE` devolve vazio (em vez de erro) quando o denominador é zero, como no Credenciamento.

**5) % de Itens Comparáveis** — formato: Porcentagem, 2 casas

```dax
% de Itens Comparáveis =
VAR _comparaveis =
    CALCULATE (
        COUNTROWS ( fato_item_contratado ),
        fato_item_contratado[comparavel] = 1
    )
VAR _total = COUNTROWS ( fato_item_contratado )
RETURN
    DIVIDE ( _comparaveis, _total )
```

### P2 — Fornecedores (pasta: `P2 Fornecedores`)

**6) Participação do Fornecedor %** — formato: Porcentagem, 2 casas

```dax
Participação do Fornecedor % =
VAR _volumeDoFornecedor = [Volume Homologado]
VAR _volumeTotal =
    CALCULATE (
        [Volume Homologado],
        ALL ( dim_fornecedor )
    )
RETURN
    DIVIDE ( _volumeDoFornecedor, _volumeTotal )
```

**7) Ranking do Fornecedor** — formato: Número inteiro

```dax
Ranking do Fornecedor =
IF (
    HASONEVALUE ( dim_fornecedor[ni_fornecedor] ),
    RANKX (
        ALL ( dim_fornecedor ),
        [Volume Homologado],
        ,
        DESC,
        DENSE
    )
)
```

> Use esta medida numa tabela que tenha a coluna `ni_fornecedor` (e o nome). O `IF/HASONEVALUE` evita mostrar "1" na linha de total. `RANKX` é uma função iteradora (percorre cada fornecedor da tabela).

**8) Concentração Top 10 %** — formato: Porcentagem, 2 casas

```dax
Concentração Top 10 % =
VAR _volumeTotal =
    CALCULATE (
        [Volume Homologado],
        ALL ( dim_fornecedor )
    )
VAR _top10 =
    TOPN (
        10,
        ALL ( dim_fornecedor ),
        [Volume Homologado], DESC
    )
VAR _volumeTop10 =
    CALCULATE (
        [Volume Homologado],
        KEEPFILTERS ( _top10 )
    )
RETURN
    DIVIDE ( _volumeTop10, _volumeTotal )
```

> **Explicação (linha a linha):** `_volumeTotal` = volume de todos os fornecedores (o `ALL` remove o filtro de fornecedor). `_top10` = tabela com os 10 fornecedores de maior volume (`TOPN`). `_volumeTop10` = soma do volume só desses 10: `KEEPFILTERS` aplica a lista como filtro **sem apagar** os outros filtros da página (ano, modalidade…). No fim, divide um pelo outro. Deve bater com a consulta P2B do SQL.

### P3 — Modalidades (pasta: `P3 Modalidades`)

**9) Participação no Volume %** — formato: Porcentagem, 2 casas

```dax
Participação no Volume % =
VAR _volumeDaLinha = [Volume Homologado]
VAR _volumeTotal =
    CALCULATE (
        [Volume Homologado],
        ALLSELECTED ()
    )
RETURN
    DIVIDE ( _volumeDaLinha, _volumeTotal )
```

> `ALLSELECTED()` sem argumentos remove o agrupamento do visual (a "linha" atual: modalidade, UF ou perfil), mas **mantém** os filtros de segmentação. Por isso a mesma medida serve nas páginas 3, 5 e 6.

**10) Deságio vs Média Geral (p.p.)** — formato: **Número decimal, 1 casa** (nunca %)

```dax
Deságio vs Média Geral (p.p.) =
VAR _economiaDaLinha = [Economia %]
VAR _economiaGeral =
    CALCULATE (
        [Economia %],
        REMOVEFILTERS ()
    )
RETURN
    IF (
        ISBLANK ( _economiaDaLinha ),
        BLANK (),
        ( _economiaDaLinha - _economiaGeral ) * 100
    )
```

> O `IF/ISBLANK` é necessário: no Credenciamento a economia da linha é vazia, e `vazio - 14%` daria "-14 p.p.", que é falso. Formatada como número (ex.: 9,6), a diferença de 9,6 pontos percentuais não vira "960%".

### P4 — Ciclo (pasta: `P4 Ciclo`)

**11) Ciclo Médio (dias)** — formato: Decimal, 1 casa

```dax
Ciclo Médio (dias) =
AVERAGE ( fato_item_contratado[dias_ciclo] )
```

**12) Ciclo Máximo (dias)** — formato: Número inteiro

```dax
Ciclo Máximo (dias) =
MAX ( fato_item_contratado[dias_ciclo] )
```

**13) Itens sem Ciclo** — formato: Número inteiro

```dax
Itens sem Ciclo =
VAR _totalDeItens = COUNTROWS ( fato_item_contratado )
VAR _itensComCiclo = COUNT ( fato_item_contratado[dias_ciclo] )
RETURN
    _totalDeItens - _itensComCiclo
```

> `COUNT` ignora os vazios, então `_itensComCiclo` conta só os itens com data de homologação válida.

### P5 — Regional (pasta: `P5 Regional`)

**14) Qtd Unidades Compradoras** — formato: Número inteiro

```dax
Qtd Unidades Compradoras =
DISTINCTCOUNT ( fato_item_contratado[sk_orgao] )
```

> **Por que na fato e não na dimensão?** O filtro anda da dimensão para a fato, nunca ao contrário. Se você contasse `dim_orgao[cnpj_orgao]`, um visual por UF mostraria 363 em todas as linhas. Contando `sk_orgao` **na fato**, só entram os órgãos que realmente compraram naquele estado. Cada `sk_orgao` corresponde a um CNPJ, então o número é o mesmo.

### P6 — Perfil (pasta: `P6 Perfil`)

**15) Ticket Médio por Item (R$)** — formato: Moeda R$

```dax
Ticket Médio por Item (R$) =
DIVIDE ( [Volume Homologado], COUNTROWS ( fato_item_contratado ) )
```

---

## 2. Extras recomendados (continuam nas pastas das perguntas)

**Itens com Sobrepreço** (pasta `P1 Economia`) — usa uma **iteradora** (`SUMX`). Deve dar 27.

```dax
Itens com Sobrepreço =
SUMX (
    fato_item_contratado,
    IF (
        fato_item_contratado[comparavel] = 1
            && fato_item_contratado[valor_total_homologado] > fato_item_contratado[valor_total_estimado],
        1,
        0
    )
)
```

**Itens com Ciclo** (pasta `P4 Ciclo`) — use como *filtro do visual* "≥ 5" no ranking de órgãos.

```dax
Itens com Ciclo =
COUNT ( fato_item_contratado[dias_ciclo] )
```

**Volume Homologado (por data de homologação)** (pasta `Tempo`) — mostra o uso da relação inativa.

```dax
Volume por Data de Homologação =
CALCULATE (
    [Volume Homologado],
    USERELATIONSHIP ( Calendario[Data], fato_item_contratado[data_homologacao] )
)
```

**Volume Acumulado no Ano** (pasta `Tempo`)

```dax
Volume Acumulado no Ano =
CALCULATE (
    [Volume Homologado],
    DATESYTD ( Calendario[Data] )
)
```

**Variação Mensal %** (pasta `Tempo`)

```dax
Variação Mensal % =
VAR _atual = [Volume Homologado]
VAR _mesAnterior =
    CALCULATE (
        [Volume Homologado],
        DATEADD ( Calendario[Data], -1, MONTH )
    )
RETURN
    DIVIDE ( _atual - _mesAnterior, _mesAnterior )
```

**Título do Tooltip** (pasta `Tooltip`) — texto dinâmico para a página de tooltip de modalidades.

```dax
Título do Tooltip =
"Detalhe: " & SELECTEDVALUE ( dim_modalidade[nome_modalidade], "todas as modalidades" )
```

---

## 3. Conferência SQL × Power BI

Os números do dashboard devem ser os mesmos da consulta correspondente (critério da seção 4.6: "os números do dashboard devem ser os mesmos do seu SQL").

| Medida | Consulta em `sql/02_perguntas.sql` | Valor esperado (prova real) |
|---|---|---|
| Economia (R$) | P1 | R$ 992.861.686,95 |
| Economia % | P1 | 14,46% |
| Volume Homologado | P1 | R$ 8.044.498.805,74 |
| % de Itens Comparáveis | P1 (`pct_itens_comparaveis`) | 5.457 de 6.126 itens |
| Concentração Top 10 % | P2B | igual ao `pct_top10` do SQL |
| Participação no Volume % (por modalidade) | P3 (`pct_do_volume`) | igual ao SQL |
| Ciclo Médio / Máximo / Itens sem Ciclo | P4A | 48,1 / 611 / 230 |
| Qtd Unidades Compradoras (total) | P5 | 363 |
| Participação (perfil) | P6 | Obras 60,8% · Serviços 36,6% · Bens 2,6% |
| Itens com Sobrepreço | — | 27 |
