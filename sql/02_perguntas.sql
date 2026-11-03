-- =====================================================================================
-- 02_perguntas.sql  -  AS 6 PERGUNTAS DA CONTROLADORIA (PostgreSQL)
-- =====================================================================================
-- Rode cada consulta no pgAdmin (Query Tool). Os numeros daqui devem ser IGUAIS aos medidas do Power BI.
--
-- 4 REGRAS QUE VALEM PARA TODAS AS CONSULTAS:
--   1) Percentual = SOMA / SOMA  (nunca a media de percentuais, que da peso igual a itens de tamanhos muito diferentes)
--   2) Economia so conta itens COMPARAVEIS (comparavel = 1). Itens nao comparaveis entram no VOLUME, nao na economia.
--   3) Quando o denominador pode ser zero (Credenciamento nao tem item comparavel), use NULLIF(denominador, 0):
--      a divisao vira NULL (vazio) em vez de dar erro "division by zero".
--   4) "Volume" = soma do valor_total_homologado de TODOS os itens da fato.
-- =====================================================================================


-- =====================================================================================
-- P1 - ECONOMIA GLOBAL DO PODER PUBLICO
-- Qual e o percentual e o valor nominal economizado (estimado - homologado)?
-- Raciocinio: o CASE WHEN "liga" a soma so nos itens comparaveis. A CTE (WITH) guarda as 3 somas uma vez,
-- e o SELECT final so faz as contas, sem repetir expressoes.
-- Conferencia (prova real): economia = R$ 992.861.686,95  |  economia % = 14,46  |  comparaveis = 5457
-- =====================================================================================
WITH base AS (
    SELECT
        SUM(valor_total_homologado)                                                    AS volume_homologado,
        SUM(CASE WHEN comparavel = 1 THEN valor_total_estimado   ELSE 0 END)           AS estimado_comparavel,
        SUM(CASE WHEN comparavel = 1 THEN valor_total_homologado ELSE 0 END)           AS homologado_comparavel,
        SUM(comparavel)                                                                AS itens_comparaveis,
        COUNT(*)                                                                       AS itens_total
    FROM fato_item_contratado
)
SELECT
    volume_homologado,
    estimado_comparavel,
    homologado_comparavel,
    estimado_comparavel - homologado_comparavel                                        AS economia_rs,
    ROUND(100.0 * (estimado_comparavel - homologado_comparavel)
          / NULLIF(estimado_comparavel, 0), 2)                                         AS economia_pct,
    itens_comparaveis,
    itens_total,
    ROUND(100.0 * itens_comparaveis / itens_total, 2)                                  AS pct_itens_comparaveis
FROM base;


-- =====================================================================================
-- P2 - CONCENTRACAO E RISCO DE FORNECEDORES
-- Quem sao os maiores fornecedores em volume e qual % do orcamento esta concentrado neles?
-- Raciocinio: primeiro a CTE soma o volume POR FORNECEDOR (ni_fornecedor = CNPJ/CPF limpo, entao filiais com
-- CNPJ diferente contam como fornecedores diferentes). Depois ordenamos e pegamos os 10 maiores (LIMIT 10).
-- O denominador do % e uma SUBCONSULTA com o volume total de todos os fornecedores.
-- =====================================================================================

-- P2A) Os 10 maiores fornecedores, com a participacao de cada um
WITH volume_por_fornecedor AS (
    SELECT
        d.ni_fornecedor,
        d.nome_fornecedor,
        SUM(f.valor_total_homologado) AS volume
    FROM fato_item_contratado f
    JOIN dim_fornecedor d ON d.sk_fornecedor = f.sk_fornecedor
    GROUP BY d.ni_fornecedor, d.nome_fornecedor
)
SELECT
    RANK() OVER (ORDER BY volume DESC)                                                 AS posicao,
    ni_fornecedor,
    nome_fornecedor,
    volume,
    ROUND(100.0 * volume / (SELECT SUM(volume) FROM volume_por_fornecedor), 2)         AS pct_do_total
FROM volume_por_fornecedor
ORDER BY volume DESC
LIMIT 10;

-- P2B) Concentracao dos 10 maiores SOMADOS (a resposta da pergunta: "qual % esta concentrado neles?")
WITH volume_por_fornecedor AS (
    SELECT d.ni_fornecedor, SUM(f.valor_total_homologado) AS volume
    FROM fato_item_contratado f
    JOIN dim_fornecedor d ON d.sk_fornecedor = f.sk_fornecedor
    GROUP BY d.ni_fornecedor
),
top10 AS (
    SELECT volume FROM volume_por_fornecedor ORDER BY volume DESC LIMIT 10
)
SELECT
    (SELECT COUNT(*) FROM volume_por_fornecedor)                                       AS fornecedores_distintos,
    (SELECT SUM(volume) FROM top10)                                                    AS volume_top10,
    (SELECT SUM(volume) FROM volume_por_fornecedor)                                    AS volume_total,
    ROUND(100.0 * (SELECT SUM(volume) FROM top10)
          / (SELECT SUM(volume) FROM volume_por_fornecedor), 2)                        AS pct_top10;


