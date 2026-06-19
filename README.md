# LedgerLite Demo

> ⚠️ **INTENTIONALLY VULNERABLE — for demonstration only. DO NOT DEPLOY. DO NOT USE REAL DATA.**
>
> This project deliberately contains security vulnerabilities to demonstrate how HashiCorp Vault
> Transit encryption-as-a-service can remediate them. It is modelled after OWASP Juice Shop:
> the bugs are real, intentional, and documented. Never run this against real customer data
> or expose it to any network you do not fully control.

---

## Overview

LedgerLite is a minimal payments API that stores customer PII (SSN, card number) and
transaction records in Postgres. Every meaningful security control has been intentionally
omitted so that a live remediation demo (adding Vault Transit) can show the before/after
contrast clearly.

**Stack:** Go 1.22 · net/http · Postgres 16 · Docker Compose · HashiCorp Vault (dev mode)

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  docker-compose                                      │
│                                                      │
│  ┌──────────────┐   SQL    ┌──────────────────────┐  │
│  │  ledgerlite  │─────────▶│  postgres:16         │  │
│  │  (Go API)    │          │  db: ledgerlite       │  │
│  └──────┬───────┘          └──────────────────────┘  │
│         │  (unused for now)                           │
│         ▼                                             │
│  ┌──────────────┐                                     │
│  │  vault (dev) │  ← Transit engine ready to enable  │
│  └──────────────┘                                     │
└─────────────────────────────────────────────────────┘
```

The Vault service is present but **not yet wired in**. The remediation workshop enables
`transit/`, creates an encryption key, and modifies the app to call Vault before every
DB write/read.

---

## Quick Start

### 1. Prerequisites

- Docker + Docker Compose v2
- `curl` and `jq` (for the demo commands)
- Go 1.22+ (only needed if building outside Docker)

### 2. Configure environment

```bash
cp .env.example .env
# Edit .env if you need different ports; the defaults work out of the box
```

### 3. Start services

```bash
make up
```

### 4. Load seed data

```bash
make seed
```

### 5. Run the attack demo

```bash
make attack
```

---

## Enable Vault Transit (pre-remediation step — document only, not wired in yet)

```bash
# Open a shell into the vault container
docker compose exec vault vault secrets enable transit

# Create the encryption key that the remediation will use
docker compose exec vault vault write -f transit/keys/ledgerlite-pii

# Verify
docker compose exec vault vault read transit/keys/ledgerlite-pii
```

---

## API Endpoints & curl Examples

All examples assume the API is running on `http://localhost:8080`.

### `GET /healthz`

```bash
curl -s http://localhost:8080/healthz | jq
```

### `POST /customers`

```bash
curl -s -X POST http://localhost:8080/customers \
  -H 'Content-Type: application/json' \
  -d '{"name":"Alice Example","email":"alice@example.com","ssn":"000-00-0001","card_number":"4111111111111111"}' \
  | jq
```

### `GET /customers/{id}`

```bash
# Returns SSN and card_number IN THE CLEAR — 
curl -s http://localhost:8080/customers/1 | jq
```

### `POST /transactions`

```bash
curl -s -X POST http://localhost:8080/transactions \
  -H 'Content-Type: application/json' \
  -d '{"customer_id":1,"amount_cents":4999,"currency":"USD"}' \
  | jq
```

### `GET /transactions/{id}`

```bash
curl -s http://localhost:8080/transactions/1 | jq
```

### `POST /auth/reset-token`

```bash
curl -s -X POST http://localhost:8080/auth/reset-token \
  -H 'Content-Type: application/json' \
  -d '{"email":"alice@example.com"}' \
  | jq
```

---

## Intentional Vulnerabilities

These are **by design**. Each maps to an OWASP Top 10 2021 category.

| # | Location | Description | OWASP |
|---|----------|-------------|-------|
| 1 | `internal/handlers/customers.go` | SSN and card number stored as **plaintext** in Postgres; returned verbatim on GET | A02: Cryptographic Failures |
| 2 | `internal/crypto/insecure.go` | Home-rolled AES-CBC with a **hardcoded key** constant and a **static IV** (all-zero) | A02: Cryptographic Failures |
| 3 | `internal/crypto/insecure.go` | **No key-rotation path** and no data-migration mechanism anywhere in the codebase | A02: Cryptographic Failures |
| 4 | `internal/handlers/transactions.go` | `hmac` column exists but is **never populated or verified** — silent tamper is undetected | A08: Software and Data Integrity Failures |

---

## Remediation Roadmap (post-demo)

After the live workshop these vulnerabilities are addressed by:
1. Enabling Vault Transit and calling `transit/encrypt` before every PII write.
2. Calling `transit/decrypt` on read, so the DB never holds plaintext.
3. Replacing the homemade cipher with the Transit API entirely.
4. Enabling key rotation via `vault write -f transit/keys/ledgerlite-pii/rotate`.
5. Computing and verifying an HMAC with `transit/hmac` on every transaction write/read.

---

## License

MIT — see [LICENSE](LICENSE). This project exists solely for security education.
