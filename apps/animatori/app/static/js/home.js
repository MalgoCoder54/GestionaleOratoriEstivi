let currentAnimatore = null;
let originalData = null;
let homeEditMode = false;

document.addEventListener('DOMContentLoaded', () => {
    const searchInput = document.getElementById('searchInput');
    if (!searchInput) {
        return;
    }

    populateDropdowns();
    searchInput.addEventListener('input', debounce(() => {
        loadAnimatoriList(searchInput.value.trim());
    }, 250));
    syncHomeLayout();
    window.addEventListener('resize', debounce(syncHomeLayout, 120));
});

function isMobileHomeViewport() {
    return window.matchMedia('(max-width: 768px)').matches;
}

function setHomeMobileMode(mode) {
    const layout = document.getElementById('homeLayout');
    if (!layout) {
        return;
    }

    layout.classList.remove('mobile-show-list', 'mobile-show-detail');
    if (!isMobileHomeViewport()) {
        return;
    }

    layout.classList.add(mode === 'detail' ? 'mobile-show-detail' : 'mobile-show-list');
}

function syncHomeLayout() {
    if (!isMobileHomeViewport()) {
        setHomeMobileMode(null);
        return;
    }

    const detailVisible = document.getElementById('detailContent')?.style.display !== 'none';
    const newVisible = document.getElementById('newForm')?.style.display !== 'none';
    setHomeMobileMode(detailVisible || newVisible ? 'detail' : 'list');
}

function fillSelect(id, options) {
    const select = document.getElementById(id);
    if (!select) {
        return;
    }
    select.innerHTML = '<option value="">--</option>' + options.map((option) => (
        `<option value="${escapeHtml(option)}">${escapeHtml(option)}</option>`
    )).join('');
}

function populateDropdowns() {
    const config = APP_CONFIG || {};
    fillSelect('selectTagliaMaglietta', config.taglie_maglietta || []);
    fillSelect('new_TagliaMaglietta', config.taglie_maglietta || []);
    fillSelect('selectTagliaPantaloncini', config.taglie_pantaloncini || []);
    fillSelect('new_TagliaPantaloncini', config.taglie_pantaloncini || []);
    fillSelect('selectStatoDocumenti', config.stati_documenti || []);
    fillSelect('selectStatoOperativo', config.stati_operativi || []);
}

async function loadAnimatoriList(query = '') {
    try {
        const suffix = query ? `?q=${encodeURIComponent(query)}` : '';
        const animatori = await api(`/api/animatori${suffix}`);
        renderAnimatoriList(animatori);
    } catch (error) {
        toast(error.message || 'Errore caricamento lista animatori', 'error');
    }
}

function renderAnimatoriList(animatori) {
    const list = document.getElementById('animatoriList');
    if (!list) {
        return;
    }

    if (!animatori.length) {
        list.innerHTML = '<li class="iscritto-item iscritto-item-empty">Nessun animatore trovato</li>';
        return;
    }

    list.innerHTML = animatori.map((animatore) => `
        <li class="iscritto-item${currentAnimatore && currentAnimatore.ID === animatore.ID ? ' active' : ''}" data-id="${animatore.ID}" onclick="selezionaAnimatore(${animatore.ID})">
            <span class="iscritto-nome">${escapeHtml(animatore.Cognome)} ${escapeHtml(animatore.Nome)}</span>
            <span class="iscritto-data">${animatore.Maggiorenne ? 'Maggiorenne' : 'Minorenne'}</span>
        </li>
    `).join('');
}

function highlightActiveAnimatore(selectedId) {
    document.querySelectorAll('.iscritto-item').forEach((element) => {
        element.classList.toggle('active', Number(element.dataset.id) === Number(selectedId));
    });
}

window.selezionaAnimatore = async function selezionaAnimatore(id) {
    try {
        const data = await api(`/api/animatori/${id}`);
        currentAnimatore = data;
        originalData = { ...data };
        renderDettaglio(data);
        highlightActiveAnimatore(id);
        setHomeMobileMode('detail');
        document.getElementById('detailPanel').scrollTop = 0;
    } catch (error) {
        toast(error.message || 'Errore nel caricamento dettaglio', 'error');
    }
};

function renderDettaglio(data) {
    document.getElementById('detailEmpty').style.display = 'none';
    document.getElementById('detailContent').style.display = 'block';
    document.getElementById('newForm').style.display = 'none';
    document.getElementById('detailName').textContent = `${data.Nome} ${data.Cognome}`;
    document.getElementById('btnContributi').href = `/contributi/${data.ID}`;

    document.querySelectorAll('.field-view').forEach((element) => {
        const field = element.dataset.field;
        let value = data[field];
        if (value === true) {
            value = 'SI';
        } else if (value === false) {
            value = 'NO';
        } else if (value === null || value === undefined) {
            value = '';
        } else if (field.includes('Data') && value) {
            value = formatDate(value);
        }
        element.textContent = value;
    });

    document.querySelectorAll('.field-edit').forEach((element) => {
        const field = element.dataset.field;
        let value = data[field];
        if (element.tagName === 'SELECT') {
            if (typeof value === 'boolean') {
                value = String(value);
            }
            element.value = value ?? '';
            return;
        }
        if (element.type === 'date' && value) {
            value = String(value).split('T')[0];
        }
        element.value = value ?? '';
    });

    exitEditMode();
}

