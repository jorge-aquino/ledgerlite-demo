// Package crypto provides an INTENTIONALLY INSECURE cipher implementation.
// This file exists solely to demonstrate what NOT to do.
package crypto

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
)

const hardcodedKey = "THIS-IS-NOT-A-SECRET-KEY-1234567"

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
	mode := cipher.NewCBCEncrypter(block, staticIV)
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
	mode := cipher.NewCBCDecrypter(block, staticIV)
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
