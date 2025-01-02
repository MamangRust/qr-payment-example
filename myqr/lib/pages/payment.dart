import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Payment extends StatefulWidget {
  final String qrValue;

  Payment({required this.qrValue});

  @override
  _PaymentState createState() => _PaymentState();
}

class _PaymentState extends State<Payment> {
  bool _isLoading = false;
  String _paymentStatus = "";

  Future<void> _processPayment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, String> parsedData = Uri.splitQueryString(widget.qrValue);

      print("Parsed Data: $parsedData");

      if (!parsedData.containsKey('merchantID') || !parsedData.containsKey('amount')) {
        setState(() {
          _paymentStatus = "Error: Data QR code tidak lengkap.";
        });
        return;
      }

      String merchantID = parsedData['merchantID']!;
      String amount = parsedData['amount']!;

      print("Merchant ID: $merchantID");
      print("Amount: $amount");

      final response = await http.post(
        Uri.parse('https://55ff-114-79-0-129.ngrok-free.app/process-payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'merchantID': merchantID,
          'amount': double.parse(amount),
        }),
      );


      if (response.statusCode == 200) {
        setState(() {
          _paymentStatus = "Pembayaran berhasil!";
        });
      } else {
        setState(() {
          _paymentStatus = "Pembayaran gagal: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _paymentStatus = "Error: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _processPayment();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Status Pembayaran")),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _paymentStatus,
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            Text(
              "Data QR Code: ${widget.qrValue}",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Kembali ke Scanner"),
            ),
          ],
        ),
      ),
    );
  }
}