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
