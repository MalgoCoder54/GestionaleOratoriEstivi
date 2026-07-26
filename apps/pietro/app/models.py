from datetime import date, datetime, timezone
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()


class Evento(db.Model):
    __tablename__ = "eventi"

    ID_Evento = db.Column(db.String(20), primary_key=True)
    Nome = db.Column(db.String(100), nullable=False)
    Anno = db.Column(db.Integer, nullable=False)
    NumeroSettimane = db.Column(db.Integer, default=5)
    DataInizio = db.Column(db.Date)
    DataFine = db.Column(db.Date)
    Attivo = db.Column(db.Boolean, default=True)

    iscritti = db.relationship("Iscritto", backref="evento", lazy=True)
    configurazione = db.relationship(
        "ConfigurazioneEvento",
        backref="evento",
        lazy=True,
        uselist=False,
        cascade="all, delete-orphan",
    )


class ConfigurazioneEvento(db.Model):
    __tablename__ = "configurazione_eventi"

    ID_Evento = db.Column(
        db.String(20),
        db.ForeignKey("eventi.ID_Evento"),
        primary_key=True,
    )
    ConfigJson = db.Column(db.Text, nullable=False)
    DataCreazione = db.Column(
        db.DateTime,
        default=lambda: datetime.now(timezone.utc),
    )
    DataModifica = db.Column(
        db.DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
    ModificatoDa = db.Column(db.String(100), default="App")


class Iscritto(db.Model):
    __tablename__ = "iscritti"

    ID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    ID_Evento = db.Column(db.String(20), db.ForeignKey("eventi.ID_Evento"), nullable=False)

    NomeRagazzo = db.Column(db.String(100), nullable=False)
    CognomeRagazzo = db.Column(db.String(100), nullable=False)
    CodiceFiscaleRagazzo = db.Column(db.String(64))
    DataNascitaRagazzo = db.Column(db.Date)
    LuogoNascitaRagazzo = db.Column(db.String(100))
    ResidenteA = db.Column(db.String(100))
    InVia = db.Column(db.String(200))
    ClasseFrequentata = db.Column(db.String(50))
    AllergieIntolleranze = db.Column(db.String(500), default="Nessuna")
    TerapieNote = db.Column(db.String(500))
    TagliaMaglietta = db.Column(db.String(20))
    MagliettaConsegnata = db.Column(db.Boolean, default=False)
    Navetta = db.Column(db.Boolean, default=False)

    NomeMamma = db.Column(db.String(100))
    CognomeMamma = db.Column(db.String(100))
    MailMamma = db.Column(db.String(200))
    CellulareMamma = db.Column(db.String(50))

    NomePapa = db.Column(db.String(100))
    CognomePapa = db.Column(db.String(100))
    MailPapa = db.Column(db.String(200))
    CellularePapa = db.Column(db.String(50))

    RicevutaIntestatA = db.Column(db.String(200))
    CodiceFiscaleRicevuta = db.Column(db.String(64))
    MailRicevuta = db.Column(db.String(200))

    Squadra = db.Column(db.String(50))
    UscitaAutorizzata = db.Column(db.Boolean, default=False)
    IscrizioneValidata = db.Column(db.Boolean, default=False)
    DataValidazione = db.Column(db.Date)

    PresenzaSettimana1 = db.Column(db.Boolean, default=False)
    PresenzaSettimana2 = db.Column(db.Boolean, default=False)
    PresenzaSettimana3 = db.Column(db.Boolean, default=False)
    PresenzaSettimana4 = db.Column(db.Boolean, default=False)
    PresenzaSettimana5 = db.Column(db.Boolean, default=False)

    DataCreazione = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    DataModifica = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    ModificatoDa = db.Column(db.String(100), default="App")
    # RowVersion gestito direttamente nello schema SQL Server

    contabilita = db.relationship(
        "Contabilita",
        backref="iscritto",
        uselist=False,
        lazy=True,
        cascade="all, delete-orphan",
        single_parent=True,
    )

    @property
    def nome_completo(self):
        return f"{self.CognomeRagazzo} {self.NomeRagazzo}"

    def to_dict(self):
        return {c.name: getattr(self, c.name) for c in self.__table__.columns}

    def to_mobile_dict(self):
        return {
            "ID": self.ID,
            "NomeRagazzo": self.NomeRagazzo,
            "CognomeRagazzo": self.CognomeRagazzo,
            "ClasseFrequentata": self.ClasseFrequentata,
            "Squadra": self.Squadra,
            "UscitaAutorizzata": self.UscitaAutorizzata,
            "AllergieIntolleranze": self.AllergieIntolleranze,
            "TerapieNote": self.TerapieNote,
            "CellulareMamma": self.CellulareMamma,
            "CellularePapa": self.CellularePapa,
            "NomeMamma": self.NomeMamma,
            "CognomeMamma": self.CognomeMamma,
            "NomePapa": self.NomePapa,
            "CognomePapa": self.CognomePapa,
        }


class Contabilita(db.Model):
    __tablename__ = "contabilita"

    ID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    ID_Iscritto = db.Column(db.Integer, db.ForeignKey("iscritti.ID"), nullable=False, unique=True)
    ID_Evento = db.Column(db.String(20), db.ForeignKey("eventi.ID_Evento"), nullable=False)

    IscrizionePagata = db.Column(db.Boolean, default=False)
    ImportoIscrizione = db.Column(db.Numeric(10, 2), default=25.0)
    DataPagamentoIscrizione = db.Column(db.Date)
    NumeroMaglietteExtra = db.Column(db.Integer, default=0)
    ImportoMaglietteExtra = db.Column(db.Numeric(10, 2), default=0.0)
    Gratuita = db.Column(db.Boolean, default=False)
    DataModifica = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    ModificatoDa = db.Column(db.String(100), default="App")

    settimane = db.relationship(
        "PagamentoSettimanale",
        backref="contabilita",
        lazy=True,
        order_by="PagamentoSettimanale.NumeroSettimana",
        cascade="all, delete-orphan",
    )


class PagamentoSettimanale(db.Model):
    __tablename__ = "pagamenti_settimanali"

    ID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    ID_Contabilita = db.Column(db.Integer, db.ForeignKey("contabilita.ID"), nullable=False)

    NumeroSettimana = db.Column(db.Integer, nullable=False)
    Mattina = db.Column(db.Boolean, default=False)
    Pomeriggio = db.Column(db.Boolean, default=False)
    Pranzo = db.Column(db.Boolean, default=False)
    GitaSettimana = db.Column(db.Boolean, default=False)
    ImportoGita = db.Column(db.Numeric(10, 2), default=0.0)
    Totale = db.Column(db.Numeric(10, 2), default=0.0)
    PrezzoManuale = db.Column(db.Boolean, default=False)
    TotaleManuale = db.Column(db.Numeric(10, 2))
    Pagato = db.Column(db.Boolean, default=False)
    DataPagamento = db.Column(db.Date)
    DataModifica = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    ModificatoDa = db.Column(db.String(100), default="App")
