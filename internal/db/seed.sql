-- LedgerLite seed data
-- ALL PII IS OBVIOUSLY FAKE — fictional names, fake SSNs, standard test card numbers.
-- Test card numbers below are the canonical test PANs from major card scheme docs
--   (Luhn-valid, never issued to real cardholders):
--     Visa:       4111111111111111, 4012888888881881
--     Mastercard: 5500005555555559, 5105105105105100
--     Amex:       371449635398431,  378282246310005
-- NEVER load real customer data into this demo database.

-- VULN #1: plaintext SSNs and card numbers written directly to the DB
INSERT INTO customers (name, email, ssn, card_number, created_at) VALUES
    ('Margaret Osei',      'margaret.osei@ledgerlite.com',     '214-38-0001', '4111111111111111',  NOW() - INTERVAL '88 days'),
    ('Dmitri Volkov',      'dmitri.volkov@ledgerlite.com',     '519-62-0002', '5500005555555559',  NOW() - INTERVAL '75 days'),
    ('Priya Nair',         'priya.nair@ledgerlite.com',        '308-77-0003', '4012888888881881',  NOW() - INTERVAL '61 days'),
    ('Tomás Guerrero',     'tomas.guerrero@ledgerlite.com',    '447-51-0004', '5105105105105100',  NOW() - INTERVAL '54 days'),
    ('Aiko Nakamura',      'aiko.nakamura@ledgerlite.com',     '623-09-0005', '371449635398431',   NOW() - INTERVAL '47 days'),
    ('James Okonkwo',      'james.okonkwo@ledgerlite.com',     '712-44-0006', '378282246310005',   NOW() - INTERVAL '39 days'),
    ('Fatima Al-Hassan',   'fatima.alhassan@ledgerlite.com',   '881-23-0007', '4111111111111111',  NOW() - INTERVAL '31 days'),
    ('Lucas Bergström',    'lucas.bergstrom@ledgerlite.com',   '334-58-0008', '5500005555555559',  NOW() - INTERVAL '22 days'),
    ('Chloe Whitmore',     'chloe.whitmore@ledgerlite.com',    '569-11-0009', '4012888888881881',  NOW() - INTERVAL '14 days'),
    ('Ravi Chandrasekhar', 'ravi.chandrasekhar@ledgerlite.com','190-67-0010', '5105105105105100',  NOW() - INTERVAL  '6 days')
ON CONFLICT (email) DO NOTHING;

-- VULN #4: hmac column left empty (default '')
-- VULN #6: idempotency_key is an MD5 hash (computed here with md5() for clarity)
-- Transactions span ~90 days and cover SaaS subscriptions, marketplace charges,
-- cross-border wires, a refund (negative amount), and FX-denominated settlements.
INSERT INTO transactions (customer_id, amount_cents, currency, idempotency_key, hmac, created_at)
SELECT
    c.id,
    t.amount_cents,
    t.currency,
    md5(c.email || '::' || t.amount_cents::text || '::' || t.currency || '::' || t.seq::text),
    '',
    NOW() - (t.days_ago * INTERVAL '1 day')
FROM (VALUES
    -- margaret.osei: annual SaaS seat, two marketplace orders, a failed-then-retry pair
    ('margaret.osei@ledgerlite.com',      119900, 'USD',  1,  85),
    ('margaret.osei@ledgerlite.com',        3499, 'USD',  2,  72),
    ('margaret.osei@ledgerlite.com',       18750, 'USD',  3,  58),
    ('margaret.osei@ledgerlite.com',       -3499, 'USD',  4,  57),  -- refund for order #2
    ('margaret.osei@ledgerlite.com',        3499, 'USD',  5,  56),  -- retry after refund

    -- dmitri.volkov: EUR cross-border wire, monthly subscription x2
    ('dmitri.volkov@ledgerlite.com',      250000, 'EUR',  6,  70),
    ('dmitri.volkov@ledgerlite.com',        9900, 'EUR',  7,  45),
    ('dmitri.volkov@ledgerlite.com',        9900, 'EUR',  8,  15),

    -- priya.nair: GBP marketplace + USD SaaS
    ('priya.nair@ledgerlite.com',          47500, 'GBP',  9,  55),
    ('priya.nair@ledgerlite.com',          14900, 'USD', 10,  40),
    ('priya.nair@ledgerlite.com',           2999, 'USD', 11,  10),

    -- tomas.guerrero: large wire, FX settlement
    ('tomas.guerrero@ledgerlite.com',     500000, 'USD', 12,  50),
    ('tomas.guerrero@ledgerlite.com',      32000, 'MXN', 13,  48),

    -- aiko.nakamura: JPY domestic + USD SaaS + small top-up
    ('aiko.nakamura@ledgerlite.com',      980000, 'JPY', 14,  42),
    ('aiko.nakamura@ledgerlite.com',       14900, 'USD', 15,  28),
    ('aiko.nakamura@ledgerlite.com',        1000, 'USD', 16,   7),

    -- james.okonkwo: NGN local payment + USD invoice
    ('james.okonkwo@ledgerlite.com',     7500000, 'NGN', 17,  35),
    ('james.okonkwo@ledgerlite.com',       89900, 'USD', 18,  20),

    -- fatima.alhassan: monthly subscription, one-time professional services
    ('fatima.alhassan@ledgerlite.com',      4900, 'USD', 19,  28),
    ('fatima.alhassan@ledgerlite.com',     75000, 'USD', 20,  12),

    -- lucas.bergstrom: SEK marketplace + EUR SaaS
    ('lucas.bergstrom@ledgerlite.com',    149900, 'SEK', 21,  18),
    ('lucas.bergstrom@ledgerlite.com',      9900, 'EUR', 22,   5),

    -- chloe.whitmore: two recent orders
    ('chloe.whitmore@ledgerlite.com',       5499, 'USD', 23,  12),
    ('chloe.whitmore@ledgerlite.com',      22000, 'USD', 24,   3),

    -- ravi.chandrasekhar: brand-new account, one pending charge
    ('ravi.chandrasekhar@ledgerlite.com',  49900, 'USD', 25,   2)
) AS t(email, amount_cents, currency, seq, days_ago)
JOIN customers c ON c.email = t.email
ON CONFLICT (idempotency_key) DO NOTHING;
