# Gestionale Oratorio Estivo

Template riutilizzabile per organizzare iscrizioni, pagamenti, presenze e animatori di un oratorio estivo.

Il progetto contiene due webapp Flask separate ma collegate allo stesso Azure SQL Database:

- `apps/pietro`: gestionale ragazzi/iscritti, pagamenti, presenze, squadre, export e reporting;
- `apps/animatori`: anagrafica animatori, disponibilità settimanali, documenti, contributi e reporting.

L’architettura supporta il flusso opzionale:

```text
Google Forms -> Google Sheets o HTTP -> Power Automate -> Azure SQL -> Webapp
                                             |
                                             +-> email di conferma / ricevuta
```

È possibile usare anche Microsoft Forms al posto di Google Forms: le stored procedure SQL sono indipendenti dal provider del form.

## Cosa contiene

```text
oratorio-estivo-export/
├── apps/
│   ├── pietro/                  # Webapp ragazzi
│   └── animatori/               # Webapp animatori
├── config/                      # JSON di esempio per gli eventi
├── docs/                        # Architettura, sicurezza e Power Automate
├── infra/                       # Landing zone Azure in Bicep
├── sql/                         # Tabelle, viste, procedure, seed, permessi, test
├── scripts/                     # Utility e note operative
├── .env.example
└── .gitignore
```

Non sono inclusi dati di produzione, ricevute, report Excel/CSV, file `.env`, password, tenant, webhook o branding specifico.

## Avvio rapido

1. Copia `.env.example` oppure l’esempio nella singola app in `.env` e sostituisci tutti i placeholder.
2. Installa Python 3.11+, il driver ODBC 18 per SQL Server e le dipendenze:

```bash
cd apps/pietro
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python run.py
```

Per l’app animatori ripetere gli stessi comandi entrando in `apps/animatori`.

L’app valida lo schema SQL all’avvio. Per il primo avvio usare `VALIDATE_DB_SCHEMA_ON_STARTUP=false` solo durante un debug locale senza database completo; in ambienti reali lasciarlo `true`.

## Deploy Azure

1. Compilare e distribuire `infra/main.bicep` usando `infra/main.parameters.example.json` come base.
2. Creare l’utente SQL applicativo e applicare gli script seguendo `sql/README.md`.
3. Pubblicare le due cartelle `apps/` nelle rispettive App Service.
4. Abilitare Easy Auth e configurare Microsoft Entra ID prima di esporre le webapp a utenti reali.
5. Configurare i flow Power Automate da `docs/power-automate/`.

I nomi dell’evento, le date, gli importi, le classi, le taglie e le squadre sono dati di configurazione: il seed SQL contiene solo valori dimostrativi da sostituire.

## Sicurezza e privacy

Questa applicazione tratta dati di minori, contatti familiari e possibili informazioni sanitarie. Prima di usarla:

- definire titolare, responsabili, tempi di conservazione e base giuridica;
- limitare l’accesso con Entra ID, ruoli e principio del minimo privilegio;
- mantenere segreti e webhook in Key Vault/secret manager;
- usare dati sintetici nei test e impedire che report o export finiscano nel repository;
- configurare auditing, backup, retention e firewall Azure SQL.

Vedi `docs/privacy-security.md`.

## Licenza

Questo repository è un template applicativo. Aggiungere una licenza prima della pubblicazione, in base alle esigenze dell’oratorio o dell’organizzazione che lo adotta.

