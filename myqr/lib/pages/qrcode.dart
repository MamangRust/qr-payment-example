import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRCodePage extends StatelessWidget {
  final String paymentData = "http://localhost:8080/process-payment?merchantID=MERCHANT123&amount=50000.00";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("QR Code Pembayaran")),
      body: Center(
        child: QrImageView(
          data: paymentData,
          version: QrVersions.auto,
          size: 200.0,
        ),
      ),
    );
  }
}