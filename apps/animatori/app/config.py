import os
import urllib.parse
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")


class Config:
    SECRET_KEY = os.environ.get("FLASK_SECRET_KEY")
    APP_DISPLAY_NAME = os.environ.get("APP_DISPLAY_NAME", "Oratorio Estivo - Animatori")
    ORGANIZATION_NAME = os.environ.get("ORGANIZATION_NAME", "Nome dell'oratorio")
    ORGANIZATION_LOCATION = os.environ.get("ORGANIZATION_LOCATION", "")
    BRAND_LOGO_PATH = os.environ.get("BRAND_LOGO_PATH", "img/logo.svg")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {"pool_pre_ping": True, "pool_recycle": 1800}

    DB_SERVER = os.environ.get("DB_SERVER")
    DB_NAME = os.environ.get("DB_NAME", "oratorio-estivo")
    DB_USER = os.environ.get("DB_USER")
    DB_PASSWORD = os.environ.get("DB_PASSWORD")
    DB_ODBC_DRIVER = os.environ.get("DB_ODBC_DRIVER", "ODBC Driver 18 for SQL Server")
    DB_ENCRYPT = os.environ.get("DB_ENCRYPT", "true").strip().lower() in {"1", "true", "yes", "on"}
    DB_TRUST_SERVER_CERTIFICATE = os.environ.get("DB_TRUST_SERVER_CERTIFICATE", "false").strip().lower() in {"1", "true", "yes", "on"}
    REQUIRE_EASY_AUTH = os.environ.get("REQUIRE_EASY_AUTH", "false").strip().lower() in {"1", "true", "yes", "on"}
    VALIDATE_DB_SCHEMA_ON_STARTUP = os.environ.get("VALIDATE_DB_SCHEMA_ON_STARTUP", "true").strip().lower() in {"1", "true", "yes", "on"}
    CONFIG_CACHE_TTL_SECONDS = int(os.environ.get("CONFIG_CACHE_TTL_SECONDS", "15"))

    @classmethod
    def configure_app(cls, app):
        if not cls.SECRET_KEY:
            raise RuntimeError("FLASK_SECRET_KEY deve essere configurata tramite ambiente o .env.")
        missing = [key for key in ("DB_SERVER", "DB_USER", "DB_PASSWORD") if not getattr(cls, key)]
        if missing:
            raise RuntimeError("Configurazione Azure SQL incompleta. Mancano: " + ", ".join(missing))

        params = (
            "DRIVER={" + cls.DB_ODBC_DRIVER + "};"
            + "SERVER=" + cls.DB_SERVER + ";"
            + "DATABASE=" + cls.DB_NAME + ";"
            + "UID=" + cls.DB_USER + ";"
            + "PWD=" + cls.DB_PASSWORD + ";"
            + "Encrypt=" + ("yes" if cls.DB_ENCRYPT else "no") + ";"
            + "TrustServerCertificate=" + ("yes" if cls.DB_TRUST_SERVER_CERTIFICATE else "no")
        )
        app.config["SQLALCHEMY_DATABASE_URI"] = "mssql+pyodbc:///?odbc_connect=" + urllib.parse.quote_plus(params)
