import React, { useState, useEffect } from "react";
import axios from "axios";
import { connect } from "nats.ws";

const App = () => {
  const [qrCode, setQrCode] = useState("");
  const [paymentStatus, setPaymentStatus] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState("");
  const [connectionError, setConnectionError] = useState("");
  const [merchantID, setMerchantID] = useState("");
  const [amount, setAmount] = useState("");

  useEffect(() => {
    const fetchQRCode = async () => {
      try {
        const response = await axios.get("http://localhost:8080/generate-qr", {
          responseType: "blob",
        });
        const url = URL.createObjectURL(response.data);
        setQrCode(url);
      } catch (err) {
        console.error("Error fetching QR code:", err);
        setError("Gagal memuat QR code.");
      }
    };

    fetchQRCode();
  }, []);

  useEffect(() => {
    let nc;
    const connectToNats = async () => {
      try {
        nc = await connect({
          servers: ["ws://localhost:4223"],
          user: "user",
          pass: "password",
          waitOnFirstConnect: true,
          reconnect: true,
          reconnectTimeWait: 2000,
          maxReconnectAttempts: 10,
        });

        console.log("Connected to NATS");
        setConnectionError("");

        // Subscribe to payment updates
        const sub = nc.subscribe("payment.completed");
        (async () => {
          for await (const msg of sub) {
            try {
              const data = JSON.parse(new TextDecoder().decode(msg.data));
              console.log("Received payment data from NATS:", data);

              setMerchantID(data.merchantID);
              setAmount(data.amount);
              setPaymentStatus(
                `Payment completed for merchant ${data.merchantID} with amount ${data.amount}`,
              );

              processPayment();
            } catch (error) {
              console.error("Error processing NATS message:", error);
            }
          }
        })();
      } catch (err) {
        console.error("NATS connection error:", err);
        setConnectionError("Failed to connect to NATS server. Retrying...");
      }
    };

    connectToNats();

    return () => {
      if (nc) {
        nc.close();
      }
    };
  }, []);

  const processPayment = async () => {
    setIsLoading(true);
    setError("");

    try {
      const response = await axios.post(
        "http://localhost:8080/process-payment",
        {
          merchantID: merchantID,
          amount: parseFloat(amount),
        },
        {
          headers: {
            "Content-Type": "application/json",
          },
        },
      );
      console.log("hello", response);

      if (response.status === 200) {
        setPaymentStatus("Pembayaran berhasil!");
      } else {
        setPaymentStatus(`Pembayaran gagal: ${response.status}`);
      }
    } catch (err) {
      console.error("Error processing payment:", err);
      setError("Terjadi kesalahan saat memproses pembayaran.");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div>
      <h1>QR Code Payment</h1>
      {qrCode ? (
        <img
          src={qrCode}
          alt="QR Code"
          style={{ width: "200px", height: "200px" }}
        />
      ) : (
        <p>Loading QR Code...</p>
      )}

      {error && <p style={{ color: "red" }}>{error}</p>}
      {connectionError && <p style={{ color: "red" }}>{connectionError}</p>}

      <h2>Payment Status</h2>
      <p>{paymentStatus}</p>

      <div>
        <h3>Payment Data from NATS</h3>
        <p>Merchant ID: {merchantID}</p>
        <p>Amount: {amount}</p>
      </div>
    </div>
  );
};

export default App;
