-- ============================================================
-- 09_migrazione_default_documenti_firma.sql
-- Allinea i default animatori a documenti gia inviati e firma attesa
-- ============================================================

SET NOCOUNT ON;
GO

IF OBJECT_ID(N'[animatori].[animatori]', N'U') IS NULL
BEGIN
    RAISERROR(N'Tabella [animatori].[animatori] non trovata.', 16, 1);
    RETURN;
END
GO

DECLARE @dfStatoDocumenti SYSNAME;

SELECT @dfStatoDocumenti = dc.[name]
FROM sys.default_constraints dc
INNER JOIN sys.columns c
    ON c.[default_object_id] = dc.[object_id]
INNER JOIN sys.tables t
    ON t.[object_id] = c.[object_id]
INNER JOIN sys.schemas s
    ON s.[schema_id] = t.[schema_id]
WHERE s.[name] = N'animatori'
  AND t.[name] = N'animatori'
  AND c.[name] = N'StatoDocumenti';

IF @dfStatoDocumenti IS NOT NULL
    EXEC(N'ALTER TABLE [animatori].[animatori] DROP CONSTRAINT [' + @dfStatoDocumenti + N']');
GO

ALTER TABLE [animatori].[animatori]
ADD CONSTRAINT [DF_animatori_StatoDocumenti] DEFAULT N'INVIATI' FOR [StatoDocumenti];
GO

DECLARE @dfStatoOperativo SYSNAME;

SELECT @dfStatoOperativo = dc.[name]
FROM sys.default_constraints dc
INNER JOIN sys.columns c
    ON c.[default_object_id] = dc.[object_id]
INNER JOIN sys.tables t
    ON t.[object_id] = c.[object_id]
INNER JOIN sys.schemas s
    ON s.[schema_id] = t.[schema_id]
WHERE s.[name] = N'animatori'
  AND t.[name] = N'animatori'
  AND c.[name] = N'StatoOperativo';

IF @dfStatoOperativo IS NOT NULL
    EXEC(N'ALTER TABLE [animatori].[animatori] DROP CONSTRAINT [' + @dfStatoOperativo + N']');
GO

ALTER TABLE [animatori].[animatori]
ADD CONSTRAINT [DF_animatori_StatoOperativo] DEFAULT N'IN_ATTESA_FIRMA' FOR [StatoOperativo];
GO

IF EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE [name] = N'CK_animatori_StatoOperativo'
      AND [parent_object_id] = OBJECT_ID(N'[animatori].[animatori]')
)
BEGIN
    ALTER TABLE [animatori].[animatori] DROP CONSTRAINT [CK_animatori_StatoOperativo];
END
GO

ALTER TABLE [animatori].[animatori] WITH CHECK
ADD CONSTRAINT [CK_animatori_StatoOperativo]
CHECK ([StatoOperativo] IN (N'IN_ATTESA_FIRMA', N'IMPORTATO', N'ATTIVO', N'SOSPESO', N'RITIRATO'));
GO

UPDATE [animatori].[animatori]
SET
    [StatoDocumenti] = CASE WHEN [StatoDocumenti] = N'DA_INVIARE' THEN N'INVIATI' ELSE [StatoDocumenti] END,
    [StatoOperativo] = CASE WHEN [StatoOperativo] = N'IMPORTATO' THEN N'IN_ATTESA_FIRMA' ELSE [StatoOperativo] END,
    [ModificatoDa] = N'Migrazione default documenti/firma'
WHERE [StatoDocumenti] = N'DA_INVIARE'
   OR [StatoOperativo] = N'IMPORTATO';
GO

PRINT 'Default e stati animatori aggiornati: documenti inviati, firma in attesa.';
GO
