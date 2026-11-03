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

