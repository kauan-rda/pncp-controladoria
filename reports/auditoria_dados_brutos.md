# Auditoria dos dados brutos (gerada por `python -m src.auditoria`)

## 1. Visao geral

- compras.csv: 2042 linhas x 25 colunas | numero_controle_pncp repetido: 0
- itens.csv: 7077 linhas x 14 colunas | chave (controle+item) repetida: 0
- resultados.csv: 15896 linhas x 13 colunas

## 2. compras.csv

**Desafio 1 - CNPJ do orgao**

| Problema | Registros afetados |
|---|---|
| `cnpj_orgao`: com mascara (. / -) | 176 |
| `cnpj_orgao`: zero a esquerda perdido (menos de 14 digitos) | 77 |
| `cnpj_orgao`: lixo/nulo (sem nenhum digito) | 0 |
| CNPJ distintos como vieram | 539 |
| CNPJ distintos depois de so digitos + zeros (unidades reais) | 370 |

**Desafio 2 - valores monetarios**

| Problema | Registros afetados |
|---|---|
| `valor_total_estimado`: com prefixo R$ | 344 |
| `valor_total_estimado`: formato ponto sozinho (1234.56 / 746.815) | 1.533 |
| `valor_total_estimado`: formato ponto E virgula (1.234,56 ou 1,234.56) | 467 |
| `valor_total_estimado`: formato virgula sozinha (12,5) | 42 |
| `valor_total_homologado`: com prefixo R$ | 346 |
| `valor_total_homologado`: formato ponto sozinho (1234.56 / 746.815) | 1.523 |
| `valor_total_homologado`: formato ponto E virgula (1.234,56 ou 1,234.56) | 483 |
| `valor_total_homologado`: formato virgula sozinha (12,5) | 36 |

**Desafio 3 - datas**

| Problema | Registros afetados |
|---|---|
| `data_publicacao`: formato AAAA-MM-DDTHH:MM:SS | 1.319 |
| `data_publicacao`: formato DD-MM-AAAA | 138 |
| `data_publicacao`: formato DD/MM/AAAA HH:MM | 126 |
| `data_publicacao`: formato DD.MM.AAAA | 120 |
| `data_publicacao`: formato DD/MM/AAAA | 117 |
| `data_publicacao`: formato AAAA/MM/DD | 116 |
| `data_publicacao`: formato AAAAMMDD | 106 |
| `data_abertura_proposta`: formato AAAA-MM-DDTHH:MM:SS | 912 |
| `data_abertura_proposta`: formato AAAAMMDD | 95 |
| `data_abertura_proposta`: formato AAAA/MM/DD | 86 |
| `data_abertura_proposta`: formato DD/MM/AAAA HH:MM | 86 |
| `data_abertura_proposta`: formato DD-MM-AAAA | 85 |
| `data_abertura_proposta`: formato DD.MM.AAAA | 83 |
| `data_abertura_proposta`: formato DD/MM/AAAA | 78 |
| `data_abertura_proposta`: vazio | 617 |
| `data_encerramento_proposta`: formato AAAA-MM-DDTHH:MM:SS | 926 |
| `data_encerramento_proposta`: formato DD/MM/AAAA HH:MM | 101 |
| `data_encerramento_proposta`: formato DD.MM.AAAA | 84 |
| `data_encerramento_proposta`: formato AAAAMMDD | 83 |
| `data_encerramento_proposta`: formato DD/MM/AAAA | 78 |
| `data_encerramento_proposta`: formato AAAA/MM/DD | 78 |
| `data_encerramento_proposta`: formato DD-MM-AAAA | 75 |
| `data_encerramento_proposta`: vazio | 617 |
| `data_encerramento_proposta`: data impossivel ou ano fora de 2000-2030 | 65 |

**Desafios 4 e 5 - textos**

| Problema | Registros afetados |
|---|---|
| `razao_social_orgao`: espacos sobrando / sem quebra | 58 |
| `nome_unidade`: acento quebrado (Ã§, Ã£...) | 14 |
| `nome_unidade`: espacos sobrando / sem quebra | 63 |
| `objeto_compra`: acento quebrado (Ã§, Ã£...) | 43 |
| `objeto_compra`: espacos sobrando / sem quebra | 519 |
| `objeto_compra`: caracteres invisiveis | 1 |
| `processo`: nulo disfarcado (N/A, -, 0, SEM INFORMACAO...) | 77 |
| `processo`: espacos sobrando / sem quebra | 47 |

**Desafio 5 - nomes de orgao e modalidade (grafias distintas)**

| Problema | Registros afetados |
|---|---|
| `razao_social_orgao`: grafias distintas como vieram | 440 |
| `razao_social_orgao`: nomes distintos depois de padronizar | 352 |
| `modalidade_nome`: grafias distintas como vieram | 7 |
| `modalidade_id`: codigos distintos (a chave que vale) | 7 |

## 3. itens.csv

**Desafio 2 - quantidades e valores**

