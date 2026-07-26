import os
import urllib.parse
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")


def _env_bool(name, default=False):
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


class Config:
    SECRET_KEY = os.environ.get("FLASK_SECRET_KEY")
    APP_DISPLAY_NAME = os.environ.get("APP_DISPLAY_NAME", "Oratorio Estivo - Ragazzi")
    ORGANIZATION_NAME = os.environ.get("ORGANIZATION_NAME", "Nome dell'oratorio")
    ORGANIZATION_LOCATION = os.environ.get("ORGANIZATION_LOCATION", "")
    BRAND_LOGO_PATH = os.environ.get("BRAND_LOGO_PATH", "img/logo.svg")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {
        "pool_pre_ping": True,
        "pool_recycle": 1800,
    }

    # Database: solo Azure SQL
    DB_SERVER = os.environ.get("DB_SERVER")
    DB_NAME = os.environ.get("DB_NAME", "oratorio-estivo")
    DB_USER = os.environ.get("DB_USER")
    DB_PASSWORD = os.environ.get("DB_PASSWORD")
    DB_ODBC_DRIVER = os.environ.get("DB_ODBC_DRIVER", "ODBC Driver 18 for SQL Server")
    DB_ENCRYPT = _env_bool("DB_ENCRYPT", True)
    DB_TRUST_SERVER_CERTIFICATE = _env_bool("DB_TRUST_SERVER_CERTIFICATE", False)
    VALIDATE_DB_SCHEMA_ON_STARTUP = _env_bool("VALIDATE_DB_SCHEMA_ON_STARTUP", True)

    # Azure App Service / Entra ID (Easy Auth)
    REQUIRE_EASY_AUTH = _env_bool("REQUIRE_EASY_AUTH", False)

    # Config cache
    CONFIG_CACHE_TTL_SECONDS = int(os.environ.get("CONFIG_CACHE_TTL_SECONDS", "15"))

    # Integrazioni esterne
    RESEND_CONFIRMATION_FLOW_URL = os.environ.get(
        "RESEND_CONFIRMATION_FLOW_URL",
        "",
    )
    RESEND_CONFIRMATION_FLOW_TIMEOUT_SECONDS = int(
        os.environ.get("RESEND_CONFIRMATION_FLOW_TIMEOUT_SECONDS", "15")
    )

    @classmethod
    def configure_app(cls, app):
        if not cls.SECRET_KEY:
            raise RuntimeError("FLASK_SECRET_KEY deve essere configurata tramite ambiente o .env.")
        missing = [
            key for key in ("DB_SERVER", "DB_USER", "DB_PASSWORD")
            if not getattr(cls, key)
        ]
        if missing:
            raise RuntimeError(
                "Configurazione Azure SQL incompleta. "
                f"Mancano: {', '.join(missing)}. "
                "Questa app usa solo Azure SQL; configura .env o le variabili d'ambiente."
            )

        params = (
            f"DRIVER={{{cls.DB_ODBC_DRIVER}}};"
            f"SERVER={cls.DB_SERVER};"
            f"DATABASE={cls.DB_NAME};"
            f"UID={cls.DB_USER};"
            f"PWD={cls.DB_PASSWORD};"
            f"Encrypt={'yes' if cls.DB_ENCRYPT else 'no'};"
            f"TrustServerCertificate={'yes' if cls.DB_TRUST_SERVER_CERTIFICATE else 'no'}"
        )
        app.config["SQLALCHEMY_DATABASE_URI"] = (
            "mssql+pyodbc:///?odbc_connect=" + urllib.parse.quote_plus(params)
        )
