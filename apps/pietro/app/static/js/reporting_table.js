const OVERVIEW_COLUMNS = [
    { key: 'Cognome', label: 'Cognome' },
    { key: 'Nome', label: 'Nome' },
    { key: 'ClasseFrequentata', label: 'Classe' },
    { key: 'Squadra', label: 'Squadra' },
    { key: 'TagliaMaglietta', label: 'Taglia' },
    { key: 'MailMamma', label: 'Mail mamma' },
    { key: 'MailPapa', label: 'Mail papa' },
    { key: 'MailRicevuta', label: 'Mail ricevuta' },
    { key: 'CellulareMamma', label: 'Cell. mamma' },
    { key: 'CellularePapa', label: 'Cell. papa' },
    { key: 'NavettaLabel', label: 'Navetta' },
    { key: 'UscitaAutorizzataLabel', label: 'Uscita da solo' },
    { key: 'IscrizioneValidataLabel', label: 'Validata' },
    { key: 'SettimaneAttiveLabel', label: 'Settimane' },
    { key: 'AllergieIntolleranze', label: 'Allergie' },
];

const overviewState = {
    rows: [],
    filters: {},
};

document.addEventListener('DOMContentLoaded', () => {
    initOverviewPage();
});

async function initOverviewPage() {
    renderOverviewHead();
    bindOverviewFilters();

    const resetButton = document.getElementById('overviewReset');
    if (resetButton) {
        resetButton.addEventListener('click', resetOverviewFilters);
    }

    try {
        const payload = await api('/api/reporting/iscritti');
        overviewState.rows = payload.rows || [];
        renderOverviewBody();
    } catch (error) {
        toast(error.message || 'Errore caricamento vista dati', 'error');
        document.getElementById('overviewCount').textContent = 'Errore caricamento';
    }
}

function renderOverviewHead() {
    const head = document.getElementById('overviewTableHead');
    head.innerHTML = `
        <tr>
            ${OVERVIEW_COLUMNS.map((column) => `
                <th>
                    <div class="column-head">
                        <span class="column-title">${escapeHtml(column.label)}</span>
                        <input
                            type="text"
                            class="column-filter"
                            data-key="${escapeHtml(column.key)}"
                            placeholder="Filtra..."
                            autocomplete="off"
                        >
                    </div>
                </th>
            `).join('')}
        </tr>
    `;
}

function bindOverviewFilters() {
    document.getElementById('overviewTableHead').addEventListener('input', debounce((event) => {
        const key = event.target.dataset.key;
        if (!key) {
            return;
        }
        overviewState.filters[key] = (event.target.value || '').trim().toLowerCase();
        renderOverviewBody();
    }, 120));
}

function resetOverviewFilters() {
    overviewState.filters = {};
    document.querySelectorAll('.column-filter').forEach((input) => {
        input.value = '';
    });
    renderOverviewBody();
}

function getOverviewFilteredRows() {
    return overviewState.rows.filter((row) => OVERVIEW_COLUMNS.every((column) => {
        const filterValue = overviewState.filters[column.key];
        if (!filterValue) {
            return true;
        }
        const normalizedValue = String(row[column.key] ?? '').toLowerCase();
        return normalizedValue.includes(filterValue);
    }));
}

function renderOverviewBody() {
    const rows = getOverviewFilteredRows();
    const body = document.getElementById('overviewTableBody');
    const count = document.getElementById('overviewCount');
    const empty = document.getElementById('overviewEmpty');
    const table = document.getElementById('overviewTable');

    count.textContent = `${rows.length} iscritti visibili`;

    if (!rows.length) {
        body.innerHTML = '';
        table.hidden = true;
        empty.hidden = false;
        return;
    }

    table.hidden = false;
    empty.hidden = true;
    body.innerHTML = rows.map((row) => `
        <tr>
            ${OVERVIEW_COLUMNS.map((column) => `
                <td>${escapeHtml(row[column.key] ?? '')}</td>
            `).join('')}
        </tr>
    `).join('');
}
