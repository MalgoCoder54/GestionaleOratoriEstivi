function getCSRFToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.getAttribute('content') : '';
}

function toast(message, type = 'success') {
    const element = document.createElement('div');
    element.className = `toast ${type}`;
    element.textContent = message;
    document.body.appendChild(element);
    setTimeout(() => element.remove(), 3000);
}

async function api(url, options = {}) {
    const requestOptions = { ...options };
    if (requestOptions.body && typeof requestOptions.body === 'object') {
        requestOptions.headers = { 'Content-Type': 'application/json', ...requestOptions.headers };
        requestOptions.body = JSON.stringify(requestOptions.body);
    }
    const method = (requestOptions.method || 'GET').toUpperCase();
    if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(method)) {
        requestOptions.headers = { 'X-CSRFToken': getCSRFToken(), ...requestOptions.headers };
    }
    const response = await fetch(url, requestOptions);
    const isJson = (response.headers.get('content-type') || '').includes('application/json');
    const payload = isJson ? await response.json() : await response.text();
    if (!response.ok) {
        const message = payload && typeof payload === 'object'
            ? (payload.error || (Array.isArray(payload.errors) ? payload.errors.join(' | ') : null))
            : null;
        throw new Error(message || `Errore ${response.status}`);
    }
    return payload;
}

function debounce(fn, delayMs) {
    let timerId;
    return function debounced(...args) {
        clearTimeout(timerId);
        timerId = setTimeout(() => fn.apply(this, args), delayMs);
    };
}

function escapeHtml(value) {
    return String(value ?? '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
}

function formatCurrency(value) {
    return `€ ${Number(value || 0).toFixed(2)}`;
}

function formatDate(isoString) {
    if (!isoString) {
        return '';
    }
    const datePart = String(isoString).split('T')[0];
    const parts = datePart.split('-');
    if (parts.length !== 3) {
        return isoString;
    }
    return `${parts[2]}/${parts[1]}/${parts[0]}`;
}
