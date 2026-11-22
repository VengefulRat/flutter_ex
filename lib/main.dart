import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:audioplayers/audioplayers.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'widgets/shared.dart';
import 'screens/login_screen.dart';
import 'screens/lock_screen.dart';
import 'settings.dart';
import 'services/auth_service.dart';
import 'services/crypto_service.dart';
import 'services/sandbox_sync.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'screens/diary_screen.dart';
import 'services/sound_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/home_screen.dart';


// Must be top-level for FCM background handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await initDiaryNotifications();
  await appSettings.load();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const LoreApp());
}

class LoreApp extends StatefulWidget {
  const LoreApp({super.key});
  @override
  State<LoreApp> createState() => _LoreAppState();
}

class _LoreAppState extends State<LoreApp> {
  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Lore the Rp App',
    debugShowCheckedModeBanner: false,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      FlutterQuillLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    theme: ThemeData(
      scaffoldBackgroundColor: appSettings.bgColor,
      colorScheme: ColorScheme.dark(
        primary: cGold,
        secondary: cIce,
        surface: appSettings.surfaceColor,
      ),
      useMaterial3: true,
    ),
    home: const SplashScreen(),
  );
}

// ════════════════════════════════════════
// SPLASH
// ════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeIn, _fadeOut;
  final _player = AudioPlayer();
  bool _musicStopping = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );
    _fadeOut = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
      ),
    );

    // Start music
    _playMusic();

    _ctrl.forward().then((_) async {
      if (!mounted) return;
      final auth = AuthService();
      final hasSession = await auth.restoreSession();
      if (hasSession) {
        await appSettings.syncFromCloud();
        await _pullSandboxIfAny();
      }
      if (!mounted) return;

      // Lock decision happens BEFORE home mounts. Otherwise home builds
      // underneath the lock screen and flashes for a frame.
      if (hasSession) {
        final code = auth.currentCode;
        if (code != null) {
          final crypto = CryptoService();
          bool shouldLock = await auth.shouldLock();

          // Wiped-device recovery: server has keys, local has nothing.
          if (!crypto.isUnlocked && !shouldLock) {
            final hasRemote = await crypto.hasRemoteKeyMaterial(code);
            if (hasRemote) shouldLock = true;
          }

          if (shouldLock) {
            if (!mounted) return;
            await showLockScreen(context);
            if (!mounted) return;
          } else {
            await crypto.silentUnlock(code);
          }
        }
      }

      if (!mounted) return;
      // Fade out music over 2 seconds
      _fadeOutMusic();
      Navigator.of(context).pushReplacement(
        fadeRoute(
          hasSession
              ? const HomeScreen()
              : (kIsWeb ? const LandingScreen() : const LandingScreen()),
        ),
      );
    });
  }

  Future<void> _playMusic() async {
    try {
      await _player.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
      await _player.setVolume(sounds.masterVolume);
      await _player.play(AssetSource('sounds/echoes_of_the_deep.mp3'));
    } catch (_) {}
  }

  Future<void> _fadeOutMusic() async {
    try {
      for (double v = sounds.masterVolume; v >= 0; v -= 0.05) {
        if (_musicStopping || !mounted) return;
        await Future.delayed(const Duration(milliseconds: 100));
        if (_musicStopping || !mounted) return;
        await _player.setVolume(v.clamp(0.0, 1.0));
      }
      if (!_musicStopping && mounted) await _player.stop();
    } catch (_) {}
  }

  Future<void> _pullSandboxIfAny() async {
    await SandboxSync.syncOnLogin();
  }

  @override
  void dispose() {
    _musicStopping = true;
    _ctrl.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cVoid,
    body: Center(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Opacity(opacity: _fadeIn.value * _fadeOut.value, child: child),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Image.asset('assets/images/1234.png', fit: BoxFit.contain),
        ),
      ),
    ),
  );
}

// ════════════════════════════════════════
// LANDING
// ════════════════════════════════════════
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cVoid,
    body: SafeArea(
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: ScrollConfiguration(
            behavior: NoGlowBehavior(),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 48),
                        if (appSettings.showLogo)
                          Text(
                            appSettings.logoText.split('').join(' '),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              color: cGold,
                              letterSpacing: 8,
                            ),
                          ),
                        const Spacer(),
                        const Text(
                          'Every story\nbegins with\nyou.',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w300,
                            color: cParchment,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Every story begins the same way —\nwith a blank page and a decision.\nThis is yours. Write it.',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w300,
                            color: cMist,
                            height: 1.8,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        LoreButton(
                          label: 'E N T E R   T H E   W O R L D',
                          filled: true,
                          onTap: () => Navigator.of(
                            context,
                          ).push(fadeRoute(const LoginScreen())),
                        ),
                        const SizedBox(height: 16),
                        LoreTap(
                          onTap: () => Navigator.of(context).push(
                            fadeRoute(const LoginScreen(startOnLogin: true)),
                          ),
                          child: const Center(
                            child: Text(
                              'Sign in',
                              style: TextStyle(
                                fontSize: 12,
                                color: cSmoke,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── DOWNLOAD ANDROID APP BUTTON ──
                        LoreTap(
                          onTap: () => showDownloadDialog(context),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: cGold.withValues(alpha: 0.3),
                              ),
                              color: cGold.withValues(alpha: 0.05),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.android, size: 16, color: cGold),
                                SizedBox(width: 10),
                                Text(
                                  'DOWNLOAD ANDROID APP',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    color: cGold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ════════════════════════════════════════
// GLOBAL DOWNLOAD DIALOG
// ════════════════════════════════════════
void showDownloadDialog(BuildContext context) {
  // ⚠️ REPLACE THIS URL WITH YOUR ACTUAL GITHUB RELEASE APK LINK! ⚠️
  const String apkUrl =
      'https://github.com/VengefulRat/flutter_ex/releases/download/v8.4.6/flutter_ex-releases.apk';

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: cInk,
      shape: const RoundedRectangleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ANDROID APK',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                color: cGold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Lore is available for Android devices. Since we are an independent platform, you will need to side-load the app.',
              style: TextStyle(
                fontSize: 13,
                color: cMist,
                fontStyle: FontStyle.italic,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: cAsh)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOW TO INSTALL:',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      color: cSmoke,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Tap "Download APK" below.\n2. Open the downloaded file.\n3. If prompted, allow "Install from Unknown Sources" in your settings.\n4. Install and open Lore.',
                    style: TextStyle(
                      fontSize: 12,
                      color: cParchment,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: cAsh),
                      ),
                      child: const Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            color: cSmoke,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      final uri = Uri.parse(apkUrl);
                      if (!await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      )) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: cInk,
                              content: Text(
                                'Could not open download link.',
                                style: TextStyle(color: cEmber),
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: cParchment,
                      child: const Center(
                        child: Text(
                          'Download APK',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            color: cVoid,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
