from pathlib import Path

from flask import Flask, url_for
from flask_wtf.csrf import CSRFProtect

from .auth import init_auth
from .config import Config
from .db_schema import validate_required_schema
from .models import db

csrf = CSRFProtect()


def _compute_asset_version(static_dir: Path) -> str:
    latest_mtime = 0
    for path in static_dir.rglob("*"):
        if path.is_file():
            latest_mtime = max(latest_mtime, int(path.stat().st_mtime))
    return str(latest_mtime or 1)


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)
    Config.configure_app(app)
    app.config["WTF_CSRF_HEADERS"] = ["X-CSRFToken"]
    app.config["ASSET_VERSION"] = _compute_asset_version(Path(app.static_folder))

    db.init_app(app)
    csrf.init_app(app)
    init_auth(app)

    from .routes import anagrafica, api, configurazione, contributi, reporting
    app.register_blueprint(anagrafica.bp)
    app.register_blueprint(contributi.bp)
    app.register_blueprint(configurazione.bp)
    app.register_blueprint(api.bp)
    app.register_blueprint(reporting.bp)

    with app.app_context():
        if app.config.get("VALIDATE_DB_SCHEMA_ON_STARTUP", True):
            validate_required_schema(db.engine)

    @app.context_processor
    def inject_asset_helpers():
        def static_asset(filename):
            return url_for("static", filename=filename, v=app.config["ASSET_VERSION"])
        return {
            "static_asset": static_asset,
            "asset_version": app.config["ASSET_VERSION"],
            "app_display_name": app.config["APP_DISPLAY_NAME"],
            "organization_name": app.config["ORGANIZATION_NAME"],
            "organization_location": app.config["ORGANIZATION_LOCATION"],
            "brand_logo_path": app.config["BRAND_LOGO_PATH"],
        }

    @app.after_request
    def add_no_cache_headers(response):
        if response.mimetype == "text/html":
            response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
            response.headers["Pragma"] = "no-cache"
            response.headers["Expires"] = "0"
        return response

    return app
