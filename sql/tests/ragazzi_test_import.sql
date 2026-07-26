-- Test sintetico/idempotente della stored procedure ragazzi.

DECLARE @Payload NVARCHAR(MAX) = N'{
  "NomeRagazzo": "Test",
  "CognomeRagazzo": "Import",
  "DataNascitaRagazzo": "2015-01-01",
  "ClasseFrequentata": "Classe 1",
  "AllergieIntolleranze": "Nessuna",
  "NomeMamma": "Test",
  "MailMamma": "test@example.invalid",
  "MailRicevuta": "test@example.invalid",
  "Gratuita": false
}';

EXEC [dbo].[usp_ImportaIscrittoDaForms]
    @PayloadJson = @Payload,
    @ResponseId = N'TEST-RAGAZZI-001',
    @FormId = N'test-oratorio-estivo',
    @ID_Evento = NULL,
    @SubmittedAt = SYSUTCDATETIME(),
    @ImportedBy = N'Test SQL';
GO

