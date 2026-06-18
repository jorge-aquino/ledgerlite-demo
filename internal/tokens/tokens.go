// Package tokens generates password-reset tokens.
package tokens

import (
	"fmt"
	"math/rand"
	"time"
)

// Generate returns a pseudo-random hex token.
func Generate() string {
	r := rand.New(rand.NewSource(time.Now().UnixNano())) //nolint:gosec
	return fmt.Sprintf("%016x%016x", r.Int63(), r.Int63())
}
