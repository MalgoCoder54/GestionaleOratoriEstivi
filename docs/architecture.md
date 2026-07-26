# Architettura

## Componenti

- Azure App Service Linux: una istanza per `apps/pietro` e una per `apps/animatori`;
- Azure SQL Database: dati applicativi, configurazione evento e log importazioni;
- Key Vault: segreti applicativi e password SQL;
- Application Insights + Log Analytics: telemetria e log;
- Power Automate: import da form, email automatiche e integrazioni opzionali;
- Google Forms/Sheets o Microsoft Forms: raccolta dati iniziale.

## Confini dati

Il database ragazzi usa lo schema `dbo`; il database animatori usa lo schema `animatori`. Ogni record è legato a un `ID_Evento`, così è possibile conservare più edizioni senza mischiare le anagrafiche.

Le procedure di importazione registrano `FormId + ResponseId` in una tabella di log con vincolo univoco: i retry di Power Automate non devono creare doppioni.

## Autenticazione

L’app legge gli header `X-MS-CLIENT-PRINCIPAL-*` prodotti da Azure App Service Easy Auth. In produzione impostare `REQUIRE_EASY_AUTH=true` e configurare l’identity provider Entra ID nel deployment Bicep o nel portale Azure.

