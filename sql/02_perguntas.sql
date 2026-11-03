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