from .config_manager import get_current_event_id
from .models import Animatore


def get_animatore_or_404(animatore_id):
    evento = get_current_event_id()
    return Animatore.query.filter_by(ID=animatore_id, ID_Evento=evento).first_or_404()
