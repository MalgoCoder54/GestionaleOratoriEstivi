#!/usr/bin/env python3
"""
Assegna squadre agli iscritti (nomi caricati da config_oratorio.json).
Bilanciamento per fascia d'età + genere. Fratelli in squadre diverse.

Uso:
  python assegna_squadre.py              # dry-run: mostra assegnazioni senza scrivere
  python assegna_squadre.py --applica    # scrive le squadre nel DB
"""

import json
import os
import random
import sys
from collections import defaultdict
from pathlib import Path

import pyodbc
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

DB_SERVER = os.environ["DB_SERVER"]
DB_NAME = os.environ.get("DB_NAME", "oratorio-estivo")
DB_USER = os.environ["DB_USER"]
DB_PASSWORD = os.environ["DB_PASSWORD"]
DB_DRIVER = os.environ.get("DB_ODBC_DRIVER", "ODBC Driver 18 for SQL Server")

_CONFIG_PATH = BASE_DIR / "config_oratorio.json"
with _CONFIG_PATH.open(encoding="utf-8") as _fh:
    SQUADRE = json.load(_fh)["squadre"]

CLASSE_ORDER = [
    "1° Elementare", "2° Elementare", "3° Elementare",
    "4° Elementare", "5° Elementare",
    "1° Media", "2° Media", "3° Media",
]


def connetti():
    return pyodbc.connect(
        f"DRIVER={{{DB_DRIVER}}};"
        f"SERVER={DB_SERVER};DATABASE={DB_NAME};"
        f"UID={DB_USER};PWD={DB_PASSWORD};"
        "Encrypt=yes;TrustServerCertificate=no"
    )


NOMI_FEMMINILI = {
    "giulia", "gaia", "sofia", "aurora", "viola", "greta", "alessia",
    "anna", "elena", "irene", "sara", "chiara", "beatrice", "emma",
    "noemi", "rebecca", "giorgia", "alice", "martina", "carlotta",
    "lavinia", "giada", "nives", "isabella", "lucia", "lea",
}


def genere_da_cf(cf):
    """Estrae M/F dal codice fiscale (giorno nascita > 40 = F)."""
    if not cf:
        return None
    cf = cf.strip()
    if len(cf) < 11:
        return None
    try:
        giorno = int(cf[9:11])
        return "F" if giorno > 40 else "M"
    except ValueError:
        return None


def genere_da_nome(nome):
    """Fallback: deduce genere dal primo nome."""
    if not nome:
        return None
    primo = nome.strip().split()[0].lower()
    if primo in NOMI_FEMMINILI:
        return "F"
    if primo.endswith("a") or primo.endswith("e"):
        return "F"
    return "M"


def identifica_famiglie(iscritti):
    """
    Raggruppa per LOWER(cognome) + LOWER(mail_ricevuta).
    Restituisce una mappa id_iscritto → family_key.
    """
    gruppi = defaultdict(list)
    for iso in iscritti:
        cognome = (iso["cognome"] or "").strip().lower()
        mail = (iso["mail_ricevuta"] or "").strip().lower()
        if cognome and mail:
            key = f"{cognome}||{mail}"
        else:
            key = f"__singolo__{iso['id']}"
        gruppi[key].append(iso["id"])

    famiglia_di = {}
    for key, membri in gruppi.items():
        if len(membri) > 1:
            for m in membri:
                famiglia_di[m] = key
    return famiglia_di, gruppi


def carica_iscritti(cursor, solo_senza_squadra=False):
    where = "WHERE i.Squadra IS NULL OR LTRIM(RTRIM(i.Squadra)) = ''" if solo_senza_squadra else ""
    cursor.execute(f"""
        SELECT i.ID, i.NomeRagazzo, i.CognomeRagazzo, i.ClasseFrequentata,
               i.CodiceFiscaleRagazzo, i.MailRicevuta, i.Squadra
        FROM dbo.iscritti i
        {where}
        ORDER BY i.ID
    """)
    result = []
    for r in cursor.fetchall():
        genere = genere_da_cf(r[4])
        result.append({
            "id": r[0],
            "nome": r[1],
            "cognome": r[2],
            "classe": r[3],
            "cf": r[4],
            "mail_ricevuta": r[5],
            "squadra_attuale": r[6],
            "genere": genere,
        })
    return result


def carica_contatori_esistenti(cursor):
    """Conta quanti M/F per classe per squadra tra chi ha già una squadra."""
    contatori = {s: defaultdict(lambda: defaultdict(int)) for s in SQUADRE}
    cursor.execute("""
        SELECT Squadra, ClasseFrequentata, CodiceFiscaleRagazzo
        FROM dbo.iscritti
        WHERE Squadra IS NOT NULL AND LTRIM(RTRIM(Squadra)) != ''
    """)
    for r in cursor.fetchall():
        sq, classe, cf = r[0], r[1], r[2]
        if sq not in contatori:
            continue
        genere = genere_da_cf(cf) or "M"
        contatori[sq][classe][genere] += 1
    return contatori


def squadra_migliore(classe, genere, contatori, escluse=None):
    """Restituisce la squadra con meno iscritti per quella combinazione classe+genere."""
    escluse = escluse or set()
    candidati = [s for s in SQUADRE if s not in escluse]
    if not candidati:
        candidati = list(SQUADRE)
    random.shuffle(candidati)
    return min(candidati, key=lambda s: contatori[s][classe][genere])


