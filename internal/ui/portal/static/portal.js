'use strict';

// ── State ─────────────────────────────────────────────────────────────────────
let currentCustomer = null;

// ── Helpers ───────────────────────────────────────────────────────────────────

async function apiFetch(path, opts) {
  const r = await fetch(path, opts);
  if (!r.ok) {
    const text = await r.text().catch(() => '');
    throw new Error(text || `HTTP ${r.status}`);
  }
  return r.json();
}

function show(id)  { document.getElementById(id).classList.remove('hidden'); }
function hide(id)  { document.getElementById(id).classList.add('hidden'); }
function text(id, val) { document.getElementById(id).textContent = val; }

function showError(id, msg) {
  const el = document.getElementById(id);
  el.textContent = msg;
  el.classList.remove('hidden');
}
function clearError(id) {
  const el = document.getElementById(id);
  el.textContent = '';
  el.classList.add('hidden');
}

let toastTimer;
function toast(msg) {
  const el = document.getElementById('toast');
  el.textContent = msg;
  el.classList.remove('hidden');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.add('hidden'), 3000);
}

function formatCents(cents) {
  return '$' + (cents / 100).toFixed(2);
}

// ── Load account ──────────────────────────────────────────────────────────────

async function loadAccount(customer) {
  currentCustomer = customer;

  // Populate account card
  text('acct-name',  customer.name);
  text('acct-email', customer.email);
  text('acct-id',    `#${customer.id}`);
  text('acct-ssn',   customer.ssn);
  text('acct-card',  customer.card_number);

  // Update nav
  text('nav-greeting', `Hello, ${customer.name.split(' ')[0]}`);
  show('nav-greeting');
  show('btn-logout');

  // Switch views
  hide('view-auth');
  show('view-account');

  // Load transactions
  await refreshTransactions();
}

// ── Transaction history ───────────────────────────────────────────────────────

async function refreshTransactions() {
  if (!currentCustomer) return;
  const list = document.getElementById('tx-history');
  list.innerHTML = '<span class="empty-state">Loading…</span>';

  // Probe IDs 1–20; keep those belonging to this customer
  const results = await Promise.allSettled(
    Array.from({ length: 20 }, (_, i) => apiFetch(`/transactions/${i + 1}`))
  );

  const mine = results
    .filter(r => r.status === 'fulfilled')
    .map(r => r.value)
    .filter(t => t && t.customer_id === currentCustomer.id)
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

  list.innerHTML = '';

  if (!mine.length) {
    list.innerHTML = '<span class="empty-state">No transactions yet.</span>';
    return;
  }

  for (const t of mine) {
    const item = document.createElement('div');
    item.className = 'tx-item';

    const icon = document.createElement('div');
    icon.className = 'tx-icon';
    icon.textContent = '↑';

    const details = document.createElement('div');
    details.className = 'tx-details';
    const idEl = document.createElement('div');
    idEl.className = 'tx-id';
    idEl.textContent = `TXN-${String(t.id).padStart(6, '0')}`;
    const desc = document.createElement('div');
    desc.className = 'tx-desc';
    desc.textContent = `Payment · ${t.currency}`;
    details.append(idEl, desc);

    const amount = document.createElement('div');
    amount.className = 'tx-amount';
    amount.textContent = formatCents(t.amount_cents);

    item.append(icon, details, amount);
    list.append(item);
  }
}

// ── Sign-up form ──────────────────────────────────────────────────────────────

document.getElementById('form-signup').addEventListener('submit', async (e) => {
  e.preventDefault();
  clearError('signup-error');
  const btn = document.getElementById('btn-signup');
  btn.disabled = true;
  btn.textContent = 'Opening account…';

  const fd = new FormData(e.target);
  try {
    const customer = await apiFetch('/customers', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name:        fd.get('name'),
        email:       fd.get('email'),
        ssn:         fd.get('ssn'),
        card_number: fd.get('card_number'),
      }),
    });
    toast(`✓ Account opened! Welcome, ${customer.name.split(' ')[0]}.`);
    await loadAccount(customer);
  } catch (err) {
    showError('signup-error', `Could not open account: ${err.message}`);
    btn.disabled = false;
    btn.textContent = 'Open my account';
  }
});

// ── Sign-in form ──────────────────────────────────────────────────────────────

document.getElementById('form-login').addEventListener('submit', async (e) => {
  e.preventDefault();
  clearError('login-error');
  const id = document.getElementById('l-id').value;

  try {
    const customer = await apiFetch(`/customers/${id}`);
    toast(`✓ Welcome back, ${customer.name.split(' ')[0]}!`);
    await loadAccount(customer);
  } catch (err) {
    showError('login-error', `Customer #${id} not found.`);
  }
});

// ── Payment form ──────────────────────────────────────────────────────────────

document.getElementById('form-payment').addEventListener('submit', async (e) => {
  e.preventDefault();
  clearError('payment-error');
  if (!currentCustomer) return;

  const dollars = parseFloat(document.getElementById('p-amount').value);
  if (isNaN(dollars) || dollars <= 0) {
    showError('payment-error', 'Please enter a valid amount.');
    return;
  }
  const amountCents = Math.round(dollars * 100);

  const btn = e.target.querySelector('button[type=submit]');
  btn.disabled = true;
  btn.textContent = 'Processing…';

  try {
    await apiFetch('/transactions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        customer_id:  currentCustomer.id,
        amount_cents: amountCents,
        currency:     'USD',
      }),
    });
    toast(`✓ Payment of ${formatCents(amountCents)} sent!`);
    e.target.reset();
    await refreshTransactions();
  } catch (err) {
    showError('payment-error', `Payment failed: ${err.message}`);
  } finally {
    btn.disabled = false;
    btn.textContent = 'Send payment';
  }
});

// ── Refresh transactions ──────────────────────────────────────────────────────

document.getElementById('btn-refresh-tx').addEventListener('click', refreshTransactions);

// ── Sign out ──────────────────────────────────────────────────────────────────

document.getElementById('btn-logout').addEventListener('click', () => {
  currentCustomer = null;
  hide('view-account');
  hide('nav-greeting');
  hide('btn-logout');
  show('view-auth');
  document.getElementById('form-signup').reset();
  document.getElementById('form-login').reset();
});