| Problema | Registros afetados |
|---|---|
| `quantidade`: com prefixo R$ | 1.148 |
| `quantidade`: formato ponto sozinho (1234.56 / 746.815) | 5.596 |
| `quantidade`: formato virgula sozinha (12,5) | 1.262 |
| `quantidade`: formato ponto E virgula (1.234,56 ou 1,234.56) | 219 |
| `valor_unitario_estimado`: com prefixo R$ | 1.188 |
| `valor_unitario_estimado`: formato ponto sozinho (1234.56 / 746.815) | 5.475 |
| `valor_unitario_estimado`: formato virgula sozinha (12,5) | 953 |
| `valor_unitario_estimado`: formato ponto E virgula (1.234,56 ou 1,234.56) | 649 |
| `valor_total_estimado`: com prefixo R$ | 1.171 |
| `valor_total_estimado`: formato ponto sozinho (1234.56 / 746.815) | 5.415 |
| `valor_total_estimado`: formato ponto E virgula (1.234,56 ou 1,234.56) | 1.303 |
| `valor_total_estimado`: formato virgula sozinha (12,5) | 359 |

**Desafios 4 e 5 - textos**

| Problema | Registros afetados |
|---|---|
| `descricao`: acento quebrado (Ã§, Ã£...) | 116 |
| `descricao`: espacos sobrando / sem quebra | 606 |
| `unidade_medida`: texto vazio | 9 |
| `unidade_medida`: espacos sobrando / sem quebra | 935 |
| `categoria_item`: nulo disfarcado (N/A, -, 0, SEM INFORMACAO...) | 7.077 |

**Outros pontos dos itens**

| Problema | Registros afetados |
|---|---|
| `sigiloso` = True (orcamento sigiloso) | 54 |
| `tem_resultado` = False | 852 |
| `unidade_medida`: grafias distintas como vieram | 360 |
| `unidade_medida`: grafias distintas depois de padronizar | 340 |

## 4. resultados.csv

**Desafio 1 - CNPJ/CPF do fornecedor**

| Problema | Registros afetados |
|---|---|
| `ni_fornecedor`: com mascara (. / -) | 1.633 |
| PJ com zero a esquerda perdido (menos de 14 digitos) | 194 |
| PF com zero a esquerda perdido (menos de 11 digitos) | 159 |
| `ni_fornecedor`: lixo/nulo (sem nenhum digito, fora PE) | 0 |
| `tipo_pessoa` PE (estrangeiro, documento nao e CNPJ/CPF) | 21 |
| Documentos distintos como vieram | 11.418 |

**Desafio 2 - quantidades e valores**

| Problema | Registros afetados |
|---|---|
| `quantidade_homologada`: com prefixo R$ | 2.561 |
| `quantidade_homologada`: formato ponto sozinho (1234.56 / 746.815) | 12.472 |
| `quantidade_homologada`: formato virgula sozinha (12,5) | 2.245 |
| `quantidade_homologada`: formato ponto E virgula (1.234,56 ou 1,234.56) | 1.179 |
| `valor_unitario_homologado`: com prefixo R$ | 2.650 |
| `valor_unitario_homologado`: formato ponto sozinho (1234.56 / 746.815) | 12.282 |
| `valor_unitario_homologado`: formato virgula sozinha (12,5) | 2.077 |
| `valor_unitario_homologado`: formato ponto E virgula (1.234,56 ou 1,234.56) | 1.537 |
| `valor_total_homologado`: com prefixo R$ | 2.647 |
| `valor_total_homologado`: formato ponto sozinho (1234.56 / 746.815) | 12.064 |
| `valor_total_homologado`: formato ponto E virgula (1.234,56 ou 1,234.56) | 3.142 |
| `valor_total_homologado`: formato virgula sozinha (12,5) | 690 |

**Desafio 3 - datas**

| Problema | Registros afetados |
|---|---|
| `data_resultado`: formato AAAA-MM-DD | 10.301 |
| `data_resultado`: formato AAAA/MM/DD | 960 |
| `data_resultado`: formato DD.MM.AAAA | 937 |
| `data_resultado`: formato DD/MM/AAAA HH:MM | 934 |
| `data_resultado`: formato DD/MM/AAAA | 929 |
| `data_resultado`: formato AAAAMMDD | 923 |
| `data_resultado`: formato DD-MM-AAAA | 912 |
| `data_cancelamento`: formato AAAA-MM-DDTHH:MM:SS | 62 |
| `data_cancelamento`: vazio | 15.834 |

**Desafios 4 e 5 - textos**

| Problema | Registros afetados |
|---|---|
| `nome_fornecedor`: acento quebrado (Ã§, Ã£...) | 1 |
| `nome_fornecedor`: espacos sobrando / sem quebra | 501 |
| `porte`: nulo disfarcado (N/A, -, 0, SEM INFORMACAO...) | 4.893 |

## 5. Cruzamentos (regras de negocio)

**Resultados e SRP**

| Problema | Registros afetados |
|---|---|
| Resultados cancelados (`data_cancelamento` preenchida) | 62 |
| Itens do itens.csv SEM nenhum resultado valido (descartados pela regra 3) | 852 |
| Itens com resultado valido | 6.225 |
| Itens com MAIS DE UM classificado valido (SRP) | 405 |
| Resultados com `ordem_classificacao_srp` vazia | 11.976 |

**Desafio 3 - coerencia temporal**

| Problema | Registros afetados |
|---|---|
| Resultados com `data_resultado` ANTERIOR a `data_publicacao` do edital | 234 |
