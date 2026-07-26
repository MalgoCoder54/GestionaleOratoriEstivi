function listEditorRowHtml(inputClass, placeholder = '') {
    return `<input type="text" class="${inputClass}" value="" placeholder="${placeholder}">` +
        '<button type="button" class="btn-icon btn-danger" onclick="this.parentElement.remove()" title="Rimuovi">&times;</button>';
}

window.aggiungiGitaItem = function aggiungiGitaItem() {
    const container = document.getElementById('giteContainer');
    const maxSettimane = Array.from(document.querySelectorAll('.cfg_data_settimana')).filter((element) => element.value).length || 1;
    const index = container.querySelectorAll('.gita-config-row').length + 1;
    const row = document.createElement('div');
    row.className = 'gita-config-row';
    row.innerHTML = `
        <div class="config-inline-header">
            <h4>Gita ${index}</h4>
            <button type="button" class="btn-icon btn-danger" onclick="this.closest('.gita-config-row').remove()" title="Rimuovi gita">&times;</button>
        </div>
        <div class="form-grid">
            <div class="form-row"><label>Nome</label><input class="cfg_gita_nome" value=""></div>
            <div class="form-row"><label>Data</label><input type="date" class="cfg_gita_data" value=""></div>
            <div class="form-row"><label>Settimana</label><input type="number" min="1" max="${maxSettimane}" class="cfg_gita_settimana" value="1"></div>
            <div class="form-row"><label>Importo (&euro;)</label><input type="number" step="0.01" class="cfg_gita_importo" value="0"></div>
            <div class="form-row form-row-inline"><label>Attiva</label><input type="checkbox" class="cfg_gita_attiva" checked></div>
        </div>
    `;
    container.appendChild(row);
};

window.aggiungiClasseItem = function aggiungiClasseItem() {
    const container = document.getElementById('classiContainer');
    const row = document.createElement('div');
    row.className = 'form-row inline-editor-row config-list-row';
    row.innerHTML = listEditorRowHtml('cfg_classe_item', 'Nuova classe');
    container.appendChild(row);
};

window.aggiungiTagliaItem = function aggiungiTagliaItem() {
    const container = document.getElementById('taglieContainer');
    const row = document.createElement('div');
    row.className = 'form-row inline-editor-row config-list-row';
    row.innerHTML = listEditorRowHtml('cfg_taglia_item', 'Nuova taglia');
    container.appendChild(row);
};

window.aggiungiSquadraItem = function aggiungiSquadraItem() {
    const container = document.getElementById('squadreContainer');
    const row = document.createElement('div');
    row.className = 'form-row inline-editor-row config-list-row';
    row.innerHTML = listEditorRowHtml('cfg_squadra_item', 'Nuova squadra');
    container.appendChild(row);
};

window.salvaConfig = async function salvaConfig(event) {
    event.preventDefault();
    const config = JSON.parse(JSON.stringify(CURRENT_CONFIG));

    config.importi_default.iscrizione = Number(document.getElementById('cfg_iscrizione').value || 0);
    config.importi_default.mattina = Number(document.getElementById('cfg_mattina').value || 0);
    config.importi_default.pomeriggio = Number(document.getElementById('cfg_pomeriggio').value || 0);
    config.importi_default.pranzo = Number(document.getElementById('cfg_pranzo').value || 0);

    config.settimane.date_inizio = Array.from(document.querySelectorAll('.cfg_data_settimana'))
        .map((element) => element.value)
        .filter(Boolean);
    config.settimane.numero_settimane = config.settimane.date_inizio.length;
    config.settimane.gite = Array.from(document.querySelectorAll('.gita-config-row')).map((row) => ({
        nome: row.querySelector('.cfg_gita_nome').value,
        data: row.querySelector('.cfg_gita_data').value,
        settimana: Number(row.querySelector('.cfg_gita_settimana').value || 0),
        importo: Number(row.querySelector('.cfg_gita_importo').value || 0),
        attiva: row.querySelector('.cfg_gita_attiva').checked,
    }));

    config.classi_disponibili = Array.from(document.querySelectorAll('.cfg_classe_item'))
        .map((element) => element.value.trim())
        .filter(Boolean);
    config.taglie_maglietta = Array.from(document.querySelectorAll('.cfg_taglia_item'))
        .map((element) => element.value.trim())
        .filter(Boolean);
    config.squadre = Array.from(document.querySelectorAll('.cfg_squadra_item'))
        .map((element) => element.value.trim())
        .filter(Boolean);

    try {
        await api('/api/config', { method: 'PUT', body: config });
        toast('Configurazione salvata');
    } catch (error) {
        toast(error.message || 'Errore nel salvataggio', 'error');
    }
    return false;
};
