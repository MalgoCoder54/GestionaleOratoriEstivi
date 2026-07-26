const COLUMNS = [
    ['Cognome', 'Cognome'],
    ['Nome', 'Nome'],
    ['MaggiorenneLabel', 'Maggiorenne'],
    ['Cellulare', 'Cellulare'],
    ['EmailModuli', 'Email'],
    ['TagliaMaglietta', 'Maglietta'],
    ['TagliaPantaloncini', 'Pantaloncini'],
    ['StatoDocumenti', 'Documenti'],
    ['StatoOperativo', 'Stato'],
    ['PagatoLabel', 'Pagato'],
    ['SettimaneDisponibiliLabel', 'Disponibilita'],
    ['NavettaLabel', 'Navetta'],
];

let reportRows = [];
let reportPayload = null;
let filters = {};

document.addEventListener('DOMContentLoaded', async () => {
    reportPayload = await api('/api/reporting/animatori');
    reportRows = reportPayload.rows || [];

    if (document.getElementById('overviewTable')) {
        renderOverview();
        bindOverviewFilters();
    }

    if (document.getElementById('biKpiGrid')) {
        renderBi();
    }
});

function getFilteredRows() {
    return reportRows.filter((row) => COLUMNS.every(([key]) => {
        const filter = filters[key];
        if (!filter) {
            return true;
        }
        return String(row[key] ?? '').toLowerCase().includes(filter);
    }));
}

function renderOverview() {
    const filtered = getFilteredRows();
    const tableHead = document.getElementById('overviewTableHead');
    const tableBody = document.getElementById('overviewTableBody');
    const emptyState = document.getElementById('overviewEmpty');
    const countChip = document.getElementById('overviewCount');

    tableHead.innerHTML = `
        <tr>
            ${COLUMNS.map(([key, label]) => `
                <th>
                    <div class="column-head">
                        <span class="column-title">${escapeHtml(label)}</span>
                        <input
                            class="column-filter"
                            data-filter="${key}"
                            placeholder="Filtra ${escapeHtml(label.toLowerCase())}"
                            value="${escapeHtml(filters[key] || '')}"
                        >
                    </div>
                </th>
            `).join('')}
        </tr>
    `;

    tableBody.innerHTML = filtered.map((row) => `
        <tr>
            ${COLUMNS.map(([key]) => `<td>${formatCellValue(key, row[key])}</td>`).join('')}
        </tr>
    `).join('');

    if (countChip) {
        countChip.textContent = `${filtered.length} di ${reportRows.length} animatori`;
    }
    if (emptyState) {
        emptyState.hidden = filtered.length !== 0;
    }
}

function bindOverviewFilters() {
    const head = document.getElementById('overviewTableHead');
    if (!head || head.dataset.bound === 'true') {
        return;
    }

    head.addEventListener('input', debounce((event) => {
        const input = event.target.closest('[data-filter]');
        if (!input) {
            return;
        }
        filters[input.dataset.filter] = input.value.trim().toLowerCase();
        renderOverview();
    }, 120));

    const resetButton = document.getElementById('overviewReset');
    if (resetButton) {
        resetButton.addEventListener('click', () => {
            filters = {};
            renderOverview();
        });
    }

    head.dataset.bound = 'true';
}

function formatCellValue(key, value) {
    if (key === 'TotaleDovuto') {
        return formatCurrency(value);
    }
    const text = String(value ?? '').trim();
    return escapeHtml(text || '-');
}

function renderBi() {
    const rows = reportRows;
    const numeroSettimane = Number(reportPayload?.settimane?.numero_settimane || 0);
    const kpiGrid = document.getElementById('biKpiGrid');
    const scopeSummary = document.getElementById('biScopeSummary');

    const maggiorenni = rows.filter((row) => row.Maggiorenne).length;
    const pagati = rows.filter((row) => row.Pagato).length;
    const navetta = rows.filter((row) => row.Navetta).length;
    const conDisponibilita = rows.filter((row) => (row.SettimaneDisponibili || []).length > 0).length;

    if (scopeSummary) {
        scopeSummary.textContent = `${rows.length} animatori importati, ${conDisponibilita} con almeno una settimana disponibile e ${pagati} con contributo registrato.`;
    }

    if (kpiGrid) {
        kpiGrid.innerHTML = [
            ['Animatori', rows.length, 'kpi-card-primary'],
            ['Maggiorenni', maggiorenni, 'kpi-card-navetta'],
            ['Disponibili', conDisponibilita, 'kpi-card-uscita'],
            ['Pagati', pagati, 'kpi-card-success'],
        ].map(([label, value, className]) => `
            <article class="kpi-card ${className}">
                <span class="kpi-label">${escapeHtml(label)}</span>
                <strong class="kpi-value">${escapeHtml(value)}</strong>
            </article>
        `).join('');
    }

    renderBars('weekChart', countWeeks(rows, numeroSettimane), 'bar-fill-class');
    renderBars('shirtChart', countBy(rows, 'TagliaMaglietta'), 'bar-fill-taglia');
    renderBars('docChart', countBy(rows, 'StatoDocumenti'), 'bar-fill-squadra');
}

function countBy(rows, key) {
    const map = new Map();
    rows.forEach((row) => {
        const label = String(row[key] || 'N/D').trim() || 'N/D';
        map.set(label, (map.get(label) || 0) + 1);
    });
    return Array.from(map.entries())
        .map(([label, value]) => ({ label, value }))
        .sort((left, right) => right.value - left.value || left.label.localeCompare(right.label));
}

function countWeeks(rows, maxWeek) {
    const labels = reportPayload?.settimane?.etichette || [];
    const items = [];
    for (let week = 1; week <= maxWeek; week += 1) {
        items.push({
            label: labels[week - 1] || `Settimana ${week}`,
            value: rows.filter((row) => (row.SettimaneDisponibili || []).includes(week)).length,
        });
    }
    return items;
}

function renderBars(id, items, fillClass) {
    const container = document.getElementById(id);
    if (!container) {
        return;
    }

    if (!items.length) {
        container.innerHTML = '<div class="report-empty-inline">Nessun dato disponibile.</div>';
        return;
    }

    const max = Math.max(...items.map((item) => item.value), 1);
    container.innerHTML = items.map((item) => `
        <div class="bar-row">
            <span class="bar-label">${escapeHtml(item.label)}</span>
            <div class="bar-track">
                <div class="bar-fill ${fillClass}" style="width:${(item.value / max) * 100}%"></div>
            </div>
            <span class="bar-value">${escapeHtml(item.value)}</span>
        </div>
    `).join('');
}
