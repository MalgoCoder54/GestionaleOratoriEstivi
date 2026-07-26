from flask import Blueprint, jsonify, render_template, request

from ..config_manager import get_current_event_id, load_config
from ..models import Animatore, db
from ..request_context import get_animatore_or_404

bp = Blueprint("api_mobile", __name__)


@bp.route("/mobile")
def mobile_page():
    return render_template("mobile.html")


@bp.route("/api/mobile/cerca")
def api_mobile_cerca():
    evento = get_current_event_id()
    q = request.args.get("q", "").strip()
    query = Animatore.query.filter_by(ID_Evento=evento)
    if q:
        like = f"%{q}%"
        query = query.filter(db.or_(Animatore.Nome.ilike(like), Animatore.Cognome.ilike(like)))
    rows = query.order_by(Animatore.Cognome, Animatore.Nome).limit(200).all()
    return jsonify([{"ID": item.ID, "Nome": item.Nome, "Cognome": item.Cognome} for item in rows])


@bp.route("/api/mobile/animatore/<int:id>")
def api_mobile_animatore(id):
    animatore = get_animatore_or_404(id)
    config = load_config()
    settimane = {item.NumeroSettimana: item for item in animatore.settimane}
    return jsonify({
        "ID": animatore.ID,
        "Nome": animatore.Nome,
        "Cognome": animatore.Cognome,
        "Cellulare": animatore.Cellulare,
        "Maggiorenne": animatore.Maggiorenne,
        "Navetta": animatore.Navetta,
        "AllergieIntolleranze": animatore.AllergieIntolleranze,
        "TerapieNote": animatore.TerapieNote,
        "StatoOperativo": animatore.StatoOperativo,
        "settimane": [{
            "settimana": week,
            "label": config["settimane"]["etichette"][week - 1] if week - 1 < len(config["settimane"]["etichette"]) else f"Settimana {week}",
            "disponibile": bool(settimane.get(week) and settimane[week].Disponibile),
            "presente": bool(settimane.get(week) and settimane[week].Presente),
            "in_gita": bool(settimane.get(week) and settimane[week].InGita),
            "in_oratorio": bool(settimane.get(week) and settimane[week].InOratorio),
            "note": settimane.get(week).NoteTurno if settimane.get(week) else None,
        } for week in range(1, config["settimane"]["numero_settimane"] + 1)],
    })
