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
