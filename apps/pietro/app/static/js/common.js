function getCSRFToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.getAttribute('content') : '';
}

function toast(message, type = 'success') {
    const toastElement = document.createElement('div');
    toastElement.className = `toast${type === 'error' ? ' error' : ''}`;
    toastElement.textContent = message;
    document.body.appendChild(toastElement);
    setTimeout(() => toastElement.remove(), 3000);
}

async function api(url, options = {}) {
    const requestOptions = { ...options };
    if (requestOptions.body && typeof requestOptions.body === 'object') {
        requestOptions.headers = {
            'Content-Type': 'application/json',
            ...requestOptions.headers,
        };
        requestOptions.body = JSON.stringify(requestOptions.body);
    }

    const method = (requestOptions.method || 'GET').toUpperCase();
    if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(method)) {
        requestOptions.headers = {
            'X-CSRFToken': getCSRFToken(),
            ...requestOptions.headers,
        };
    }

    const response = await fetch(url, requestOptions);
    const isJson = (response.headers.get('content-type') || '').includes('application/json');
    const payload = isJson ? await response.json() : await response.text();

    if (!response.ok) {
        const message = (
            payload && typeof payload === 'object' && (
                payload.error ||
                (Array.isArray(payload.errors) ? payload.errors.join(' | ') : null)
            )
        ) || `Errore ${response.status}`;
        const error = new Error(message);
        error.status = response.status;
        error.payload = payload;
        throw error;
    }

    return payload;
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

function formatCurrency(value) {
    const amount = Number(value || 0);
    return `€ ${amount.toFixed(2)}`;
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
