# Script e utility

Le utility operative sono mantenute accanto alla webapp che le usa:

- `apps/pietro/assegna_squadre.py`: assegnazione squadre, con modalità dry-run prima della scrittura;
- `apps/pietro/genera_report.py`: export Excel ragazzi;
- `apps/animatori/genera_report_animatori.py`: export Excel animatori.

Tutte leggono `DB_SERVER`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` e `DB_ODBC_DRIVER` dall’ambiente. I file Excel generati sono esclusi dal `.gitignore`.

