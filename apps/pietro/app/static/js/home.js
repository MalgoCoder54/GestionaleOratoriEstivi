let currentIscritto = null;
let originalData = null;
let homeEditMode = false;

document.addEventListener('DOMContentLoaded', () => {
    const searchInput = document.getElementById('searchInput');
    if (!searchInput) {
        return;
    }

    populateDropdowns();
    searchInput.addEventListener('input', debounce(() => {
        loadIscrittiList(searchInput.value.trim());
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
    fillSelect('selectClasse', config.classi_disponibili || []);
    fillSelect('new_ClasseFrequentata', config.classi_disponibili || []);
    fillSelect('selectTaglia', config.taglie_maglietta || []);
    fillSelect('new_TagliaMaglietta', config.taglie_maglietta || []);
    fillSelect('selectSquadra', config.squadre || []);
    fillSelect('new_Squadra', config.squadre || []);
}

async function loadIscrittiList(query = '') {
    try {
        const suffix = query ? `?q=${encodeURIComponent(query)}` : '';
        const iscritti = await api(`/api/iscritti${suffix}`);
        renderIscrittiList(iscritti);
    } catch (error) {
        toast(error.message || 'Errore caricamento lista iscritti', 'error');
    }
}

function renderIscrittiList(iscritti) {
    const list = document.getElementById('iscrittiList');
    if (!list) {
        return;
    }

    if (!iscritti.length) {
        list.innerHTML = '<li class="iscritto-item iscritto-item-empty">Nessun iscritto trovato</li>';
        return;
    }

    list.innerHTML = iscritti.map((iscritto) => `
        <li class="iscritto-item${currentIscritto && currentIscritto.ID === iscritto.ID ? ' active' : ''}" data-id="${iscritto.ID}" onclick="selezionaIscritto(${iscritto.ID})">
            <span class="iscritto-nome">${escapeHtml(iscritto.CognomeRagazzo)} ${escapeHtml(iscritto.NomeRagazzo)}</span>
            <span class="iscritto-data">${iscritto.DataNascitaRagazzo ? formatDate(iscritto.DataNascitaRagazzo) : ''}</span>
        </li>
    `).join('');
}

function highlightActiveIscritto(selectedId) {
    document.querySelectorAll('.iscritto-item').forEach((element) => {
        element.classList.toggle('active', Number(element.dataset.id) === Number(selectedId));
    });
}

window.selezionaIscritto = async function selezionaIscritto(id) {
    try {
        const data = await api(`/api/iscritti/${id}`);
        currentIscritto = data;
        originalData = { ...data };
        renderDettaglio(data);
        highlightActiveIscritto(id);
        setHomeMobileMode('detail');
        document.getElementById('detailPanel').scrollTop = 0;
    } catch (error) {
        toast(error.message || 'Errore nel caricamento', 'error');
    }
};

function renderDettaglio(data) {
    const emailRicevuta = String(data.MailRicevuta || '').trim();

    document.getElementById('detailEmpty').style.display = 'none';
    document.getElementById('detailContent').style.display = 'block';
    document.getElementById('newForm').style.display = 'none';
    document.getElementById('detailName').textContent = `${data.NomeRagazzo} ${data.CognomeRagazzo}`;
    document.getElementById('btnPagamenti').href = `/pagamenti/${data.ID}`;
    const resendButton = document.getElementById('btnResendConfirmation');
    if (resendButton) {
        resendButton.disabled = !emailRicevuta;
        resendButton.title = emailRicevuta
            ? `Reinvia email di conferma a ${emailRicevuta}`
            : 'Email ricevuta non disponibile';
    }

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
            const target = value ?? '';
            const hasOption = Array.from(element.options).some((option) => option.value === String(target));
            if (target !== '' && !hasOption) {
                const option = document.createElement('option');
                option.value = String(target);
                option.textContent = `${target} (non in elenco)`;
                element.appendChild(option);
            }
            element.value = target;
            return;
        }
        element.value = value ?? '';
    });

    exitEditMode();
}

window.toggleEdit = function toggleEdit() {
    if (!currentIscritto) {
        return;
    }
    homeEditMode = true;
    document.getElementById('btnEdit').style.display = 'none';
    document.getElementById('btnSave').style.display = 'flex';
    document.getElementById('btnCancel').style.display = 'flex';
    document.querySelectorAll('.field-view:not(.field-static)').forEach((element) => { element.style.display = 'none'; });
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

window.salvaIscritto = async function salvaIscritto() {
    if (!currentIscritto) {
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
        await api(`/api/iscritti/${currentIscritto.ID}`, {
            method: 'PUT',
            body: data,
        });
        toast('Scheda salvata');
        await loadIscrittiList(document.getElementById('searchInput').value.trim());
        await selezionaIscritto(currentIscritto.ID);
    } catch (error) {
        toast(error.message || 'Errore nel salvataggio', 'error');
    }
};

window.eliminaIscritto = async function eliminaIscritto() {
    if (!currentIscritto) {
        return;
    }
    if (!confirm(`Eliminare ${currentIscritto.NomeRagazzo} ${currentIscritto.CognomeRagazzo}?`)) {
        return;
    }

    try {
        await api(`/api/iscritti/${currentIscritto.ID}`, { method: 'DELETE' });
        toast('Iscritto eliminato');
        currentIscritto = null;
        originalData = null;
        document.getElementById('detailContent').style.display = 'none';
        document.getElementById('newForm').style.display = 'none';
        document.getElementById('detailEmpty').style.display = 'flex';
        setHomeMobileMode('list');
        await loadIscrittiList(document.getElementById('searchInput').value.trim());
    } catch (error) {
        toast(error.message || 'Errore nella cancellazione', 'error');
    }
};

window.reinviaEmailConferma = async function reinviaEmailConferma() {
    if (!currentIscritto) {
        return;
    }

    const nome = String(currentIscritto.NomeRagazzo || '').trim();
    const cognome = String(currentIscritto.CognomeRagazzo || '').trim();
    const email = String(currentIscritto.MailRicevuta || '').trim();

    if (!email) {
        toast('Email ricevuta non disponibile per questo iscritto', 'error');
        return;
    }

    if (!confirm(`Vuoi reinviare l'email di conferma a ${nome} - ${cognome} - ${email}?`)) {
        return;
    }

    try {
        await api(`/api/iscritti/${currentIscritto.ID}/reinvia-email-conferma`, {
            method: 'POST',
        });
        toast('Email di conferma reinviata');
    } catch (error) {
        toast(error.message || "Errore durante il reinvio dell'email", 'error');
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

function validateNewIscritto(data) {
    const errors = [];
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    if (!data.NomeRagazzo) {
        errors.push('Nome Ragazzo/a obbligatorio');
    }
    if (!data.CognomeRagazzo) {
        errors.push('Cognome Ragazzo/a obbligatorio');
    }

    ['MailMamma', 'MailPapa', 'MailRicevuta'].forEach((field) => {
        if (data[field] && !emailRegex.test(data[field])) {
            errors.push(`${field}: formato email non valido`);
        }
    });

    return errors;
}

window.salvaNuovoIscritto = async function salvaNuovoIscritto() {
    const fields = [
        'NomeRagazzo', 'CognomeRagazzo', 'DataNascitaRagazzo', 'CodiceFiscaleRagazzo',
        'ClasseFrequentata', 'LuogoNascitaRagazzo', 'ResidenteA', 'InVia',
        'AllergieIntolleranze', 'TerapieNote', 'TagliaMaglietta', 'Navetta',
        'NomeMamma', 'CognomeMamma', 'MailMamma', 'CellulareMamma',
        'NomePapa', 'CognomePapa', 'MailPapa', 'CellularePapa',
        'RicevutaIntestatA', 'CodiceFiscaleRicevuta', 'MailRicevuta',
        'Squadra', 'UscitaAutorizzata',
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

    const errors = validateNewIscritto(data);
    if (errors.length) {
        toast(errors.join(' | '), 'error');
        return;
    }

    try {
        const result = await api('/api/iscritti', {
            method: 'POST',
            body: data,
        });
        toast('Iscritto creato');
        await loadIscrittiList(document.getElementById('searchInput').value.trim());
        await selezionaIscritto(result.id);
    } catch (error) {
        toast(error.message || 'Errore nella creazione', 'error');
    }
};
