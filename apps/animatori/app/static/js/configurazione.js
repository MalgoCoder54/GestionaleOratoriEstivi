window.saveConfig = async function saveConfig(event) {
    event.preventDefault();
    const config = JSON.parse(JSON.stringify(CURRENT_CONFIG));
    config.importi_default.contributo = Number(document.getElementById('cfgContributo').value || 0);
    config.importi_default.maglietta_extra = Number(document.getElementById('cfgMagliettaExtra').value || 0);
    config.settimane.date_inizio = Array.from(document.querySelectorAll('.week-date')).map((item) => item.value).filter(Boolean);
    config.settimane.etichette = Array.from(document.querySelectorAll('.week-label')).map((item) => item.value.trim()).filter(Boolean);
    config.settimane.numero_settimane = config.settimane.date_inizio.length;
    await api('/api/config', { method: 'PUT', body: config });
    toast('Configurazione salvata');
    return false;
};
