-- =====================================================================================
-- 01_criar_banco.sql  -  STAR SCHEMA DA CONTROLADORIA PNCP (PostgreSQL)
-- =====================================================================================
-- 1 FATO (fato_item_contratado) + 4 DIMENSOES (orgao, fornecedor, modalidade, localidade).
-- O tempo NAO e tabela do banco: e o Calendario criado em DAX no Power BI.
--
-- COMO ESTE ARQUIVO E EXECUTADO: src/carregar.py chama banco.executar_script(), que remove os
-- comentarios (tudo depois de dois hifens) e separa os comandos pelo ponto e virgula.
-- Por isso: nao escreva ponto e virgula dentro de textos entre aspas, nem dois hifens seguidos em textos.
-- A carga recria o banco do zero a cada execucao (banco.recriar_banco), entao este script so cria tabelas.
-- Os DROP abaixo servem apenas para voce poder rodar o arquivo na mao no pgAdmin sem erro.
-- =====================================================================================

DROP TABLE IF EXISTS fato_item_contratado;
DROP TABLE IF EXISTS dim_orgao;
DROP TABLE IF EXISTS dim_fornecedor;
DROP TABLE IF EXISTS dim_modalidade;
DROP TABLE IF EXISTS dim_localidade;

-- -------------------------------------------------------------------------------------
-- DIMENSOES: descrevem QUEM / COMO / ONDE. Cada uma tem:
--   * sk_...  = chave SUBSTITUTA (PRIMARY KEY): um numero sem significado, gerado pelo pipeline
--   * a chave NATURAL (cnpj_orgao, ni_fornecedor...) protegida por UNIQUE: nao existem duas linhas iguais
-- -------------------------------------------------------------------------------------
CREATE TABLE dim_orgao (
    sk_orgao    INTEGER      PRIMARY KEY,
    cnpj_orgao  VARCHAR(14)  NOT NULL,
    nome_orgao  VARCHAR(300),
    poder       VARCHAR(20),
    CONSTRAINT uq_dim_orgao_cnpj UNIQUE (cnpj_orgao)
);

CREATE TABLE dim_fornecedor (
    sk_fornecedor    INTEGER       PRIMARY KEY,
    ni_fornecedor    VARCHAR(30)   NOT NULL,
    nome_fornecedor  VARCHAR(300),
    tipo_pessoa      VARCHAR(5),
    porte            VARCHAR(20),
    CONSTRAINT uq_dim_fornecedor_ni UNIQUE (ni_fornecedor)
);

CREATE TABLE dim_modalidade (
    sk_modalidade    INTEGER      PRIMARY KEY,
    modalidade_id    INTEGER      NOT NULL,
    nome_modalidade  VARCHAR(60)  NOT NULL,
    CONSTRAINT uq_dim_modalidade_id UNIQUE (modalidade_id)
);

CREATE TABLE dim_localidade (
    sk_localidade  INTEGER      PRIMARY KEY,
    uf_sigla       VARCHAR(10)  NOT NULL,
    uf_nome        VARCHAR(60),
    regiao         VARCHAR(20),
    CONSTRAINT uq_dim_localidade_uf UNIQUE (uf_sigla)
);

-- -------------------------------------------------------------------------------------
-- LINHA "NAO INFORMADO" (sk = -1) em cada dimensao.
-- Rede de seguranca: se algum dia faltar o dado, a fato aponta para -1 em vez de ficar com FK solta.
-- -1 fica FORA da sequencia 1, 2, 3... do pipeline, entao nunca colide. A chave natural '-1' (ou o id -1)
-- e um valor que nao existe nas outras linhas. Estas linhas NAO contam nas contagens esperadas.
-- -------------------------------------------------------------------------------------
INSERT INTO dim_orgao      (sk_orgao, cnpj_orgao, nome_orgao, poder)                         VALUES (-1, '-1', 'NÃO INFORMADO', 'Não informado');
INSERT INTO dim_fornecedor (sk_fornecedor, ni_fornecedor, nome_fornecedor, tipo_pessoa, porte) VALUES (-1, '-1', 'NÃO INFORMADO', NULL, NULL);
INSERT INTO dim_modalidade (sk_modalidade, modalidade_id, nome_modalidade)                   VALUES (-1, -1, 'Não informado');
INSERT INTO dim_localidade (sk_localidade, uf_sigla, uf_nome, regiao)                        VALUES (-1, '-1', 'Não informado', 'Não informado');

