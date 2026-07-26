# Google Forms → Power Automate → Azure SQL

Google Forms salva normalmente le risposte in Google Sheets. Esistono due percorsi: scegliere quello consentito dalle licenze e dai connettori del tenant.

## Percorso A: trigger Google Sheets

Se il tenant dispone del trigger Google Sheets per la nuova riga:

1. Crea il Google Form e collega le risposte a un Google Sheet.
2. In Power Automate crea un flow cloud con trigger Google Sheets “When a row is added, modified or deleted” oppure l’equivalente disponibile nel tenant.
3. Aggiungi un’azione `Compose` che costruisca l’oggetto nel file `templates/payload-ragazzo.json` usando il contenuto dinamico delle colonne.
4. Aggiungi `SQL Server → Execute stored procedure (V2)`.
5. Seleziona `dbo.usp_ImportaIscrittoDaForms` e mappa:

| Parametro | Valore |
|---|---|
| `PayloadJson` | `string(outputs('Compose'))` |
| `ResponseId` | ID univoco della riga, non il nome del ragazzo |
| `FormId` | identificativo stabile scelto dal gestore |
| `ID_Evento` | ID dell’evento configurato oppure vuoto |
| `SubmittedAt` | timestamp della risposta o `utcNow()` |
| `ImportedBy` | `Power Automate - Google Forms` |

6. Aggiungi una condizione su `Success`. Se `Success=true` e `AlreadyImported=false`, richiama il flow email descritto in `email-confirmation.md`.

Il nome delle colonne Google Sheets dipende dalle domande del form: mappare per intestazione, non per posizione.

## Percorso B: Google Apps Script → trigger HTTP

Usare questo percorso quando il connettore Google Sheets non espone un trigger adatto o serve un payload controllato.

1. Crea un flow Power Automate con trigger `When an HTTP request is received`.
2. Definisci uno schema con almeno:

```json
{
  "type": "object",
  "properties": {
    "formId": { "type": "string" },
    "responseId": { "type": "string" },
    "submittedAt": { "type": "string" },
    "payload": { "type": "object" }
  },
  "required": ["formId", "responseId", "payload"]
}
```

3. Copia l’URL del trigger in una proprietà protetta di Google Apps Script chiamata `POWER_AUTOMATE_FLOW_URL`; non salvarla nel codice.
4. Crea un trigger installabile `From spreadsheet → On form submit` sul foglio risposte e usa uno script equivalente:

```javascript
function onFormSubmit(event) {
  const props = PropertiesService.getScriptProperties();
  const flowUrl = props.getProperty('POWER_AUTOMATE_FLOW_URL');
  if (!flowUrl) throw new Error('POWER_AUTOMATE_FLOW_URL non configurato');

  const values = event.namedValues || {};
  const first = (key) => (values[key] && values[key][0]) || '';
  const payload = {
    NomeRagazzo: first('NOME_RAGAZZO_DA_CONFIGURARE'),
    CognomeRagazzo: first('COGNOME_RAGAZZO_DA_CONFIGURARE'),
    MailRicevuta: first('EMAIL_DA_CONFIGURARE'),
    AllergieIntolleranze: first('ALLERGIE_DA_CONFIGURARE') || 'Nessuna'
  };

  UrlFetchApp.fetch(flowUrl, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify({
      formId: 'FORM_ID_DA_CONFIGURARE',
      responseId: first('Timestamp'),
      submittedAt: new Date().toISOString(),
      payload: payload
    }),
    muteHttpExceptions: false
  });
}
```

5. Nel flow HTTP usa `string(triggerBody()?['payload'])` come `PayloadJson` per `dbo.usp_ImportaIscrittoDaForms`; `ResponseId`, `FormId` e `SubmittedAt` vengono dagli altri campi del body.

## Mapping minimo ragazzi

Il payload completo è in `templates/payload-ragazzo.json`. I campi obbligatori sono `NomeRagazzo` e `CognomeRagazzo`. Per partire rapidamente si possono lasciare vuoti settimane, squadra e validazione: la stored procedure crea comunque contabilita e una riga per ogni settimana configurata.

Booleani come `Navetta`, `UscitaAutorizzata` e `Gratuita` devono arrivare come `true/false`, `1/0` o `SI/NO`; la stored procedure normalizza questi formati.

## Verifica

Controllare nel DB:

- una riga in `dbo.iscritti`;
- una riga in `dbo.contabilita`;
- tante righe in `dbo.pagamenti_settimanali` quante sono le settimane dell’evento;
- una riga in `dbo.import_forms_log`;
- su un retry, `AlreadyImported=1` senza nuova riga anagrafica.