window.toggleEdit = function toggleEdit() {
    if (!currentAnimatore) {
        return;
    }
    homeEditMode = true;
    document.getElementById('btnEdit').style.display = 'none';
    document.getElementById('btnSave').style.display = 'flex';
    document.getElementById('btnCancel').style.display = 'flex';
    document.querySelectorAll('.field-view').forEach((element) => { element.style.display = 'none'; });
    document.querySelectorAll('.field-edit').forEach((element) => { element.style.display = ''; });
};

function exitEditMode() {
    homeEditMode = false;
    document.getElementById('btnEdit').style.display = 'flex';
    document.getElementById('btnSave').style.display = 'none';
    document.getElementById('btnCancel').style.display = 'none';
    document.querySelectorAll('.field-view').forEach((element) => { element.style.display = ''; });
    document.querySelectorAll('.field-edit').forEach((element) => { element.style.display = 'none'; });
}

window.annullaEdit = function annullaEdit() {
    if (originalData) {
        renderDettaglio(originalData);
    }
    exitEditMode();
};

window.salvaAnimatore = async function salvaAnimatore() {
    if (!currentAnimatore) {
        return;
    }

    const data = {};
    document.querySelectorAll('#detailContent .field-edit').forEach((element) => {
        const field = element.dataset.field;
        let value = element.value;
        if (element.tagName === 'SELECT') {
            if (value === 'true') {
                value = true;
            } else if (value === 'false') {
                value = false;
            }
        }
        data[field] = value;
    });

    try {
        await api(`/api/animatori/${currentAnimatore.ID}`, {
            method: 'PUT',
            body: data,
        });
        toast('Scheda salvata');
        await loadAnimatoriList(document.getElementById('searchInput').value.trim());
        await selezionaAnimatore(currentAnimatore.ID);
    } catch (error) {
        toast(error.message || 'Errore nel salvataggio', 'error');
    }
};

window.eliminaAnimatore = async function eliminaAnimatore() {
    if (!currentAnimatore) {
        return;
    }
    if (!confirm(`Eliminare ${currentAnimatore.Nome} ${currentAnimatore.Cognome}?`)) {
        return;
    }

    try {
        await api(`/api/animatori/${currentAnimatore.ID}`, { method: 'DELETE' });
        toast('Animatore eliminato');
        currentAnimatore = null;
        originalData = null;
        document.getElementById('detailContent').style.display = 'none';
        document.getElementById('newForm').style.display = 'none';
        document.getElementById('detailEmpty').style.display = 'flex';
        setHomeMobileMode('list');
        await loadAnimatoriList(document.getElementById('searchInput').value.trim());
    } catch (error) {
        toast(error.message || 'Errore nella cancellazione', 'error');
    }
};

window.nuovaScheda = function nuovaScheda() {
    document.getElementById('detailEmpty').style.display = 'none';
    document.getElementById('detailContent').style.display = 'none';
    document.getElementById('newForm').style.display = 'block';
    document.querySelectorAll('.iscritto-item').forEach((element) => element.classList.remove('active'));
    document.getElementById('detailPanel').scrollTop = 0;
    setHomeMobileMode('detail');
};

window.annullaNuovo = function annullaNuovo() {
    document.getElementById('newForm').style.display = 'none';
    document.getElementById('detailEmpty').style.display = 'flex';
    setHomeMobileMode('list');
};

window.tornaAllaLista = function tornaAllaLista() {
    if (!isMobileHomeViewport()) {
        return;
    }
    setHomeMobileMode('list');
};

function validateNuovoAnimatore(data) {
    const errors = [];
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    if (!data.Nome) {
        errors.push('Nome obbligatorio');
    }
    if (!data.Cognome) {
        errors.push('Cognome obbligatorio');
    }

    ['EmailModuli', 'MailMamma', 'MailPapa'].forEach((field) => {
        if (data[field] && !emailRegex.test(data[field])) {
            errors.push(`${field}: formato email non valido`);
        }
    });

    return errors;
}

window.salvaNuovoAnimatore = async function salvaNuovoAnimatore() {
    const fields = [
        'Nome', 'Cognome', 'DataNascita', 'CodiceFiscale', 'Cellulare', 'EmailModuli',
        'TagliaMaglietta', 'TagliaPantaloncini', 'Navetta', 'Maggiorenne',
        'AllergieIntolleranze', 'TerapieNote',
        'NomeMamma', 'CognomeMamma', 'MailMamma', 'CellulareMamma',
        'NomePapa', 'CognomePapa', 'MailPapa', 'CellularePapa',
    ];

    const data = {};
    fields.forEach((field) => {
        const element = document.getElementById(`new_${field}`);
        if (!element) {
            return;
        }
        let value = element.value;
        if (value === 'true') {
            value = true;
        } else if (value === 'false') {
            value = false;
        }
        data[field] = value;
    });

    const errors = validateNuovoAnimatore(data);
    if (errors.length) {
        toast(errors.join(' | '), 'error');
        return;
    }

    try {
        const result = await api('/api/animatori', {
            method: 'POST',
            body: data,
        });
        toast('Nuovo animatore creato');
        await loadAnimatoriList(document.getElementById('searchInput').value.trim());
        await selezionaAnimatore(result.id);
    } catch (error) {
        toast(error.message || 'Errore creazione animatore', 'error');
    }
};
