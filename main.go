package main

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"

	"github.com/skip2/go-qrcode"
)

type PaymentRequest struct {
	MerchantID string  `json:"merchantID"`
	Amount     float64 `json:"amount"`
}

var encryptionKey = "fb5c2571b945ac7a1848eab0b0ffe94e2919e8a27047993746c6da35a44dded0"

func pkcs7Padding(data []byte, blockSize int) []byte {
	padding := blockSize - len(data)%blockSize
	padtext := bytes.Repeat([]byte{byte(padding)}, padding)
	return append(data, padtext...)
}

func encryptAES(data string, key string) (string, error) {
	keyBytes, err := hex.DecodeString(key)
	if err != nil {
		return "", fmt.Errorf("failed to decode key: %w", err)
	}

	block, err := aes.NewCipher(keyBytes)
	if err != nil {
		return "", fmt.Errorf("failed to create cipher: %w", err)
	}

	plaintext := pkcs7Padding([]byte(data), aes.BlockSize)

	iv := make([]byte, aes.BlockSize)
	copy(iv, []byte("1234567890123456"))

	ciphertext := make([]byte, len(plaintext))

	mode := cipher.NewCBCEncrypter(block, iv)
	mode.CryptBlocks(ciphertext, plaintext)

	combined := append(iv, ciphertext...)

	return base64.StdEncoding.EncodeToString(combined), nil
}

func generateQRCode(w http.ResponseWriter, r *http.Request) {
	data := PaymentRequest{
		MerchantID: "MERCHANT123",
		Amount:     50000.00,
	}

	jsonData, err := json.Marshal(data)
	if err != nil {
		http.Error(w, "Failed to create JSON", http.StatusInternalServerError)
		return
	}

	encryptedData, err := encryptAES(string(jsonData), encryptionKey)
	if err != nil {
		http.Error(w, "Failed to encrypt data", http.StatusInternalServerError)
		return
	}

	qr, err := qrcode.New(encryptedData, qrcode.Medium)
	if err != nil {
		http.Error(w, "Failed to generate QR code", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "image/png")
	err = qr.Write(256, w)
	if err != nil {
		http.Error(w, "Failed to write QR code", http.StatusInternalServerError)
	}
}
func processPayment(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method tidak diizinkan", http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Gagal membaca body request", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	var paymentReq PaymentRequest
	err = json.Unmarshal(body, &paymentReq)
	if err != nil {
		http.Error(w, "Gagal parsing JSON", http.StatusBadRequest)
		return
	}

	fmt.Printf("Memproses pembayaran untuk merchant %s sebesar %.2f\n", paymentReq.MerchantID, paymentReq.Amount)

	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Pembayaran berhasil diproses"))
}

func main() {
	http.HandleFunc("/generate-qr", generateQRCode)
	http.HandleFunc("/process-payment", processPayment)
	fmt.Println("Server berjalan di http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
