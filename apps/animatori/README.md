# App animatori

Webapp Flask separata per anagrafica, contributi, documenti e disponibilità degli animatori.

Funzioni principali:

- importazione idempotente dell’anagrafica da Power Automate;
- contatti, taglie, navetta, maggiore età e note sanitarie;
- stato documenti e stato operativo;
- contributo, magliette extra e ricevuta contabile;
- disponibilità, presenza, gite, turni e note per settimana;
- vista mobile, reporting ed export Excel.

L’app usa lo stesso Azure SQL Database dell’app ragazzi, ma opera esclusivamente nello schema `animatori`.

## Avvio

```bash
cd apps/animatori
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python run.py
```

In Azure App Service usare `sh startup_azure.sh` come startup command. Non inserire mai credenziali direttamente in `app/config.py`: la configurazione è interamente ambientale.

