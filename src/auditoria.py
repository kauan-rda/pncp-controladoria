"""
auditoria.py  -  SPRINT 1: CONTAR OS PROBLEMAS DOS DADOS BRUTOS
================================================================
"""

import re
from datetime import datetime

import pandas as pd

from src import config, limpeza

RELATORIO = []                      # guarda cada linha impressa, para gravar no arquivo no final


def dizer(texto=""):
    print(texto)
    RELATORIO.append(texto)


def ler(nome):
    """Le o CSV tudo como texto, sem converter nada (assim enxergamos a sujeira original)."""
    return pd.read_csv(config.PASTA_RAW / f"{nome}.csv", dtype=str, keep_default_na=False)


def contar(serie, regra):
    """Quantos valores da coluna satisfazem a 'regra' (uma funcao que recebe o texto e devolve True/False)."""
    return int(serie.map(regra).sum())


def mostrar(titulo, linhas):
    """Imprime uma tabelinha markdown: problema | quantidade de registros."""
    dizer(f"\n**{titulo}**\n")
    dizer("| Problema | Registros afetados |")
    dizer("|---|---|")
    for descricao, quantidade in linhas:
        qtd = f"{quantidade:,}".replace(",", ".")          # 1234 -> 1.234 (so o numero, nao o texto)
        dizer(f"| {descricao} | {qtd} |")


# ---------------------------------------------------------------------------------------------
# REGRAS DE DETECCAO (cada uma devolve True quando o valor TEM o problema)
# ---------------------------------------------------------------------------------------------
def vazio(v):
    return v.strip() == ""


def nulo_disfarcado(v, zero_eh_nulo=True):
    """'N/A', 'NULL', '-', 'SEM INFORMACAO'... (o '0' so conta como nulo em campo de texto)."""
    chave = v.strip().upper()
    if chave == "":
        return False
    if chave == "0":
        return zero_eh_nulo
    return chave in limpeza.NULOS


def acento_quebrado(v):
    return limpeza.consertar_acento(v) != v           # se o conserto muda o texto, ele estava quebrado


def espaco_sujo(v):
    return v != " ".join(v.split())                   # espaco nas pontas, repetido ou 'sem quebra'


def invisivel(v):
    return any(c in v for c in "\u200b\u200c\u200d\ufeff")


def digitos(v):
    return re.sub(r"\D", "", v)


def doc_com_mascara(v):
    return bool(re.search(r"[./-]", v))


def doc_sem_zero(v, tamanho):
    d = digitos(v)
    return 0 < len(d) < tamanho


def numero_limpo(v):
    """Tira R$, espacos, parenteses e sinais, para olhar so os separadores."""
    return re.sub(r"[R$\s()\-]", "", v.replace("\xa0", ""))


def numero_tem_rs(v):
    return "R$" in v


def numero_negativo(v):
    t = v.replace("R$", "").strip()
    return t.startswith("(") or (t not in ("-", "") and (t.startswith("-") or t.endswith("-")))


def formato_numero(v):
    """Classifica o separador usado: ex. '1.234,56', '1,234.56', '12,5', '746.815'..."""
    t = numero_limpo(v)
    if t == "" or not re.search(r"\d", t):
        return None
    if "." in t and "," in t:
        return "ponto E virgula (1.234,56 ou 1,234.56)"
    if t.count(",") > 1 or t.count(".") > 1:
        return "separador repetido (1.234.567)"
    if "," in t:
        return "virgula sozinha (12,5)"
    if "." in t:
        return "ponto sozinho (1234.56 / 746.815)"
    return "inteiro sem separador"


PADROES_DATA = [
    ("AAAA-MM-DDTHH:MM:SS", r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}"),
    ("AAAA-MM-DD", r"^\d{4}-\d{2}-\d{2}$"),
    ("DD/MM/AAAA HH:MM", r"^\d{2}/\d{2}/\d{4} \d{2}:\d{2}"),
    ("DD/MM/AAAA", r"^\d{2}/\d{2}/\d{4}$"),
    ("DD-MM-AAAA", r"^\d{2}-\d{2}-\d{4}$"),
    ("DD.MM.AAAA", r"^\d{2}\.\d{2}\.\d{4}$"),
    ("AAAA/MM/DD", r"^\d{4}/\d{2}/\d{2}$"),
    ("AAAAMMDD", r"^\d{8}$"),
]


def formato_data(v):
    t = v.strip()
    for nome, padrao in PADROES_DATA:
        if re.search(padrao, t):
            return nome
    return None if t == "" else "outro formato"


def ler_data(v):
    """Tenta ler a data com os mesmos formatos do kit. Devolve None se for impossivel ou fora de 2000-2030."""
    t = v.strip()[:10]
    for formato in limpeza.FORMATOS_DATA:
        try:
            d = datetime.strptime(t, formato).date()
        except ValueError:
            continue
        return d if 2000 <= d.year <= 2030 else None
    return None


