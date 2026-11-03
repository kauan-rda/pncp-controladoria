## Auditoria inicial dos dados brutos

1. **Quantas linhas tem cada arquivo? Há `numero_controle_pncp` repetido?**
   compras: 2.042 · itens: 7.077 · resultados: 15.896. Chaves repetidas em compras: 0.
   (Seção 1 do relatório.)

2. **Que formatos de dinheiro, data e CNPJ aparecem? Quais colunas têm N/A, -, 0, vazio?**
   - Dinheiro: com prefixo R$, ponto sozinho (1234.56 / 746.815), ponto e vírgula (1.234,56 ou 1,234.56) e vírgula sozinha (12,5).
   - Data: em `data_publicacao` (AAAA-MM-DDTHH:MM:SS, DD-MM-AAAA, DD/MM/AAAA HH:MM, DD.MM.AAAA, DD/MM/AAAA, AAAA/MM/DD, AAAAMMDD) e em `data_resultado` (AAAA-MM-DD, AAAA/MM/DD, DD.MM.AAAA, DD/MM/AAAA HH:MM, DD/MM/AAAA, AAAAMMDD, DD-MM-AAAA).
   - CNPJ/CPF: 1.809 com máscara (176 em compras e 1.633 em resultados), 430 sem o zero à esquerda (77 em compras, 194 PJ em resultados e 159 PF em resultados).
   - Nulos disfarçados: colunas `processo` (77), `categoria_item` (7.077) e `porte` (4.893) com os valores N/A, -, 0, SEM INFORMACAO... (além de vazios em `data_abertura_proposta` [617], `data_encerramento_proposta` [617], `unidade_medida` [9], `data_cancelamento` [15.834] e `ordem_classificacao_srp` [11.976]).
   (Seções 2, 3 e 4 do relatório.)

3. **Existe texto com acento quebrado (Ã§, Ã£)? Em quais colunas?**
   Sim, em `nome_unidade` (14), `objeto_compra` (43), `descricao` (116) e `nome_fornecedor` (1).

4. **Existe `data_resultado` anterior a `data_publicacao`?**
   Sim, em 234 resultados. (Seção 5 do relatório.)

5. Dicionário das inconsistências tratadas

| # | Desafio | Arquivo / coluna | Exemplo bruto | Registros afetados | Como foi tratado |
|---|---|---|---|---|---|
| 1 | CNPJ/CPF | `cnpj_orgao`, `ni_fornecedor` | `11.222.333/0001-81` · `1222333000181` | 1.809 com máscara (176 + 1.633) · 430 sem zero à esquerda (77 + 194 PJ + 159 PF) | só dígitos + `zfill` conforme o tipo (PJ 14 / PF 11); PE intocado |
| 2 | Dinheiro e decimais | `quantidade`, `valor_*` | `R$ 1.234,56` · `1,234.56` · `746.815` · `(1.500,00)` | 12.055 com R$ · 56.360 ponto sozinho · 8.979 ponto e vírgula · 7.664 vírgula sozinha | `converter_numero`: ponto/vírgula sozinho = decimal; símbolo repetido = milhar |
| 3 | Datas | `data_publicacao`, `data_resultado` | `10/03/2025 14:20` · `20250310` · `0001-01-01` | 6.318 fora do ISO (723 em `data_publicacao` + 5.595 em `data_resultado`) · 65 datas impossíveis (em `data_encerramento_proposta`) | `converter_data` (6 formatos, anos de 2000 a 2030) |
| 3b | Cronologia | `data_resultado` < `data_publicacao` | homologação antes do edital | 234 | data de homologação anulada; item fica na fato sem ciclo |
| 4 | Nulos disfarçados | `processo`, `porte`, `categoria_item` | `N/A` · `-` · `0` · `SEM INFORMAÇÃO` | 12.047 (77 em `processo` + 4.893 em `porte` + 7.077 em `categoria_item`) | conjunto `NULOS` (o `0` só é nulo em texto) |
| 5 | Encoding | `descricao`, `objeto_compra` | `AquisiÃ§Ã£o` | 159 (116 em `descricao` + 43 em `objeto_compra`) · 174 no total (+14 em `nome_unidade` + 1 em `nome_fornecedor`) | `encode('latin-1').decode('utf-8')` |
| 5b | Nomes repetidos | `razao_social_orgao`, `nome_fornecedor` | `Ministério da Saúde` · `MINISTERIO  DA SAUDE ` | 440 grafias → 352 nomes (`razao_social_orgao`) · 559 com espaços sobrando (58 + 501) | maiúsculas + espaços + hífen padronizado |
| 6 | Vários classificados (SRP) | `resultados.csv` | 1º colocado cancelado | 405 itens com mais de 1 classificado (e 62 cancelados) | cancelados saem primeiro; 1º por ordem e, no empate, menor `sequencial_resultado` |

• economia_valor vazia (NULL) nos itens não comparáveis. O enunciado (4.3) pede vazio; o kit gravava 0.0 (.where(..., 0.0)). As somas são idênticas. Escolhi vazio porque “não comparável” não é “economia zero”.
• As quatro palavras de obra (obra, construção, reforma, engenharia) e o limite de palavra \b.