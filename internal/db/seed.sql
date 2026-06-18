-- LedgerLite seed data
-- ALL PII IS OBVIOUSLY FAKE — fictional names, fake SSNs, standard test card numbers.
-- The card number 4111111111111111 is the canonical Visa test number (Luhn-valid, never issued).
-- NEVER load real customer data into this demo database.

-- VULN #1: plaintext SSNs and card numbers written directly to the DB
INSERT INTO customers (name, email, ssn, card_number) VALUES
    ('Alice Testuser',   'alice@example.invalid',   '000-00-0001', '4111111111111111'),
    ('Bob Fakename',     'bob@example.invalid',     '000-00-0002', '4111111111111111'),
    ('Carol Demouser',   'carol@example.invalid',   '000-00-0003', '4111111111111111'),
    ('Dave Placeholder', 'dave@example.invalid',    '000-00-0004', '4111111111111111'),
    ('Eve Seeddata',     'eve@example.invalid',     '000-00-0005', '4111111111111111')
ON CONFLICT (email) DO NOTHING;

-- VULN #4: hmac column left empty (default '')
INSERT INTO transactions (customer_id, amount_cents, currency, idempotency_key, hmac)
SELECT
    c.id,
    amount_cents,
    currency,
    md5(c.email || '::' || amount_cents::text || '::' || currency),
    ''
FROM (VALUES
    ('alice@example.invalid', 4999,   'USD'),
    ('alice@example.invalid', 19900,  'USD'),
    ('bob@example.invalid',   9900,   'EUR'),
    ('carol@example.invalid', 149900, 'USD'),
    ('dave@example.invalid',  2499,   'GBP')
) AS t(email, amount_cents, currency)
JOIN customers c ON c.email = t.email
ON CONFLICT (idempotency_key) DO NOTHING;
