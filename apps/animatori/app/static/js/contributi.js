let payData = null;

document.addEventListener('DOMContentLoaded', () => {
    loadContributo();
    bindContributiHandlers();
});

async function loadContributo() {
    payData = await api(`/api/animatori/${ANIMATORE_ID}/contributo`);
    document.querySelectorAll('[data-pay]').forEach((field) => {
        let value = payData[field.dataset.pay];
        if (typeof value === 'boolean') {
            value = String(value);
        }
        field.value = value ?? '';
    });
    refreshTotalePreview();
    renderWeeks();
}

function bindContributiHandlers() {
    const baseInput = document.querySelector('[data-pay="ImportoContributo"]');
    const extraInput = document.querySelector('[data-pay="NumeroMaglietteExtra"]');

    [baseInput, extraInput].forEach((field) => {
        if (!field) {
            return;
        }
        field.addEventListener('input', refreshTotalePreview);
        field.addEventListener('change', refreshTotalePreview);
    });

    const weeksContainer = document.getElementById('settimaneContainer');
    if (!weeksContainer) {
        return;
    }

    weeksContainer.addEventListener('click', (event) => {
        const header = event.target.closest('.settimana-header');
        if (!header) {
            return;
        }
        const card = header.closest('.settimana-card');
        if (!card) {
            return;
        }
        toggleWeekCard(card);
    });

    weeksContainer.addEventListener('change', (event) => {
        const card = event.target.closest('.settimana-card');
        if (!card) {
            return;
        }
        syncWeekStatus(card);
    });
}

function refreshTotalePreview() {
    const baseValue = Number(document.querySelector('[data-pay="ImportoContributo"]')?.value || 0);
    const extraQuantity = normalizeExtraQuantity(document.querySelector('[data-pay="NumeroMaglietteExtra"]')?.value);
    const extraUnitPrice = Number(APP_CONFIG.importi_default?.maglietta_extra || 0);
    const totalField = document.querySelector('[data-pay="TotaleDovuto"]');

    if (document.querySelector('[data-pay="NumeroMaglietteExtra"]')) {
        document.querySelector('[data-pay="NumeroMaglietteExtra"]').value = String(extraQuantity);
    }
    if (totalField) {
        totalField.value = (baseValue + (extraQuantity * extraUnitPrice)).toFixed(2);
    }
}

function normalizeExtraQuantity(value) {
    if (value === '' || value === null || value === undefined) {
        return 0;
    }
    const parsed = Number(value);
    if (!Number.isFinite(parsed) || parsed < 0) {
        return 0;
    }
    return Math.trunc(parsed);
}

function renderWeeks() {
    const labels = APP_CONFIG.settimane?.etichette || [];
    const container = document.getElementById('settimaneContainer');
    container.innerHTML = payData.settimane.map((week) => {
        const label = labels[week.NumeroSettimana - 1] || `Settimana ${week.NumeroSettimana}`;
        const status = getWeekStatus(week);
        return `
            <section class="settimana-card" data-week="${week.NumeroSettimana}">
                <div class="settimana-header" role="button" tabindex="0">
                    <h4>${escapeHtml(label)}</h4>
                    <div style="display:flex; align-items:center; gap:10px;">
                        <span class="settimana-badge ${status.badgeClass}" data-week-badge>${escapeHtml(status.label)}</span>
                        <span class="collapse-icon" data-collapse-icon>&#9662;</span>
                    </div>
                </div>
                <div class="settimana-body" data-week-body>
                    <div class="settimana-grid">
                        ${weekSelectRow('Disponibile', week.Disponibile)}
                        ${weekSelectRow('Presente', week.Presente)}
                        ${weekSelectRow('InGita', week.InGita)}
                        ${weekSelectRow('InOratorio', week.InOratorio)}
                        <div class="form-row form-row-full">
                            <label>Note turno</label>
                            <textarea data-week-field="NoteTurno" rows="3">${escapeHtml(week.NoteTurno || '')}</textarea>
                        </div>
                    </div>
                    <div class="settimana-totale-row">
                        <span class="settimana-totale-label">
                            Stato turnazione
                            <span class="manual-price-badge">${escapeHtml(status.shortLabel)}</span>
                        </span>
                        <span class="settimana-totale-value" data-week-summary>${escapeHtml(status.summary)}</span>
                    </div>
                </div>
            </section>
        `;
    }).join('');

    container.querySelectorAll('.settimana-card').forEach((card) => syncWeekStatus(card));
    container.querySelectorAll('.settimana-header').forEach((header) => {
        header.addEventListener('keydown', (event) => {
            if (event.key === 'Enter' || event.key === ' ') {
                event.preventDefault();
                const card = event.currentTarget.closest('.settimana-card');
                if (card) {
                    toggleWeekCard(card);
                }
            }
        });
    });
}

