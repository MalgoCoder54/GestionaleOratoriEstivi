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