def assegna(iscritti, contatori, famiglia_di, gruppi_famiglia):
    """
    Algoritmo principale:
    1. Famiglie grandi prima (3+, poi 2)
    2. Singoli dopo
    """
    assegnazioni = {}
    squadre_famiglia = defaultdict(set)
    senza_genere = []

    for iso in iscritti:
        if iso["genere"] is None:
            senza_genere.append(iso)

    if senza_genere:
        print(f"\n  ATTENZIONE: {len(senza_genere)} iscritti senza CF valido, genere dedotto dal nome:")
        for iso in senza_genere:
            iso["genere"] = genere_da_nome(iso["nome"]) or "M"
            print(f"    - {iso['nome']} {iso['cognome']} (CF: {iso['cf']}) → {iso['genere']}")

    famiglie_ordinate = sorted(
        [(k, v) for k, v in gruppi_famiglia.items() if len(v) > 1],
        key=lambda x: -len(x[1])
    )

    for fam_key, membri_ids in famiglie_ordinate:
        membri = [iso for iso in iscritti if iso["id"] in membri_ids]
        random.shuffle(membri)

        for membro in membri:
            escluse = squadre_famiglia[fam_key]
            sq = squadra_migliore(membro["classe"], membro["genere"], contatori, escluse)
            assegnazioni[membro["id"]] = sq
            contatori[sq][membro["classe"]][membro["genere"]] += 1
            squadre_famiglia[fam_key].add(sq)

    singoli = [iso for iso in iscritti if iso["id"] not in assegnazioni]
    random.shuffle(singoli)

    for iso in singoli:
        sq = squadra_migliore(iso["classe"], iso["genere"], contatori)
        assegnazioni[iso["id"]] = sq
        contatori[sq][iso["classe"]][iso["genere"]] += 1

    return assegnazioni


def stampa_riepilogo(contatori, assegnazioni, iscritti, famiglia_di):
    print("\n" + "=" * 70)
    print("RIEPILOGO ASSEGNAZIONI")
    print("=" * 70)

    totali_squadra = {s: 0 for s in SQUADRE}

    header = f"{'Classe':<20}" + "".join(f"{'  ' + s + ' (M/F)':>16}" for s in SQUADRE)
    print(f"\n{header}")
    print("-" * (20 + 16 * len(SQUADRE)))

    for classe in CLASSE_ORDER:
        row = f"{classe:<20}"
        for sq in SQUADRE:
            m = contatori[sq][classe]["M"]
            f = contatori[sq][classe]["F"]
            row += f"{m:>6}M {f}F     "
            totali_squadra[sq] += m + f
        print(row)

    print("-" * (20 + 16 * len(SQUADRE)))
    tot_row = f"{'TOTALE':<20}"
    for sq in SQUADRE:
        tot_m = sum(contatori[sq][c]["M"] for c in CLASSE_ORDER)
        tot_f = sum(contatori[sq][c]["F"] for c in CLASSE_ORDER)
        tot_row += f"{tot_m:>6}M {tot_f}F     "
    print(tot_row)

    print(f"\nTotale per squadra: ", end="")
    print(" | ".join(f"{sq}: {totali_squadra[sq]}" for sq in SQUADRE))
    print(f"Totale generale: {sum(totali_squadra.values())}")

    collisioni = defaultdict(list)
    iso_map = {iso["id"]: iso for iso in iscritti}
    for iso_id, sq in assegnazioni.items():
        iso = iso_map.get(iso_id)
        if not iso:
            continue
        fam = famiglia_di.get(iso_id)
        if fam:
            collisioni[(fam, sq)].append(iso)

    fratelli_stessa_sq = {k: v for k, v in collisioni.items() if len(v) > 1}
    if fratelli_stessa_sq:
        print(f"\n  COLLISIONI FRATELLI ({len(fratelli_stessa_sq)}):")
        for (fam, sq), membri in fratelli_stessa_sq.items():
            nomi = ", ".join(f"{m['nome']} {m['cognome']} ({m['classe']})" for m in membri)
            print(f"    Squadra {sq}: {nomi}")
    else:
        print("\n  Nessuna collisione fratelli!")


def main():
    applica = "--applica" in sys.argv
    print(f"{'APPLICAZIONE' if applica else 'DRY-RUN'} — Assegnazione squadre")
    print(f"Squadre: {', '.join(SQUADRE)}\n")

    conn = connetti()
    cursor = conn.cursor()

    tutti = carica_iscritti(cursor, solo_senza_squadra=False)
    da_assegnare = [iso for iso in tutti if not iso["squadra_attuale"] or iso["squadra_attuale"].strip() == ""]
    gia_assegnati = [iso for iso in tutti if iso["squadra_attuale"] and iso["squadra_attuale"].strip() != ""]

    print(f"Iscritti totali: {len(tutti)}")
    print(f"Già assegnati: {len(gia_assegnati)}")
    print(f"Da assegnare: {len(da_assegnare)}")

    if not da_assegnare:
        print("\nNessun iscritto da assegnare!")
        conn.close()
        return

    famiglia_di, gruppi = identifica_famiglie(tutti)
    famiglie_multi = {k: v for k, v in gruppi.items() if len(v) > 1}
    print(f"Famiglie con 2+ fratelli: {len(famiglie_multi)}")

    contatori = carica_contatori_esistenti(cursor) if gia_assegnati else {
        s: defaultdict(lambda: defaultdict(int)) for s in SQUADRE
    }

    assegnazioni = assegna(da_assegnare, contatori, famiglia_di, gruppi)
    stampa_riepilogo(contatori, assegnazioni, tutti, famiglia_di)

    if applica:
        print("\nScrivo nel DB...")
        for iso_id, sq in assegnazioni.items():
            cursor.execute("UPDATE dbo.iscritti SET Squadra = ? WHERE ID = ?", sq, iso_id)
        conn.commit()
        print(f"Aggiornati {len(assegnazioni)} iscritti.")
    else:
        print("\n*** DRY-RUN: nessuna modifica al DB. Usa --applica per scrivere. ***")

    conn.close()


if __name__ == "__main__":
    main()
