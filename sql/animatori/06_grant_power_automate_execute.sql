:setvar APP_USER "oratorio_app_rw"

USE [$(DB_NAME)];
GO

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE [name] = N'$(APP_USER)')
BEGIN
    GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[animatori] TO [$(APP_USER)];
    GRANT EXECUTE ON SCHEMA::[animatori] TO [$(APP_USER)];
    GRANT VIEW DEFINITION ON SCHEMA::[animatori] TO [$(APP_USER)];
END
GO

PRINT 'Permessi applicativi e Power Automate su schema [animatori] applicati.';
GO
