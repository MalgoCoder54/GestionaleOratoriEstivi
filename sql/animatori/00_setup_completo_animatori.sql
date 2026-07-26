-- ============================================================
-- 00_setup_completo_animatori.sql
-- Setup unico schema [animatori] sul database selezionato ($(DB_NAME))
-- Generato dagli script 01-06. Non include dati di test.
-- ============================================================

:setvar DB_NAME "oratorio-estivo"
:setvar EVENT_ID "EVENTO_ESEMPIO"
:setvar EVENT_YEAR "2030"
:setvar EVENT_END "2030-07-14"
:setvar APP_USER "oratorio_app_rw"
:setvar WEEK1_START "2030-06-10"
:setvar WEEK2_START "2030-06-17"
:setvar WEEK3_START "2030-06-24"
:setvar WEEK4_START "2030-07-01"
:setvar WEEK5_START "2030-07-08"

USE [$(DB_NAME)];
GO

-- ============================================================
-- BEGIN 01_create_schema.sql
-- ============================================================

-- ============================================================
-- 01_create_schema.sql
-- Schema dedicato animatori nel database applicativo esistente
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE [name] = N'animatori')
BEGIN
    EXEC(N'CREATE SCHEMA [animatori]');
END
GO

PRINT 'Schema [animatori] creato o gia presente.';
GO

-- ============================================================
-- END 01_create_schema.sql
-- ============================================================

-- ============================================================
-- BEGIN 02_create_tables.sql
-- ============================================================