function weekSelectRow(field, value) {
    return `
        <div class="form-row">
            <label>${fieldLabel(field)}</label>
            <select data-week-field="${field}">
                <option value="false"${!value ? ' selected' : ''}>NO</option>
                <option value="true"${value ? ' selected' : ''}>SI</option>
            </select>
        </div>
    `;
}

function fieldLabel(field) {
    const labels = {
        Disponibile: 'Disponibile',
        Presente: 'Presente',
        InGita: 'Assegnato gita',
        InOratorio: 'Assegnato oratorio',
    };
    return labels[field] || field;
}

function getWeekStatus(week) {
    if (week.Presente) {
        return {
            label: 'Presente',
            shortLabel: 'OK',
            summary: week.InGita ? 'Confermato in gita' : week.InOratorio ? 'Confermato in oratorio' : 'Confermato',
            badgeClass: 'pagato',
        };
    }
    if (week.Disponibile) {
        return {
            label: 'Disponibile',
            shortLabel: 'OPEN',
            summary: 'Disponibile da assegnare',
            badgeClass: 'gratuita-badge',
        };
    }
    return {
        label: 'Non disponibile',
        shortLabel: 'OFF',
        summary: 'Nessuna disponibilita inserita',
        badgeClass: 'non-pagato',
    };
}

function syncWeekStatus(card) {
    const week = readWeekPayload(card);
    const status = getWeekStatus(week);
    const badge = card.querySelector('[data-week-badge]');
    const summary = card.querySelector('[data-week-summary]');
    const shortBadge = card.querySelector('.manual-price-badge');

    if (badge) {
        badge.className = `settimana-badge ${status.badgeClass}`;
        badge.textContent = status.label;
    }
    if (summary) {
        summary.textContent = status.summary;
    }
    if (shortBadge) {
        shortBadge.textContent = status.shortLabel;
    }
}

function readWeekPayload(card) {
    const payload = {};
    card.querySelectorAll('[data-week-field]').forEach((field) => {
        let value = field.value;
        if (field.tagName === 'SELECT') {
            value = value === 'true';
        }
        payload[field.dataset.weekField] = value;
    });
    return payload;
}

function toggleWeekCard(card) {
    const body = card.querySelector('[data-week-body]');
    const icon = card.querySelector('[data-collapse-icon]');
    if (!body || !icon) {
        return;
    }
    body.classList.toggle('collapsed');
    icon.classList.toggle('collapsed');
}

window.saveAll = async function saveAll() {
    const payPayload = {};
    document.querySelectorAll('[data-pay]').forEach((field) => {
        let value = field.value;
        if (field.tagName === 'SELECT' && ['true', 'false'].includes(value)) {
            value = value === 'true';
        }
        payPayload[field.dataset.pay] = value;
    });
    await api(`/api/animatori/${ANIMATORE_ID}/contributo`, { method: 'PUT', body: payPayload });

    const updates = Array.from(document.querySelectorAll('.settimana-card')).map((card) => {
        const payload = readWeekPayload(card);
        return api(`/api/animatori/${ANIMATORE_ID}/settimana/${card.dataset.week}`, {
            method: 'PUT',
            body: payload,
        });
    });

    await Promise.all(updates);
    toast('Contributo e turni salvati');
    await loadContributo();
};