def padronizar(v):
    """Versao simplificada de padronizar_nome, so para contar quantas grafias distintas sobram."""
    return " ".join(limpeza.consertar_acento(v.strip()).upper().replace("-", " - ").split())


# ---------------------------------------------------------------------------------------------
# AUDITORIA
# ---------------------------------------------------------------------------------------------
def auditar_texto(df, colunas, zero_eh_nulo=True):
    linhas = []
    for c in colunas:
        linhas.append((f"`{c}`: texto vazio", contar(df[c], vazio)))
        linhas.append((f"`{c}`: nulo disfarcado (N/A, -, 0, SEM INFORMACAO...)", contar(df[c], lambda v: nulo_disfarcado(v, zero_eh_nulo))))
        linhas.append((f"`{c}`: acento quebrado (Ã§, Ã£...)", contar(df[c], acento_quebrado)))
        linhas.append((f"`{c}`: espacos sobrando / sem quebra", contar(df[c], espaco_sujo)))
        linhas.append((f"`{c}`: caracteres invisiveis", contar(df[c], invisivel)))
    return [(d, q) for d, q in linhas if q > 0]


def auditar_numeros(df, colunas):
    linhas = []
    for c in colunas:
        linhas.append((f"`{c}`: vazio", contar(df[c], vazio)))
        linhas.append((f"`{c}`: nulo disfarcado", contar(df[c], lambda v: nulo_disfarcado(v, zero_eh_nulo=False))))
        linhas.append((f"`{c}`: com prefixo R$", contar(df[c], numero_tem_rs)))
        linhas.append((f"`{c}`: negativo (parenteses ou sinal)", contar(df[c], numero_negativo)))
        for formato, qtd in df[c].map(formato_numero).value_counts().items():
            linhas.append((f"`{c}`: formato {formato}", int(qtd)))
    return [(d, q) for d, q in linhas if q > 0]


def auditar_datas(df, colunas):
    linhas = []
    for c in colunas:
        for formato, qtd in df[c].map(formato_data).value_counts().items():
            linhas.append((f"`{c}`: formato {formato}", int(qtd)))
        linhas.append((f"`{c}`: vazio", contar(df[c], vazio)))
        invalidas = contar(df[c], lambda v: v.strip() != "" and ler_data(v) is None)
        linhas.append((f"`{c}`: data impossivel ou ano fora de 2000-2030", invalidas))
    return [(d, q) for d, q in linhas if q > 0]


