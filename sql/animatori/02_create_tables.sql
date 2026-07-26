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
        [MagliettaConsegnata]    BIT             NOT NULL CONSTRAINT [DF_animatori_MagliettaConsegnata] DEFAULT 0,
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
