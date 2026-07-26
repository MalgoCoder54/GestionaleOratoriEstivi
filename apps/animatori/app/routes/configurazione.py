from flask import Blueprint, g, jsonify, render_template, request

from ..config_manager import load_config, save_config

bp = Blueprint("configurazione", __name__)


def _actor_name():
    auth_user = getattr(g, "auth_user", None) or {}
    return auth_user.get("name") or "App"


@bp.route("/configurazione")
def config_page():
    return render_template("configurazione.html", config=load_config())


@bp.route("/api/config")
def api_get_config():
    return jsonify(load_config())


@bp.route("/api/config", methods=["PUT"])
def api_save_config():
    data = request.get_json(silent=True)
    try:
        save_config(data, modified_by=_actor_name())
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400
    return jsonify({"ok": True})
