from sqlalchemy import inspect, text


REQUIRED_TABLES = (
    "eventi",
    "configurazione_eventi",
    "iscritti",
    "contabilita",
    "pagamenti_settimanali",
)

REQUIRED_COLUMNS = {
    "contabilita": {
        "NumeroMaglietteExtra",
        "ImportoMaglietteExtra",
    },
    "pagamenti_settimanali": {
        "PrezzoManuale",
        "TotaleManuale",
    },
}


def get_missing_tables(engine):
    with engine.connect() as connection:
        inspector = inspect(connection)
        existing = set(inspector.get_table_names())
        existing.update(inspector.get_table_names(schema="dbo"))
    return [table for table in REQUIRED_TABLES if table not in existing]


def get_missing_columns(engine):
    missing = []
    with engine.connect() as connection:
        inspector = inspect(connection)
        for table_name, required_columns in REQUIRED_COLUMNS.items():
            existing_columns = {
                column["name"]
                for column in inspector.get_columns(table_name, schema="dbo")
            }
            for column_name in sorted(required_columns.difference(existing_columns)):
                missing.append((table_name, column_name))
    return missing


def validate_required_schema(engine):
    missing_tables = get_missing_tables(engine)
    if missing_tables:
        missing = ", ".join(missing_tables)
        raise RuntimeError(
            "Schema Azure SQL incompleto. "
            f"Mancano le tabelle: {missing}. "
            "Esegui `python3 sql/00_apply_sql_scripts.py --ensure` prima di avviare l'app."
        )

    missing_columns = get_missing_columns(engine)
    if missing_columns:
        missing = ", ".join(f"{table}.{column}" for table, column in missing_columns)
        raise RuntimeError(
            "Schema Azure SQL incompleto. "
            f"Mancano le colonne richieste: {missing}. "
            "Esegui `python3 sql/00_apply_sql_scripts.py --ensure` prima di avviare l'app."
        )

    with engine.connect() as connection:
        config_count = connection.execute(
            text("SELECT COUNT(*) FROM [dbo].[configurazione_eventi]")
        ).scalar()

    if not config_count:
        raise RuntimeError(
            "Schema Azure SQL presente ma senza configurazione evento. "
            "Esegui `python3 sql/00_apply_sql_scripts.py --ensure` per caricare la configurazione iniziale."
        )
