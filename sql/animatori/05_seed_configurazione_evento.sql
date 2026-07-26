-- Seed idempotente per la configurazione animatori di un evento di esempio.

:setvar DB_NAME "oratorio-estivo"
:setvar EVENT_ID "EVENTO_ESEMPIO"
:setvar EVENT_NAME "Animatori - da configurare"
:setvar EVENT_YEAR "2030"
:setvar EVENT_START "2030-06-10"
:setvar EVENT_END "2030-07-14"
:setvar WEEK1_START "2030-06-10"
:setvar WEEK2_START "2030-06-17"
:setvar WEEK3_START "2030-06-24"
:setvar WEEK4_START "2030-07-01"
:setvar WEEK5_START "2030-07-08"

USE [$(DB_NAME)];
GO

DECLARE @ID_Evento VARCHAR(20) = '$(EVENT_ID)';
DECLARE @ConfigJson NVARCHAR(MAX) = N'{
  "importi_default": {"contributo": 25.0, "maglietta_extra": 5.0},
  "settimane": {
    "numero_settimane": 5,
    "date_inizio": ["$(WEEK1_START)", "$(WEEK2_START)", "$(WEEK3_START)", "$(WEEK4_START)", "$(WEEK5_START)"],
    "etichette": ["Settimana 1", "Settimana 2", "Settimana 3", "Settimana 4", "Settimana 5"],
    "gite": []
  },
  "taglie_maglietta": ["XS", "S", "M", "L", "XL"],
  "taglie_pantaloncini": ["XS", "S", "M", "L", "XL"],
  "stati_documenti": ["DA_INVIARE", "INVIATI", "FIRMATI_RICEVUTI"],
  "stati_operativi": ["IN_ATTESA_FIRMA", "IMPORTATO", "ATTIVO", "SOSPESO", "RITIRATO"]
}';

IF EXISTS (SELECT 1 FROM [animatori].[eventi_animatori] WHERE [ID_Evento] = @ID_Evento)
BEGIN
    UPDATE [animatori].[eventi_animatori]
    SET [Nome] = N'$(EVENT_NAME)', [Anno] = $(EVENT_YEAR), [NumeroSettimane] = 5,
        [DataInizio] = '$(EVENT_START)', [DataFine] = '$(EVENT_END)', [Attivo] = 1
    WHERE [ID_Evento] = @ID_Evento;
END
ELSE
BEGIN
    UPDATE [animatori].[eventi_animatori] SET [Attivo] = 0 WHERE [Attivo] = 1;
    INSERT INTO [animatori].[eventi_animatori] ([ID_Evento], [Nome], [Anno], [NumeroSettimane], [DataInizio], [DataFine], [Attivo])
    VALUES (@ID_Evento, N'$(EVENT_NAME)', $(EVENT_YEAR), 5, '$(EVENT_START)', '$(EVENT_END)', 1);
END
GO

DECLARE @ConfigJson NVARCHAR(MAX) = N'{
  "importi_default": {"contributo": 25.0, "maglietta_extra": 5.0},
  "settimane": {"numero_settimane": 5, "date_inizio": ["$(WEEK1_START)", "$(WEEK2_START)", "$(WEEK3_START)", "$(WEEK4_START)", "$(WEEK5_START)"], "etichette": ["Settimana 1", "Settimana 2", "Settimana 3", "Settimana 4", "Settimana 5"], "gite": []},
  "taglie_maglietta": ["XS", "S", "M", "L", "XL"],
  "taglie_pantaloncini": ["XS", "S", "M", "L", "XL"],
  "stati_documenti": ["DA_INVIARE", "INVIATI", "FIRMATI_RICEVUTI"],
  "stati_operativi": ["IN_ATTESA_FIRMA", "IMPORTATO", "ATTIVO", "SOSPESO", "RITIRATO"]
}';

IF EXISTS (SELECT 1 FROM [animatori].[configurazione_animatori_eventi] WHERE [ID_Evento] = '$(EVENT_ID)')
    UPDATE [animatori].[configurazione_animatori_eventi] SET [ConfigJson] = @ConfigJson, [ModificatoDa] = N'Bootstrap SQL' WHERE [ID_Evento] = '$(EVENT_ID)';
ELSE
    INSERT INTO [animatori].[configurazione_animatori_eventi] ([ID_Evento], [ConfigJson], [ModificatoDa]) VALUES ('$(EVENT_ID)', @ConfigJson, N'Bootstrap SQL');
GO
