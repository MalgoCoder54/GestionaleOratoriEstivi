from copy import deepcopy
from datetime import date, timedelta
import json
import os
import re
import time

from .models import ConfigurazioneAnimatoriEvento, EventoAnimatori, db

_config_cache = None
_config_cache_ts = 0.0

DEFAULT_CONFIG = {
    "evento_corrente": os.environ.get("DEFAULT_EVENT_ID", "EVENTO_ESEMPIO"),
    "importi_default": {
        "contributo": 25.00,
        "maglietta_extra": 5.00,
    },
    "settimane": {
        "numero_settimane": 5,
        "date_inizio": ["2030-06-10", "2030-06-17", "2030-06-24", "2030-07-01", "2030-07-08"],
        "etichette": [
            "1^ sett. (08-12 giugno)",
            "2^ sett. (15-19 giugno)",
            "3^ sett. (22-26 giugno)",
            "4^ sett. (29 giugno-03 luglio)",
            "5^ sett. (06-10 luglio)",
        ],
        "gite": [],
    },
    "taglie_maglietta": ["XS", "S", "M", "L", "XL", "2XL", "3XL"],
    "taglie_pantaloncini": ["S", "M", "L", "XL", "2XL"],
    "stati_documenti": ["INVIATI", "FIRMATI_RICEVUTI", "DA_INVIARE"],
    "stati_operativi": ["IN_ATTESA_FIRMA", "IMPORTATO", "ATTIVO", "SOSPESO", "RITIRATO"],
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
    return f"Animatori - {_infer_year_from_event_id(event_id)}"


def get_current_event_id():
    active_event = (
        EventoAnimatori.query.filter_by(Attivo=True)
        .order_by(EventoAnimatori.Anno.desc(), EventoAnimatori.ID_Evento.desc())
        .first()
    )
    if active_event:
        return active_event.ID_Evento
    fallback = ConfigurazioneAnimatoriEvento.query.order_by(ConfigurazioneAnimatoriEvento.ID_Evento.desc()).first()
    return fallback.ID_Evento if fallback else DEFAULT_CONFIG["evento_corrente"]


def load_config(force=False):
    if not force and _cache_is_valid():
        return deepcopy(_config_cache)

    event_id = get_current_event_id()
    row = ConfigurazioneAnimatoriEvento.query.filter_by(ID_Evento=event_id).first()
    if not row:
        raise RuntimeError("Configurazione animatori non trovata. Esegui gli script SQL di seed prima di avviare l'app.")

    normalized = normalize_config(json.loads(row.ConfigJson))
    normalized["evento_corrente"] = event_id
    _reset_cache(normalized)
    return deepcopy(normalized)


def save_config(config, modified_by="App"):
    normalized = normalize_config(config)
    event_id = normalized["evento_corrente"]

    evento = EventoAnimatori.query.filter_by(ID_Evento=event_id).first()
    if not evento:
        evento = EventoAnimatori(ID_Evento=event_id, Nome=_default_event_name(event_id), Anno=_infer_year_from_event_id(event_id))
        db.session.add(evento)

    EventoAnimatori.query.filter(EventoAnimatori.ID_Evento != event_id, EventoAnimatori.Attivo == True).update(
        {"Attivo": False},
        synchronize_session=False,
    )
    evento.Attivo = True
    evento.NumeroSettimane = normalized["settimane"]["numero_settimane"]
    evento.DataInizio = date.fromisoformat(normalized["settimane"]["date_inizio"][0])
    evento.DataFine = date.fromisoformat(normalized["settimane"]["date_inizio"][-1]) + timedelta(days=4)

    row = ConfigurazioneAnimatoriEvento.query.filter_by(ID_Evento=event_id).first()
    if not row:
        row = ConfigurazioneAnimatoriEvento(ID_Evento=event_id)
        db.session.add(row)

    payload = deepcopy(normalized)
    payload.pop("evento_corrente", None)
    row.ConfigJson = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    row.ModificatoDa = modified_by
    db.session.commit()
    _reset_cache(normalized)


def normalize_config(config):
    if not isinstance(config, dict):
        raise ValueError("La configurazione deve essere un oggetto JSON.")

    normalized = deepcopy(DEFAULT_CONFIG)
    normalized["evento_corrente"] = str(config.get("evento_corrente", normalized["evento_corrente"])).strip() or normalized["evento_corrente"]

    importi_in = config.get("importi_default", {})
    for key, default_value in normalized["importi_default"].items():
        normalized["importi_default"][key] = round(float(importi_in.get(key, default_value)), 2)

    settimane_in = config.get("settimane", {})
    date_inizio = [str(item).strip() for item in settimane_in.get("date_inizio", normalized["settimane"]["date_inizio"]) if str(item).strip()]
    numero_settimane = int(settimane_in.get("numero_settimane", len(date_inizio)))
    if numero_settimane < 1 or numero_settimane > 12:
        raise ValueError("numero_settimane deve essere compreso tra 1 e 12.")
    if len(date_inizio) != numero_settimane:
        raise ValueError("Il numero di date settimana deve coincidere con numero_settimane.")

    etichette = settimane_in.get("etichette", normalized["settimane"]["etichette"])
    etichette = [str(item).strip() for item in etichette if str(item).strip()]
    if len(etichette) != numero_settimane:
        etichette = [f"Settimana {index}" for index in range(1, numero_settimane + 1)]

    gite = []
    for item in settimane_in.get("gite", []):
        if not isinstance(item, dict):
            raise ValueError("Ogni gita deve essere un oggetto.")
        settimana = int(item.get("settimana", 0))
        if settimana < 1 or settimana > numero_settimane:
            raise ValueError("Ogni gita deve puntare a una settimana valida.")
        gite.append({
            "nome": str(item.get("nome", "")).strip() or f"Gita settimana {settimana}",
            "data": str(item.get("data", "")).strip(),
            "settimana": settimana,
            "attiva": bool(item.get("attiva", False)),
        })

    normalized["settimane"] = {
        "numero_settimane": numero_settimane,
        "date_inizio": date_inizio,
        "etichette": etichette,
        "gite": gite,
    }

    for key in ("taglie_maglietta", "taglie_pantaloncini", "stati_documenti", "stati_operativi"):
        values = config.get(key, normalized[key])
        if not isinstance(values, list):
            raise ValueError(f"{key} deve essere una lista.")
        normalized[key] = [str(value).strip() for value in values if str(value).strip()]

    return normalized
