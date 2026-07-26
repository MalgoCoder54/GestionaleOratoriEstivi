const BI_COLORS = ['#2693CF', '#1E78AA', '#2F5AA8', '#5E60CE', '#7B2CBF', '#C84D9D', '#E07A3F', '#F2C14E', '#D85757', '#57A773'];

const biState = {
    rows: [],
    meta: null,
    filters: {
        week: '',
        classe: '',
        squadra: '',
        taglia: '',
    },
};

document.addEventListener('DOMContentLoaded', () => {
    initBiDashboard();
});

async function initBiDashboard() {
    try {
        const payload = await api('/api/reporting/iscritti');
        biState.rows = payload.rows || [];
        biState.meta = payload;
        populateBiFilters(payload);
        bindBiFilters();
        renderBiDashboard();
    } catch (error) {
        toast(error.message || 'Errore caricamento grafici', 'error');
        document.getElementById('biScopeSummary').textContent = 'Impossibile caricare i dati BI.';
    }
}

function populateBiFilters(payload) {
    fillSelectOptions(document.getElementById('biWeekFilter'), payload.settimane || [], 'numero', 'label', 'Tutte le settimane');
    fillSelectOptions(
        document.getElementById('biClasseFilter'),
        mergeConfiguredAndObserved(payload.classi_disponibili || [], payload.rows || [], 'ClasseFrequentata', 'Non indicata'),
        'value',
        'label',
        'Tutte le classi'
    );
    fillSelectOptions(
        document.getElementById('biSquadraFilter'),
        mergeConfiguredAndObserved(payload.squadre || [], payload.rows || [], 'Squadra', 'Non assegnata'),
        'value',
        'label',
        'Tutte le squadre'
    );
    fillSelectOptions(
        document.getElementById('biTagliaFilter'),
        mergeConfiguredAndObserved(payload.taglie_maglietta || [], payload.rows || [], 'TagliaMaglietta', 'Non indicata'),
        'value',
        'label',
        'Tutte le taglie'
    );
}

function fillSelectOptions(select, items, valueKey, labelKey, emptyLabel) {
    if (!select) {
        return;
    }
    const options = [`<option value="">${escapeHtml(emptyLabel)}</option>`];
    items.forEach((item) => {
        options.push(`<option value="${escapeHtml(item[valueKey])}">${escapeHtml(item[labelKey])}</option>`);
    });
    select.innerHTML = options.join('');
}

function mergeConfiguredAndObserved(configuredValues, rows, key, emptyLabel) {
    const values = [];
    const seen = new Set();

    configuredValues.forEach((value) => {
        const normalized = normalizeBucket(value, emptyLabel);
        if (!seen.has(normalized)) {
            seen.add(normalized);
            values.push({ value: normalized, label: normalized });
        }
    });

    rows.forEach((row) => {
        const normalized = normalizeBucket(row[key], emptyLabel);
        if (!seen.has(normalized)) {
            seen.add(normalized);
            values.push({ value: normalized, label: normalized });
        }
    });

    return values;
}

function bindBiFilters() {
    ['week', 'classe', 'squadra', 'taglia'].forEach((key) => {
        const element = document.getElementById(`bi${capitalize(key)}Filter`);
        if (!element) {
            return;
        }
        element.addEventListener('change', (event) => {
            biState.filters[key] = event.target.value;
            renderBiDashboard();
        });
    });

    document.getElementById('biResetFilters').addEventListener('click', () => {
        biState.filters = { week: '', classe: '', squadra: '', taglia: '' };
        document.getElementById('biWeekFilter').value = '';
        document.getElementById('biClasseFilter').value = '';
        document.getElementById('biSquadraFilter').value = '';
        document.getElementById('biTagliaFilter').value = '';
        renderBiDashboard();
    });
}

function capitalize(value) {
    return value.charAt(0).toUpperCase() + value.slice(1);
}

function getBiFilteredRows() {
    return biState.rows.filter((row) => {
        if (biState.filters.week) {
            const selectedWeek = Number(biState.filters.week);
            const activeInWeek = row.Gratuita || (row.SettimaneAttive || []).includes(selectedWeek);
            if (!activeInWeek) {
                return false;
            }
        }
        if (biState.filters.classe && row.ClasseFrequentata !== biState.filters.classe) {
            return false;
        }
        if (biState.filters.squadra && row.Squadra !== biState.filters.squadra) {
            return false;
        }
        if (biState.filters.taglia && row.TagliaMaglietta !== biState.filters.taglia) {
            return false;
        }
        return true;
    });
}

function renderBiDashboard() {
    const rows = getBiFilteredRows();
    renderBiSummary(rows);
    renderKpis(rows);
    renderBars('biClassChart', buildDistribution(rows, 'ClasseFrequentata', biState.meta.classi_disponibili, 'Non indicata'), 'class');
    renderBars('biTagliaChart', buildDistribution(rows, 'TagliaMaglietta', biState.meta.taglie_maglietta, 'Non indicata'), 'taglia');
    renderBars('biSquadraChart', buildDistribution(rows, 'Squadra', biState.meta.squadre, 'Non assegnata'), 'squadra');
    renderStackedChart(rows);
}

