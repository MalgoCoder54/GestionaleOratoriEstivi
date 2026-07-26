from datetime import date
from flask import Blueprint, jsonify, render_template, request

from ..config_manager import load_config
from ..models import db, Iscritto, PagamentoSettimanale
from ..request_context import get_current_event_id, get_iscritto_or_404

bp = Blueprint("api_mobile", __name__)


@bp.route("/mobile")
def mobile_page():
    return render_template("mobile/ricerca.html")


@bp.route("/api/mobile/cerca")
def api_mobile_cerca():
    evento = get_current_event_id()
    q = request.args.get("q", "").strip()

    query = Iscritto.query.filter_by(ID_Evento=evento)
    if q:
        like = f"%{q}%"
        query = query.filter(db.or_(
            Iscritto.NomeRagazzo.ilike(like),
            Iscritto.CognomeRagazzo.ilike(like),
        ))

    iscritti = (query
                .order_by(Iscritto.CognomeRagazzo, Iscritto.NomeRagazzo)
                .limit(200)
                .all())

    return jsonify([{
        "ID": i.ID,
        "NomeRagazzo": i.NomeRagazzo,
        "CognomeRagazzo": i.CognomeRagazzo,
    } for i in iscritti])


@bp.route("/api/mobile/iscritto/<int:id>")
def api_mobile_iscritto(id):
    iscritto = get_iscritto_or_404(id)
    data = iscritto.to_mobile_dict()

    # Determina settimana corrente e stato presenza
    config = load_config()
    date_inizio = config["settimane"]["date_inizio"]
    oggi = date.today()
    settimana_corrente = None

    for i, d in enumerate(date_inizio):
        inizio = date.fromisoformat(d)
        if i + 1 < len(date_inizio):
            fine = date.fromisoformat(date_inizio[i + 1])
        else:
            from datetime import timedelta
            fine = inizio + timedelta(days=7)

        if inizio <= oggi < fine:
            settimana_corrente = i + 1
            break

    data["settimana_corrente"] = settimana_corrente
    data["presenze_settimanali"] = []

    if iscritto.contabilita:
        settimane = {
            item.NumeroSettimana: item
            for item in iscritto.contabilita.settimane
        }
        for settimana in range(1, config["settimane"]["numero_settimane"] + 1):
            if iscritto.contabilita.Gratuita:
                presente = True
            else:
                presente = bool(settimane.get(settimana) and settimane[settimana].Pagato)
            data["presenze_settimanali"].append({
                "settimana": settimana,
                "presente": presente,
            })

        if iscritto.contabilita.Gratuita:
            data["stato_presenza"] = "Gratuita - Risulta presente"
            data["presente"] = True
        elif settimana_corrente:
            sett = PagamentoSettimanale.query.filter_by(
                ID_Contabilita=iscritto.contabilita.ID,
                NumeroSettimana=settimana_corrente
            ).first()
            if sett and sett.Pagato:
                data["stato_presenza"] = f"Settimana {settimana_corrente}: Risulta presente"
                data["presente"] = True
            else:
                data["stato_presenza"] = f"Settimana {settimana_corrente}: NON risulta presente"
                data["presente"] = False
        else:
            data["stato_presenza"] = "Nessuna settimana attiva"
            data["presente"] = None
    else:
        data["stato_presenza"] = "Dati contabili non disponibili"
        data["presente"] = None

    return jsonify(data)
