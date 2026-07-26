# App ragazzi

Webapp Flask per la gestione degli iscritti all’oratorio estivo.

Funzioni principali:

- anagrafica iscritti e familiari;
- validazione iscrizioni, allergie/note, navetta e uscita autorizzata;
- configurazione evento, settimane, gite, classi, taglie e squadre;
- contabilita iscrizione, servizi settimanali, gite, gratuità e magliette extra;
- vista mobile per ricerca rapida;
- report Excel, vista dati e grafici;
- assegnazione squadre opzionale con `assegna_squadre.py`.

## Configurazione

La webapp usa esclusivamente Azure SQL tramite le variabili in `.env.example`. Il database è condiviso con l’app animatori, ma l’app ragazzi usa lo schema `dbo` e le tabelle principali.

Il webhook di reinvio email è opzionale: impostare `RESEND_CONFIRMATION_FLOW_URL` solo dopo aver creato il flow Power Automate corrispondente. Se vuoto, il pulsante non viene mostrato.

## Avvio

```bash
cd apps/pietro
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python run.py
```

In Azure App Service usare `sh startup_azure.sh` come startup command.

