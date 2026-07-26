from datetime import date
from decimal import Decimal

from flask import Blueprint, g, jsonify, render_template, request

from ..config_manager import load_config
from ..models import DisponibilitaAnimatore, db
from ..request_context import get_animatore_or_404

bp = Blueprint("contributi", __name__)


def _actor_name():
    auth_user = getattr(g, "auth_user", None) or {}
    return auth_user.get("name") or "App"


def _coerce_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "si", "sì", "yes", "on"}
    return bool(value)


def _parse_decimal(value, field_name):
    if value in (None, ""):
        return Decimal("0.00")
    parsed = Decimal(str(value))
    if parsed < 0:
        raise ValueError(f"{field_name} non puo essere negativo.")
    return parsed


def _parse_int(value, field_name):
    if value in (None, ""):
        return 0
    parsed = Decimal(str(value))
    if parsed != parsed.to_integral_value() or parsed < 0:
        raise ValueError(f"{field_name} deve essere un intero non negativo.")
    return int(parsed)


def _recalculate(contributo):
    unit_price = Decimal(str(load_config()["importi_default"]["maglietta_extra"]))
    qty = int(contributo.NumeroMaglietteExtra or 0)
    contributo.ImportoMaglietteExtra = unit_price * Decimal(qty)
    contributo.TotaleDovuto = Decimal(str(contributo.ImportoContributo or 0)) + contributo.ImportoMaglietteExtra


@bp.route("/contributi/<int:id>")
def contributi_page(id):
    animatore = get_animatore_or_404(id)
    return render_template("contributi.html", animatore=animatore, config=load_config())


@bp.route("/api/animatori/<int:id>/contributo")
def api_get_contributo(id):
    animatore = get_animatore_or_404(id)
    contributo = animatore.contributo
    if not contributo:
        return jsonify({"error": "Nessun contributo"}), 404
    return jsonify({
        "ID": contributo.ID,
        "ImportoContributo": float(contributo.ImportoContributo or 0),
        "NumeroMaglietteExtra": int(contributo.NumeroMaglietteExtra or 0),
        "ImportoMaglietteExtra": float(contributo.ImportoMaglietteExtra or 0),
        "TotaleDovuto": float(contributo.TotaleDovuto or 0),
        "Pagato": contributo.Pagato,
        "DataPagamento": contributo.DataPagamento.isoformat() if contributo.DataPagamento else None,
        "MetodoPagamento": contributo.MetodoPagamento,
        "ContabileRicevuta": contributo.ContabileRicevuta,
        "NotePagamento": contributo.NotePagamento,
        "settimane": [{
            "ID": item.ID,
            "NumeroSettimana": item.NumeroSettimana,
            "Disponibile": item.Disponibile,
            "Presente": item.Presente,
            "InGita": item.InGita,
            "InOratorio": item.InOratorio,
            "NoteTurno": item.NoteTurno,
        } for item in animatore.settimane],
    })


@bp.route("/api/animatori/<int:id>/contributo", methods=["PUT"])
def api_update_contributo(id):
    animatore = get_animatore_or_404(id)
    contributo = animatore.contributo
    if not contributo:
        return jsonify({"error": "Nessun contributo"}), 404
    data = request.get_json(silent=True) or {}
    try:
        if "ImportoContributo" in data:
            contributo.ImportoContributo = _parse_decimal(data["ImportoContributo"], "ImportoContributo")
        if "NumeroMaglietteExtra" in data:
            contributo.NumeroMaglietteExtra = _parse_int(data["NumeroMaglietteExtra"], "NumeroMaglietteExtra")
        if "Pagato" in data:
            contributo.Pagato = _coerce_bool(data["Pagato"])
        if "ContabileRicevuta" in data:
            contributo.ContabileRicevuta = _coerce_bool(data["ContabileRicevuta"])
        if "MetodoPagamento" in data:
            contributo.MetodoPagamento = str(data["MetodoPagamento"] or "BONIFICO").strip() or "BONIFICO"
        if "NotePagamento" in data:
            contributo.NotePagamento = str(data["NotePagamento"] or "").strip() or None
        if "DataPagamento" in data:
            contributo.DataPagamento = date.fromisoformat(data["DataPagamento"]) if data["DataPagamento"] else None
    except (ArithmeticError, ValueError) as exc:
        return jsonify({"error": str(exc)}), 400
    if contributo.Pagato and not contributo.DataPagamento:
        contributo.DataPagamento = date.today()
    if not contributo.Pagato:
        contributo.DataPagamento = None
    _recalculate(contributo)
    contributo.ModificatoDa = _actor_name()
    db.session.commit()
    return jsonify({"ok": True})


@bp.route("/api/animatori/<int:id>/settimana/<int:num>", methods=["PUT"])
def api_update_settimana(id, num):
    animatore = get_animatore_or_404(id)
    config = load_config()
    if num < 1 or num > config["settimane"]["numero_settimane"]:
        return jsonify({"error": "Numero settimana non valido."}), 400
    settimana = DisponibilitaAnimatore.query.filter_by(ID_Animatore=animatore.ID, NumeroSettimana=num).first_or_404()
    data = request.get_json(silent=True) or {}
    for field in ("Disponibile", "Presente", "InGita", "InOratorio"):
        if field in data:
            setattr(settimana, field, _coerce_bool(data[field]))
    if "NoteTurno" in data:
        settimana.NoteTurno = str(data["NoteTurno"] or "").strip() or None
    settimana.ModificatoDa = _actor_name()
    db.session.commit()
    return jsonify({"ok": True})
