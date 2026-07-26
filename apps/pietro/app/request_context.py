from .config_manager import get_current_event_id
from .models import Iscritto


def get_iscritto_or_404(iscritto_id):
    evento = get_current_event_id()
    return Iscritto.query.filter_by(ID=iscritto_id, ID_Evento=evento).first_or_404()
