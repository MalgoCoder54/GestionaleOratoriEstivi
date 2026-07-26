from sqlalchemy.orm import selectinload
from flask import Blueprint, jsonify, render_template

from ..config_manager import get_current_event_id, load_config
from ..models import Contabilita, Iscritto

bp = Blueprint("reporting", __name__)


def _bool_label(value):
    return "SI" if value else "NO"


def _safe_text(value, fallback=""):
    if value is None:
        return fallback
    value = str(value).strip()
    return value or fallback


def _build_week_payload(contabilita, numero_settimane):
    weeks_by_number = {}
    if contabilita:
        weeks_by_number = {item.NumeroSettimana: item for item in contabilita.settimane}

    week_entries = []
    active_weeks = []
    paid_weeks = []

    for week_number in range(1, numero_settimane + 1):
        item = weeks_by_number.get(week_number)
        total = float(item.Totale or 0) if item else 0
        manual_total = float(item.TotaleManuale or 0) if item and item.TotaleManuale is not None else 0

        if contabilita and contabilita.Gratuita:
            active = True
            paid = True
        elif item:
            active = bool(
                item.Mattina
                or item.Pomeriggio
                or item.Pranzo
                or item.GitaSettimana
                or item.Pagato
                or item.PrezzoManuale
                or total > 0
                or manual_total > 0
            )
            paid = bool(item.Pagato)
        else:
            active = False
            paid = False

        if active:
            active_weeks.append(week_number)
        if paid:
            paid_weeks.append(week_number)

        week_entries.append(
            {
                "NumeroSettimana": week_number,
                "Attiva": active,
                "Pagata": paid,
                "Mattina": bool(item and item.Mattina),
                "Pomeriggio": bool(item and item.Pomeriggio),
                "Pranzo": bool(item and item.Pranzo),
                "GitaSettimana": bool(item and item.GitaSettimana),
            }
        )

    return week_entries, active_weeks, paid_weeks


def _serialize_row(iscritto, numero_settimane):
    contabilita = iscritto.contabilita
    week_entries, active_weeks, paid_weeks = _build_week_payload(contabilita, numero_settimane)

    return {
        "ID": iscritto.ID,
        "Cognome": _safe_text(iscritto.CognomeRagazzo),
        "Nome": _safe_text(iscritto.NomeRagazzo),
        "NomeCompleto": _safe_text(iscritto.nome_completo),
        "DataNascita": iscritto.DataNascitaRagazzo.isoformat() if iscritto.DataNascitaRagazzo else "",
        "CodiceFiscale": _safe_text(iscritto.CodiceFiscaleRagazzo),
        "ClasseFrequentata": _safe_text(iscritto.ClasseFrequentata, "Non indicata"),
        "Squadra": _safe_text(iscritto.Squadra, "Non assegnata"),
        "TagliaMaglietta": _safe_text(iscritto.TagliaMaglietta, "Non indicata"),
        "ResidenteA": _safe_text(iscritto.ResidenteA),
        "InVia": _safe_text(iscritto.InVia),
        "MailMamma": _safe_text(iscritto.MailMamma),
        "MailPapa": _safe_text(iscritto.MailPapa),
        "MailRicevuta": _safe_text(iscritto.MailRicevuta),
        "CellulareMamma": _safe_text(iscritto.CellulareMamma),
        "CellularePapa": _safe_text(iscritto.CellularePapa),
        "Navetta": bool(iscritto.Navetta),
        "NavettaLabel": _bool_label(bool(iscritto.Navetta)),
        "UscitaAutorizzata": bool(iscritto.UscitaAutorizzata),
        "UscitaAutorizzataLabel": _bool_label(bool(iscritto.UscitaAutorizzata)),
        "IscrizioneValidata": bool(iscritto.IscrizioneValidata),
        "IscrizioneValidataLabel": _bool_label(bool(iscritto.IscrizioneValidata)),
        "AllergieIntolleranze": _safe_text(iscritto.AllergieIntolleranze, "Nessuna"),
        "TerapieNote": _safe_text(iscritto.TerapieNote),
        "Gratuita": bool(contabilita and contabilita.Gratuita),
        "GratuitaLabel": _bool_label(bool(contabilita and contabilita.Gratuita)),
        "IscrizionePagata": bool(contabilita and contabilita.IscrizionePagata),
        "IscrizionePagataLabel": _bool_label(bool(contabilita and contabilita.IscrizionePagata)),
        "SettimaneAttive": active_weeks,
        "SettimaneAttiveLabel": ", ".join(str(item) for item in active_weeks),
        "SettimanePagate": paid_weeks,
        "SettimanePagateLabel": ", ".join(str(item) for item in paid_weeks),
        "weeks": week_entries,
    }


def _load_reporting_dataset():
    event_id = get_current_event_id()
    config = load_config()
    numero_settimane = config["settimane"]["numero_settimane"]

    iscritti = (
        Iscritto.query.options(
            selectinload(Iscritto.contabilita).selectinload(Contabilita.settimane)
        )
        .filter_by(ID_Evento=event_id)
        .order_by(Iscritto.CognomeRagazzo, Iscritto.NomeRagazzo)
        .all()
    )

    week_meta = []
    for week_number in range(1, numero_settimane + 1):
        start_date = ""
        if week_number - 1 < len(config["settimane"]["date_inizio"]):
            start_date = config["settimane"]["date_inizio"][week_number - 1]
        week_meta.append(
            {
                "numero": week_number,
                "label": f"Settimana {week_number}",
                "inizio": start_date,
            }
        )

    rows = [_serialize_row(iscritto, numero_settimane) for iscritto in iscritti]
    return event_id, config, week_meta, rows


@bp.route("/visualizzazione-dati")
def data_overview_page():
    return render_template("reporting_data.html")


@bp.route("/bi")
def bi_page():
    return render_template("reporting_bi.html")


@bp.route("/api/reporting/iscritti")
def api_reporting_iscritti():
    event_id, config, week_meta, rows = _load_reporting_dataset()
    return jsonify(
        {
            "evento": event_id,
            "rows": rows,
            "settimane": week_meta,
            "classi_disponibili": config.get("classi_disponibili", []),
            "squadre": config.get("squadre", []),
            "taglie_maglietta": config.get("taglie_maglietta", []),
        }
    )
