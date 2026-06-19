// Package handlers contains HTTP request handlers for the LedgerLite API.
package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/your-org/ledgerlite-demo/internal/tokens"
)

// ── Request / Response types ─────────────────────────────────────────────────

type CreateCustomerRequest struct {
	Name       string `json:"name"`
	Email      string `json:"email"`
	SSN        string `json:"ssn"`
	CardNumber string `json:"card_number"`
}

// Customer is the API response type.
// VULN #1: ssn and card_number are returned verbatim from the DB — plaintext PII in API responses.
type Customer struct {
	ID         int64     `json:"id"`
	Name       string    `json:"name"`
	Email      string    `json:"email"`
	SSN        string    `json:"ssn"`         // VULN #1: plaintext in response
	CardNumber string    `json:"card_number"` // VULN #1: plaintext in response
	CreatedAt  time.Time `json:"created_at"`
}

// ResetTokenRequest is the body for POST /auth/reset-token.
type ResetTokenRequest struct {
	Email string `json:"email"`
}

// ResetTokenResponse wraps the generated token.
type ResetTokenResponse struct {
	Token string `json:"token"`
}

// ── Handlers ──────────────────────────────────────────────────────────────────

// CreateCustomer handles POST /customers.
func CreateCustomer(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req CreateCustomerRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid JSON", http.StatusBadRequest)
			return
		}

		// VULN #1: SSN and card number are inserted as plaintext — no encryption before storage.
		var c Customer
		err := db.QueryRowContext(r.Context(), `
			INSERT INTO customers (name, email, ssn, card_number)
			VALUES ($1, $2, $3, $4)
			RETURNING id, name, email, ssn, card_number, created_at`,
			req.Name, req.Email, req.SSN, req.CardNumber, // VULN #1
		).Scan(&c.ID, &c.Name, &c.Email, &c.SSN, &c.CardNumber, &c.CreatedAt)
		if err != nil {
			http.Error(w, "db error: "+err.Error(), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(c) //nolint:errcheck
	}
}

// GetCustomer handles GET /customers/{id}.
func GetCustomer(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
		if err != nil {
			http.Error(w, "invalid id", http.StatusBadRequest)
			return
		}

		var c Customer
		// VULN #1: SSN and card number read back as plaintext and returned to the caller.
		err = db.QueryRowContext(r.Context(), `
			SELECT id, name, email, ssn, card_number, created_at
			FROM customers WHERE id = $1`, id,
		).Scan(&c.ID, &c.Name, &c.Email, &c.SSN, &c.CardNumber, &c.CreatedAt) // VULN #1
		if err == sql.ErrNoRows {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		if err != nil {
			http.Error(w, "db error: "+err.Error(), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(c) //nolint:errcheck
	}
}

// ResetToken handles POST /auth/reset-token.
func ResetToken(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req ResetTokenRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid JSON", http.StatusBadRequest)
			return
		}

		// Verify the email exists (basic lookup — no auth beyond this).
		var exists bool
		_ = db.QueryRowContext(r.Context(),
			`SELECT EXISTS(SELECT 1 FROM customers WHERE email=$1)`, req.Email,
		).Scan(&exists)

		tok := tokens.Generate()

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(ResetTokenResponse{Token: tok}) //nolint:errcheck
	}
}
