import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/staged_account_demo.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'This local demo currently supports Android emulators and web.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  final app = await Firebase.initializeApp(
    name: 'lore-migration-demo',
    options: FirebaseOptions(
      apiKey: 'AIzaAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      appId: kIsWeb
          ? '1:123:web:0123456789abcdef'
          : '1:123:android:0123456789abcdef',
      messagingSenderId: '123',
      projectId: 'demo-lore-migration',
    ),
  );
  final auth = FirebaseAuth.instanceFor(app: app);
  final firestore = FirebaseFirestore.instanceFor(app: app);
  await auth.useAuthEmulator('127.0.0.1', 18765);
  firestore.useFirestoreEmulator('127.0.0.1', 18764);
  runApp(
    MaterialApp(
      title: 'Lore migration demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: cGold,
          secondary: cIce,
          surface: cInk,
        ),
        useMaterial3: true,
      ),
      home: StagedAccountDemo(auth: auth, firestore: firestore),
    ),
  );
}
