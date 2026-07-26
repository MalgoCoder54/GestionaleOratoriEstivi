document.addEventListener('DOMContentLoaded', () => {
    initMobile();
});

function setMobileView(view) {
    const listScreen = document.getElementById('mobileListScreen');
    const detailScreen = document.getElementById('mobileCard');

    document.body.classList.toggle('mobile-detail-open', view === 'detail');
    if (listScreen) {
        listScreen.style.display = view === 'detail' ? 'none' : '';
    }
    if (detailScreen) {
        detailScreen.hidden = view !== 'detail';
    }
}

function setMobileLoading(isLoading) {
    const spinner = document.getElementById('mobileSpinner');
    if (spinner) {
        spinner.style.display = isLoading ? '' : 'none';
    }
}

async function loadMobileResults(query = '') {
    const results = document.getElementById('mobileResults');
    const clearButton = document.getElementById('mobileClearSearch');
    const countLabel = document.getElementById('mobileResultCount');
    const suffix = query ? `?q=${encodeURIComponent(query)}` : '';

    if (clearButton) {
        clearButton.style.display = query ? '' : 'none';
    }
    setMobileView('list');

    setMobileLoading(true);
    try {
        const data = await api(`/api/mobile/cerca${suffix}`);
        if (countLabel) {
            countLabel.textContent = query
                ? `${data.length} risultati per "${query}"`
                : `${data.length} iscritti disponibili`;
        }
        results.innerHTML = data.length ? data.map((iscritto) => `
            <li class="mobile-result-item" onclick="apriSchedaMobile(${iscritto.ID})">
                <span class="mobile-result-name">${escapeHtml(iscritto.CognomeRagazzo)} ${escapeHtml(iscritto.NomeRagazzo)}</span>
                <span class="mobile-result-arrow">&rsaquo;</span>
            </li>
        `).join('') : '<li class="mobile-result-item mobile-result-empty">Nessun iscritto trovato</li>';
    } catch (error) {
        toast(error.message || 'Errore nel caricamento elenco', 'error');
    } finally {
        setMobileLoading(false);
    }
}

function initMobile() {
    const searchInput = document.getElementById('mobileSearch');
    if (!searchInput) {
        return;
    }

    loadMobileResults('');
    searchInput.addEventListener('input', debounce((event) => {
        loadMobileResults(event.target.value.trim());
    }, 250));
}

window.clearMobileSearch = function clearMobileSearch() {
    const searchInput = document.getElementById('mobileSearch');
    if (searchInput) {
        searchInput.value = '';
        searchInput.focus();
    }
    loadMobileResults('');
};

window.apriSchedaMobile = async function apriSchedaMobile(id) {
    try {
        const data = await api(`/api/mobile/iscritto/${id}`);
        setMobileView('detail');
        document.getElementById('mobileNome').textContent = `${data.NomeRagazzo} ${data.CognomeRagazzo}`;
        document.getElementById('mobileClasse').textContent = data.ClasseFrequentata || 'Non indicata';
        document.getElementById('mobileSquadra').textContent = data.Squadra || 'Non assegnata';
        document.getElementById('mobileUscitaAutorizzata').textContent = formatMobileBool(data.UscitaAutorizzata);

        const badge = document.getElementById('mobilePresenza');
        badge.textContent = data.stato_presenza;
        badge.className = 'mobile-presence-badge ' +
            (data.presente === true ? 'presente' : data.presente === false ? 'non-presente' : 'neutro');

        const presenzeSection = document.getElementById('mobilePresenzeSection');
        const presenzeList = document.getElementById('mobilePresenzeList');
        const presenze = data.presenze_settimanali || [];
        if (presenzeSection && presenzeList) {
            if (presenze.length) {
                presenzeList.innerHTML = presenze.map((item) => `
                    <span class="presence-chip ${item.presente ? 'presence-chip-on' : 'presence-chip-off'}">
                        Sett. ${item.settimana}: ${item.presente ? 'SI' : 'NO'}
                    </span>
                `).join('');
                presenzeSection.style.display = '';
            } else {
                presenzeSection.style.display = 'none';
            }
        }

        let contactsHtml = '';
        if (data.NomeMamma && data.NomeMamma !== 'NO') {
            contactsHtml += contactItem(`${data.NomeMamma} ${data.CognomeMamma || ''} (Mamma)`, data.CellulareMamma);
        }
        if (data.NomePapa && data.NomePapa !== 'NO') {
            contactsHtml += contactItem(`${data.NomePapa} ${data.CognomePapa || ''} (Papa)`, data.CellularePapa);
        }
        document.getElementById('mobileContatti').innerHTML = contactsHtml || '<p>Nessun contatto disponibile</p>';

        document.getElementById('mobileAllergie').textContent = data.AllergieIntolleranze || 'Nessuna';

        const terapieSection = document.getElementById('mobileTerapieSection');
        if (data.TerapieNote) {
            terapieSection.style.display = '';
            document.getElementById('mobileTerapie').textContent = data.TerapieNote;
        } else {
            terapieSection.style.display = 'none';
        }
    } catch (error) {
        toast(error.message || 'Errore nel caricamento', 'error');
    }
};

function contactItem(name, phone) {
    const phoneLink = phone && phone !== 'NO'
        ? `<a href="tel:${escapeHtml(phone)}">${escapeHtml(phone)}</a>`
        : 'N/D';
    return `<div class="mobile-contact-item">
        <span class="contact-name">${escapeHtml(name)}</span>
        <span class="contact-phone">${phoneLink}</span>
    </div>`;
}

function formatMobileBool(value) {
    if (value === true) {
        return 'SI';
    }
    if (value === false) {
        return 'NO';
    }
    return 'N/D';
}

window.chiudiScheda = function chiudiScheda() {
    setMobileView('list');
    const searchInput = document.getElementById('mobileSearch');
    if (searchInput) {
        searchInput.focus();
    }
};
