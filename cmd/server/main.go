// cmd/server is the entry point for the LedgerLite demo API.
package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"io/fs"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	_ "github.com/lib/pq"

	"github.com/your-org/ledgerlite-demo/internal/handlers"
	"github.com/your-org/ledgerlite-demo/internal/ui"
	"github.com/your-org/ledgerlite-demo/internal/ui/portal"
)

func main() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		log.Fatal("DATABASE_URL is required")
	}

	db, err := openDB(dsn)
	if err != nil {
		log.Fatalf("cannot connect to database: %v", err)
	}
	defer db.Close()

	port := os.Getenv("APP_PORT")
	if port == "" {
		port = "8080"
	}

	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	// Customer-facing portal at "/".
	portalRoot, err := fs.Sub(portal.Static, "static")
	if err != nil {
		log.Fatalf("embed portal sub-FS error: %v", err)
	}
	r.Get("/", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFileFS(w, r, portalRoot, "index.html")
	})
	r.Handle("/portal.css", http.FileServerFS(portalRoot))
	r.Handle("/portal.js", http.FileServerFS(portalRoot))

	// Security dashboard at "/security".
	securityRoot, err := fs.Sub(ui.Static, "static")
	if err != nil {
		log.Fatalf("embed security sub-FS error: %v", err)
	}
	r.Get("/security", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFileFS(w, r, securityRoot, "index.html")
	})
	r.Handle("/styles.css", http.FileServerFS(securityRoot))
	r.Handle("/dashboard.js", http.FileServerFS(securityRoot))

	r.Get("/healthz", healthz(db))

	r.Post("/customers", handlers.CreateCustomer(db))
	r.Get("/customers/{id}", handlers.GetCustomer(db))

	r.Post("/transactions", handlers.CreateTransaction(db))
	r.Get("/transactions/{id}", handlers.GetTransaction(db))

	r.Post("/auth/reset-token", handlers.ResetToken(db))

	log.Printf("ledgerlite listening on :%s", port)
	if err := http.ListenAndServe(":"+port, r); err != nil {
		log.Fatalf("server error: %v", err)
	}
}

// openDB opens a *sql.DB with a simple retry loop to wait for Postgres to be ready.
func openDB(dsn string) (*sql.DB, error) {
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, err
	}
	for i := 0; i < 20; i++ {
		if err = db.Ping(); err == nil {
			log.Println("database connected")
			return db, nil
		}
		log.Printf("waiting for database (%d/20): %v", i+1, err)
		time.Sleep(2 * time.Second)
	}
	return nil, fmt.Errorf("database not reachable after retries: %w", err)
}

// healthz returns a simple JSON health response.
func healthz(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		status := "ok"
		if err := db.PingContext(r.Context()); err != nil {
			status = "db unavailable"
			w.WriteHeader(http.StatusServiceUnavailable)
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": status}) //nolint:errcheck
	}
}
