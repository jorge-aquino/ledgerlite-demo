-- LedgerLite schema
-- VULN #1: ssn and card_number are stored as plaintext text columns (A02)

CREATE TABLE IF NOT EXISTS customers (
    id         SERIAL PRIMARY KEY,
    name       TEXT        NOT NULL,
    email      TEXT        NOT NULL UNIQUE,
    ssn        TEXT        NOT NULL,   -- VULN #1: plaintext PII
    card_number TEXT       NOT NULL,   -- VULN #1: plaintext PII
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- VULN #4: hmac column exists but is never populated or verified (A08)
CREATE TABLE IF NOT EXISTS transactions (
    id               SERIAL PRIMARY KEY,
    customer_id      INT         NOT NULL REFERENCES customers(id),
    amount_cents     BIGINT      NOT NULL,
    currency         TEXT        NOT NULL DEFAULT 'USD',
    idempotency_key  TEXT        NOT NULL UNIQUE,  -- VULN #6: computed with MD5
    hmac             TEXT        NOT NULL DEFAULT '', -- VULN #4: always empty
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
