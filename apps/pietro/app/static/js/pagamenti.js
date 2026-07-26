let pagamentiData = null;
let pagamentiEditMode = false;
const EXTRA_SHIRT_UNIT_PRICE = 5;

document.addEventListener('DOMContentLoaded', () => {
    if (typeof ISCRITTO_ID === 'undefined') {
        return;
    }
    loadPagamenti();
});

function formatPresenza(value) {
    if (value === true) {
        return '<span style="color: var(--green); font-weight: 600;">SI</span>';
    }
    return '<span style="color: var(--gray-400);">NO</span>';
}

function setPagField(field, value) {
    const viewElement = document.querySelector(`.pag-view[data-field="${field}"]`);
    const editElement = document.querySelector(`.pag-edit[data-field="${field}"]`);

    if (viewElement) {
        if (typeof value === 'boolean') {
            viewElement.innerHTML = formatPresenza(value);
        } else if (field.includes('Data') && value) {
            viewElement.textContent = formatDate(value);
        } else if (field.includes('Importo')) {
            viewElement.textContent = formatCurrency(value);
        } else {
            viewElement.textContent = value === null || value === undefined || value === '' ? '-' : value;
        }
    }

    if (editElement) {
        if (editElement.type === 'checkbox') {
            editElement.checked = Boolean(value);
        } else if (editElement.tagName === 'SELECT') {
            editElement.value = typeof value === 'boolean' ? String(value) : (value || 'false');
        } else {
            editElement.value = value ?? '';
        }
    }
}

function getBooleanInputValue(element) {
    if (!element) {
        return false;
    }
    if (element.type === 'checkbox') {
        return element.checked;
    }
    if (element.tagName === 'SELECT') {
        return element.value === 'true';
    }
    return Boolean(element.value);
}

function getNumberInputValue(element) {
    if (!element || element.value === '') {
        return null;
    }
    return Number(element.value);
}

function normalizeExtraShirtQuantity(value) {
    if (value === null || value === undefined || value === '') {
        return 0;
    }

    const parsed = Number(value);
    if (!Number.isFinite(parsed) || parsed <= 0) {
        return 0;
    }

    return Math.trunc(parsed);
}

function calculateExtraShirtTotal(quantity) {
    return normalizeExtraShirtQuantity(quantity) * EXTRA_SHIRT_UNIT_PRICE;
}

function refreshExtraShirtPreview() {
    const quantityInput = document.querySelector('.pag-edit[data-field="NumeroMaglietteExtra"]');
    const totalInput = document.querySelector('.pag-edit[data-field="ImportoMaglietteExtra"]');

    if (!quantityInput || !totalInput) {
        return;
    }

    const quantity = normalizeExtraShirtQuantity(quantityInput.value);
    if (quantityInput.value !== '' && Number(quantityInput.value) !== quantity) {
        quantityInput.value = String(quantity);
    }

    totalInput.value = calculateExtraShirtTotal(quantity).toFixed(2);
}

function isGratuitaAttiva() {
    const gratuitaField = document.querySelector('.pag-edit[data-field="Gratuita"]');
    if (gratuitaField) {
        return getBooleanInputValue(gratuitaField);
    }
    return Boolean(pagamentiData && pagamentiData.Gratuita);
}

function calcolaTotaleAutomatico(card) {
    if (!card || isGratuitaAttiva()) {
        return 0;
    }

    const importi = APP_CONFIG.importi_default || {};
    const readBool = (field) => getBooleanInputValue(
        card.querySelector(`.sett-edit[data-f="${field}"]`),
    );

    let total = 0;
    if (readBool('Mattina')) {
        total += Number(importi.mattina || 0);
    }
    if (readBool('Pomeriggio')) {
        total += Number(importi.pomeriggio || 0);
    }
    if (readBool('Pranzo')) {
        total += Number(importi.pranzo || 0);
    }
    if (readBool('GitaSettimana')) {
        const gitaElement = card.querySelector('.sett-edit[data-f="GitaSettimana"]');
        total += Number((gitaElement && gitaElement.dataset.importoGita) || 0);
    }
    return total;
}

