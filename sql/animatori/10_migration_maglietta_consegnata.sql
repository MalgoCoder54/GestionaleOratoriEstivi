-- ============================================================
-- 10_migration_maglietta_consegnata.sql
-- Aggiunge la colonna MagliettaConsegnata alla tabella animatori.animatori
-- Idempotente: si può rieseguire senza errori
-- ============================================================

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[animatori].[animatori]')
      AND name = 'MagliettaConsegnata'
)
BEGIN
    ALTER TABLE [animatori].[animatori]
        ADD [MagliettaConsegnata] BIT NOT NULL
        CONSTRAINT [DF_animatori_MagliettaConsegnata] DEFAULT 0;
    PRINT 'Colonna [MagliettaConsegnata] aggiunta a [animatori].[animatori].';
END
ELSE
    PRINT 'Colonna [MagliettaConsegnata] gia presente.';
GO
