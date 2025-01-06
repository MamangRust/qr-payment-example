import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dart_nats/dart_nats.dart';
import 'package:myqr/pages/payment.dart';

class QRScannerPage extends StatefulWidget {
  @override
  _QRScannerPageState createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  MobileScannerController cameraController = MobileScannerController();
  final String encryptionKey =
      "fb5c2571b945ac7a1848eab0b0ffe94e2919e8a27047993746c6da35a44dded0";

  String decryptAES(String encryptedData, String key) {
    try {
      final keyBytes = List<int>.generate(
          32, (i) => int.parse(key.substring(i * 2, i * 2 + 2), radix: 16));

      final combined = base64.decode(encryptedData);

      final iv = encrypt.IV(combined.sublist(0, 16));
      final ciphertext = combined.sublist(16);

      final encrypter = encrypt.Encrypter(
        encrypt.AES(
          encrypt.Key(Uint8List.fromList(keyBytes)),
          mode: encrypt.AESMode.cbc,
          padding: 'PKCS7',
        ),
      );

      final decrypted = encrypter.decrypt(
        encrypt.Encrypted(Uint8List.fromList(ciphertext)),
        iv: iv,
      );

      return decrypted;
    } catch (e) {
      print("Decryption error: $e");
      throw Exception("Decryption failed: $e");
    }
  }

  Future<void> sendPaymentNotification(String merchantID, double amount) async {
    try {
      final client = Client();
      await client.connect(Uri.parse("ws://192.168.1.28:4223"),
          connectOption: ConnectOption(
              user: "user", pass: "password", tlsRequired: false));

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Success"),
            content: Text("Connected to NATS successfully!"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK"),
              ),
            ],
          );
        },
      );

      final message = jsonEncode({
        'merchantID': merchantID,
        'amount': amount,
        'status': 'completed',
      });

      await client.pubString('payment.completed', message);
      await client.close();
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Error"),
            content: Text("Failed to connect to NATS: $e"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK"),
              ),
            ],
          );
        },
      );
    }
  }

  void processQRData(String qrValue) {
    try {
      print("Raw QR Value: $qrValue");

      String decryptedData = decryptAES(qrValue, encryptionKey);
      print("Decrypted data: $decryptedData");

      Map<String, dynamic> data = jsonDecode(decryptedData);

      if (!data.containsKey('merchantID') || !data.containsKey('amount')) {
        throw Exception("Incomplete data");
      }

      double amount;
      if (data['amount'] is int) {
        amount = (data['amount'] as int).toDouble();
      } else if (data['amount'] is double) {
        amount = data['amount'];
      } else {
        throw Exception("Invalid amount format");
      }

      sendPaymentNotification(data['merchantID'], amount);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Payment(
            qrValue:
                "merchantID=${data['merchantID']}&amount=${data['amount']}",
          ),
        ),
      );
    } catch (e) {
      print("Processing error: $e");
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Error"),
            content:
                Text("Invalid QR code format. Please try again.\nError: $e"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK"),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Scan Payment QR")),
      body: MobileScanner(
        controller: cameraController,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              processQRData(barcode.rawValue!);
              break;
            }
          }
        },
      ),
    );
  }
}
