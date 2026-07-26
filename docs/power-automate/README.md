# Power Automate

Questa cartella descrive flussi opzionali per automatizzare iscrizioni, import nel database e comunicazioni.

## Flussi consigliati

1. Import iscrizione ragazzi: Google Forms/Sheets o Microsoft Forms → stored procedure SQL.
2. Import animatore: form animatori → stored procedure nello schema `animatori`.
3. Email conferma iscrizione: dopo un import riuscito, invia una mail a `MailRicevuta`.
4. Email ricevuta o documenti: opzionale, usando il connettore email e un template approvato.
5. Reinvio conferma dalla webapp: trigger HTTP con body `{ "nome": "...", "cognome": "...", "email": "..." }`.

## Principi comuni

- tenere i flow in una Power Platform Solution quando possibile;
- usare una connessione SQL con il solo utente applicativo e permessi `EXECUTE` sulle procedure;
- usare `FormId + ResponseId` stabili: le stored procedure sono idempotenti sui retry;
- non inserire password o URL con firma in Compose, file JSON o repository;
- salvare la risposta SQL e gestire esplicitamente `Success`, `AlreadyImported` e `Message`;
- separare import, email e documenti in flow diversi se serve ritentare senza duplicare l’iscrizione.

Guide:

- [Google Forms / Google Sheets → Azure SQL](google-forms-to-sql.md)
- [Import animatori](animatori-import.md)
- [Email di conferma](email-confirmation.md)

Template payload:

- [payload-ragazzo.json](templates/payload-ragazzo.json)
- [payload-animatore.json](templates/payload-animatore.json)
- [email-conferma.html](templates/email-conferma.html)

