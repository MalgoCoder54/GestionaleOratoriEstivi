"""Gestione configurazione evento letta e salvata direttamente su Azure SQL."""
from copy import deepcopy
from datetime import date, timedelta
import json
import os
import re
import time

from .models import ConfigurazioneEvento, Evento, db

_config_cache = None
_config_cache_ts = 0.0

DEFAULT_CONFIG = {
    "evento_corrente": os.environ.get("DEFAULT_EVENT_ID", "EVENTO_ESEMPIO"),
    "importi_default": {
        "iscrizione": 25.00,
        "mattina": 20.00,
        "pomeriggio": 20.00,
        "pranzo": 20.00,
    },
    "settimane": {
        "numero_settimane": 5,
        "date_inizio": [
            "2030-06-10", "2030-06-17", "2030-06-24", "2030-07-01", "2030-07-08",
        ],
        "gite": [
            {"nome": "Gita 1", "data": "2030-06-14", "settimana": 1, "importo": 30.00, "attiva": False},
            {"nome": "Gita 2", "data": "2030-06-21", "settimana": 2, "importo": 30.00, "attiva": False},
            {"nome": "Gita 3", "data": "2030-06-28", "settimana": 3, "importo": 30.00, "attiva": False},
            {"nome": "Gita 4", "data": "2030-07-05", "settimana": 4, "importo": 30.00, "attiva": False},
        ],
    },
    "classi_disponibili": [
        "1° Elementare", "2° Elementare", "3° Elementare",
        "4° Elementare", "5° Elementare",
        "1° Media", "2° Media", "3° Media",
    ],
    "taglie_maglietta": [
        "5/6 anni", "7/8 anni", "9/10 anni", "11/12 anni", "13/14 anni", "S", "M", "L",
    ],
    "squadre": ["Rossa", "Blu", "Gialla", "Verde"],
}


def _cache_ttl_seconds():
    from flask import current_app
    return int(current_app.config.get("CONFIG_CACHE_TTL_SECONDS", 15))


def _cache_is_valid():
    return _config_cache is not None and (time.time() - _config_cache_ts) < _cache_ttl_seconds()


def _reset_cache(normalized):
    global _config_cache, _config_cache_ts
    _config_cache = deepcopy(normalized)
    _config_cache_ts = time.time()


def _infer_year_from_event_id(event_id):
    match = re.search(r"(20\d{2})$", event_id or "")
    return int(match.group(1)) if match else date.today().year


def _default_event_name(event_id):
    year = _infer_year_from_event_id(event_id)
    return f"Oratorio Estivo {year}"


def _get_active_event():
    return (Evento.query
            .filter_by(Attivo=True)
            .order_by(Evento.Anno.desc(), Evento.ID_Evento.desc())
            .first())


def get_current_event_id():
    active_event = _get_active_event()
    if active_event:
        return active_event.ID_Evento

    fallback = (ConfigurazioneEvento.query
                .order_by(ConfigurazioneEvento.ID_Evento.desc())
                .first())
    if fallback:
        return fallback.ID_Evento

    return DEFAULT_CONFIG["evento_corrente"]


def load_config(force=False):
    if not force and _cache_is_valid():
        return deepcopy(_config_cache)

    event_id = get_current_event_id()
    row = ConfigurazioneEvento.query.filter_by(ID_Evento=event_id).first()
    if not row:
        raise RuntimeError(
            "Configurazione evento non trovata su Azure SQL. "
            "Esegui `python3 sql/00_apply_sql_scripts.py --ensure` per inizializzarla."
        )

    try:
        raw_config = json.loads(row.ConfigJson)
    except json.JSONDecodeError as exc:
        raise RuntimeError(
            f"ConfigJson non valido per l'evento {event_id}: {exc}"
        ) from exc

    normalized = normalize_config(raw_config)
    normalized["evento_corrente"] = event_id
    _reset_cache(normalized)
    return deepcopy(normalized)


