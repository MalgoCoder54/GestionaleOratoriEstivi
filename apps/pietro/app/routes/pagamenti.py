from datetime import date
from decimal import Decimal

from flask import Blueprint, current_app, g, jsonify, render_template, request

from ..config_manager import load_config
from ..models import db, PagamentoSettimanale
from ..request_context import get_iscritto_or_404

bp = Blueprint("pagamenti", __name__)
EXTRA_SHIRT_UNIT_PRICE = Decimal("5.00")


def _money(value):
    return float(value or 0)


def _actor_name():
    auth_user = getattr(g, "auth_user", None) or {}
    return auth_user.get("name") or "App"


def _coerce_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "si", "sì", "yes", "on"}
    return bool(value)


def _parse_decimal(value, field_name, allow_null=False):
    if value in (None, ""):
        if allow_null:
            return None
        return Decimal("0.00")

    parsed = Decimal(str(value))
    if parsed < 0:
        raise ValueError(f"{field_name} non puo essere negativo.")
    return parsed


def _parse_non_negative_int(value, field_name):
    if value in (None, ""):
        return 0
    if isinstance(value, bool):
        raise ValueError(f"{field_name} non puo essere booleano.")

    parsed = Decimal(str(value))
    if parsed != parsed.to_integral_value():
        raise ValueError(f"{field_name} deve essere un numero intero.")
    if parsed < 0:
        raise ValueError(f"{field_name} non puo essere negativo.")
    return int(parsed)


def _recalculate_extra_shirt_total(contabilita):
    quantity = int(contabilita.NumeroMaglietteExtra or 0)
    if quantity < 0:
        quantity = 0
    contabilita.NumeroMaglietteExtra = quantity
    contabilita.ImportoMaglietteExtra = EXTRA_SHIRT_UNIT_PRICE * Decimal(quantity)


def _recalculate_settimana_total(settimana, contabilita, importi):
    if contabilita.Gratuita:
        settimana.Totale = Decimal("0.00")
        return

    if settimana.PrezzoManuale:
        manual_total = settimana.TotaleManuale
        if manual_total is None:
            manual_total = settimana.Totale or Decimal("0.00")
        settimana.TotaleManuale = Decimal(str(manual_total))
        settimana.Totale = Decimal(str(settimana.TotaleManuale))
        return

    total = Decimal("0.00")
    if settimana.Mattina:
        total += Decimal(str(importi["mattina"]))
    if settimana.Pomeriggio:
        total += Decimal(str(importi["pomeriggio"]))
    if settimana.Pranzo:
        total += Decimal(str(importi["pranzo"]))
    if settimana.GitaSettimana:
        total += Decimal(str(settimana.ImportoGita or 0))
    settimana.Totale = total


@bp.route("/pagamenti/<int:id>")
def pagamenti_page(id):
    iscritto = get_iscritto_or_404(id)
    config = load_config()
    return render_template("pagamenti.html", iscritto=iscritto, config=config)


@bp.route("/api/iscritti/<int:id>/contabilita")
def api_get_contabilita(id):
    iscritto = get_iscritto_or_404(id)
    cont = iscritto.contabilita
    if not cont:
        return jsonify({"error": "Nessuna contabilita"}), 404

    data = {
        "ID": cont.ID,
        "IscrizionePagata": cont.IscrizionePagata,
        "ImportoIscrizione": _money(cont.ImportoIscrizione),
        "DataPagamentoIscrizione": cont.DataPagamentoIscrizione.isoformat() if cont.DataPagamentoIscrizione else None,
        "NumeroMaglietteExtra": int(cont.NumeroMaglietteExtra or 0),
        "ImportoMaglietteExtra": _money(cont.ImportoMaglietteExtra),
        "Gratuita": cont.Gratuita,
        "settimane": []
    }

    for s in cont.settimane:
        data["settimane"].append({
            "ID": s.ID,
            "NumeroSettimana": s.NumeroSettimana,
            "Mattina": s.Mattina,
            "Pomeriggio": s.Pomeriggio,
            "Pranzo": s.Pranzo,
            "GitaSettimana": s.GitaSettimana,
            "ImportoGita": _money(s.ImportoGita),
            "Totale": _money(s.Totale),
            "PrezzoManuale": s.PrezzoManuale,
            "TotaleManuale": _money(s.TotaleManuale) if s.TotaleManuale is not None else None,
            "Pagato": s.Pagato,
            "DataPagamento": s.DataPagamento.isoformat() if s.DataPagamento else None,
        })

    return jsonify(data)


