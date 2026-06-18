// Package portal exposes the embedded customer-facing portal assets.
package portal

import "embed"

// Static holds all files under internal/ui/portal, embedded at build time.
//
//go:embed static
var Static embed.FS
