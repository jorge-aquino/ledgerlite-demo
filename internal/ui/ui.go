// Package ui exposes the embedded static dashboard assets.
package ui

import "embed"

// Static holds all files under internal/ui/static, embedded at build time.
//
//go:embed static
var Static embed.FS