function renderBiSummary(rows) {
    const summary = document.getElementById('biScopeSummary');
    const activeFilters = [];

    if (biState.filters.week) {
        activeFilters.push(`Settimana ${biState.filters.week}`);
    }
    if (biState.filters.classe) {
        activeFilters.push(`Classe ${biState.filters.classe}`);
    }
    if (biState.filters.squadra) {
        activeFilters.push(`Squadra ${biState.filters.squadra}`);
    }
    if (biState.filters.taglia) {
        activeFilters.push(`Taglia ${biState.filters.taglia}`);
    }

    if (!activeFilters.length) {
        summary.textContent = `${rows.length} iscritti nel quadro complessivo dell'evento.`;
        return;
    }

    summary.textContent = `${rows.length} iscritti dopo i filtri: ${activeFilters.join(' · ')}.`;
}

function renderKpis(rows) {
    const selectedWeek = biState.filters.week ? Number(biState.filters.week) : null;
    const paidInScope = selectedWeek
        ? rows.filter((row) => row.Gratuita || (row.SettimanePagate || []).includes(selectedWeek)).length
        : rows.filter((row) => row.IscrizionePagata).length;

    const cards = [
        { label: 'Iscritti visibili', value: rows.length, tone: 'primary' },
        { label: 'Con navetta', value: rows.filter((row) => row.Navetta).length, tone: 'navetta' },
        { label: 'Uscita autonoma', value: rows.filter((row) => row.UscitaAutorizzata).length, tone: 'uscita' },
        { label: selectedWeek ? `Pagati sett. ${selectedWeek}` : 'Iscrizioni pagate', value: paidInScope, tone: 'success' },
    ];

    document.getElementById('biKpiGrid').innerHTML = cards.map((card) => `
        <article class="kpi-card kpi-card-${card.tone}">
            <span class="kpi-label">${escapeHtml(card.label)}</span>
            <strong class="kpi-value">${escapeHtml(card.value)}</strong>
        </article>
    `).join('');
}

function buildDistribution(rows, key, preferredOrder, emptyLabel) {
    const counts = new Map();
    rows.forEach((row) => {
        const label = normalizeBucket(row[key], emptyLabel);
        counts.set(label, (counts.get(label) || 0) + 1);
    });

    const ordered = [];
    (preferredOrder || []).forEach((label) => {
        if (counts.has(label)) {
            ordered.push({ label, value: counts.get(label) });
            counts.delete(label);
        }
    });

    const remaining = Array.from(counts.entries())
        .map(([label, value]) => ({ label, value }))
        .sort((left, right) => right.value - left.value || left.label.localeCompare(right.label, 'it'));

    return [...ordered, ...remaining];
}

function normalizeBucket(value, emptyLabel) {
    const normalized = String(value || '').trim();
    return normalized || emptyLabel;
}

function renderBars(containerId, items, tone) {
    const container = document.getElementById(containerId);
    if (!items.length) {
        container.innerHTML = '<div class="report-empty-inline">Nessun dato disponibile per questo grafico.</div>';
        return;
    }

    const maxValue = Math.max(...items.map((item) => item.value), 1);
    container.innerHTML = items.map((item) => {
        const width = (item.value / maxValue) * 100;
        return `
            <div class="bar-row">
                <div class="bar-label">${escapeHtml(item.label)}</div>
                <div class="bar-track">
                    <div class="bar-fill bar-fill-${tone}" style="width:${width}%"></div>
                </div>
                <div class="bar-value">${escapeHtml(item.value)}</div>
            </div>
        `;
    }).join('');
}

function renderStackedChart(rows) {
    const stackContainer = document.getElementById('biStackChart');
    const legendContainer = document.getElementById('biStackLegend');

    if (!rows.length) {
        legendContainer.innerHTML = '';
        stackContainer.innerHTML = '<div class="report-empty-inline">Nessun dato disponibile per la composizione delle squadre.</div>';
        return;
    }

    const classLabels = buildDistribution(rows, 'ClasseFrequentata', biState.meta.classi_disponibili, 'Non indicata').map((item) => item.label);
    const squadraLabels = buildDistribution(rows, 'Squadra', biState.meta.squadre, 'Non assegnata').map((item) => item.label);
    const colorMap = new Map(classLabels.map((label, index) => [label, BI_COLORS[index % BI_COLORS.length]]));

    legendContainer.innerHTML = classLabels.map((label) => `
        <span class="stacked-legend-item">
            <span class="stacked-legend-color" style="background:${colorMap.get(label)}"></span>
            ${escapeHtml(label)}
        </span>
    `).join('');

    stackContainer.innerHTML = squadraLabels.map((squadra) => {
        const squadRows = rows.filter((row) => normalizeBucket(row.Squadra, 'Non assegnata') === squadra);
        const total = squadRows.length || 1;
        const segments = classLabels.map((label) => {
            const value = squadRows.filter((row) => normalizeBucket(row.ClasseFrequentata, 'Non indicata') === label).length;
            const width = value ? (value / total) * 100 : 0;
            return { label, value, width, color: colorMap.get(label) };
        }).filter((segment) => segment.value > 0);

        return `
            <div class="stacked-row">
                <div class="stacked-row-label">${escapeHtml(squadra)}</div>
                <div class="stacked-row-track">
                    ${segments.map((segment) => `
                        <div
                            class="stacked-segment"
                            style="width:${segment.width}%; background:${segment.color}"
                            title="${escapeHtml(segment.label)}: ${escapeHtml(segment.value)}"
                        >
                            ${segment.width >= 18 ? escapeHtml(segment.value) : ''}
                        </div>
                    `).join('')}
                </div>
                <div class="stacked-row-total">${escapeHtml(squadRows.length)}</div>
            </div>
        `;
    }).join('');
}
