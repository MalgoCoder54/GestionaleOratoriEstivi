# Privacy e sicurezza

Il gestionale può trattare dati personali di minori, contatti dei genitori e dati relativi ad allergie/terapie. Questo documento è una checklist tecnica, non sostituisce una valutazione legale o il registro dei trattamenti.

## Prima della messa in produzione

- definire titolare, responsabili, finalità, base giuridica e periodo di conservazione;
- raccogliere solo i campi indispensabili e documentare il consenso/informativa del form;
- usare un tenant e un resource group dedicati;
- attivare Entra ID Easy Auth su entrambe le app;
- assegnare ruoli separati a segreteria, animatori e amministratori;
- creare un utente SQL applicativo contained con permessi minimi;
- tenere password, `FLASK_SECRET_KEY`, webhook Power Automate e client secret in Key Vault;
- configurare firewall, private endpoint/VNet se richiesto, TLS 1.2, auditing e backup;
- limitare accesso ai report Excel ed eliminare gli export temporanei;
- non usare nomi o codici fiscali reali negli script di test;
- definire una procedura per cancellazione, rettifica, data breach e fine evento.

## Repository

Non committare `.env`, report, ricevute, CSV, database locali, screenshot con dati o URL Power Automate con `sig=`. Se un segreto è stato committato per errore, revocarlo/ruotarlo: cancellarlo dal commit corrente non basta.

