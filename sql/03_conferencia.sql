-- =====================================================================================
-- 03_conferencia.sql  -  PROVA REAL E INTEGRIDADE (nao responde as perguntas de negocio)
-- =====================================================================================

-- C1) Linhas por tabela x prova real (a linha tecnica "Nao informado", sk = -1, nao conta)
SELECT 'fato_item_contratado' AS tabela, COUNT(*) AS linhas_no_banco, 6126 AS prova_real FROM fato_item_contratado
UNION ALL SELECT 'dim_orgao',      COUNT(*), 363  FROM dim_orgao      WHERE sk_orgao > 0
UNION ALL SELECT 'dim_fornecedor', COUNT(*), 2652 FROM dim_fornecedor WHERE sk_fornecedor > 0
UNION ALL SELECT 'dim_modalidade', COUNT(*), 7    FROM dim_modalidade WHERE sk_modalidade > 0
UNION ALL SELECT 'dim_localidade', COUNT(*), 27   FROM dim_localidade WHERE sk_localidade > 0;

-- C2) Totais da fato x prova real (anexo 8)
SELECT
    COUNT(DISTINCT numero_controle_pncp)                                               AS contratacoes_distintas,   -- 1962
    SUM(valor_total_homologado)                                                        AS volume_homologado,        -- 8.044.498.805,74
    SUM(valor_total_estimado)                                                          AS estimado_todos_itens,     -- 32.629.639.732,13
    SUM(CASE WHEN comparavel = 1 THEN valor_total_estimado ELSE 0 END)                 AS estimado_comparavel,      -- 6.867.663.469,91
    SUM(comparavel)                                                                    AS itens_comparaveis,        -- 5457
    SUM(economia_valor)                                                                AS economia_nominal,         -- 992.861.686,95
    SUM(CASE WHEN comparavel = 1 AND valor_total_homologado > valor_total_estimado
             THEN 1 ELSE 0 END)                                                        AS itens_com_sobrepreco      -- 27
FROM fato_item_contratado;

-- C3) FK SOLTA: linhas da fato sem dimensao correspondente. ESPERADO: 0 em todas as linhas.
-- LEFT JOIN mantem toda a fato. Onde a dimensao nao existe, a coluna dela vem vazia (IS NULL).
SELECT 'fato -> dim_orgao' AS relacao, COUNT(*) AS fk_soltas
FROM fato_item_contratado f LEFT JOIN dim_orgao d ON d.sk_orgao = f.sk_orgao WHERE d.sk_orgao IS NULL
UNION ALL
SELECT 'fato -> dim_fornecedor', COUNT(*)
FROM fato_item_contratado f LEFT JOIN dim_fornecedor d ON d.sk_fornecedor = f.sk_fornecedor WHERE d.sk_fornecedor IS NULL
UNION ALL
SELECT 'fato -> dim_modalidade', COUNT(*)
FROM fato_item_contratado f LEFT JOIN dim_modalidade d ON d.sk_modalidade = f.sk_modalidade WHERE d.sk_modalidade IS NULL
UNION ALL
SELECT 'fato -> dim_localidade', COUNT(*)
FROM fato_item_contratado f LEFT JOIN dim_localidade d ON d.sk_localidade = f.sk_localidade WHERE d.sk_localidade IS NULL;

-- C4) GRAO: nenhum item pode aparecer duas vezes. ESPERADO: nenhuma linha no resultado.
SELECT numero_controle_pncp, numero_item, COUNT(*) AS vezes
FROM fato_item_contratado
GROUP BY numero_controle_pncp, numero_item
HAVING COUNT(*) > 1;
