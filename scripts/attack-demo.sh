#!/usr/bin/env bash
# scripts/attack-demo.sh
#
# Demonstrates two vulnerabilities without any exploit tooling:
#   1. VULN #1  — SELECT shows SSN and card_number in plaintext.
#   2. VULN #4  — UPDATE changes amount_cents with no HMAC check; tampering is silent.
#
# Run via: make attack
# (Executed inside the Postgres container by the Makefile)

\echo ''
\echo '=========================================================='
\echo ' ATTACK DEMO — INTENTIONALLY VULNERABLE'
\echo ' DO NOT RUN AGAINST REAL DATA'
\echo '=========================================================='

-- ── STEP 1: Plaintext PII leak (VULN #1) ─────────────────────────────────
\echo ''
\echo '--- VULN #1: SELECT shows SSN and card_number in plaintext ---'
SELECT id, name, email, ssn, card_number FROM customers ORDER BY id;

-- ── STEP 2: Silent transaction tampering (VULN #4) ────────────────────────
\echo ''
\echo '--- VULN #4: Showing transaction amounts BEFORE tampering ---'
SELECT id, customer_id, amount_cents, currency, hmac FROM transactions ORDER BY id;

\echo ''
\echo '--- VULN #4: Directly UPDATE amount_cents — no HMAC check will catch this ---'
UPDATE transactions SET amount_cents = 1 WHERE id = 1;

\echo ''
\echo '--- VULN #4: Transaction amounts AFTER tampering (hmac is still empty — undetected) ---'
SELECT id, customer_id, amount_cents, currency, hmac FROM transactions ORDER BY id;

\echo ''
\echo '=========================================================='
\echo ' ATTACK DEMO COMPLETE'
\echo ' Observation: plaintext PII was visible; amount was'
\echo ' silently modified with no integrity violation raised.'
\echo '=========================================================='
