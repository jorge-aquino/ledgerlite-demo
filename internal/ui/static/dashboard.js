/* ── LedgerLite Security Dashboard ────────────────────────────────────────── */
'use strict';

// ── Helpers ──────────────────────────────────────────────────────────────────

function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls)  e.className = cls;
  if (text != null) e.textContent = text;
  return e;
}

function badge(label, kind) {          // kind: 'red'|'amber'|'green'
  return el('span', `badge badge-${kind}`, label);
}

function pill(label, kind) {           // kind: 'red'|'amber'|'green'|'grey'
  return el('span', `sc-status-pill pill-${kind}`, label);
}

async function apiFetch(path, opts) {
  try {
    const r = await fetch(path, opts);
    if (r.status === 404) return null;
    if (!r.ok) return null;
    return await r.json();
  } catch (_) {
    return null;
  }
}

// Range [1..max] of integers
function range(max) {
  return Array.from({ length: max }, (_, i) => i + 1);
}

// ── PII heuristics ───────────────────────────────────────────────────────────

function classifyPii(value) {
  if (!value) return 'empty';
  if (value.startsWith('vault:v')) return 'encrypted';
  return 'plaintext';
}

// Returns {kind:'red'|'green', badgeEl}
function piiBadge(value) {
  const kind = classifyPii(value);
  if (kind === 'encrypted') {
    return { kind: 'green', badgeEl: badge('🔒 ENCRYPTED (Vault Transit)', 'green') };
  }
  return { kind: 'red', badgeEl: badge('⚠ EXPOSED PLAINTEXT', 'red') };
}

// ── HMAC heuristics ──────────────────────────────────────────────────────────

function hmacBadge(hmac) {
  if (!hmac) return { kind: 'red', badgeEl: badge('✗ UNVERIFIED (no HMAC)', 'red') };
  return { kind: 'green', badgeEl: badge('✓ HMAC PRESENT', 'green') };
}

// ── Scorecard definitions ─────────────────────────────────────────────────────

const VULN_DEFS = [
  {
    id: 'VULN #1',
    title: 'Plaintext PII Storage',
    owasp: 'A02 Cryptographic Failures',
    detail: 'SSN and card_number stored & returned as cleartext from Postgres.',
    derive: (data) => {
      if (!data.customers.length) return { s: 'grey', msg: 'No data (create a customer first)' };
      const anyPlain = data.customers.some(c =>
        classifyPii(c.ssn) === 'plaintext' || classifyPii(c.card_number) === 'plaintext'
      );
      if (anyPlain) return { s: 'red',   msg: '⚠ Plaintext PII detected in API responses' };
      return              { s: 'green', msg: '✓ PII appears encrypted (Vault Transit)' };
    },
  },
  {
    id: 'VULN #2',
    title: 'Hardcoded AES Key + Static IV',
    owasp: 'A02 Cryptographic Failures',
    detail: 'internal/crypto/insecure.go: AES-CBC with hardcoded key "THIS-IS-NOT-A-SECRET-KEY…" and all-zero IV.',
    derive: (data) => {
      // Heuristic: if PII is encrypted via Transit, the insecure module is not in use
      if (data.customers.length && data.customers.every(c =>
        classifyPii(c.ssn) === 'encrypted' && classifyPii(c.card_number) === 'encrypted'
      )) return { s: 'green', msg: '✓ Transit in use — insecure module bypassed' };
      return { s: 'red', msg: '⚠ Home-rolled AES-CBC with hardcoded key present' };
    },
  },
  {
    id: 'VULN #3',
    title: 'No Key-Rotation Mechanism',
    owasp: 'A02 Cryptographic Failures',
    detail: 'No re-encryption tooling exists; key compromise = permanent data exposure.',
    derive: (data) => {
      if (data.customers.length && data.customers.every(c =>
        classifyPii(c.ssn) === 'encrypted'
      )) return { s: 'green', msg: '✓ Vault Transit handles rotation automatically' };
      return { s: 'red', msg: '⚠ No rotation — static key, no re-encryption tooling' };
    },
  },
  {
    id: 'VULN #4',
    title: 'Missing Transaction HMAC',
    owasp: 'A08 Software & Data Integrity',
    detail: 'hmac column hardcoded to "". Tampered amount_cents goes undetected.',
    derive: (data) => {
      if (!data.transactions.length) return { s: 'grey', msg: 'No data (create a transaction first)' };
      const anyEmpty = data.transactions.some(t => !t.hmac);
      if (anyEmpty) return { s: 'red',   msg: '⚠ HMAC absent — integrity unverified' };
      return              { s: 'green', msg: '✓ HMAC present on all sampled transactions' };
    },
  },
];

// ── Shared live data store ────────────────────────────────────────────────────

const store = {
  customers:    [],   // fetched Customer objects (may be partial)
  transactions: [],   // fetched Transaction objects
};

// ── Scorecard rendering ───────────────────────────────────────────────────────

