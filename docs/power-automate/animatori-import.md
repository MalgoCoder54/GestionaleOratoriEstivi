# Import animatori

## Flow

1. Trigger del form scelto dal gestore: Google Sheets/HTTP oppure Microsoft Forms.
2. Recupera i dettagli della risposta.
3. Costruisci il payload secondo `templates/payload-animatore.json`.
4. Usa `SQL Server → Execute stored procedure (V2)` con `[animatori].[usp_ImportaAnimatoreDaForms]`.

Parametri:

| Parametro | Valore |
|---|---|
| `PayloadJson` | JSON completo dell’animatore |
| `ResponseId` | ID univoco della risposta |
| `FormId` | identificativo stabile del form |
| `ID_Evento` | evento animatori attivo oppure vuoto |
| `SubmittedAt` | timestamp risposta o `utcNow()` |
| `ImportedBy` | `Power Automate` |

La procedura crea anagrafica, contributo e le righe di disponibilità per tutte le settimane. Le disponibilità possono essere lasciate a `false` e compilate dalla webapp.

## Campi consigliati

Mappare nome, cognome, codice fiscale, data di nascita, cellulare, email, taglie, allergie/note, navetta, maggiore età e contatti dei genitori. I campi `SI/NO` sono normalizzati dalla procedura.

## Permessi

Applicare `sql/animatori/06_grant_power_automate_execute.sql` dopo aver creato il contained user. L’azione SQL deve usare il database applicativo, non `master`.

