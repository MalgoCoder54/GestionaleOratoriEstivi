from datetime import datetime, timezone

from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()


class EventoAnimatori(db.Model):
    __tablename__ = "eventi_animatori"
    __table_args__ = {"schema": "animatori"}

    ID_Evento = db.Column(db.String(20), primary_key=True)
    Nome = db.Column(db.String(100), nullable=False)
    Anno = db.Column(db.Integer, nullable=False)
    NumeroSettimane = db.Column(db.Integer, default=5)
    DataInizio = db.Column(db.Date)
    DataFine = db.Column(db.Date)
    Attivo = db.Column(db.Boolean, default=True)


class ConfigurazioneAnimatoriEvento(db.Model):
    __tablename__ = "configurazione_animatori_eventi"
    __table_args__ = {"schema": "animatori"}

    ID_Evento = db.Column(db.String(20), db.ForeignKey("animatori.eventi_animatori.ID_Evento"), primary_key=True)
    ConfigJson = db.Column(db.Text, nullable=False)
    DataCreazione = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    DataModifica = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    ModificatoDa = db.Column(db.String(100), default="App")


class Animatore(db.Model):
    __tablename__ = "animatori"
    __table_args__ = {"schema": "animatori"}

    ID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    ID_Evento = db.Column(db.String(20), db.ForeignKey("animatori.eventi_animatori.ID_Evento"), nullable=False)
    Nome = db.Column(db.String(100), nullable=False)
    Cognome = db.Column(db.String(100), nullable=False)
    CodiceFiscale = db.Column(db.String(64))
    DataNascita = db.Column(db.Date)
    Cellulare = db.Column(db.String(50))
    EmailModuli = db.Column(db.String(200))
    TagliaMaglietta = db.Column(db.String(20))
    TagliaPantaloncini = db.Column(db.String(20))
    MagliettaConsegnata = db.Column(db.Boolean, default=False)
    AllergieIntolleranze = db.Column(db.String(800), default="Nessuna")
    TerapieNote = db.Column(db.String(800))
    Navetta = db.Column(db.Boolean, default=False)
    Maggiorenne = db.Column(db.Boolean, default=False)

    NomeMamma = db.Column(db.String(100))
    CognomeMamma = db.Column(db.String(100))
    MailMamma = db.Column(db.String(200))
    CellulareMamma = db.Column(db.String(50))
    NomePapa = db.Column(db.String(100))
    CognomePapa = db.Column(db.String(100))
    MailPapa = db.Column(db.String(200))
    CellularePapa = db.Column(db.String(50))

    StatoDocumenti = db.Column(db.String(30), default="INVIATI")
    StatoOperativo = db.Column(db.String(30), default="IMPORTATO")
    IscrizioneValidata = db.Column(db.Boolean, default=False)
    DataValidazione = db.Column(db.Date)
    NoteSegreteria = db.Column(db.Text)

    DataCreazione = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    DataModifica = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    ModificatoDa = db.Column(db.String(100), default="App")

    contributo = db.relationship("ContributoAnimatore", backref="animatore", uselist=False, lazy=True, cascade="all, delete-orphan")
    settimane = db.relationship("DisponibilitaAnimatore", backref="animatore", lazy=True, order_by="DisponibilitaAnimatore.NumeroSettimana", cascade="all, delete-orphan")

    @property
    def nome_completo(self):
        return f"{self.Cognome} {self.Nome}".strip()

    def to_dict(self):
        data = {}
        for column in self.__table__.columns:
            value = getattr(self, column.name)
            if hasattr(value, "isoformat"):
                value = value.isoformat()
            data[column.name] = value
        return data


class ContributoAnimatore(db.Model):
    __tablename__ = "contributi_animatori"
    __table_args__ = {"schema": "animatori"}

    ID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    ID_Animatore = db.Column(db.Integer, db.ForeignKey("animatori.animatori.ID"), nullable=False, unique=True)
    ID_Evento = db.Column(db.String(20), db.ForeignKey("animatori.eventi_animatori.ID_Evento"), nullable=False)
    ImportoContributo = db.Column(db.Numeric(10, 2), default=25.0)
    NumeroMaglietteExtra = db.Column(db.Integer, default=0)
    ImportoMaglietteExtra = db.Column(db.Numeric(10, 2), default=0.0)
    TotaleDovuto = db.Column(db.Numeric(10, 2), default=25.0)
    Pagato = db.Column(db.Boolean, default=False)
    DataPagamento = db.Column(db.Date)
    MetodoPagamento = db.Column(db.String(30), default="BONIFICO")
    ContabileRicevuta = db.Column(db.Boolean, default=False)
    NotePagamento = db.Column(db.Text)
    DataModifica = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    ModificatoDa = db.Column(db.String(100), default="App")


class DisponibilitaAnimatore(db.Model):
    __tablename__ = "disponibilita_animatori"
    __table_args__ = {"schema": "animatori"}

    ID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    ID_Animatore = db.Column(db.Integer, db.ForeignKey("animatori.animatori.ID"), nullable=False)
    ID_Evento = db.Column(db.String(20), db.ForeignKey("animatori.eventi_animatori.ID_Evento"), nullable=False)
    NumeroSettimana = db.Column(db.Integer, nullable=False)
    Disponibile = db.Column(db.Boolean, default=False)
    Presente = db.Column(db.Boolean, default=False)
    InGita = db.Column(db.Boolean, default=False)
    InOratorio = db.Column(db.Boolean, default=True)
    NoteTurno = db.Column(db.String(500))
    DataModifica = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    ModificatoDa = db.Column(db.String(100), default="App")
