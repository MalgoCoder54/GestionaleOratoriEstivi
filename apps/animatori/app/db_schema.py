from sqlalchemy import inspect, text

REQUIRED_TABLES = (
    "eventi_animatori",
    "configurazione_animatori_eventi",
    "animatori",
    "contributi_animatori",
    "disponibilita_animatori",
    "import_animatori_forms_log",
)


def validate_required_schema(engine):
    with engine.connect() as connection:
        inspector = inspect(connection)
        existing = set(inspector.get_table_names(schema="animatori"))
        missing = [table for table in REQUIRED_TABLES if table not in existing]
        if missing:
            raise RuntimeError("Schema animatori incompleto. Mancano le tabelle: " + ", ".join(missing))
        config_count = connection.execute(text("SELECT COUNT(*) FROM [animatori].[configurazione_animatori_eventi]")).scalar()
        if not config_count:
            raise RuntimeError("Schema animatori presente ma senza configurazione evento. Esegui lo script di seed.")