-- ============================================================
-- 02_create_tables.sql
-- Tabelle applicazione Animatori
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[animatori].[eventi_animatori]') AND type = 'U')
BEGIN
    CREATE TABLE [animatori].[eventi_animatori]
    (
        [ID_Evento]       VARCHAR(20)    NOT NULL,
        [Nome]            NVARCHAR(100)  NOT NULL,
        [Anno]            INT            NOT NULL,
        [NumeroSettimane] INT            NOT NULL CONSTRAINT [DF_eventi_animatori_NumeroSettimane] DEFAULT 5,
        [DataInizio]      DATE           NULL,
        [DataFine]        DATE           NULL,
        [Attivo]          BIT            NOT NULL CONSTRAINT [DF_eventi_animatori_Attivo] DEFAULT 1,
        CONSTRAINT [PK_eventi_animatori] PRIMARY KEY CLUSTERED ([ID_Evento]),
        CONSTRAINT [CK_eventi_animatori_Anno] CHECK ([Anno] BETWEEN 2000 AND 2100),
        CONSTRAINT [CK_eventi_animatori_NumeroSettimane] CHECK ([NumeroSettimane] BETWEEN 1 AND 12)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[animatori].[configurazione_animatori_eventi]') AND type = 'U')
BEGIN
    CREATE TABLE [animatori].[configurazione_animatori_eventi]
    (
        [ID_Evento]     VARCHAR(20)    NOT NULL,
        [ConfigJson]    NVARCHAR(MAX)  NOT NULL,
        [DataCreazione] DATETIME2(0)   NOT NULL CONSTRAINT [DF_cfg_animatori_DataCreazione] DEFAULT SYSUTCDATETIME(),
        [DataModifica]  DATETIME2(0)   NOT NULL CONSTRAINT [DF_cfg_animatori_DataModifica] DEFAULT SYSUTCDATETIME(),
        [ModificatoDa]  NVARCHAR(100)  NOT NULL CONSTRAINT [DF_cfg_animatori_ModificatoDa] DEFAULT N'App',
        [RowVersion]    ROWVERSION     NOT NULL,
        CONSTRAINT [PK_configurazione_animatori_eventi] PRIMARY KEY CLUSTERED ([ID_Evento]),
        CONSTRAINT [FK_configurazione_animatori_eventi_eventi] FOREIGN KEY ([ID_Evento])
            REFERENCES [animatori].[eventi_animatori] ([ID_Evento]) ON DELETE CASCADE,
        CONSTRAINT [CK_configurazione_animatori_ConfigJson] CHECK (ISJSON([ConfigJson]) = 1)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[animatori].[animatori]') AND type = 'U')
BEGIN
    CREATE TABLE [animatori].[animatori]
    (
        [ID]                     INT             IDENTITY(1,1) NOT NULL,
        [ID_Evento]              VARCHAR(20)     NOT NULL,
        [Nome]                   NVARCHAR(100)   NOT NULL,
        [Cognome]                NVARCHAR(100)   NOT NULL,
        [CodiceFiscale]          NVARCHAR(64)    NULL,
        [DataNascita]            DATE            NULL,
        [Cellulare]              NVARCHAR(50)    NULL,
        [EmailModuli]            NVARCHAR(200)   NULL,
        [TagliaMaglietta]        NVARCHAR(20)    NULL,
        [TagliaPantaloncini]     NVARCHAR(20)    NULL,
        [AllergieIntolleranze]   NVARCHAR(800)   NULL CONSTRAINT [DF_animatori_Allergie] DEFAULT N'Nessuna',
        [TerapieNote]            NVARCHAR(800)   NULL,
        [Navetta]                BIT             NOT NULL CONSTRAINT [DF_animatori_Navetta] DEFAULT 0,
        [Maggiorenne]            BIT             NOT NULL CONSTRAINT [DF_animatori_Maggiorenne] DEFAULT 0,
        [NomeMamma]              NVARCHAR(100)   NULL,
        [CognomeMamma]           NVARCHAR(100)   NULL,
        [MailMamma]              NVARCHAR(200)   NULL,
        [CellulareMamma]         NVARCHAR(50)    NULL,
        [NomePapa]               NVARCHAR(100)   NULL,
        [CognomePapa]            NVARCHAR(100)   NULL,
        [MailPapa]               NVARCHAR(200)   NULL,
        [CellularePapa]          NVARCHAR(50)    NULL,
        [StatoDocumenti]         NVARCHAR(30)    NOT NULL CONSTRAINT [DF_animatori_StatoDocumenti] DEFAULT N'INVIATI',
        [StatoOperativo]         NVARCHAR(30)    NOT NULL CONSTRAINT [DF_animatori_StatoOperativo] DEFAULT N'IN_ATTESA_FIRMA',
        [IscrizioneValidata]     BIT             NOT NULL CONSTRAINT [DF_animatori_Validata] DEFAULT 0,
        [DataValidazione]        DATE            NULL,
        [NoteSegreteria]         NVARCHAR(MAX)   NULL,
        [DataCreazione]          DATETIME2(0)    NOT NULL CONSTRAINT [DF_animatori_DataCreazione] DEFAULT SYSUTCDATETIME(),
        [DataModifica]           DATETIME2(0)    NOT NULL CONSTRAINT [DF_animatori_DataModifica] DEFAULT SYSUTCDATETIME(),
        [ModificatoDa]           NVARCHAR(100)   NOT NULL CONSTRAINT [DF_animatori_ModificatoDa] DEFAULT N'App',
        [RowVersion]             ROWVERSION      NOT NULL,
        CONSTRAINT [PK_animatori] PRIMARY KEY CLUSTERED ([ID]),
        CONSTRAINT [FK_animatori_eventi] FOREIGN KEY ([ID_Evento])
            REFERENCES [animatori].[eventi_animatori] ([ID_Evento]) ON DELETE NO ACTION,
        CONSTRAINT [CK_animatori_StatoDocumenti] CHECK ([StatoDocumenti] IN (N'DA_INVIARE', N'INVIATI', N'FIRMATI_RICEVUTI')),
        CONSTRAINT [CK_animatori_StatoOperativo] CHECK ([StatoOperativo] IN (N'IN_ATTESA_FIRMA', N'IMPORTATO', N'ATTIVO', N'SOSPESO', N'RITIRATO'))
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[animatori].[contributi_animatori]') AND type = 'U')
BEGIN
    CREATE TABLE [animatori].[contributi_animatori]
    (
        [ID]                      INT            IDENTITY(1,1) NOT NULL,
        [ID_Animatore]            INT            NOT NULL,
        [ID_Evento]               VARCHAR(20)    NOT NULL,
        [ImportoContributo]       DECIMAL(10,2)  NOT NULL CONSTRAINT [DF_contributi_animatori_Contributo] DEFAULT 25.00,
        [NumeroMaglietteExtra]    INT            NOT NULL CONSTRAINT [DF_contributi_animatori_QtaMagliette] DEFAULT 0,
        [ImportoMaglietteExtra]   DECIMAL(10,2)  NOT NULL CONSTRAINT [DF_contributi_animatori_ImportoMagliette] DEFAULT 0.00,
        [TotaleDovuto]            DECIMAL(10,2)  NOT NULL CONSTRAINT [DF_contributi_animatori_Totale] DEFAULT 25.00,
        [Pagato]                  BIT            NOT NULL CONSTRAINT [DF_contributi_animatori_Pagato] DEFAULT 0,
        [DataPagamento]           DATE           NULL,
        [MetodoPagamento]         NVARCHAR(30)   NOT NULL CONSTRAINT [DF_contributi_animatori_Metodo] DEFAULT N'BONIFICO',
        [ContabileRicevuta]       BIT            NOT NULL CONSTRAINT [DF_contributi_animatori_Contabile] DEFAULT 0,
        [NotePagamento]           NVARCHAR(MAX)  NULL,
        [DataModifica]            DATETIME2(0)   NOT NULL CONSTRAINT [DF_contributi_animatori_DataModifica] DEFAULT SYSUTCDATETIME(),
        [ModificatoDa]            NVARCHAR(100)  NOT NULL CONSTRAINT [DF_contributi_animatori_ModificatoDa] DEFAULT N'App',
        [RowVersion]              ROWVERSION     NOT NULL,
        CONSTRAINT [PK_contributi_animatori] PRIMARY KEY CLUSTERED ([ID]),
        CONSTRAINT [FK_contributi_animatori_animatori] FOREIGN KEY ([ID_Animatore])
            REFERENCES [animatori].[animatori] ([ID]) ON DELETE CASCADE,
        CONSTRAINT [FK_contributi_animatori_eventi] FOREIGN KEY ([ID_Evento])
            REFERENCES [animatori].[eventi_animatori] ([ID_Evento]) ON DELETE NO ACTION,
        CONSTRAINT [UQ_contributi_animatori_animatore] UNIQUE ([ID_Animatore]),
        CONSTRAINT [CK_contributi_animatori_Qta] CHECK ([NumeroMaglietteExtra] >= 0)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[animatori].[disponibilita_animatori]') AND type = 'U')
BEGIN
    CREATE TABLE [animatori].[disponibilita_animatori]
    (
        [ID]              INT            IDENTITY(1,1) NOT NULL,
        [ID_Animatore]    INT            NOT NULL,
        [ID_Evento]       VARCHAR(20)    NOT NULL,
        [NumeroSettimana] INT            NOT NULL,
        [Disponibile]     BIT            NOT NULL CONSTRAINT [DF_disp_animatori_Disponibile] DEFAULT 0,
        [Presente]        BIT            NOT NULL CONSTRAINT [DF_disp_animatori_Presente] DEFAULT 0,
        [InGita]          BIT            NOT NULL CONSTRAINT [DF_disp_animatori_InGita] DEFAULT 0,
        [InOratorio]      BIT            NOT NULL CONSTRAINT [DF_disp_animatori_InOratorio] DEFAULT 1,
        [NoteTurno]       NVARCHAR(500)  NULL,
        [DataModifica]    DATETIME2(0)   NOT NULL CONSTRAINT [DF_disp_animatori_DataModifica] DEFAULT SYSUTCDATETIME(),
        [ModificatoDa]    NVARCHAR(100)  NOT NULL CONSTRAINT [DF_disp_animatori_ModificatoDa] DEFAULT N'App',
        [RowVersion]      ROWVERSION     NOT NULL,
        CONSTRAINT [PK_disponibilita_animatori] PRIMARY KEY CLUSTERED ([ID]),
        CONSTRAINT [FK_disp_animatori_animatori] FOREIGN KEY ([ID_Animatore])
            REFERENCES [animatori].[animatori] ([ID]) ON DELETE CASCADE,
        CONSTRAINT [FK_disp_animatori_eventi] FOREIGN KEY ([ID_Evento])
            REFERENCES [animatori].[eventi_animatori] ([ID_Evento]) ON DELETE NO ACTION,
        CONSTRAINT [UQ_disp_animatori_settimana] UNIQUE ([ID_Animatore], [NumeroSettimana]),
        CONSTRAINT [CK_disp_animatori_NumeroSettimana] CHECK ([NumeroSettimana] BETWEEN 1 AND 12)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[animatori].[import_animatori_forms_log]') AND type = 'U')
BEGIN
    CREATE TABLE [animatori].[import_animatori_forms_log]
    (
        [ID]             INT            IDENTITY(1,1) NOT NULL,
        [FormId]         NVARCHAR(200)  NOT NULL CONSTRAINT [DF_import_animatori_FormId] DEFAULT N'',
        [ResponseId]     NVARCHAR(100)  NOT NULL,
        [ID_Evento]      VARCHAR(20)    NULL,
        [ID_Animatore]   INT            NULL,
        [PayloadJson]    NVARCHAR(MAX)  NULL,
        [Stato]          NVARCHAR(20)   NOT NULL CONSTRAINT [DF_import_animatori_Stato] DEFAULT N'IMPORTED',
        [Messaggio]      NVARCHAR(500)  NULL,
        [DataRicezione]  DATETIME2(0)   NULL,
        [DataImport]     DATETIME2(0)   NOT NULL CONSTRAINT [DF_import_animatori_DataImport] DEFAULT SYSUTCDATETIME(),
        [ImportatoDa]    NVARCHAR(100)  NOT NULL CONSTRAINT [DF_import_animatori_ImportatoDa] DEFAULT N'Power Automate',
        [RowVersion]     ROWVERSION     NOT NULL,
        CONSTRAINT [PK_import_animatori_forms_log] PRIMARY KEY CLUSTERED ([ID]),
        CONSTRAINT [UQ_import_animatori_Form_Response] UNIQUE ([FormId], [ResponseId]),
        CONSTRAINT [FK_import_animatori_eventi] FOREIGN KEY ([ID_Evento])
            REFERENCES [animatori].[eventi_animatori] ([ID_Evento]) ON DELETE NO ACTION,
        CONSTRAINT [FK_import_animatori_animatori] FOREIGN KEY ([ID_Animatore])
            REFERENCES [animatori].[animatori] ([ID]) ON DELETE SET NULL,
        CONSTRAINT [CK_import_animatori_PayloadJson] CHECK ([PayloadJson] IS NULL OR ISJSON([PayloadJson]) = 1)
    );
END
GO

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = N'TR_animatori_DataModifica')
    DROP TRIGGER [animatori].[TR_animatori_DataModifica];
GO

CREATE TRIGGER [animatori].[TR_animatori_DataModifica]
ON [animatori].[animatori]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE target
    SET [DataModifica] = SYSUTCDATETIME()
    FROM [animatori].[animatori] target
    INNER JOIN inserted ins ON ins.[ID] = target.[ID];
END
GO

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = N'TR_contributi_animatori_DataModifica')
    DROP TRIGGER [animatori].[TR_contributi_animatori_DataModifica];
GO

CREATE TRIGGER [animatori].[TR_contributi_animatori_DataModifica]
ON [animatori].[contributi_animatori]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE target
    SET [DataModifica] = SYSUTCDATETIME()
    FROM [animatori].[contributi_animatori] target
    INNER JOIN inserted ins ON ins.[ID] = target.[ID];
END
GO

IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = N'TR_disponibilita_animatori_DataModifica')
    DROP TRIGGER [animatori].[TR_disponibilita_animatori_DataModifica];
GO

CREATE TRIGGER [animatori].[TR_disponibilita_animatori_DataModifica]
ON [animatori].[disponibilita_animatori]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE target
    SET [DataModifica] = SYSUTCDATETIME()
    FROM [animatori].[disponibilita_animatori] target
    INNER JOIN inserted ins ON ins.[ID] = target.[ID];
END
GO

PRINT 'Tabelle animatori create o verificate.';
GO

-- ============================================================
-- END 02_create_tables.sql
-- ============================================================

-- ============================================================
-- BEGIN 03_create_indexes.sql
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_animatori_Evento')
    CREATE NONCLUSTERED INDEX [IX_animatori_Evento]
    ON [animatori].[animatori] ([ID_Evento])
    INCLUDE ([Nome], [Cognome], [Maggiorenne], [StatoDocumenti], [StatoOperativo]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_animatori_CognomeNome')
    CREATE NONCLUSTERED INDEX [IX_animatori_CognomeNome]
    ON [animatori].[animatori] ([Cognome], [Nome]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_animatori_CodiceFiscale')
    CREATE NONCLUSTERED INDEX [IX_animatori_CodiceFiscale]
    ON [animatori].[animatori] ([ID_Evento], [CodiceFiscale])
    WHERE [CodiceFiscale] IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_contributi_animatori_EventoPagato')
    CREATE NONCLUSTERED INDEX [IX_contributi_animatori_EventoPagato]
    ON [animatori].[contributi_animatori] ([ID_Evento], [Pagato], [ContabileRicevuta]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_disponibilita_animatori_EventoSettimana')
    CREATE NONCLUSTERED INDEX [IX_disponibilita_animatori_EventoSettimana]
    ON [animatori].[disponibilita_animatori] ([ID_Evento], [NumeroSettimana], [Disponibile])
    INCLUDE ([Presente], [InGita], [InOratorio]);
GO

PRINT 'Indici animatori creati o verificati.';
GO

-- ============================================================
-- END 03_create_indexes.sql
-- ============================================================

-- ============================================================
-- BEGIN 04_seed_configurazione_evento.sql
-- ============================================================

DECLARE @ID_Evento VARCHAR(20) = '$(EVENT_ID)';
DECLARE @ConfigJson NVARCHAR(MAX) = N'{
  "importi_default": {
    "contributo": 25.0,
    "maglietta_extra": 5.0
  },
  "settimane": {
    "numero_settimane": 5,
    "date_inizio": ["$(WEEK1_START)", "$(WEEK2_START)", "$(WEEK3_START)", "$(WEEK4_START)", "$(WEEK5_START)"],
    "etichette": [
      "1^ sett. (08-12 giugno)",
      "2^ sett. (15-19 giugno)",
      "3^ sett. (22-26 giugno)",
      "4^ sett. (29 giugno-03 luglio)",
      "5^ sett. (06-10 luglio)"
    ],
    "gite": []
  },
  "taglie_maglietta": ["XS", "S", "M", "L", "XL", "2XL", "3XL"],
  "taglie_pantaloncini": ["S", "M", "L", "XL", "2XL"],
  "stati_documenti": ["INVIATI", "FIRMATI_RICEVUTI", "DA_INVIARE"],
  "stati_operativi": ["IN_ATTESA_FIRMA", "IMPORTATO", "ATTIVO", "SOSPESO", "RITIRATO"]
}';

IF EXISTS (SELECT 1 FROM [animatori].[eventi_animatori] WHERE [ID_Evento] = @ID_Evento)
BEGIN
    UPDATE [animatori].[eventi_animatori]
    SET [Nome] = N'Animatori - evento da configurare',
        [Anno] = $(EVENT_YEAR),
        [NumeroSettimane] = 5,
        [DataInizio] = '$(WEEK1_START)',
        [DataFine] = '$(EVENT_END)',
        [Attivo] = 1
    WHERE [ID_Evento] = @ID_Evento;
END
ELSE
BEGIN
    INSERT INTO [animatori].[eventi_animatori] ([ID_Evento], [Nome], [Anno], [NumeroSettimane], [DataInizio], [DataFine], [Attivo])
    VALUES (@ID_Evento, N'Animatori - evento da configurare', $(EVENT_YEAR), 5, '$(WEEK1_START)', '$(EVENT_END)', 1);
END
GO

DECLARE @ConfigJson NVARCHAR(MAX) = N'{
  "importi_default": {
    "contributo": 25.0,
    "maglietta_extra": 5.0
  },
  "settimane": {
    "numero_settimane": 5,
    "date_inizio": ["$(WEEK1_START)", "$(WEEK2_START)", "$(WEEK3_START)", "$(WEEK4_START)", "$(WEEK5_START)"],
    "etichette": [
      "1^ sett. (08-12 giugno)",
      "2^ sett. (15-19 giugno)",
      "3^ sett. (22-26 giugno)",
      "4^ sett. (29 giugno-03 luglio)",
      "5^ sett. (06-10 luglio)"
    ],
    "gite": []
  },
  "taglie_maglietta": ["XS", "S", "M", "L", "XL", "2XL", "3XL"],
  "taglie_pantaloncini": ["S", "M", "L", "XL", "2XL"],
  "stati_documenti": ["INVIATI", "FIRMATI_RICEVUTI", "DA_INVIARE"],
  "stati_operativi": ["IN_ATTESA_FIRMA", "IMPORTATO", "ATTIVO", "SOSPESO", "RITIRATO"]
}';

IF EXISTS (SELECT 1 FROM [animatori].[configurazione_animatori_eventi] WHERE [ID_Evento] = '$(EVENT_ID)')
BEGIN
    UPDATE [animatori].[configurazione_animatori_eventi]
    SET [ConfigJson] = @ConfigJson,
        [ModificatoDa] = N'Bootstrap SQL'
    WHERE [ID_Evento] = '$(EVENT_ID)';
END
ELSE
BEGIN
    INSERT INTO [animatori].[configurazione_animatori_eventi] ([ID_Evento], [ConfigJson], [ModificatoDa])
    VALUES ('$(EVENT_ID)', @ConfigJson, N'Bootstrap SQL');
END
GO

PRINT 'Configurazione $(EVENT_ID) creata o aggiornata.';
GO

-- ============================================================
-- END 04_seed_configurazione_evento.sql
-- ============================================================

-- ============================================================
-- BEGIN 05_stored_procedures.sql
-- ============================================================

-- ============================================================
-- 05_stored_procedures.sql
-- Stored procedure schema [animatori]
-- ============================================================

IF OBJECT_ID(N'[animatori].[usp_GetAnimatoriByEvento]', N'P') IS NOT NULL
    DROP PROCEDURE [animatori].[usp_GetAnimatoriByEvento];
GO

CREATE PROCEDURE [animatori].[usp_GetAnimatoriByEvento]
    @ID_Evento VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        a.[ID],
        a.[Nome],
        a.[Cognome],
        a.[CodiceFiscale],
        a.[DataNascita],
        a.[Cellulare],
        a.[EmailModuli],
        a.[TagliaMaglietta],
        a.[TagliaPantaloncini],
        a.[Navetta],
        a.[Maggiorenne],
        a.[StatoDocumenti],
        a.[StatoOperativo],
        c.[TotaleDovuto],
        c.[Pagato],
        c.[ContabileRicevuta]
    FROM [animatori].[animatori] a
    LEFT JOIN [animatori].[contributi_animatori] c ON c.[ID_Animatore] = a.[ID]
    WHERE a.[ID_Evento] = @ID_Evento
    ORDER BY a.[Cognome], a.[Nome];
END
GO

IF OBJECT_ID(N'[animatori].[usp_ImportaAnimatoreDaForms]', N'P') IS NOT NULL
    DROP PROCEDURE [animatori].[usp_ImportaAnimatoreDaForms];
GO

CREATE PROCEDURE [animatori].[usp_ImportaAnimatoreDaForms]
    @PayloadJson    NVARCHAR(MAX),
    @ResponseId     NVARCHAR(100),
    @FormId         NVARCHAR(200) = N'',
    @ID_Evento      VARCHAR(20)   = NULL,
    @SubmittedAt    DATETIME2(0)  = NULL,
    @ImportedBy     NVARCHAR(100) = N'Power Automate'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @ResolvedEvento VARCHAR(20),
        @ConfigJson NVARCHAR(MAX),
        @NumeroSettimane INT,
        @ImportoContributo DECIMAL(10,2),
        @ID_Animatore INT,
        @ExistingImportID INT,
        @ExistingAnimatoreID INT,
        @ExistingStatus NVARCHAR(20),
        @Nome NVARCHAR(100),
        @Cognome NVARCHAR(100),
        @CodiceFiscale NVARCHAR(64),
        @DataNascita DATE,
        @Cellulare NVARCHAR(50),
        @EmailModuli NVARCHAR(200),
        @TagliaMaglietta NVARCHAR(20),
        @TagliaPantaloncini NVARCHAR(20),
        @AllergieIntolleranze NVARCHAR(800),
        @TerapieNote NVARCHAR(800),
        @Navetta BIT,
        @Maggiorenne BIT,
        @NomeMamma NVARCHAR(100),
        @CognomeMamma NVARCHAR(100),
        @MailMamma NVARCHAR(200),
        @CellulareMamma NVARCHAR(50),
        @NomePapa NVARCHAR(100),
        @CognomePapa NVARCHAR(100),
        @MailPapa NVARCHAR(200),
        @CellularePapa NVARCHAR(50),
        @NumeroMaglietteExtra INT,
        @ErrorMessage NVARCHAR(4000);

    SET @FormId = ISNULL(@FormId, N'');
    SET @SubmittedAt = ISNULL(@SubmittedAt, SYSUTCDATETIME());
    SET @ImportedBy = COALESCE(NULLIF(LTRIM(RTRIM(@ImportedBy)), N''), N'Power Automate');

    IF ISJSON(@PayloadJson) <> 1
    BEGIN
        RAISERROR(N'PayloadJson non e'' un JSON valido.', 16, 1);
        RETURN;
    END

    SET @ResolvedEvento = COALESCE(
        NULLIF(@ID_Evento, ''),
        NULLIF(JSON_VALUE(@PayloadJson, '$.ID_Evento'), ''),
        NULLIF(JSON_VALUE(@PayloadJson, '$.evento_corrente'), ''),
        (SELECT TOP (1) [ID_Evento] FROM [animatori].[eventi_animatori] WHERE [Attivo] = 1 ORDER BY [Anno] DESC, [ID_Evento] DESC)
    );

    SELECT
        @ConfigJson = cfg.[ConfigJson],
        @NumeroSettimane = evt.[NumeroSettimane]
    FROM [animatori].[eventi_animatori] evt
    LEFT JOIN [animatori].[configurazione_animatori_eventi] cfg ON cfg.[ID_Evento] = evt.[ID_Evento]
    WHERE evt.[ID_Evento] = @ResolvedEvento;

    IF @NumeroSettimane IS NULL
    BEGIN
        RAISERROR(N'Evento animatori non trovato.', 16, 1);
        RETURN;
    END

    SET @ImportoContributo = COALESCE(TRY_CONVERT(DECIMAL(10,2), JSON_VALUE(@ConfigJson, '$.importi_default.contributo')), 25.00);
    SET @Nome = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.Nome'))), N'');
    SET @Cognome = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.Cognome'))), N'');
    SET @CodiceFiscale = UPPER(NULLIF(LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.CodiceFiscale'))), N''));
    SET @DataNascita = TRY_CONVERT(DATE, JSON_VALUE(@PayloadJson, '$.DataNascita'), 23);
    SET @Cellulare = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.Cellulare'))), N'');
    SET @EmailModuli = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.EmailModuli'))), N'');
    SET @TagliaMaglietta = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.TagliaMaglietta'))), N'');
    SET @TagliaPantaloncini = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.TagliaPantaloncini'))), N'');
    SET @AllergieIntolleranze = COALESCE(NULLIF(LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.AllergieIntolleranze'))), N''), N'Nessuna');
    SET @TerapieNote = NULLIF(LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.TerapieNote'))), N'');
    SET @Navetta = CASE WHEN LOWER(COALESCE(JSON_VALUE(@PayloadJson, '$.Navetta'), N'false')) IN (N'true', N'1', N'si', N'sì', N'yes', N'on') THEN 1 ELSE 0 END;
    SET @Maggiorenne = CASE WHEN LOWER(COALESCE(JSON_VALUE(@PayloadJson, '$.Maggiorenne'), N'false')) IN (N'true', N'1', N'si', N'sì', N'yes', N'on') THEN 1 ELSE 0 END;
    SET @NumeroMaglietteExtra = COALESCE(TRY_CONVERT(INT, JSON_VALUE(@PayloadJson, '$.NumeroMaglietteExtra')), 0);

    SET @NomeMamma = CASE WHEN UPPER(COALESCE(LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.NomeMamma'))), N'')) IN (N'', N'NO') THEN NULL ELSE LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.NomeMamma'))) END;
    SET @CognomeMamma = CASE WHEN UPPER(COALESCE(LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.CognomeMamma'))), N'')) IN (N'', N'NO') THEN NULL ELSE LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.CognomeMamma'))) END;
    SET @MailMamma = CASE WHEN UPPER(COALESCE(LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.MailMamma'))), N'')) IN (N'', N'NO') THEN NULL ELSE LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.MailMamma'))) END;
    SET @CellulareMamma = CASE WHEN UPPER(COALESCE(LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.CellulareMamma'))), N'')) IN (N'', N'NO') THEN NULL ELSE LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.CellulareMamma'))) END;
    SET @NomePapa = CASE WHEN UPPER(COALESCE(LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.NomePapa'))), N'')) IN (N'', N'NO') THEN NULL ELSE LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.NomePapa'))) END;
    SET @CognomePapa = CASE WHEN UPPER(COALESCE(LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.CognomePapa'))), N'')) IN (N'', N'NO') THEN NULL ELSE LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.CognomePapa'))) END;
    SET @MailPapa = CASE WHEN UPPER(COALESCE(LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.MailPapa'))), N'')) IN (N'', N'NO') THEN NULL ELSE LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.MailPapa'))) END;
    SET @CellularePapa = CASE WHEN UPPER(COALESCE(LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.CellularePapa'))), N'')) IN (N'', N'NO') THEN NULL ELSE LTRIM(RTRIM(JSON_VALUE(@PayloadJson, '$.CellularePapa'))) END;

    IF @Nome IS NULL OR @Cognome IS NULL
    BEGIN
        RAISERROR(N'Nome e Cognome sono obbligatori nel payload.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT TOP (1)
            @ExistingImportID = [ID],
            @ExistingAnimatoreID = [ID_Animatore],
            @ExistingStatus = [Stato]
        FROM [animatori].[import_animatori_forms_log] WITH (UPDLOCK, HOLDLOCK)
        WHERE [FormId] = @FormId
          AND [ResponseId] = @ResponseId;

        IF @ExistingImportID IS NOT NULL AND @ExistingStatus = N'IMPORTED'
        BEGIN
            COMMIT TRANSACTION;
            SELECT CAST(1 AS BIT) AS [Success], CAST(1 AS BIT) AS [AlreadyImported], @ExistingAnimatoreID AS [ID_Animatore], @ResolvedEvento AS [ID_Evento], N'Risposta Forms gia importata.' AS [Message];
            RETURN;
        END

        IF @ExistingImportID IS NULL
        BEGIN
            INSERT INTO [animatori].[import_animatori_forms_log] ([FormId], [ResponseId], [ID_Evento], [PayloadJson], [Stato], [Messaggio], [DataRicezione], [ImportatoDa])
            VALUES (@FormId, @ResponseId, @ResolvedEvento, @PayloadJson, N'PROCESSING', N'Importazione in corso', @SubmittedAt, @ImportedBy);
            SET @ExistingImportID = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE [animatori].[import_animatori_forms_log]
            SET [Stato] = N'PROCESSING',
                [Messaggio] = N'Importazione in corso',
                [ID_Evento] = @ResolvedEvento,
                [PayloadJson] = @PayloadJson,
                [DataRicezione] = @SubmittedAt,
                [DataImport] = SYSUTCDATETIME(),
                [ImportatoDa] = @ImportedBy
            WHERE [ID] = @ExistingImportID;
        END

        IF @CodiceFiscale IS NOT NULL
           AND EXISTS (
                SELECT 1
                FROM [animatori].[animatori]
                WHERE [ID_Evento] = @ResolvedEvento
                  AND [CodiceFiscale] = @CodiceFiscale
           )
        BEGIN
            SELECT TOP (1) @ExistingAnimatoreID = [ID]
            FROM [animatori].[animatori]
            WHERE [ID_Evento] = @ResolvedEvento
              AND [CodiceFiscale] = @CodiceFiscale
            ORDER BY [ID] DESC;

            UPDATE [animatori].[import_animatori_forms_log]
            SET [Stato] = N'DUPLICATE',
                [Messaggio] = N'Esiste gia un animatore con lo stesso codice fiscale per questo evento.',
                [ID_Animatore] = @ExistingAnimatoreID,
                [DataImport] = SYSUTCDATETIME()
            WHERE [ID] = @ExistingImportID;

            COMMIT TRANSACTION;
            SELECT CAST(0 AS BIT) AS [Success], CAST(0 AS BIT) AS [AlreadyImported], @ExistingAnimatoreID AS [ID_Animatore], @ResolvedEvento AS [ID_Evento], N'Esiste gia un animatore con lo stesso codice fiscale per questo evento.' AS [Message];
            RETURN;
        END

        INSERT INTO [animatori].[animatori] (
            [ID_Evento], [Nome], [Cognome], [CodiceFiscale], [DataNascita],
            [Cellulare], [EmailModuli], [TagliaMaglietta], [TagliaPantaloncini],
            [AllergieIntolleranze], [TerapieNote], [Navetta], [Maggiorenne],
            [NomeMamma], [CognomeMamma], [MailMamma], [CellulareMamma],
            [NomePapa], [CognomePapa], [MailPapa], [CellularePapa],
            [ModificatoDa]
        )
        VALUES (
            @ResolvedEvento, @Nome, @Cognome, @CodiceFiscale, @DataNascita,
            @Cellulare, @EmailModuli, @TagliaMaglietta, @TagliaPantaloncini,
            @AllergieIntolleranze, @TerapieNote, @Navetta, @Maggiorenne,
            @NomeMamma, @CognomeMamma, @MailMamma, @CellulareMamma,
            @NomePapa, @CognomePapa, @MailPapa, @CellularePapa,
            @ImportedBy
        );

        SET @ID_Animatore = SCOPE_IDENTITY();

        INSERT INTO [animatori].[contributi_animatori] (
            [ID_Animatore], [ID_Evento], [ImportoContributo],
            [NumeroMaglietteExtra], [ImportoMaglietteExtra], [TotaleDovuto],
            [ModificatoDa]
        )
        VALUES (
            @ID_Animatore, @ResolvedEvento, @ImportoContributo,
            CASE WHEN @NumeroMaglietteExtra < 0 THEN 0 ELSE @NumeroMaglietteExtra END,
            CASE WHEN @NumeroMaglietteExtra < 0 THEN 0 ELSE @NumeroMaglietteExtra END * 5.00,
            @ImportoContributo + (CASE WHEN @NumeroMaglietteExtra < 0 THEN 0 ELSE @NumeroMaglietteExtra END * 5.00),
            @ImportedBy
        );

        ;WITH [Settimane] AS
        (
            SELECT 1 AS [NumeroSettimana]
            UNION ALL
            SELECT [NumeroSettimana] + 1
            FROM [Settimane]
            WHERE [NumeroSettimana] < @NumeroSettimane
        )
        INSERT INTO [animatori].[disponibilita_animatori] (
            [ID_Animatore], [ID_Evento], [NumeroSettimana], [Disponibile], [Presente], [InOratorio], [ModificatoDa]
        )
        SELECT
            @ID_Animatore,
            @ResolvedEvento,
            s.[NumeroSettimana],
            CASE
                WHEN LOWER(COALESCE(
                    CASE s.[NumeroSettimana]
                        WHEN 1 THEN JSON_VALUE(@PayloadJson, '$.DisponibilitaSettimana1')
                        WHEN 2 THEN JSON_VALUE(@PayloadJson, '$.DisponibilitaSettimana2')
                        WHEN 3 THEN JSON_VALUE(@PayloadJson, '$.DisponibilitaSettimana3')
                        WHEN 4 THEN JSON_VALUE(@PayloadJson, '$.DisponibilitaSettimana4')
                        WHEN 5 THEN JSON_VALUE(@PayloadJson, '$.DisponibilitaSettimana5')
                    END,
                    CASE s.[NumeroSettimana]
                        WHEN 1 THEN JSON_VALUE(@PayloadJson, '$.PresenzaSettimana1')
                        WHEN 2 THEN JSON_VALUE(@PayloadJson, '$.PresenzaSettimana2')
                        WHEN 3 THEN JSON_VALUE(@PayloadJson, '$.PresenzaSettimana3')
                        WHEN 4 THEN JSON_VALUE(@PayloadJson, '$.PresenzaSettimana4')
                        WHEN 5 THEN JSON_VALUE(@PayloadJson, '$.PresenzaSettimana5')
                    END,
                    N'false'
                )) IN (N'true', N'1', N'si', N'sì', N'yes', N'on') THEN 1
                ELSE 0
            END,
            0,
            1,
            @ImportedBy
        FROM [Settimane] s
        OPTION (MAXRECURSION 12);

        UPDATE [animatori].[import_animatori_forms_log]
        SET [Stato] = N'IMPORTED',
            [Messaggio] = N'Import completato con successo.',
            [ID_Animatore] = @ID_Animatore,
            [DataImport] = SYSUTCDATETIME(),
            [ImportatoDa] = @ImportedBy
        WHERE [ID] = @ExistingImportID;

        COMMIT TRANSACTION;
        SELECT CAST(1 AS BIT) AS [Success], CAST(0 AS BIT) AS [AlreadyImported], @ID_Animatore AS [ID_Animatore], @ResolvedEvento AS [ID_Evento], N'Import completato con successo.' AS [Message];
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @ErrorMessage = ERROR_MESSAGE();

        IF EXISTS (SELECT 1 FROM [animatori].[import_animatori_forms_log] WHERE [FormId] = @FormId AND [ResponseId] = @ResponseId)
        BEGIN
            UPDATE [animatori].[import_animatori_forms_log]
            SET [Stato] = N'ERROR',
                [Messaggio] = LEFT(@ErrorMessage, 500),
                [ID_Evento] = @ResolvedEvento,
                [DataImport] = SYSUTCDATETIME(),
                [ImportatoDa] = @ImportedBy
            WHERE [FormId] = @FormId
              AND [ResponseId] = @ResponseId;
        END

        ;THROW;
    END CATCH
END
GO

IF OBJECT_ID(N'[animatori].[usp_ImportaAnimatoreDaFormsFlat]', N'P') IS NOT NULL
    DROP PROCEDURE [animatori].[usp_ImportaAnimatoreDaFormsFlat];
GO

CREATE PROCEDURE [animatori].[usp_ImportaAnimatoreDaFormsFlat]
    @ResponseId NVARCHAR(100),
    @FormId NVARCHAR(200) = N'',
    @ID_Evento VARCHAR(20) = NULL,
    @SubmittedAt DATETIME2(0) = NULL,
    @ImportedBy NVARCHAR(100) = N'Power Automate',
    @Nome NVARCHAR(100),
    @Cognome NVARCHAR(100),
    @CodiceFiscale NVARCHAR(64) = NULL,
    @DataNascita DATE = NULL,
    @Cellulare NVARCHAR(50) = NULL,
    @EmailModuli NVARCHAR(200) = NULL,
    @TagliaMaglietta NVARCHAR(20) = NULL,
    @TagliaPantaloncini NVARCHAR(20) = NULL,
    @AllergieIntolleranze NVARCHAR(800) = NULL,
    @TerapieNote NVARCHAR(800) = NULL,
    @Navetta BIT = 0,
    @Maggiorenne BIT = 0,
    @NomeMamma NVARCHAR(100) = NULL,
    @CognomeMamma NVARCHAR(100) = NULL,
    @MailMamma NVARCHAR(200) = NULL,
    @CellulareMamma NVARCHAR(50) = NULL,
    @NomePapa NVARCHAR(100) = NULL,
    @CognomePapa NVARCHAR(100) = NULL,
    @MailPapa NVARCHAR(200) = NULL,
    @CellularePapa NVARCHAR(50) = NULL,
    @DisponibilitaSettimana1 BIT = 0,
    @DisponibilitaSettimana2 BIT = 0,
    @DisponibilitaSettimana3 BIT = 0,
    @DisponibilitaSettimana4 BIT = 0,
    @DisponibilitaSettimana5 BIT = 0,
    @NumeroMaglietteExtra INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PayloadJson NVARCHAR(MAX);

    SELECT @PayloadJson = (
        SELECT
            @Nome AS [Nome],
            @Cognome AS [Cognome],
            @CodiceFiscale AS [CodiceFiscale],
            CONVERT(VARCHAR(10), @DataNascita, 23) AS [DataNascita],
            @Cellulare AS [Cellulare],
            @EmailModuli AS [EmailModuli],
            @TagliaMaglietta AS [TagliaMaglietta],
            @TagliaPantaloncini AS [TagliaPantaloncini],
            @AllergieIntolleranze AS [AllergieIntolleranze],
            @TerapieNote AS [TerapieNote],
            @Navetta AS [Navetta],
            @Maggiorenne AS [Maggiorenne],
            @NomeMamma AS [NomeMamma],
            @CognomeMamma AS [CognomeMamma],
            @MailMamma AS [MailMamma],
            @CellulareMamma AS [CellulareMamma],
            @NomePapa AS [NomePapa],
            @CognomePapa AS [CognomePapa],
            @MailPapa AS [MailPapa],
            @CellularePapa AS [CellularePapa],
            @DisponibilitaSettimana1 AS [DisponibilitaSettimana1],
            @DisponibilitaSettimana2 AS [DisponibilitaSettimana2],
            @DisponibilitaSettimana3 AS [DisponibilitaSettimana3],
            @DisponibilitaSettimana4 AS [DisponibilitaSettimana4],
            @DisponibilitaSettimana5 AS [DisponibilitaSettimana5],
            @NumeroMaglietteExtra AS [NumeroMaglietteExtra]
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );

    EXEC [animatori].[usp_ImportaAnimatoreDaForms]
        @PayloadJson = @PayloadJson,
        @ResponseId = @ResponseId,
        @FormId = @FormId,
        @ID_Evento = @ID_Evento,
        @SubmittedAt = @SubmittedAt,
        @ImportedBy = @ImportedBy;
END
GO

PRINT 'Stored procedure animatori create.';
GO

-- ============================================================
-- END 05_stored_procedures.sql
-- ============================================================

-- ============================================================
-- BEGIN 06_grant_power_automate_execute.sql
-- ============================================================

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE [name] = N'$(APP_USER)')
BEGIN
    GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[animatori] TO [$(APP_USER)];
    GRANT EXECUTE ON SCHEMA::[animatori] TO [$(APP_USER)];
    GRANT VIEW DEFINITION ON SCHEMA::[animatori] TO [$(APP_USER)];
END
GO

PRINT 'Permessi applicativi e Power Automate su schema [animatori] applicati.';
GO

-- ============================================================
-- END 06_grant_power_automate_execute.sql
-- ============================================================