-- =====================================================================================
-- P3 - EFICACIA POR MODALIDADE
-- Quais modalidades trazem maior desagio (economia %) e quais concentram o maior volume?
-- Raciocinio: GROUP BY modalidade. Volume = todos os itens. Desagio = so os comparaveis (soma/soma).
-- No Credenciamento (modalidade 12) nenhum item e comparavel: NULLIF faz o desagio sair VAZIO (esperado, nao e erro).
-- =====================================================================================
SELECT
    m.nome_modalidade,
    COUNT(*)                                                                           AS itens,
    SUM(f.valor_total_homologado)                                                      AS volume,
    ROUND(100.0 * SUM(f.valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)         AS pct_do_volume,
    SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END)             AS estimado_comparavel,
    SUM(CASE WHEN f.comparavel = 1
             THEN f.valor_total_estimado - f.valor_total_homologado ELSE 0 END)        AS economia_rs,
    ROUND(100.0 * SUM(CASE WHEN f.comparavel = 1
                           THEN f.valor_total_estimado - f.valor_total_homologado ELSE 0 END)
          / NULLIF(SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END), 0), 2)
                                                                                       AS desagio_pct
FROM fato_item_contratado f
JOIN dim_modalidade m ON m.sk_modalidade = f.sk_modalidade
GROUP BY m.nome_modalidade
ORDER BY volume DESC;


-- =====================================================================================
-- P4 - TEMPO DO CICLO DE COMPRAS
-- Qual a duracao media (dias) entre a publicacao do edital e a homologacao, por orgao?
-- Raciocinio: dias_ciclo ja vem calculado (e vazio quando a homologacao e anterior a publicacao).
-- AVG e COUNT(coluna) IGNORAM os vazios. O mesmo orgao tem varias unidades (CNPJ), por isso agrupamos pelo NOME
-- padronizado e contamos CNPJ distintos. HAVING (e nao WHERE) filtra DEPOIS do agrupamento: so orgaos com
-- 5 ou mais itens COM ciclo.
-- =====================================================================================

-- P4A) Visao geral (prova real: ciclo medio 48,1 | maximo 611 | itens sem ciclo 230)
SELECT
    ROUND(AVG(dias_ciclo), 1)        AS ciclo_medio_dias,
    MAX(dias_ciclo)                  AS ciclo_maximo_dias,
    COUNT(dias_ciclo)                AS itens_com_ciclo,
    COUNT(*) - COUNT(dias_ciclo)     AS itens_sem_ciclo
FROM fato_item_contratado;

-- P4B) Ranking por orgao: do ciclo mais LONGO para o mais curto
SELECT
    o.nome_orgao,
    COUNT(DISTINCT o.cnpj_orgao)     AS unidades_compradoras,
    COUNT(f.dias_ciclo)              AS itens_com_ciclo,
    ROUND(AVG(f.dias_ciclo), 1)      AS ciclo_medio_dias,
    MAX(f.dias_ciclo)                AS ciclo_maximo_dias
FROM fato_item_contratado f
JOIN dim_orgao o ON o.sk_orgao = f.sk_orgao
GROUP BY o.nome_orgao
HAVING COUNT(f.dias_ciclo) >= 5
ORDER BY ciclo_medio_dias DESC, o.nome_orgao;


-- =====================================================================================
-- P5 - DISTRIBUICAO REGIONAL
-- Quais estados e regioes concentram as maiores despesas e quais tem os melhores descontos?
-- Raciocinio: a regiao foi montada no Python (dim_localidade.regiao). Mesma estrutura da P3, agrupando por UF e por regiao.
-- Unidades compradoras = COUNT(DISTINCT sk_orgao): como cada CNPJ tem uma unica sk_orgao, e o mesmo numero.
-- =====================================================================================

-- P5A) Por estado (UF)
SELECT
    l.regiao,
    l.uf_sigla,
    l.uf_nome,
    COUNT(DISTINCT f.sk_orgao)                                                         AS unidades_compradoras,
    SUM(f.valor_total_homologado)                                                      AS volume,
    ROUND(100.0 * SUM(f.valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)         AS pct_do_volume,
    ROUND(100.0 * SUM(CASE WHEN f.comparavel = 1
                           THEN f.valor_total_estimado - f.valor_total_homologado ELSE 0 END)
          / NULLIF(SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END), 0), 2)
                                                                                       AS desagio_pct
FROM fato_item_contratado f
JOIN dim_localidade l ON l.sk_localidade = f.sk_localidade
GROUP BY l.regiao, l.uf_sigla, l.uf_nome
ORDER BY volume DESC;

-- P5B) Por regiao
SELECT
    l.regiao,
    COUNT(DISTINCT f.sk_orgao)                                                         AS unidades_compradoras,
    SUM(f.valor_total_homologado)                                                      AS volume,
    ROUND(100.0 * SUM(f.valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2)         AS pct_do_volume,
    ROUND(100.0 * SUM(CASE WHEN f.comparavel = 1
                           THEN f.valor_total_estimado - f.valor_total_homologado ELSE 0 END)
          / NULLIF(SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END), 0), 2)
                                                                                       AS desagio_pct
FROM fato_item_contratado f
JOIN dim_localidade l ON l.sk_localidade = f.sk_localidade
GROUP BY l.regiao
ORDER BY volume DESC;


-- =====================================================================================
-- P6 - PERFIL DOS GASTOS
-- Como os recursos se distribuem entre bens, servicos e obras e engenharia?
-- Raciocinio: perfil_gasto e coluna da propria fato (foi classificada no Python), entao NAO precisa de JOIN.
-- Conferencia (prova real): Obras e engenharia 60,8% | Servicos 36,6% | Bens 2,6%  (itens: 967 | 1.849 | 3.310)
-- =====================================================================================
SELECT
    perfil_gasto,
    COUNT(*)                                                                           AS itens,
    SUM(valor_total_homologado)                                                        AS volume,
    ROUND(100.0 * SUM(valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 1)         AS pct_do_volume,
    ROUND(SUM(valor_total_homologado) / COUNT(*), 2)                                   AS ticket_medio_por_item
FROM fato_item_contratado
GROUP BY perfil_gasto
ORDER BY volume DESC;
