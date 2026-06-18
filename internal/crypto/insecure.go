// Package crypto provides an INTENTIONALLY INSECURE cipher implementation.
// This file exists solely to demonstrate what NOT to do.
//
// VULN #2: Home-rolled AES-CBC with a hardcoded key constant and a static (all-zero) IV.
//          - The key never changes (no rotation path) — see VULN #3.
//          - A static IV means identical plaintexts always produce identical ciphertexts,
//            completely defeating semantic security.
//          - Using a custom cipher instead of an AEAD (e.g., AES-GCM) means there is
//            no authentication; ciphertexts can be silently tampered.
//
// VULN #3: There is no key-rotation mechanism and no data-migration path in this codebase.
//          Rotating the key would require re-encrypting every row, but no such tooling exists.
package crypto

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
)

// VULN #2: hardcoded 32-byte AES key — trivially discoverable in source / binaries.
const hardcodedKey = "THIS-IS-NOT-A-SECRET-KEY-1234567"

// VULN #2: static (all-zero) IV — reusing the same IV with the same key is cryptographically broken.
var staticIV = make([]byte, aes.BlockSize) // [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

// Encrypt encrypts plaintext with AES-CBC using the hardcoded key and static IV.
// NEVER USE THIS IN PRODUCTION.
func Encrypt(plaintext []byte) ([]byte, error) {
	block, err := aes.NewCipher([]byte(hardcodedKey))
	if err != nil {
		return nil, err
	}
	padded := pkcs7Pad(plaintext, aes.BlockSize)
	ciphertext := make([]byte, len(padded))
	mode := cipher.NewCBCEncrypter(block, staticIV) // VULN #2: static IV
	mode.CryptBlocks(ciphertext, padded)
	return ciphertext, nil
}

// Decrypt decrypts ciphertext with AES-CBC using the hardcoded key and static IV.
// NEVER USE THIS IN PRODUCTION.
func Decrypt(ciphertext []byte) ([]byte, error) {
	block, err := aes.NewCipher([]byte(hardcodedKey))
	if err != nil {
		return nil, err
	}
	mode := cipher.NewCBCDecrypter(block, staticIV) // VULN #2: static IV
	plaintext := make([]byte, len(ciphertext))
	mode.CryptBlocks(plaintext, ciphertext)
	return pkcs7Unpad(plaintext), nil
}

func pkcs7Pad(b []byte, blockSize int) []byte {
	n := blockSize - len(b)%blockSize
	padding := bytes.Repeat([]byte{byte(n)}, n)
	return append(b, padding...)
}

func pkcs7Unpad(b []byte) []byte {
	if len(b) == 0 {
		return b
	}
	n := int(b[len(b)-1])
	if n > len(b) {
		return b
	}
	return b[:len(b)-n]
}
