// Simple HTML escape function to prevent XSS in this demo app, not needed, but found it and thought it'd be good practice to include :)
function escapeHtml(s) { return String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }


// Simple function to handle floats: round to cents
function toCents(amount) {
    return Math.round(parseFloat(amount) * 100);
}

// Convert datetime-local string to ISO string, or null if empty/invalid
// Server stores timestamptz, so we send ISO - searched online to find this out, can't remember where
function isoFromDatetimeLocal(v) {
    if (!v) return null;
    // Interpret as local time and send ISO; server stores timestamptz
    const d = new Date(v);
    if (isNaN(d)) return null;
    return d.toISOString();
}

// Format cents as dollars
function formatMoney(cents) {
    const abs = Math.abs(cents);
    return (cents < 0 ? '-' : '') + '$' + (abs / 100).toFixed(2);
}

// These next functions communicate with the API VM to get/add/remove transactions
let tries = 0;
async function getTransactions() {
    try {
        const response = await fetch(`/api/transactions`);
        if (!response.ok) {
            const text = await response.text(); // might be HTML from nginx
            throw new Error(`HTTP ${response.status} ${response.statusText}: ${text.slice(0, 200)}`);
        }
        const rows = await response.json();
        render(rows);
    } catch (e) {
        console.error('GET /transactions failed:', e);
        document.getElementById('list').innerHTML =
            '<li class="meta">Starting up… retrying in 2s</li>';
        if (++tries <= 3) setTimeout(getTransactions, 2000);
        else document.getElementById('list').innerHTML =
            '<li class="meta error">Failed to load transactions. Is the API running?</li>';
    }
}

// Render the list of transactions fetched from the API
// Had ChatGPT help with the formatting, especially the date handling on the site
function render(rows) {
    const ul = document.getElementById('list');
    ul.innerHTML = rows.map(x => {
        const when = new Date(x.occurred_at);
        // Conditional, if description is present, show it, else don't
        const desc = x.description ? `<div class="meta">${escapeHtml(x.description)}</div>` : '';
        return `
          <li data-id="${x.id}">
            <button class="del" title="Delete" aria-label="Delete">×</button>
            <div>
              <div><strong>${escapeHtml(x.name)}</strong> <span class="meta">(${when.toLocaleString()})</span></div>
              ${desc}
            </div>
            <div class="amt">${formatMoney(x.amount_cents)}</div>
          </li>`;
    }).join('');

    // Tack on delete buttons to each trans in the list
    ul.querySelectorAll('button.del').forEach(btn => {
        btn.addEventListener('click', async (e) => {
            const li = e.currentTarget.closest('li');
            const id = li.getAttribute('data-id');
            try {
                const response = await fetch(`/api/transactions/${id}`, { method: 'DELETE' });
                if (response.status === 204) {
                    li.remove();
                } else {
                    alert('Failed to delete transaction');
                }
            } catch (err) {
                console.error('DELETE /transactions/' + id + ' failed:', err);
                alert('Failed to delete transaction: ' + err.message);
            }
        });
    });
}

// Handle form submission to add a new transaction
document.getElementById('tx-form').addEventListener('submit', async (e) => {
    e.preventDefault(); // <- stops the browser's GET submit
    const errorText = document.getElementById('err');
    errorText.textContent = '';

    const name = document.getElementById('f-name').value.trim();
    const description = document.getElementById('f-desc').value.trim();
    const amountNZD = document.getElementById('f-amt').value;
    const whenVal = document.getElementById('f-when').value;

    const amount_cents = toCents(amountNZD);
    const occurred_at = isoFromDatetimeLocal(whenVal);

    if (!name || !amountNZD) {
        errorText.textContent = 'Name and amount are required.';
        return;
    }
    if (!Number.isInteger(amount_cents)) {
        errorText.textContent = 'Amount must be a number.';
        return;
    }

    try {
        const response = await fetch(`/api/transactions`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                name,
                description: description || null,
                amount_cents: amount_cents,
                occurred_at: occurred_at // null -> server uses NOW()
            })
        });
        if (!response.ok) {
            const json = await response.json().catch(() => ({}));
            throw new Error(json.error || response.statusText);
        }
        // put in new row without reloading everything
        const created = await response.json();
        const list = document.getElementById('list');
        const when = new Date(created.occurred_at);
        const listItem = document.createElement('li');
        listItem.setAttribute('data-id', created.id);
        listItem.innerHTML = `
          <button class="del" title="Delete" aria-label="Delete">×</button>
          <div>
            <div><strong>${escapeHtml(created.name)}</strong> <span class="meta">(${when.toLocaleString()})</span></div>
            ${created.description ? `<div class="meta">${escapeHtml(created.description)}</div>` : ''}
          </div>
          <div class="amt">${formatMoney(created.amount_cents)}</div>
        `;
        list.prepend(listItem);
        listItem.querySelector('button.del').addEventListener('click', async () => {
            const response2 = await fetch(`/api/transactions/${created.id}`, { method: 'DELETE' });
            if (response2.status === 204) listItem.remove();
        });

        // reset form (keep datetime)
        document.getElementById('f-name').value = '';
        document.getElementById('f-desc').value = '';
        document.getElementById('f-amt').value = '';
    } catch (e) {
        errorText.textContent = 'Failed to add: ' + e.message;
    }
});

// Default the datetime-local to now (rounded to minute)
// LLM generated function, I dont know how to do this offhand
(function initNow() {
    const pad = n => String(n).padStart(2, '0');
    const d = new Date();
    d.setSeconds(0, 0);
    const v = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
    document.getElementById('f-when').value = v;
})();
getTransactions();