function renderScorecard() {
  const grid = document.getElementById('scorecard-grid');
  grid.innerHTML = '';
  let secured = 0;

  for (const def of VULN_DEFS) {
    const result = def.derive(store);
    const s = result.s;   // 'red'|'amber'|'green'|'grey'
    if (s === 'green') secured++;

    const card = el('div', `sc-card${s !== 'grey' ? ` status-${s}` : ''}`);

    const top = el('div', 'sc-card-top');
    top.append(el('span', 'sc-vuln-id', def.id));
    top.append(el('span', 'sc-title', def.title));
    card.append(top);

    card.append(el('div', 'sc-owasp', def.owasp));

    const pillMap = { red: '✗ VULNERABLE', amber: '⚠ WEAK', green: '✓ SECURED', grey: '— UNKNOWN' };
    card.append(pill(pillMap[s] ?? '—', s));
    card.append(el('div', 'sc-detail', result.msg));

    grid.append(card);
  }

  const total = VULN_DEFS.length;
  const summary = document.getElementById('score-summary');
  const color = secured === total ? '#3fb950' : secured > 0 ? '#d29922' : '#f85149';
  summary.textContent = `Secured ${secured} / ${total}`;
  summary.style.color = color;
}

// ── Customer panel ────────────────────────────────────────────────────────────

async function fetchCustomers() {
  const max = Math.max(1, Math.min(20, parseInt(document.getElementById('customer-max').value, 10) || 5));
  const results = await Promise.all(range(max).map(i => apiFetch(`/customers/${i}`)));
  store.customers = results.filter(Boolean);
}

function renderCustomers() {
  const list = document.getElementById('customer-list');
  list.innerHTML = '';

  if (!store.customers.length) {
    list.append(el('span', '', 'No customers found for the scanned ID range.'));
    return;
  }

  for (const c of store.customers) {
    const card = el('div', 'record-card');
    card.append(el('div', 'record-id', `#${c.id}  ·  ${c.name}  ·  ${c.email}`));

    // SSN row
    const ssnRow = el('div', 'record-row');
    ssnRow.append(el('span', 'record-label', 'ssn'));
    ssnRow.append(el('span', 'record-value', c.ssn));
    const ssnB = piiBadge(c.ssn);
    ssnRow.append(ssnB.badgeEl);
    card.append(ssnRow);

    // Card number row
    const cardRow = el('div', 'record-row');
    cardRow.append(el('span', 'record-label', 'card_number'));
    cardRow.append(el('span', 'record-value', c.card_number));
    const cardB = piiBadge(c.card_number);
    cardRow.append(cardB.badgeEl);
    card.append(cardRow);

    list.append(card);
  }
}

// ── Transaction panel ─────────────────────────────────────────────────────────

async function fetchTransactions() {
  const max = Math.max(1, Math.min(20, parseInt(document.getElementById('tx-max').value, 10) || 5));
  const results = await Promise.all(range(max).map(i => apiFetch(`/transactions/${i}`)));
  store.transactions = results.filter(Boolean);
}

function renderTransactions() {
  const list = document.getElementById('tx-list');
  list.innerHTML = '';

  if (!store.transactions.length) {
    list.append(el('span', '', 'No transactions found for the scanned ID range.'));
    return;
  }

  for (const t of store.transactions) {
    const card = el('div', 'record-card');
    card.append(el('div', 'record-id', `#${t.id}  ·  customer ${t.customer_id}  ·  ${t.amount_cents} ${t.currency}`));

    // HMAC row
    const hmacRow = el('div', 'record-row');
    hmacRow.append(el('span', 'record-label', 'hmac'));
    hmacRow.append(el('span', 'record-value', t.hmac || '(empty)'));
    hmacRow.append(hmacBadge(t.hmac).badgeEl);
    card.append(hmacRow);

    list.append(card);
  }
}

// ── Full scan ─────────────────────────────────────────────────────────────────

async function scan() {
  const btn = document.getElementById('btn-refresh');
  btn.disabled = true;
  btn.textContent = '⟳ Scanning…';

  await Promise.all([fetchCustomers(), fetchTransactions()]);

  renderCustomers();
  renderTransactions();
  renderScorecard();

  btn.disabled = false;
  btn.textContent = '⟳ Re-scan';
}

// ── Forms ─────────────────────────────────────────────────────────────────────

function setStatus(id, msg, isErr) {
  const el2 = document.getElementById(id);
  el2.textContent = msg;
  el2.className = `form-status${isErr ? ' err' : ''}`;
  if (!isErr) setTimeout(() => { el2.textContent = ''; }, 4000);
}

document.getElementById('form-create-customer').addEventListener('submit', async (e) => {
  e.preventDefault();
  const fd = new FormData(e.target);
  const body = {
    name:        fd.get('name'),
    email:       fd.get('email'),
    ssn:         fd.get('ssn'),
    card_number: fd.get('card_number'),
  };
  const r = await apiFetch('/customers', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (r) {
    setStatus('customer-form-status', `✓ Created customer #${r.id}`, false);
    e.target.reset();
    await scan();
  } else {
    setStatus('customer-form-status', '✗ Failed to create customer', true);
  }
});

document.getElementById('form-create-tx').addEventListener('submit', async (e) => {
  e.preventDefault();
  const fd = new FormData(e.target);
  const body = {
    customer_id:  parseInt(fd.get('customer_id'), 10),
    amount_cents: parseInt(fd.get('amount_cents'), 10),
    currency:     fd.get('currency') || 'USD',
  };
  const r = await apiFetch('/transactions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (r) {
    setStatus('tx-form-status', `✓ Created transaction #${r.id}`, false);
    e.target.reset();
    await scan();
  } else {
    setStatus('tx-form-status', '✗ Failed to create transaction', true);
  }
});

// ── Event wiring ──────────────────────────────────────────────────────────────

document.getElementById('btn-refresh').addEventListener('click', scan);

// Initial scan on load
scan();