@bp.route("/api/iscritti/<int:id>/contabilita", methods=["PUT"])
def api_update_contabilita(id):
    iscritto = get_iscritto_or_404(id)
    cont = iscritto.contabilita
    if not cont:
        return jsonify({"error": "Nessuna contabilita"}), 404

    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return jsonify({"error": "Payload JSON non valido."}), 400

    try:
        if "IscrizionePagata" in data:
            cont.IscrizionePagata = _coerce_bool(data["IscrizionePagata"])
        if "ImportoIscrizione" in data:
            cont.ImportoIscrizione = _parse_decimal(data["ImportoIscrizione"], "ImportoIscrizione")
        if "DataPagamentoIscrizione" in data:
            val = data["DataPagamentoIscrizione"]
            cont.DataPagamentoIscrizione = date.fromisoformat(val) if val else None
        if "NumeroMaglietteExtra" in data:
            cont.NumeroMaglietteExtra = _parse_non_negative_int(
                data["NumeroMaglietteExtra"],
                "NumeroMaglietteExtra",
            )
        if "Gratuita" in data:
            cont.Gratuita = _coerce_bool(data["Gratuita"])
    except (ArithmeticError, ValueError) as exc:
        return jsonify({"error": f"Dati contabilita non validi: {exc}"}), 400

    _recalculate_extra_shirt_total(cont)

    if cont.IscrizionePagata and not cont.DataPagamentoIscrizione:
        cont.DataPagamentoIscrizione = date.today()
    if not cont.IscrizionePagata:
        cont.DataPagamentoIscrizione = None

    importi = load_config()["importi_default"]
    for settimana in cont.settimane:
        _recalculate_settimana_total(settimana, cont, importi)
        settimana.ModificatoDa = _actor_name()
    cont.ModificatoDa = _actor_name()

    db.session.commit()
    return jsonify({"ok": True})


@bp.route("/api/iscritti/<int:id>/settimana/<int:num>", methods=["PUT"])
def api_update_settimana(id, num):
    iscritto = get_iscritto_or_404(id)
    cont = iscritto.contabilita
    if not cont:
        return jsonify({"error": "Nessuna contabilita"}), 404

    config = load_config()
    numero_settimane = config["settimane"]["numero_settimane"]
    if num < 1 or num > numero_settimane:
        return jsonify({"error": "Numero settimana non valido."}), 400

    sett = PagamentoSettimanale.query.filter_by(
        ID_Contabilita=cont.ID, NumeroSettimana=num
    ).first_or_404()

    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return jsonify({"error": "Payload JSON non valido."}), 400

    importi = config["importi_default"]

    try:
        if "Mattina" in data:
            sett.Mattina = _coerce_bool(data["Mattina"])
        if "Pomeriggio" in data:
            sett.Pomeriggio = _coerce_bool(data["Pomeriggio"])
        if "Pranzo" in data:
            sett.Pranzo = _coerce_bool(data["Pranzo"])
        if "GitaSettimana" in data:
            sett.GitaSettimana = _coerce_bool(data["GitaSettimana"])
        if "ImportoGita" in data:
            sett.ImportoGita = _parse_decimal(data["ImportoGita"], "ImportoGita")
        if "PrezzoManuale" in data:
            sett.PrezzoManuale = _coerce_bool(data["PrezzoManuale"])
        if "TotaleManuale" in data:
            sett.TotaleManuale = _parse_decimal(
                data["TotaleManuale"],
                "TotaleManuale",
                allow_null=True,
            )
        if "Pagato" in data:
            sett.Pagato = _coerce_bool(data["Pagato"])
        if "DataPagamento" in data:
            val = data["DataPagamento"]
            sett.DataPagamento = date.fromisoformat(val) if val else None
    except (ArithmeticError, ValueError) as exc:
        return jsonify({"error": f"Dati settimana non validi: {exc}"}), 400

    if sett.Pagato and not sett.DataPagamento:
        sett.DataPagamento = date.today()
    if not sett.Pagato:
        sett.DataPagamento = None

    _recalculate_settimana_total(sett, cont, importi)
    sett.ModificatoDa = _actor_name()

    db.session.commit()
    return jsonify({"ok": True, "totale": _money(sett.Totale)})