def save_config(config, modified_by="App"):
    normalized = normalize_config(config)
    event_id = normalized["evento_corrente"]

    evento = Evento.query.filter_by(ID_Evento=event_id).first()
    if not evento:
        evento = Evento(
            ID_Evento=event_id,
            Nome=_default_event_name(event_id),
            Anno=_infer_year_from_event_id(event_id),
        )
        db.session.add(evento)

    Evento.query.filter(Evento.ID_Evento != event_id, Evento.Attivo == True).update(
        {"Attivo": False},
        synchronize_session=False,
    )
    evento.Attivo = True
    evento.NumeroSettimane = normalized["settimane"]["numero_settimane"]
    if normalized["settimane"]["date_inizio"]:
        evento.DataInizio = date.fromisoformat(normalized["settimane"]["date_inizio"][0])
        evento.DataFine = date.fromisoformat(normalized["settimane"]["date_inizio"][-1]) + timedelta(days=6)

    row = ConfigurazioneEvento.query.filter_by(ID_Evento=event_id).first()
    if not row:
        row = ConfigurazioneEvento(ID_Evento=event_id)
        db.session.add(row)

    payload = deepcopy(normalized)
    payload.pop("evento_corrente", None)
    row.ConfigJson = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    row.ModificatoDa = modified_by

    db.session.commit()
    normalized["evento_corrente"] = event_id
    _reset_cache(normalized)


def normalize_config(config):
    if not isinstance(config, dict):
        raise ValueError("La configurazione deve essere un oggetto JSON.")

    normalized = deepcopy(DEFAULT_CONFIG)

    evento_corrente = str(config.get("evento_corrente", normalized["evento_corrente"])).strip()
    normalized["evento_corrente"] = evento_corrente or normalized["evento_corrente"]

    importi_in = config.get("importi_default", {})
    if not isinstance(importi_in, dict):
        raise ValueError("importi_default deve essere un oggetto.")
    for key, default_value in normalized["importi_default"].items():
        value = importi_in.get(key, default_value)
        normalized["importi_default"][key] = round(float(value), 2)

    settimane_in = config.get("settimane", {})
    if not isinstance(settimane_in, dict):
        raise ValueError("settimane deve essere un oggetto.")

    numero_settimane = int(settimane_in.get(
        "numero_settimane",
        len(settimane_in.get("date_inizio", normalized["settimane"]["date_inizio"])),
    ))
    if numero_settimane < 1 or numero_settimane > 12:
        raise ValueError("numero_settimane deve essere compreso tra 1 e 12.")

    date_inizio = settimane_in.get("date_inizio", normalized["settimane"]["date_inizio"])
    if not isinstance(date_inizio, list):
        raise ValueError("settimane.date_inizio deve essere una lista.")
    cleaned_dates = [str(item).strip() for item in date_inizio if str(item).strip()]
    if len(cleaned_dates) != numero_settimane:
        raise ValueError("Il numero di date settimana deve coincidere con numero_settimane.")

    gite_in = settimane_in.get("gite", normalized["settimane"]["gite"])
    if not isinstance(gite_in, list):
        raise ValueError("settimane.gite deve essere una lista.")
    cleaned_gite = []
    for gita in gite_in:
        if not isinstance(gita, dict):
            raise ValueError("Ogni gita deve essere un oggetto.")
        settimana = int(gita.get("settimana", 0))
        if settimana < 1 or settimana > numero_settimane:
            raise ValueError("Ogni gita deve puntare a una settimana valida.")
        cleaned_gite.append({
            "nome": str(gita.get("nome", "")).strip() or f"Gita {settimana}",
            "data": str(gita.get("data", "")).strip(),
            "settimana": settimana,
            "importo": round(float(gita.get("importo", 0)), 2),
            "attiva": bool(gita.get("attiva", False)),
        })

    normalized["settimane"] = {
        "numero_settimane": numero_settimane,
        "date_inizio": cleaned_dates,
        "gite": cleaned_gite,
    }

    for key in ("classi_disponibili", "taglie_maglietta", "squadre"):
        values = config.get(key, normalized[key])
        if not isinstance(values, list):
            raise ValueError(f"{key} deve essere una lista.")
        normalized[key] = [str(value).strip() for value in values if str(value).strip()]

    return normalized
