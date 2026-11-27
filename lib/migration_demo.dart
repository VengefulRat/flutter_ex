import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/staged_account_demo.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const MigrationDemoHome(),
    ),
  );
}

/// Initializes only the named demo project and its local emulators.
class MigrationDemoHome extends StatefulWidget {
  const MigrationDemoHome({super.key});

  @override
  State<MigrationDemoHome> createState() => _MigrationDemoHomeState();
}

class _MigrationDemoHomeState extends State<MigrationDemoHome> {
  bool _authConfigured = false;
  bool _firestoreConfigured = false;
  bool _functionsConfigured = false;
  late Future<
    ({
      FirebaseAuth auth,
      FirebaseFirestore firestore,
      FirebaseFunctions functions,
    })
  >
  _services;

  @override
  void initState() {
    super.initState();
    _services = _connect();
  }

  Future<
    ({
      FirebaseAuth auth,
      FirebaseFirestore firestore,
      FirebaseFunctions functions,
    })
  >
  _connect() async {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'This local demo currently supports Android emulators and web.',
      );
    }
    const name = 'lore-migration-demo';
    const project = 'demo-lore-migration';
    final existing = Firebase.apps.where((app) => app.name == name);
    final app = existing.isEmpty
        ? await Firebase.initializeApp(
            name: name,
            options: FirebaseOptions(
              apiKey: 'AIzaAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
              appId: kIsWeb
                  ? '1:123:web:0123456789abcdef'
                  : '1:123:android:0123456789abcdef',
              messagingSenderId: '123',
              projectId: project,
            ),
          )
        : existing.single;
    if (app.options.projectId != project) {
      throw StateError('The migration demo Firebase project is invalid.');
    }
    final auth = FirebaseAuth.instanceFor(app: app);
    final firestore = FirebaseFirestore.instanceFor(app: app);
    final functions = FirebaseFunctions.instanceFor(app: app);
    if (!_authConfigured) {
      await auth.useAuthEmulator('127.0.0.1', 18765);
      _authConfigured = true;
    }
    if (!_firestoreConfigured) {
      firestore.useFirestoreEmulator('127.0.0.1', 18764);
      _firestoreConfigured = true;
    }
    if (!_functionsConfigured) {
      functions.useFunctionsEmulator('127.0.0.1', 18766);
      _functionsConfigured = true;
    }
    return (auth: auth, firestore: firestore, functions: functions);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _services,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not start the local migration demo: ${snapshot.error}',
                ),
                TextButton(
                  onPressed: () => setState(() => _services = _connect()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      final services = snapshot.data;
      if (services == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return StagedAccountDemo(
        auth: services.auth,
        firestore: services.firestore,
        functions: services.functions,
      );
    },
  );
}
