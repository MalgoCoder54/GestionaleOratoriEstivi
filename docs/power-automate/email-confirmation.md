# Email automatiche

L’email può essere parte dello stesso flow di import oppure di un flow separato. Separarla è utile quando una nuova prova dell’email non deve reinserire il ragazzo.

## Email dopo l’iscrizione

Struttura consigliata:

1. Trigger del form/Google Sheet/HTTP.
2. Import SQL tramite `dbo.usp_ImportaIscrittoDaForms`.
3. Condizione: inviare la mail solo quando `Success=true` e `AlreadyImported=false`.
4. Determinare l’indirizzo `MailRicevuta`; se vuoto, usare un indirizzo genitore validato secondo la policy dell’oratorio oppure terminare con stato “da verificare”.
5. `Send an email (V2)` con il template `templates/email-conferma.html`.
6. Registrare l’esito in una tabella/log dedicato o in una colonna di controllo, se si vuole evitare un reinvio accidentale.

## Reinvio dalla webapp

Il pulsante opzionale della webapp ragazzi invia al webhook un JSON minimale:

```json
{
  "nome": "...",
  "cognome": "...",
  "email": "..."
}
```

Per abilitarlo:

1. crea un flow con trigger `When an HTTP request is received`;
2. aggiungi l’azione email usando i tre campi del body;
3. proteggi l’URL del trigger in Key Vault/App Settings;
4. imposta `RESEND_CONFIRMATION_FLOW_URL` nell’App Service della webapp ragazzi.

Se l’URL è vuoto, il pulsante non viene mostrato.

## Contenuto minimo della mail

- nome del ragazzo/a;
- riepilogo dell’avvenuta ricezione, non una promessa di validazione;
- contatto dell’oratorio configurato dal gestore;
- informativa privacy e istruzioni per correzioni;
- nessun dato sanitario non necessario nel corpo della mail.

