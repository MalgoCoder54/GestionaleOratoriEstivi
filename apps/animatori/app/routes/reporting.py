from sqlalchemy.orm import selectinload
from flask import Blueprint, jsonify, render_template

from ..config_manager import get_current_event_id, load_config
from ..models import Animatore, ContributoAnimatore

bp = Blueprint("reporting", __name__)


def _safe(value, fallback=""):
    if value is None:
        return fallback
    text = str(value).strip()
    return text or fallback


def _serialize(animatore, numero_settimane):
    contributo = animatore.contributo
    settimane = {item.NumeroSettimana: item for item in animatore.settimane}
    disponibili = []
    presenti = []
    gita = []
    for week in range(1, numero_settimane + 1):
        item = settimane.get(week)
        if item and item.Disponibile:
            disponibili.append(week)
        if item and item.Presente:
            presenti.append(week)
        if item and item.InGita:
            gita.append(week)
    return {
        "ID": animatore.ID,
        "Cognome": _safe(animatore.Cognome),
        "Nome": _safe(animatore.Nome),
        "NomeCompleto": animatore.nome_completo,
        "CodiceFiscale": _safe(animatore.CodiceFiscale),
        "Cellulare": _safe(animatore.Cellulare),
        "EmailModuli": _safe(animatore.EmailModuli),
        "Maggiorenne": bool(animatore.Maggiorenne),
        "MaggiorenneLabel": "SI" if animatore.Maggiorenne else "NO",
        "Navetta": bool(animatore.Navetta),
        "NavettaLabel": "SI" if animatore.Navetta else "NO",
        "TagliaMaglietta": _safe(animatore.TagliaMaglietta, "Non indicata"),
        "TagliaPantaloncini": _safe(animatore.TagliaPantaloncini, "Non indicata"),
        "StatoDocumenti": _safe(animatore.StatoDocumenti),
        "StatoOperativo": _safe(animatore.StatoOperativo),
        "Pagato": bool(contributo and contributo.Pagato),
        "PagatoLabel": "SI" if contributo and contributo.Pagato else "NO",
        "ContabileRicevuta": bool(contributo and contributo.ContabileRicevuta),
        "TotaleDovuto": float(contributo.TotaleDovuto or 0) if contributo else 0,
        "SettimaneDisponibili": disponibili,
        "SettimaneDisponibiliLabel": ", ".join(str(item) for item in disponibili),
        "SettimanePresenti": presenti,
        "SettimaneGita": gita,
        "AllergieIntolleranze": _safe(animatore.AllergieIntolleranze, "Nessuna"),
    }


def _dataset():
    config = load_config()
    numero_settimane = config["settimane"]["numero_settimane"]
    rows = (
        Animatore.query.options(selectinload(Animatore.contributo), selectinload(Animatore.settimane))
        .filter_by(ID_Evento=get_current_event_id())
        .order_by(Animatore.Cognome, Animatore.Nome)
        .all()
    )
    return config, [_serialize(item, numero_settimane) for item in rows]


@bp.route("/visualizzazione-dati")
def data_page():
    return render_template("reporting_data.html")


@bp.route("/bi")
def bi_page():
    return render_template("reporting_bi.html")


@bp.route("/api/reporting/animatori")
def api_reporting_animatori():
    config, rows = _dataset()
    return jsonify({
        "rows": rows,
        "settimane": config["settimane"],
        "taglie_maglietta": config["taglie_maglietta"],
        "taglie_pantaloncini": config["taglie_pantaloncini"],
        "stati_documenti": config["stati_documenti"],
        "stati_operativi": config["stati_operativi"],
    })
