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
