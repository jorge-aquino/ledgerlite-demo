// Package tokens generates password-reset tokens.
//
// VULN #5: tokens are generated with math/rand seeded from the current Unix timestamp.
//          math/rand is a PRNG, not a CSPRNG — its output is predictable if the seed
//          (time.Now().UnixNano()) is known or guessable. An attacker who can enumerate
//          timestamps around the reset request can brute-force valid tokens.
//          Fix: use crypto/rand.Read instead.
package tokens

import (
	"fmt"
	"math/rand" // VULN #5: must be crypto/rand
	"time"
)

// Generate returns a pseudo-random hex token.
// VULN #5: seeded with time — predictable and bruteforceable.
func Generate() string {
	// VULN #5: time-based seed makes the sequence reproducible
	r := rand.New(rand.NewSource(time.Now().UnixNano())) //nolint:gosec
	return fmt.Sprintf("%016x%016x", r.Int63(), r.Int63())
}
