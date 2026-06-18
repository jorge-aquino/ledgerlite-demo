#!/usr/bin/env bash
# setup.sh — run this ONCE after copying ledgerlite-demo/ to its final location.
#
# Usage:
#   cp -r ledgerlite-demo/ ../ledgerlite-demo   # move out of vault-mcp-server workspace
#   cd ../ledgerlite-demo
#   chmod +x setup.sh && ./setup.sh
#
# What it does:
#   1. Renames gitignore → .gitignore
#   2. Copies .env.example → .env
#   3. Runs go mod tidy to generate go.sum
#   4. Initialises the git repo and makes the initial commit

set -euo pipefail

echo "==> [1/4] Rename gitignore → .gitignore"
mv -f gitignore .gitignore

echo "==> [2/4] Copy .env.example → .env"
if [ ! -f .env ]; then
  cp .env.example .env
  echo "      Created .env — review and edit before running docker compose."
else
  echo "      .env already exists — skipping."
fi

echo "==> [3/4] go mod tidy (downloads chi and lib/pq)"
go mod tidy

echo "==> [4/4] git init + initial commit"
git init -b main
git add .
git commit -m "chore: initial LedgerLite demo scaffold

Intentionally vulnerable payments API for HashiCorp Vault Transit demo.

Vulnerabilities included (see README § Intentional Vulnerabilities):
  VULN #1 - Plaintext SSN/card storage (A02)
  VULN #2 - Homemade AES-CBC, hardcoded key, static IV (A02)
  VULN #3 - No key rotation or data-migration path (A02)
  VULN #4 - HMAC column empty, no integrity verification (A08)
  VULN #5 - Reset tokens via math/rand (A02)
  VULN #6 - Idempotency key via MD5 (A02)

WARNING: DO NOT DEPLOY. DO NOT USE REAL DATA."

echo ""
echo "✓ Setup complete."
echo ""
echo "Next steps:"
echo "  docker compose up --build -d"
echo "  make seed"
echo "  make attack"