-- -------------------------------------------------------------------------------------
-- FATO: o que foi comprado. GRAO = 1 linha por item de contratacao (com o vencedor do item).
-- Dinheiro = DECIMAL(18,2)  |  preco unitario e quantidade = DECIMAL(18,4)  (nunca FLOAT para dinheiro)
-- -------------------------------------------------------------------------------------
CREATE TABLE fato_item_contratado (
    sk_fato                    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    numero_controle_pncp       VARCHAR(60)    NOT NULL,
    numero_item                INTEGER        NOT NULL,

    sk_orgao                   INTEGER        NOT NULL REFERENCES dim_orgao (sk_orgao),
    sk_fornecedor              INTEGER        NOT NULL REFERENCES dim_fornecedor (sk_fornecedor),
    sk_modalidade              INTEGER        NOT NULL REFERENCES dim_modalidade (sk_modalidade),
    sk_localidade              INTEGER        NOT NULL REFERENCES dim_localidade (sk_localidade),

    data_publicacao            DATE           NOT NULL,
    data_homologacao           DATE,                          -- vazia quando a regra 7 a anula

    descricao_item             TEXT,
    perfil_gasto               VARCHAR(30)    NOT NULL,

    quantidade                 DECIMAL(18,4)  NOT NULL,
    valor_unitario_estimado    DECIMAL(18,4)  NOT NULL,
    valor_unitario_homologado  DECIMAL(18,4)  NOT NULL,
    valor_total_estimado       DECIMAL(18,2)  NOT NULL,
    valor_total_homologado     DECIMAL(18,2)  NOT NULL,

    comparavel                 SMALLINT       NOT NULL,       -- 1 ou 0 (regra 6)
    economia_valor             DECIMAL(18,2),                 -- vazia nos itens nao comparaveis. PODE ser negativa (sobrepreco)
    dias_ciclo                 INTEGER,                       -- vazio quando nao ha ciclo

    -- GRAO: um item de uma contratacao so aparece uma vez
    CONSTRAINT uq_fato_item        UNIQUE (numero_controle_pncp, numero_item),

    -- SEGUNDA BARREIRA (a primeira e o Python): o banco recusa dados impossiveis
    CONSTRAINT ck_fato_quantidade  CHECK (quantidade > 0),
    CONSTRAINT ck_fato_sem_valor_negativo
        CHECK (valor_unitario_estimado >= 0 AND valor_unitario_homologado >= 0
               AND valor_total_estimado >= 0 AND valor_total_homologado >= 0),
    CONSTRAINT ck_fato_comparavel  CHECK (comparavel IN (0, 1)),
    CONSTRAINT ck_fato_perfil      CHECK (perfil_gasto IN ('Bens', 'Serviços', 'Obras e engenharia')),

    -- regras de negocio 6 e 7 dentro do banco
    CONSTRAINT ck_fato_economia_so_comparavel  CHECK (comparavel = 1 OR economia_valor IS NULL OR economia_valor = 0),
    CONSTRAINT ck_fato_cronologia  CHECK (data_homologacao IS NULL OR data_homologacao >= data_publicacao),
    CONSTRAINT ck_fato_ciclo       CHECK (dias_ciclo IS NULL OR dias_ciclo >= 0),
    CONSTRAINT ck_fato_ciclo_coerente  CHECK ((data_homologacao IS NULL) = (dias_ciclo IS NULL))
);

-- Indices nas chaves estrangeiras: aceleram os JOINs das 6 perguntas e o Power BI
CREATE INDEX idx_fato_orgao       ON fato_item_contratado (sk_orgao);
CREATE INDEX idx_fato_fornecedor  ON fato_item_contratado (sk_fornecedor);
CREATE INDEX idx_fato_modalidade  ON fato_item_contratado (sk_modalidade);
CREATE INDEX idx_fato_localidade  ON fato_item_contratado (sk_localidade);
