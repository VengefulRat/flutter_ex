import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../services/auth_service.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});
  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final _auth = AuthService();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose(); // Clean up the camera when leaving the screen
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_scanned) return;
    final barcode = capture.barcodes.first;
    final sessionId = barcode.rawValue;
    final myCode = _auth.currentCode;

    if (sessionId != null && myCode != null) {
      setState(() => _scanned = true);
      
      await FirebaseFirestore.instance.collection('web_auth_sessions').doc(sessionId).set({
        'status': 'authorized',
        'userCode': myCode,
        'authorizedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: cInk,
          content: Text('Desktop Logged In!', style: TextStyle(color: cGold)),
        ));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cVoid,
      appBar: AppBar(
        backgroundColor: cInk,
        title: const Text('Scan Desktop QR', style: TextStyle(fontFamily: 'monospace', fontSize: 14, color: cParchment)),
        iconTheme: const IconThemeData(color: cSmoke),
      ),
      body: MobileScanner(
        controller: _controller, // Pass the controller here
        onDetect: _onDetect,
        errorBuilder: (context, error, child) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Camera Error:\n${error.errorCode}: $error\n\nIf this persists, check your camera permissions or restart the app.',
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}