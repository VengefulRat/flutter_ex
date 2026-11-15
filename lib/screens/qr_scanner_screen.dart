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
  bool _authorizing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose(); // Clean up the camera when leaving the screen
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_scanned) return;
    if (capture.barcodes.isEmpty) return;
    final sessionId = capture.barcodes.first.rawValue;
    final myCode = _auth.currentCode;

    if (sessionId == null || sessionId.isEmpty) return;
    if (myCode == null || myCode.isEmpty) {
      if (mounted) {
        setState(
          () => _error =
              'You are not logged in on this phone. Log in first, then scan again.',
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _scanned = true;
      _authorizing = true;
      _error = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('web_auth_sessions')
          .doc(sessionId)
          .set({
            'status': 'authorized',
            'userCode': myCode,
            'authorizedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      // Write failed — unlock the scanner so the user can try again.
      if (!mounted) return;
      setState(() {
        _scanned = false;
        _authorizing = false;
        _error =
            'Could not link desktop. Check your connection and scan again.';
      });
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cVoid,
      appBar: AppBar(
        backgroundColor: cInk,
        title: const Text(
          'Scan Desktop QR',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: cParchment,
          ),
        ),
        iconTheme: const IconThemeData(color: cSmoke),
      ),
      body: Stack(
        children: [
          MobileScanner(
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
          if (_authorizing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: cGold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Linking your desktop...',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: cParchment,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_error != null && !_authorizing)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: cInk,
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: cEmber,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