function refreshSettimanaPreview(card) {
    if (!card) {
        return;
    }

    const totaleValue = card.querySelector('.settimana-totale-value');
    const manualBadge = card.querySelector('.manual-price-badge');
    const manualToggle = card.querySelector('.sett-edit[data-f="PrezzoManuale"]');
    const manualTotalInput = card.querySelector('.sett-edit[data-f="TotaleManuale"]');

    if (!totaleValue || !manualToggle || !manualTotalInput) {
        return;
    }

    const gratuita = isGratuitaAttiva();
    const manualActive = manualToggle.checked && !gratuita;

    manualToggle.disabled = gratuita;
    manualTotalInput.disabled = !manualActive;
    manualTotalInput.classList.toggle('input-disabled', !manualActive);

    if (manualToggle.checked && !manualTotalInput.value) {
        manualTotalInput.value = String(card.dataset.totale || calcolaTotaleAutomatico(card) || 0);
    }

    const totale = gratuita
        ? 0
        : manualActive
            ? Number(manualTotalInput.value || 0)
            : calcolaTotaleAutomatico(card);

    totaleValue.textContent = formatCurrency(totale);
    manualBadge.style.display = manualActive ? 'inline-flex' : 'none';
}

function refreshAllSettimanasPreview() {
    document.querySelectorAll('.settimana-card').forEach((card) => refreshSettimanaPreview(card));
}

function bindPagamentiEditorHandlers() {
    const container = document.getElementById('settimaneContainer');
    if (!container || container.dataset.bound === 'true') {
        return;
    }

    container.addEventListener('change', (event) => {
        const card = event.target.closest('.settimana-card');
        if (!card) {
            return;
        }
        refreshSettimanaPreview(card);
    });

    container.addEventListener('input', (event) => {
        const card = event.target.closest('.settimana-card');
        if (!card) {
            return;
        }
        if (event.target.matches('.sett-edit[data-f="TotaleManuale"]')) {
            refreshSettimanaPreview(card);
        }
    });

    const gratuitaField = document.querySelector('.pag-edit[data-field="Gratuita"]');
    if (gratuitaField) {
        gratuitaField.addEventListener('change', refreshAllSettimanasPreview);
    }

    const extraShirtField = document.querySelector('.pag-edit[data-field="NumeroMaglietteExtra"]');
    if (extraShirtField) {
        extraShirtField.addEventListener('input', refreshExtraShirtPreview);
        extraShirtField.addEventListener('change', refreshExtraShirtPreview);
    }

    container.dataset.bound = 'true';
}

async function loadPagamenti() {
    try {
        pagamentiData = await api(`/api/iscritti/${ISCRITTO_ID}/contabilita`);
        renderPagamenti();
    } catch (error) {
        toast(error.message || 'Errore caricamento pagamenti', 'error');
    }
}

