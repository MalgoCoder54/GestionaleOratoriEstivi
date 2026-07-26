# Azure landing zone e infrastruttura

`main.bicep` è uno deployment a scope subscription: crea il resource group e invoca il modulo applicativo. Il modulo crea:

- Azure SQL logical server e database;
- App Service Plan Linux condiviso;
- due App Service Linux, uno per ragazzi e uno per animatori;
- Key Vault con RBAC, contenente password SQL applicativa e `FLASK_SECRET_KEY`;
- Log Analytics e Application Insights;
- firewall Azure SQL e, opzionalmente, un IP autorizzato;
- Azure Entra ID Easy Auth opzionale per entrambe le webapp.

Il Bicep prepara l’infrastruttura e gli App Settings, ma non pubblica il codice Python. Il codice va pubblicato successivamente nelle due webapp dalla rispettiva cartella `apps/` tramite GitHub Actions, ZIP deploy, Azure Deployment Center o altro processo CI/CD.

## Deploy

1. Copia `main.parameters.example.json` in un file locale non versionato, ad esempio `main.parameters.json`.
2. Sostituisci nomi, regione e valori segreti usando un secret manager.
3. Se `enableEasyAuth=true`, valorizza anche tenant, client id e client secret dell’app registration Entra ID.
4. Valida e distribuisci:

```bash
az bicep build --file infra/main.bicep
az deployment sub create \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.json
```

Per il primo ambiente si può lasciare `sqlAllowAzureServices=true`; per un ambiente più chiuso, preferire accesso privato/VNet Integration e impostare il firewall su IP o reti autorizzate. `0.0.0.0` in Azure SQL significa “consenti servizi Azure”, non “consenti internet indiscriminato”.

## Dopo il deploy

1. Crea il contained user nel database con `sql/00_create_app_user.sql` oppure usa un’identità Entra ID dedicata.
2. Esegui gli script in `sql/README.md`.
3. Configura `ORGANIZATION_NAME`, `ORGANIZATION_LOCATION`, `DEFAULT_EVENT_ID` e gli eventuali App Settings personalizzati.
4. Pubblica `apps/pietro` e `apps/animatori` nelle rispettive App Service.
5. Configura i flow Power Automate descritti in `docs/power-automate/`.