def main():
    compras, itens, resultados = ler("compras"), ler("itens"), ler("resultados")
    dizer("# Auditoria dos dados brutos (gerada por `python -m src.auditoria`)")

    # ---------------- visao geral
    dizer("\n## 1. Visao geral")
    dizer(f"\n- compras.csv: {len(compras)} linhas x {compras.shape[1]} colunas | numero_controle_pncp repetido: {compras['numero_controle_pncp'].duplicated().sum()}")
    dizer(f"- itens.csv: {len(itens)} linhas x {itens.shape[1]} colunas | chave (controle+item) repetida: {itens.duplicated(['numero_controle_pncp', 'numero_item']).sum()}")
    dizer(f"- resultados.csv: {len(resultados)} linhas x {resultados.shape[1]} colunas")

    # ---------------- compras
    dizer("\n## 2. compras.csv")
    dc = compras["cnpj_orgao"]
    mostrar("Desafio 1 - CNPJ do orgao", [
        ("`cnpj_orgao`: com mascara (. / -)", contar(dc, doc_com_mascara)),
        ("`cnpj_orgao`: zero a esquerda perdido (menos de 14 digitos)", contar(dc, lambda v: doc_sem_zero(v, 14))),
        ("`cnpj_orgao`: lixo/nulo (sem nenhum digito)", contar(dc, lambda v: digitos(v) == "")),
        ("CNPJ distintos como vieram", dc.nunique()),
        ("CNPJ distintos depois de so digitos + zeros (unidades reais)", dc.map(lambda v: digitos(v).zfill(14)).nunique()),
    ])
    mostrar("Desafio 2 - valores monetarios", auditar_numeros(compras, ["valor_total_estimado", "valor_total_homologado"]))
    mostrar("Desafio 3 - datas", auditar_datas(compras, ["data_publicacao", "data_abertura_proposta", "data_encerramento_proposta"]))
    mostrar("Desafios 4 e 5 - textos", auditar_texto(compras, ["razao_social_orgao", "nome_unidade", "objeto_compra", "uf_sigla", "uf_nome", "modalidade_nome", "processo", "numero_compra"]))
    mostrar("Desafio 5 - nomes de orgao e modalidade (grafias distintas)", [
        ("`razao_social_orgao`: grafias distintas como vieram", compras["razao_social_orgao"].nunique()),
        ("`razao_social_orgao`: nomes distintos depois de padronizar", compras["razao_social_orgao"].map(padronizar).nunique()),
        ("`modalidade_nome`: grafias distintas como vieram", compras["modalidade_nome"].nunique()),
        ("`modalidade_id`: codigos distintos (a chave que vale)", compras["modalidade_id"].nunique()),
    ])

    # ---------------- itens
    dizer("\n## 3. itens.csv")
    mostrar("Desafio 2 - quantidades e valores", auditar_numeros(itens, ["quantidade", "valor_unitario_estimado", "valor_total_estimado"]))
    mostrar("Desafios 4 e 5 - textos", auditar_texto(itens, ["descricao", "material_ou_servico", "unidade_medida", "categoria_item"]))
    mostrar("Outros pontos dos itens", [
        ("`sigiloso` = True (orcamento sigiloso)", int((itens["sigiloso"].str.lower() == "true").sum())),
        ("`tem_resultado` = False", int((itens["tem_resultado"].str.lower() == "false").sum())),
        ("`unidade_medida`: grafias distintas como vieram", itens["unidade_medida"].nunique()),
        ("`unidade_medida`: grafias distintas depois de padronizar", itens["unidade_medida"].map(padronizar).nunique()),
    ])

    # ---------------- resultados
    dizer("\n## 4. resultados.csv")
    pj, pf = resultados["tipo_pessoa"] == "PJ", resultados["tipo_pessoa"] == "PF"
    ni = resultados["ni_fornecedor"]
    mostrar("Desafio 1 - CNPJ/CPF do fornecedor", [
        ("`ni_fornecedor`: com mascara (. / -)", contar(ni, doc_com_mascara)),
        ("PJ com zero a esquerda perdido (menos de 14 digitos)", contar(ni[pj], lambda v: doc_sem_zero(v, 14))),
        ("PF com zero a esquerda perdido (menos de 11 digitos)", contar(ni[pf], lambda v: doc_sem_zero(v, 11))),
        ("`ni_fornecedor`: lixo/nulo (sem nenhum digito, fora PE)", contar(ni[resultados["tipo_pessoa"] != "PE"], lambda v: digitos(v) == "")),
        ("`tipo_pessoa` PE (estrangeiro, documento nao e CNPJ/CPF)", int((resultados["tipo_pessoa"] == "PE").sum())),
        ("Documentos distintos como vieram", ni.nunique()),
    ])
    mostrar("Desafio 2 - quantidades e valores", auditar_numeros(resultados, ["quantidade_homologada", "valor_unitario_homologado", "valor_total_homologado"]))
    mostrar("Desafio 3 - datas", auditar_datas(resultados, ["data_resultado", "data_cancelamento"]))
    mostrar("Desafios 4 e 5 - textos", auditar_texto(resultados, ["nome_fornecedor", "porte", "tipo_pessoa"]))

    # ---------------- cruzamentos
    dizer("\n## 5. Cruzamentos (regras de negocio)")
    pub = compras.set_index("numero_controle_pncp")["data_publicacao"].map(ler_data)
    data_res = resultados["data_resultado"].map(ler_data)
    data_pub = resultados["numero_controle_pncp"].map(pub)
    antes = [(r is not None and not pd.isna(r)) and (p is not None and not pd.isna(p)) and r < p
             for r, p in zip(data_res, data_pub)]
    cancelado = resultados["data_cancelamento"].str.strip() != ""
    vivos = resultados[~cancelado]
    por_item = vivos.groupby(["numero_controle_pncp", "numero_item"]).size()
    itens_com_resultado_vivo = len(por_item)
    mostrar("Resultados e SRP", [
        ("Resultados cancelados (`data_cancelamento` preenchida)", int(cancelado.sum())),
        ("Itens do itens.csv SEM nenhum resultado valido (descartados pela regra 3)", len(itens) - itens_com_resultado_vivo),
        ("Itens com resultado valido", itens_com_resultado_vivo),
        ("Itens com MAIS DE UM classificado valido (SRP)", int((por_item > 1).sum())),
        ("Resultados com `ordem_classificacao_srp` vazia", contar(resultados["ordem_classificacao_srp"], vazio)),
    ])
    mostrar("Desafio 3 - coerencia temporal", [
        ("Resultados com `data_resultado` ANTERIOR a `data_publicacao` do edital", int(sum(antes))),
    ])

    config.PASTA_REPORTS.mkdir(parents=True, exist_ok=True)
    destino = config.PASTA_REPORTS / "auditoria_dados_brutos.md"
    destino.write_text("\n".join(RELATORIO) + "\n", encoding="utf-8")
    print(f"\nRelatorio gravado em {destino}")


if __name__ == "__main__":
    main()