function renderPagamenti() {
    const data = pagamentiData;
    const isGratuita = data.Gratuita;

    setPagField('Gratuita', data.Gratuita);
    setPagField('ImportoIscrizione', data.ImportoIscrizione);
    setPagField('NumeroMaglietteExtra', data.NumeroMaglietteExtra);
    setPagField('ImportoMaglietteExtra', data.ImportoMaglietteExtra);
    setPagField('IscrizionePagata', data.IscrizionePagata);
    setPagField('DataPagamentoIscrizione', data.DataPagamentoIscrizione);

    const container = document.getElementById('settimaneContainer');
    const gite = (APP_CONFIG.settimane && APP_CONFIG.settimane.gite) || [];
    container.innerHTML = '';

    data.settimane.forEach((settimana) => {
        const gita = gite.find((item) => item.settimana === settimana.NumeroSettimana && item.attiva);
        const isPagato = settimana.Pagato;
        const cardClass = isGratuita ? 'gratuita' : (isPagato ? '' : 'non-pagata');
        const badgeClass = isGratuita ? 'gratuita-badge' : (isPagato ? 'pagato' : 'non-pagato');
        const badgeText = isGratuita ? 'GRATUITA' : (isPagato ? 'PAGATO' : 'NON PAGATO');
        const totaleManuale = settimana.TotaleManuale ?? settimana.Totale;

        let html = `
            <div class="settimana-card ${cardClass}" data-settimana="${settimana.NumeroSettimana}" data-totale="${settimana.Totale}">
                <div class="settimana-header">
                    <h4>${settimana.NumeroSettimana}&ordf; Settimana</h4>
                    <span class="settimana-badge ${badgeClass}">${badgeText}</span>
                </div>
                <div class="settimana-grid">
                    <div class="form-row">
                        <label>Mattina</label>
                        <span class="sett-view" data-sett="${settimana.NumeroSettimana}" data-f="Mattina">${formatPresenza(settimana.Mattina)}</span>
                        <select class="sett-edit" data-sett="${settimana.NumeroSettimana}" data-f="Mattina" style="display:none;">
                            <option value="false" ${!settimana.Mattina ? 'selected' : ''}>NO</option>
                            <option value="true" ${settimana.Mattina ? 'selected' : ''}>SI</option>
                        </select>
                    </div>
                    <div class="form-row">
                        <label>Pomeriggio</label>
                        <span class="sett-view" data-sett="${settimana.NumeroSettimana}" data-f="Pomeriggio">${formatPresenza(settimana.Pomeriggio)}</span>
                        <select class="sett-edit" data-sett="${settimana.NumeroSettimana}" data-f="Pomeriggio" style="display:none;">
                            <option value="false" ${!settimana.Pomeriggio ? 'selected' : ''}>NO</option>
                            <option value="true" ${settimana.Pomeriggio ? 'selected' : ''}>SI</option>
                        </select>
                    </div>
                    <div class="form-row">
                        <label>Pranzo</label>
                        <span class="sett-view" data-sett="${settimana.NumeroSettimana}" data-f="Pranzo">${formatPresenza(settimana.Pranzo)}</span>
                        <select class="sett-edit" data-sett="${settimana.NumeroSettimana}" data-f="Pranzo" style="display:none;">
                            <option value="false" ${!settimana.Pranzo ? 'selected' : ''}>NO</option>
                            <option value="true" ${settimana.Pranzo ? 'selected' : ''}>SI</option>
                        </select>
                    </div>
        `;

        if (gita) {
            html += `
                    <div class="form-row">
                        <label>${escapeHtml(gita.nome)} (${formatCurrency(gita.importo)})</label>
                        <span class="sett-view" data-sett="${settimana.NumeroSettimana}" data-f="GitaSettimana">${formatPresenza(settimana.GitaSettimana)}</span>
                        <select class="sett-edit" data-sett="${settimana.NumeroSettimana}" data-f="GitaSettimana" data-importo-gita="${gita.importo}" style="display:none;">
                            <option value="false" ${!settimana.GitaSettimana ? 'selected' : ''}>NO</option>
                            <option value="true" ${settimana.GitaSettimana ? 'selected' : ''}>SI</option>
                        </select>
                    </div>
            `;
        }

        html += `
                    <div class="form-row">
                        <label>Pagato</label>
                        <span class="sett-view" data-sett="${settimana.NumeroSettimana}" data-f="Pagato">${formatPresenza(settimana.Pagato)}</span>
                        <select class="sett-edit" data-sett="${settimana.NumeroSettimana}" data-f="Pagato" style="display:none;">
                            <option value="false" ${!settimana.Pagato ? 'selected' : ''}>NO</option>
                            <option value="true" ${settimana.Pagato ? 'selected' : ''}>SI</option>
                        </select>
                    </div>
                    <div class="form-row">
                        <label>Prezzo manuale</label>
                        <span class="sett-view" data-sett="${settimana.NumeroSettimana}" data-f="PrezzoManuale">${formatPresenza(settimana.PrezzoManuale)}</span>
                        <input
                            type="checkbox"
                            class="sett-edit manual-price-toggle"
                            data-sett="${settimana.NumeroSettimana}"
                            data-f="PrezzoManuale"
                            ${settimana.PrezzoManuale ? 'checked' : ''}
                            style="display:none;"
                        >
                    </div>
                    <div class="form-row">
                        <label>Totale manuale</label>
                        <span class="sett-view" data-sett="${settimana.NumeroSettimana}" data-f="TotaleManuale">
                            ${settimana.PrezzoManuale && settimana.TotaleManuale != null ? formatCurrency(settimana.TotaleManuale) : '-'}
                        </span>
                        <input
                            type="number"
                            min="0"
                            step="0.01"
                            class="sett-edit manual-total-input"
                            data-sett="${settimana.NumeroSettimana}"
                            data-f="TotaleManuale"
                            value="${totaleManuale ?? ''}"
                            style="display:none;"
                        >
                    </div>
                    <div class="form-row">
                        <label>Data Pagamento</label>
                        <span class="sett-view" data-sett="${settimana.NumeroSettimana}" data-f="DataPagamento">${settimana.DataPagamento ? formatDate(settimana.DataPagamento) : '-'}</span>
                        <input type="date" class="sett-edit" data-sett="${settimana.NumeroSettimana}" data-f="DataPagamento" value="${settimana.DataPagamento || ''}" style="display:none;">
                    </div>
                </div>
                <div class="settimana-totale-row">
                    <span class="settimana-totale-label">
                        Totale Settimana
                        <span class="manual-price-badge" style="display:${settimana.PrezzoManuale && !isGratuita ? 'inline-flex' : 'none'};">Manuale</span>
                    </span>
                    <span class="settimana-totale-value">${formatCurrency(settimana.Totale)}</span>
                </div>
            </div>
        `;

        container.innerHTML += html;
    });

    bindPagamentiEditorHandlers();
    refreshExtraShirtPreview();
    refreshAllSettimanasPreview();
}

