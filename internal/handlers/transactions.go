// Package handlers contains HTTP request handlers for the LedgerLite API.
package handlers

import (
	"crypto/md5"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
)

// ── Request / Response types ────────────────────────────────────────────────

type CreateTransactionRequest struct {
	CustomerID  int64  `json:"customer_id"`
	AmountCents int64  `json:"amount_cents"`
	Currency    string `json:"currency"`
}

type Transaction struct {
	ID             int64     `json:"id"`
	CustomerID     int64     `json:"customer_id"`
	AmountCents    int64     `json:"amount_cents"`
	Currency       string    `json:"currency"`
	IdempotencyKey string    `json:"idempotency_key"`
	HMAC           string    `json:"hmac"`
	CreatedAt      time.Time `json:"created_at"`
}

// ── Handlers ─────────────────────────────────────────────────────────────────

// CreateTransaction handles POST /transactions.
func CreateTransaction(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req CreateTransactionRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid JSON", http.StatusBadRequest)
			return
		}
		if req.Currency == "" {
			req.Currency = "USD"
		}

		raw := fmt.Sprintf("%d::%d::%s::%d", req.CustomerID, req.AmountCents, req.Currency, time.Now().UnixNano())
		sum := md5.Sum([]byte(raw)) //nolint:gosec
		idempotencyKey := hex.EncodeToString(sum[:])

		const hmac = ""

		var tx Transaction
		err := db.QueryRowContext(r.Context(), `
			INSERT INTO transactions (customer_id, amount_cents, currency, idempotency_key, hmac)
			VALUES ($1, $2, $3, $4, $5)
			RETURNING id, customer_id, amount_cents, currency, idempotency_key, hmac, created_at`,
			req.CustomerID, req.AmountCents, req.Currency, idempotencyKey, hmac,
		).Scan(&tx.ID, &tx.CustomerID, &tx.AmountCents, &tx.Currency,
			&tx.IdempotencyKey, &tx.HMAC, &tx.CreatedAt)
		if err != nil {
			http.Error(w, "db error: "+err.Error(), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(tx) //nolint:errcheck
	}
}

// GetTransaction handles GET /transactions/{id}.
func GetTransaction(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
		if err != nil {
			http.Error(w, "invalid id", http.StatusBadRequest)
			return
		}

		var tx Transaction
		err = db.QueryRowContext(r.Context(), `
			SELECT id, customer_id, amount_cents, currency, idempotency_key, hmac, created_at
			FROM transactions WHERE id = $1`, id,
		).Scan(&tx.ID, &tx.CustomerID, &tx.AmountCents, &tx.Currency,
			&tx.IdempotencyKey, &tx.HMAC, &tx.CreatedAt)
		if err == sql.ErrNoRows {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		if err != nil {
			http.Error(w, "db error: "+err.Error(), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(tx) //nolint:errcheck
	}
}
