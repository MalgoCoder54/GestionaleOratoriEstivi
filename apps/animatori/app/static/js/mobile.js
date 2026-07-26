document.addEventListener('DOMContentLoaded', initMobile);

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
                : `${data.length} animatori disponibili`;
        }
        results.innerHTML = data.length
            ? data.map((animatore) => `
                <li class="mobile-result-item" onclick="apriSchedaMobile(${animatore.ID})">
                    <span class="mobile-result-name">${escapeHtml(animatore.Cognome)} ${escapeHtml(animatore.Nome)}</span>
                    <span class="mobile-result-arrow">&rsaquo;</span>
                </li>
            `).join('')
            : '<li class="mobile-result-item mobile-result-empty">Nessun animatore trovato</li>';
    } catch (error) {
        toast(error.message || 'Errore nel caricamento elenco', 'error');
    } finally {
        setMobileLoading(false);
    }
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
        const data = await api(`/api/mobile/animatore/${id}`);
        const settimane = data.settimane || [];
        const badge = document.getElementById('mobilePresenza');
        const presenzaAttiva = settimane.some((item) => item.presente);
        const disponibilitaAttiva = settimane.some((item) => item.disponibile);

        setMobileView('detail');
        document.getElementById('mobileNome').textContent = `${data.Cognome} ${data.Nome}`;
        document.getElementById('mobileCellulare').textContent = data.Cellulare || 'N/D';
        document.getElementById('mobileNavetta').textContent = formatMobileBool(data.Navetta);
        document.getElementById('mobileMaggiorenne').textContent = formatMobileBool(data.Maggiorenne);
        document.getElementById('mobileAllergie').textContent = data.AllergieIntolleranze || 'Nessuna';

        if (badge) {
            if (presenzaAttiva) {
                badge.textContent = 'Presente';
                badge.className = 'mobile-presence-badge presente';
            } else if (disponibilitaAttiva) {
                badge.textContent = 'Disponibile';
                badge.className = 'mobile-presence-badge neutro';
            } else {
                badge.textContent = data.StatoOperativo || 'Da assegnare';
                badge.className = 'mobile-presence-badge non-presente';
            }
        }

        renderMobileWeeks(settimane);

        const terapieSection = document.getElementById('mobileTerapieSection');
        if (data.TerapieNote) {
            terapieSection.style.display = '';
            document.getElementById('mobileTerapie').textContent = data.TerapieNote;
        } else {
            terapieSection.style.display = 'none';
        }
    } catch (error) {
        toast(error.message || 'Errore nel caricamento dettaglio', 'error');
    }
};

function renderMobileWeeks(settimane) {
    const section = document.getElementById('mobilePresenzeSection');
    const list = document.getElementById('mobilePresenzeList');

    if (!section || !list) {
        return;
    }

    if (!settimane.length) {
        section.style.display = 'none';
        return;
    }

    list.innerHTML = settimane.map((item) => {
        const chipClass = item.disponibile ? 'presence-chip-on' : 'presence-chip-off';
        const flags = [];
        if (item.presente) {
            flags.push('presente');
        }
        if (item.in_gita) {
            flags.push('gita');
        }
        if (item.in_oratorio) {
            flags.push('oratorio');
        }
        const suffix = flags.length ? ` · ${flags.join(' · ')}` : '';
        return `
            <span class="presence-chip ${chipClass}">
                ${escapeHtml(item.label)}: ${item.disponibile ? 'SI' : 'NO'}${escapeHtml(suffix)}
            </span>
        `;
    }).join('');
    section.style.display = '';
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
