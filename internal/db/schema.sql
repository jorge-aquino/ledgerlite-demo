-- LedgerLite schema

CREATE TABLE IF NOT EXISTS customers (
    id         SERIAL PRIMARY KEY,
    name       TEXT        NOT NULL,
    email      TEXT        NOT NULL UNIQUE,
    ssn        TEXT        NOT NULL,   
    card_number TEXT       NOT NULL,   
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS transactions (
    id               SERIAL PRIMARY KEY,
    customer_id      INT         NOT NULL REFERENCES customers(id),
    amount_cents     BIGINT      NOT NULL,
    currency         TEXT        NOT NULL DEFAULT 'USD',
    idempotency_key  TEXT        NOT NULL UNIQUE,
    hmac             TEXT        NOT NULL DEFAULT '', 
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