window.toggleEditPagamenti = function toggleEditPagamenti() {
    pagamentiEditMode = true;
    document.getElementById('btnEditPag').style.display = 'none';
    document.getElementById('btnSavePag').style.display = 'flex';
    document.getElementById('btnCancelPag').style.display = 'flex';
    document.querySelectorAll('.pag-view, .sett-view').forEach((element) => { element.style.display = 'none'; });
    document.querySelectorAll('.pag-edit, .sett-edit').forEach((element) => { element.style.display = ''; });
    refreshExtraShirtPreview();
    refreshAllSettimanasPreview();
};

window.annullaEditPagamenti = function annullaEditPagamenti() {
    pagamentiEditMode = false;
    document.getElementById('btnEditPag').style.display = 'flex';
    document.getElementById('btnSavePag').style.display = 'none';
    document.getElementById('btnCancelPag').style.display = 'none';
    document.querySelectorAll('.pag-view, .sett-view').forEach((element) => { element.style.display = ''; });
    document.querySelectorAll('.pag-edit, .sett-edit').forEach((element) => { element.style.display = 'none'; });
    loadPagamenti();
};

window.salvaPagamenti = async function salvaPagamenti() {
    try {
        const getEditValue = (field) => {
            const element = document.querySelector(`.pag-edit[data-field="${field}"]`);
            if (!element) {
                return undefined;
            }
            if (element.type === 'checkbox') {
                return element.checked;
            }
            if (element.tagName === 'SELECT') {
                return element.value === 'true';
            }
            if (element.type === 'number') {
                return element.value === '' ? null : Number(element.value);
            }
            return element.value || null;
        };

        await api(`/api/iscritti/${ISCRITTO_ID}/contabilita`, {
            method: 'PUT',
            body: {
                Gratuita: getEditValue('Gratuita'),
                IscrizionePagata: getEditValue('IscrizionePagata'),
                ImportoIscrizione: getEditValue('ImportoIscrizione'),
                NumeroMaglietteExtra: getEditValue('NumeroMaglietteExtra'),
                DataPagamentoIscrizione: getEditValue('DataPagamentoIscrizione'),
            },
        });

        const settimane = new Set();
        document.querySelectorAll('.sett-edit').forEach((element) => {
            settimane.add(Number(element.dataset.sett));
        });

        for (const numeroSettimana of settimane) {
            const getSettValue = (field) => {
                const element = document.querySelector(`.sett-edit[data-sett="${numeroSettimana}"][data-f="${field}"]`);
                if (!element) {
                    return undefined;
                }
                if (element.type === 'checkbox') {
                    return element.checked;
                }
                if (element.tagName === 'SELECT') {
                    return element.value === 'true';
                }
                if (element.type === 'number') {
                    return element.value === '' ? null : Number(element.value);
                }
                return element.value || null;
            };

            const card = document.querySelector(`.settimana-card[data-settimana="${numeroSettimana}"]`);
            const gitaElement = document.querySelector(`.sett-edit[data-sett="${numeroSettimana}"][data-f="GitaSettimana"]`);
            const gitaSelezionata = gitaElement ? gitaElement.value === 'true' : false;
            const prezzoManuale = Boolean(getSettValue('PrezzoManuale'));
            const totaleManuale = prezzoManuale
                ? (getSettValue('TotaleManuale') ?? calcolaTotaleAutomatico(card))
                : null;

            await api(`/api/iscritti/${ISCRITTO_ID}/settimana/${numeroSettimana}`, {
                method: 'PUT',
                body: {
                    Mattina: getSettValue('Mattina'),
                    Pomeriggio: getSettValue('Pomeriggio'),
                    Pranzo: getSettValue('Pranzo'),
                    GitaSettimana: gitaSelezionata,
                    ImportoGita: gitaSelezionata ? Number(gitaElement.dataset.importoGita || 0) : 0,
                    PrezzoManuale: prezzoManuale,
                    TotaleManuale: totaleManuale,
                    Pagato: getSettValue('Pagato'),
                    DataPagamento: getSettValue('DataPagamento'),
                },
            });
        }

        toast('Pagamenti salvati');
        pagamentiEditMode = false;
        await loadPagamenti();
        document.getElementById('btnEditPag').style.display = 'flex';
        document.getElementById('btnSavePag').style.display = 'none';
        document.getElementById('btnCancelPag').style.display = 'none';
        document.querySelectorAll('.pag-view, .sett-view').forEach((element) => { element.style.display = ''; });
        document.querySelectorAll('.pag-edit, .sett-edit').forEach((element) => { element.style.display = 'none'; });
    } catch (error) {
        toast(error.message || 'Errore nel salvataggio', 'error');
    }
};
