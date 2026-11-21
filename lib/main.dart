import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'widgets/shared.dart';
import 'screens/rp_room.dart';
import 'screens/sandbox_screen.dart';
import 'screens/brainstorm_room.dart';
import 'screens/login_screen.dart';
import 'screens/lock_screen.dart';
import 'settings.dart';
import 'screens/customize_screen.dart';
import 'services/auth_service.dart';
import 'services/crypto_service.dart';
import 'services/firestore_service.dart';
import 'services/sandbox_sync.dart';
import 'services/dev_tools.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'screens/diary_screen.dart';
import 'services/sound_service.dart';
import 'widgets/request_card_view.dart';
import 'widgets/card_frame.dart';
import 'widgets/home_profile_card.dart';
import 'widgets/block_style_sheet.dart';
import 'screens/gestures_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'screens/qr_scanner_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'widgets/colour_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'widgets/holo_card_v2.dart';
import 'widgets/floating_menu.dart';
import 'services/update_service.dart';

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
      await _player.setVolume(0.8);
      await _player.play(AssetSource('sounds/echoes_of_the_deep.mp3'));
    } catch (_) {}
  }

  Future<void> _fadeOutMusic() async {
    try {
      for (double v = 0.8; v >= 0; v -= 0.05) {
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
// HOME SCREEN
// ════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  String _buildProfileSubtitle() {
    final profile = _profile;
    if (profile == null) return '';
    final tags = (profile['tags'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((t) => t['label'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    if (tags.isNotEmpty) return tags.join(' · ');
    final style = profile['writingStyle'] as String? ?? '';
    if (style.isNotEmpty) return style;
    final genre = profile['genre'] as String? ?? '';
    return genre;
  }

  // ── Desktop layout state ──
  // null  → the "Overview" view (mobile-style, centered on wide screens)
  // string → split view with the sidebar collapsed and this block shown
  String? _activeBlock;

  bool get _isDesktop => MediaQuery.sizeOf(context).width >= 900;

  final _auth = AuthService();
  final _fs = FirestoreService();

  List<_NotifData> _notifications = [];
  List<_RPData> _roleplays = [];
  List<_RPData> _brainstorms = [];
  Map<String, dynamic>? _profile;
  _RPData? _continueSession;
  StreamSubscription? _sessionsSub;
  StreamSubscription? _notifsSub;
  StreamSubscription? _fcmOpenedAppSub;
  Timer? _updateCheckTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If the window was shrunk below the desktop breakpoint while a
    // block was open, drop back to the mobile layout cleanly instead
    // of leaving orphaned split-mode state around.
    if (_activeBlock != null && MediaQuery.sizeOf(context).width < 900) {
      _activeBlock = null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    appSettings.addListener(_onSettingsChanged);
    _loadData();
    _setupFCMRouting();
    _initialChecks();
  }

  /// Runs on cold start. Session version check first — if we've been
  /// signed out from elsewhere, return to Landing before anything else.
  ///
  /// Lock-on-start is now handled by the splash screen before home
  /// mounts, so this only does the remote-sign-out check.
  Future<void> _initialChecks() async {
    debugPrint('🔍 [MAIN] _initialChecks STARTED');

    final valid = await _auth.verifySessionVersion();
    if (!valid && mounted) {
      await _handleSessionKicked();
      return;
    }

    if (!kIsWeb) {
      debugPrint('🔍 [MAIN] Android detected. Waiting 2 seconds...');
      _updateCheckTimer?.cancel();
      _updateCheckTimer = Timer(const Duration(seconds: 2), () {
        debugPrint(
          '🔍 [MAIN] 2 seconds passed. Calling UpdateService.checkForUpdates...',
        );
        if (mounted) UpdateService.checkForUpdates(context);
      });
    } else {
      debugPrint('🔍 [MAIN] Web detected. Skipping update check.');
    }
  }

  Future<void> _handleSessionKicked() async {
    await _auth.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: cInk,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(),
        content: Text(
          'You were signed out because your account signed in elsewhere.',
          style: TextStyle(color: cParchment),
        ),
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      fadeRoute(kIsWeb ? const LoginScreen() : const LandingScreen()),
      (_) => false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      await _auth.saveBackgroundTimestamp();
    } else if (state == AppLifecycleState.resumed) {
      // Session version check — signed in elsewhere?
      final valid = await _auth.verifySessionVersion();
      if (!valid && mounted) {
        await _handleSessionKicked();
      }
      // No re-lock on resume. The PIN is only required on cold start
      // when the encryption keys need loading. Once they're in memory
      // they stay for the session.
    }
  }

  void _setupFCMRouting() {
    // App opened from terminated state via notification tap
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _routeFromMessage(message.data);
        });
      }
    });

    // App in background, notification tapped
    _fcmOpenedAppSub?.cancel();
    _fcmOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (mounted) _routeFromMessage(message.data);
    });
  }

  void _routeFromMessage(Map<String, dynamic> data) async {
    final type = data['type'] as String? ?? '';
    final sessionId = data['sessionId'] as String? ?? '';
    // #7: don't push a duplicate RP room if this session is already open
    if (sessionId.isNotEmpty &&
        (type == 'rp_post' || type == 'ooc_message') &&
        RPRoomScreen.openSessionId == sessionId) {
      return;
    }
    // #7: don't push a duplicate RP room if this session is already open
    if (sessionId.isNotEmpty &&
        (type == 'rp_post' || type == 'ooc_message') &&
        RPRoomScreen.openSessionId == sessionId) {
      return;
    }
    final notifId = data['notifId'] as String? ?? '';

    if (sessionId.isNotEmpty &&
        (type == 'rp_post' ||
            type == 'ooc_message' ||
            type == 'brainstorm_message')) {
      // Fetch session doc to get partnerName and genre
      try {
        final doc = await FirebaseFirestore.instance
            .collection('sessions')
            .doc(sessionId)
            .get();
        if (!mounted) return;
        final sessionData = doc.data() ?? {};
        final myCode = AuthService().currentCode ?? '';
        final participants = List<String>.from(
          sessionData['participants'] ?? [],
        );
        final partnerCode = participants.firstWhere(
          (p) => p != myCode,
          orElse: () => '',
        );
        final partnerName =
            sessionData['participantNames']?[partnerCode] as String? ??
            partnerCode;
        final genre = sessionData['genre'] as String? ?? '';

        if (type == 'brainstorm_message') {
          Navigator.of(context).push(
            fadeRoute(
              BrainstormRoomScreen(
                sessionId: sessionId,
                partnerName: partnerName,
                partnerCode: partnerCode,
                genre: genre,
              ),
            ),
          );
        } else {
          Navigator.of(context).push(
            fadeRoute(
              RPRoomScreen(
                sessionId: sessionId,
                partnerName: partnerName,
                partnerCode: partnerCode,
                genre: genre,
              ),
            ),
          );
        }
      } catch (_) {}
    } else if (type == 'interest' || type == 'accepted') {
      _openNotifications();
    }

    // Don't mark interest / accepted as read on tap - if we do,
    // the Accept / "Tap to choose" buttons disappear because
    // they only show when !n.read
    if (notifId.isNotEmpty && type != 'interest' && type != 'accepted') {
      FirestoreService().markNotificationRead(notifId);
    }
  }

  Future<void> _loadData() async {
    final code = _auth.currentCode;
    if (code == null) return;

    final profile = await _fs.getProfile(code);
    if (mounted) setState(() => _profile = profile);

    if (profile != null) {
      _CardState.bio = profile['bio'] as String? ?? '';
      _CardState.avatarUrl = profile['avatarUrl'] as String?;
      _CardState.writingStyle = profile['writingStyle'] as String? ?? '';
      _CardState.frequency = profile['postFrequency'] as String? ?? '';
      final tagList = profile['tags'] as List<dynamic>?;
      _CardState.tags = (tagList ?? [])
          .whereType<Map>()
          .map((t) {
            final label = t['label'] as String? ?? '';
            final color = t['color'] as int? ?? cGold.toARGB32();
            return _TagData(label, Color(color));
          })
          .where((t) => t.label.isNotEmpty)
          .toList();
      _CardState.accentColor = profile['accentColor'] != null
          ? Color(profile['accentColor'] as int)
          : cGold;
      _CardState.bgTint = profile['bgTint'] != null
          ? Color(profile['bgTint'] as int)
          : Colors.transparent;
      final bs = profile['borderStyle'] as String?;
      _CardState.borderStyle = bs != null
          ? _BorderStyle.values.firstWhere(
              (e) => e.name == bs,
              orElse: () => _BorderStyle.solid,
            )
          : _BorderStyle.solid;
      // ── TCG card frame + foil ──
      _CardState.frameSeed = profile['requestCardSeed'] as int? ?? 7;
      _CardState.frameGlow = profile['requestCardGlow'] as bool? ?? true;
      _CardState.frameOrnate = profile['requestCardOrnate'] as bool? ?? true;
      _CardState.frameDense = profile['requestCardDense'] as bool? ?? false;
      _CardState.foilEnabled = profile['requestCardFoil'] as bool? ?? true;
      _CardState.foilIntensity =
          (profile['requestCardFoilLevel'] as num?)?.toDouble() ?? 0.6;
      if (profile['isDiscoverable'] != null) {
        appSettings.setDiscoverable(profile['isDiscoverable'] as bool);
      }
    }

    await _sessionsSub?.cancel();
    _sessionsSub = _fs.mySessions().listen((sessions) async {
      if (!mounted) return;
      final blocked = await _fs.getBlockedCodes(code);
      final blockedBy = await _fs.getWhoBlockedMe(code);
      final hiddenCodes = <String>{...blocked, ...blockedBy};
      final rps = <_RPData>[];
      final brains = <_RPData>[];
      for (final s in sessions) {
        final participants = List<String>.from(s['participants'] ?? []);
        final names = Map<String, dynamic>.from(s['participantNames'] ?? {});
        final partnerCode = participants.firstWhere(
          (p) => p != code,
          orElse: () => '',
        );
        if (hiddenCodes.contains(partnerCode)) continue;
        final partnerName = names[partnerCode] as String? ?? partnerCode;
        final genre = s['genre'] as String? ?? '';
        final postCount = s['postCount'] as int? ?? 0;
        final status = s['status'] as String? ?? '';
        final sessionId = s['id'] as String? ?? '';
        final lastPostRaw = s['lastPostAt'];
        DateTime? lastPostAt;
        if (lastPostRaw is Timestamp) {
          lastPostAt = lastPostRaw.toDate();
        } else if (lastPostRaw is DateTime) {
          lastPostAt = lastPostRaw;
        }
        final item = _RPData(
          partnerName,
          partnerCode,
          genre,
          postCount,
          false,
          id: sessionId,
          lastPostAt: lastPostAt,
          status: status.isEmpty ? 'active' : status,
          title: (s['title'] as String?) ?? '',
          summary: (s['summary'] as String?) ?? '', // <-- ADD
          backgroundUrl: s['backgroundUrl'] as String?, // <-- ADD
        );
        if (status == 'brainstorm') {
          brains.add(item);
        } else {
          rps.add(item);
        }
      }
      if (mounted) {
        setState(() {
          _roleplays = rps;
          _brainstorms = brains;
          _recomputeContinue();
        });
      }
    });

    await _notifsSub?.cancel();
    _notifsSub = _fs.myNotifications().listen((notifs) {
      if (!mounted) return;
      setState(() {
        _notifications = notifs
            .map(
              (n) => _NotifData(
                n['title'] as String? ?? '',
                n['subtitle'] as String? ?? '',
                n['read'] as bool? ?? false,
                id: n['id'] as String? ?? '',
                type: n['type'] as String? ?? '',
                data: Map<String, dynamic>.from(n['data'] as Map? ?? {}),
              ),
            )
            .toList();
      });
    });
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshProfile() async {
    final code = _auth.currentCode;
    if (code == null) return;
    final profile = await _fs.getProfile(code);
    if (mounted) {
      setState(() {
        _profile = profile;
        // UPDATE THE REQUEST CARD STATE HERE
        if (profile != null) {
          _CardState.avatarUrl = profile['avatarUrl'] as String?;
          _CardState.bio = profile['bio'] as String? ?? '';
          _CardState.writingStyle = profile['writingStyle'] as String? ?? '';
          _CardState.frequency = profile['postFrequency'] as String? ?? '';
        }
      });
    }
  }

  String _humanAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${d.inDays ~/ 7}w';
  }

  Future<void> _pushPanel(String title, Widget child) {
    return Navigator.of(
      context,
    ).push(fadeRoute(_ExpansionRoute(title: title, child: child)));
  }

  void _openProfile() {
    if (_isDesktop) {
      setState(() => _activeBlock = 'profile');
      return;
    }
    _pushPanel(
      'Profile',
      _ProfileContent(profile: _profile, onRefresh: _refreshProfile),
    );
  }

  void _openNotifications() {
    if (_isDesktop) {
      setState(() => _activeBlock = 'notifications');
      return;
    }
    _pushPanel(
      'Notifications',
      _NotificationsContent(
        notifications: _notifications,
        roleplays: _roleplays,
        brainstorms: _brainstorms,
      ),
    );
  }

  void _openRoleplays() {
    if (_isDesktop) {
      setState(() => _activeBlock = 'roleplays');
      return;
    }
    _pushPanel(
      'Roleplays',
      _RoleplaysContent(
        roleplays: _roleplays,
        onEnter: (rp) => Navigator.of(context).push(
          fadeRoute(
            RPRoomScreen(
              partnerName: rp.partner,
              partnerCode: rp.partnerCode,
              genre: rp.genre,
              sessionId: rp.id,
              title: rp.title,
            ),
          ),
        ),
        onArchive: (rp) async {
          await _fs.updateSessionStatus(rp.id, 'archived');
        },
        onUnarchive: (rp) async {
          await _fs.updateSessionStatus(rp.id, 'active');
        },
        onDelete: (rp) async {
          await _fs.deleteSessionCompletely(rp.id);
        },
        onBlock: (rp) {
          showBlockDialog(
            context: context,
            partnerName: rp.partner,
            myCode: _auth.currentCode ?? '',
            partnerCode: rp.partnerCode,
            fs: _fs,
          );
        },
      ),
    );
  }

  void _openBrainstorms() {
    if (_isDesktop) {
      setState(() => _activeBlock = 'preludes');
      return;
    }
    _pushPanel(
      'Preludes',
      _BrainstormContent(
        brainstorms: _brainstorms,
        onEnter: (b) => Navigator.of(context).push(
          fadeRoute(
            BrainstormRoomScreen(
              partnerName: b.partner,
              partnerCode: b.partnerCode,
              genre: b.genre,
              sessionId: b.id,
            ),
          ),
        ),
      ),
    );
  }

  void _openRequestCard() {
    if (_isDesktop) {
      setState(() => _activeBlock = 'card');
      return;
    }
    _pushPanel('Request Card', _RequestCardContent());
  }

  void _openSettings() {
    if (_isDesktop) {
      setState(() => _activeBlock = 'settings');
      return;
    }
    _pushPanel('Settings', const _SettingsContent());
  }

  List<ProfileStat> _computeStats() {
    final visible = appSettings.visibleStatKeys;
    if (visible.isEmpty) return const [];

    final allSessions = [..._roleplays, ..._brainstorms];
    final totalPosts = allSessions.fold<int>(0, (a, b) => a + b.posts);
    final partnerCodes = allSessions
        .map((r) => r.partnerCode)
        .where((c) => c.isNotEmpty)
        .toSet();

    int daysActive = 0;
    final createdRaw = _profile?['createdAt'];
    if (createdRaw is Timestamp) {
      daysActive = DateTime.now().difference(createdRaw.toDate()).inDays + 1;
    } else if (createdRaw is DateTime) {
      daysActive = DateTime.now().difference(createdRaw).inDays + 1;
    }

    // Populated once the sandbox syncs these counters onto the user doc.
    // Until then they read 0.
    final worldsCreated = (_profile?['worldsCreated'] as int?) ?? 0;
    final charactersCreated = (_profile?['charactersCreated'] as int?) ?? 0;

    final stats = <ProfileStat>[];
    for (final key in visible) {
      switch (key) {
        case AppSettings.statActiveRPs:
          stats.add(
            ProfileStat(
              key: key,
              label: 'Active RPs',
              value: '${_roleplays.where((r) => !r.isArchived).length}',
            ),
          );
          break;
        case AppSettings.statTotalPosts:
          stats.add(
            ProfileStat(key: key, label: 'Posts', value: '$totalPosts'),
          );
          break;
        case AppSettings.statBrainstormRooms:
          stats.add(
            ProfileStat(
              key: key,
              label: 'Preludes',
              value: '${_brainstorms.length}',
            ),
          );
          break;
        case AppSettings.statWritingPartners:
          stats.add(
            ProfileStat(
              key: key,
              label: 'Partners',
              value: '${partnerCodes.length}',
            ),
          );
          break;
        case AppSettings.statDaysActive:
          stats.add(ProfileStat(key: key, label: 'Days', value: '$daysActive'));
          break;
        case AppSettings.statLastPost:
          DateTime? latest;
          for (final s in allSessions) {
            final t = s.lastPostAt;
            if (t == null) continue;
            if (latest == null || t.isAfter(latest)) latest = t;
          }
          stats.add(
            ProfileStat(
              key: key,
              label: 'Last Post',
              value: latest == null ? '—' : _humanAgo(latest),
            ),
          );
          break;
        case AppSettings.statWorldsCreated:
          stats.add(
            ProfileStat(key: key, label: 'Worlds', value: '$worldsCreated'),
          );
          break;
        case AppSettings.statCharactersCreated:
          stats.add(
            ProfileStat(
              key: key,
              label: 'Characters',
              value: '$charactersCreated',
            ),
          );
          break;
      }
    }
    return stats;
  }

  @override
  void dispose() {
    _sessionsSub?.cancel();
    _notifsSub?.cancel();
    _fcmOpenedAppSub?.cancel();
    _updateCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    appSettings.removeListener(_onSettingsChanged);
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _recomputeContinue({bool advance = false}) {
    final active = _roleplays.where((r) => !r.isArchived).toList();
    if (active.isEmpty) {
      _continueSession = null;
      return;
    }

    final mode = appSettings.continueMode;
    final preferred = appSettings.continueIds;

    // Build candidate pool depending on mode
    List<_RPData> pool;
    if (mode == AppSettings.continueModeCycleSelected && preferred.isNotEmpty) {
      pool = active.where((r) => preferred.contains(r.id)).toList();
      if (pool.isEmpty) pool = active;
    } else {
      pool = active;
    }

    // Pinned mode: straight to the pinned session
    if (mode == AppSettings.continueModePinned && preferred.isNotEmpty) {
      final match = pool.where((r) => r.id == preferred.first).toList();
      _continueSession = match.isNotEmpty ? match.first : pool.first;
      appSettings.setContinueLastShown(_continueSession!.id);
      return;
    }

    // Keep the current session if it's still valid and we're not advancing
    if (!advance &&
        _continueSession != null &&
        pool.any((r) => r.id == _continueSession!.id)) {
      return;
    }

    // Rotate: pick the session after continueLastShown
    final lastId = appSettings.continueLastShown;
    int index = 0;
    if (lastId != null) {
      final i = pool.indexWhere((r) => r.id == lastId);
      if (i != -1) index = (i + 1) % pool.length;
    }
    _continueSession = pool[index];
    appSettings.setContinueLastShown(_continueSession!.id);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final inSplitMode = isDesktop;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(1.0, -1.0),
            radius: isDesktop ? 0.8 : 1.4, // Tighter glow on big screens
            colors: [
              Color.lerp(
                appSettings.bgColor,
                appSettings.bgGlowColor,
                isDesktop ? 0.15 : 0.5,
              )!,
              appSettings.bgColor,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              children: [
                LoreTopBar(
                  onLogoTap: () {
                    if (inSplitMode) setState(() => _activeBlock = null);
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (kIsWeb)
                        LoreTap(
                          onTap: () => _showDownloadDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            margin: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: cGold.withValues(alpha: 0.3),
                              ),
                              color: cGold.withValues(alpha: 0.05),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.android, size: 14, color: cGold),
                                SizedBox(width: 6),
                                Text(
                                  'GET APP',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 9,
                                    color: cGold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: !isDesktop
                        ? KeyedSubtree(
                            key: const ValueKey('mobile'),
                            child: _buildMobileBody(),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('desktop-split'),
                            child: _buildDesktopSplitBody(),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── MOBILE BODY ─────────────────────────
  // The same layout as before, just extracted into its own method so
  // the outer build can decide what to show. Nothing inside this
  // method changed.
  Widget _buildMobileBody() {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 900 : double.infinity,
        ),
        child: Stack(
          children: [
            // 1. We wrap the whole layout in a LayoutBuilder + SingleChildScrollView
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          constraints.maxHeight, // Fill the screen if tall
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          if (isDesktop)
                            Expanded(
                              child: Center(
                                // <-- SingleChildScrollView removed here
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 24,
                                    bottom: 24,
                                  ),
                                  child: HomeProfileCard(
                                    name: _auth.currentName ?? '—',
                                    code: _auth.currentCode ?? '—',
                                    bio: _profile?['bio'] as String? ?? '',
                                    subtitle: _buildProfileSubtitle(),
                                    stats: _computeStats(),
                                    avatarUrl:
                                        _profile?['avatarUrl'] as String?,
                                    onTap: _openProfile,
                                    onLongPress: () =>
                                        ProfileStyleSheet.show(context),
                                    fillHeight:
                                        false, // Natural height on desktop!
                                  ),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: HomeProfileCard(
                                name: _auth.currentName ?? '—',
                                code: _auth.currentCode ?? '—',
                                bio: _profile?['bio'] as String? ?? '',
                                subtitle: _buildProfileSubtitle(),
                                stats: _computeStats(),
                                avatarUrl: _profile?['avatarUrl'] as String?,
                                onTap: _openProfile,
                                onLongPress: () =>
                                    ProfileStyleSheet.show(context),
                                fillHeight: true, // Fill screen on mobile
                              ),
                            ),

                          if (isDesktop) _buildDesktopContinue(),
                          if (!appSettings.showFloatingButton && !isDesktop)
                            _buildHomeBlocks(),
                          const SizedBox(height: 16),
                          // ── FLOATING BOTTOM BAR ──
                          if (!isDesktop)
                            Container(
                              constraints: const BoxConstraints(minHeight: 96),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.bottomCenter,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: HoloCardV2(
                                          accent: cSmoke,
                                          intensity: 0.35,
                                          seed: 'sandbox_btn'.hashCode,
                                          bgColor: appSettings.surfaceColor,
                                          child: LoreTap(
                                            onTap: () async {
                                              await Navigator.of(context).push(
                                                fadeRoute(
                                                  const SandboxScreen(),
                                                ),
                                              );
                                              if (mounted)
                                                await _refreshProfile();
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: appSettings.surfaceColor,
                                                border: Border.all(
                                                  color: cAsh,
                                                  width: 1.5,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.6),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 6),
                                                  ),
                                                ],
                                              ),
                                              child: const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.public_outlined,
                                                    size: 16,
                                                    color: cSmoke,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Sandbox',
                                                    style: TextStyle(
                                                      fontFamily: 'monospace',
                                                      fontSize: 11,
                                                      color: cSmoke,
                                                      letterSpacing: 1,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 90),
                                      Expanded(
                                        child: HoloCardV2(
                                          accent: cGold,
                                          intensity: 0.4,
                                          seed: 'find_btn'.hashCode,
                                          bgColor: appSettings.surfaceColor,
                                          child: LoreTap(
                                            onTap: () =>
                                                Navigator.of(context).push(
                                                  fadeRoute(
                                                    const CardDiscoveryScreen(),
                                                  ),
                                                ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: appSettings.surfaceColor,
                                                border: Border.all(
                                                  color: cGold.withValues(
                                                    alpha: 0.5,
                                                  ),
                                                  width: 1.5,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.6),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 6),
                                                  ),
                                                  BoxShadow(
                                                    color: cGold.withValues(
                                                      alpha: 0.15,
                                                    ),
                                                    blurRadius: 20,
                                                    offset: const Offset(0, 8),
                                                  ),
                                                ],
                                              ),
                                              child: const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.explore_outlined,
                                                    size: 16,
                                                    color: cGold,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Find Partners',
                                                    style: TextStyle(
                                                      fontFamily: 'monospace',
                                                      fontSize: 11,
                                                      color: cGold,
                                                      letterSpacing: 1,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    child: HoloCardV2(
                                      accent: cGold,
                                      intensity: 0.6,
                                      seed: 'diary_btn'.hashCode,
                                      bgColor: appSettings.bgColor,
                                      maxTiltDegrees: 15,
                                      child: LoreTap(
                                        onTap: () => Navigator.of(
                                          context,
                                        ).push(fadeRoute(const DiaryScreen())),
                                        child: Container(
                                          width: 82,
                                          height: 82,
                                          decoration: BoxDecoration(
                                            color: appSettings.bgColor,
                                            border: Border.all(
                                              color: cGold.withValues(
                                                alpha: 0.7,
                                              ),
                                              width: 1.5,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.8,
                                                ),
                                                blurRadius: 16,
                                                offset: const Offset(0, 8),
                                              ),
                                              BoxShadow(
                                                color: cGold.withValues(
                                                  alpha: 0.25,
                                                ),
                                                blurRadius: 30,
                                                offset: const Offset(0, 12),
                                                spreadRadius: -2,
                                              ),
                                            ],
                                          ),
                                          child: const Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.menu_book_outlined,
                                                size: 24,
                                                color: cGold,
                                              ),
                                              SizedBox(height: 6),
                                              Text(
                                                'Diary',
                                                style: TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 10,
                                                  color: cGold,
                                                  letterSpacing: 2,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            // ── DESKTOP RIGHT RAIL: Sandbox + Diary ──
            if (isDesktop)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sandbox
                      Tooltip(
                        message: 'Sandbox',
                        child: LoreTap(
                          onTap: () async {
                            await Navigator.of(
                              context,
                            ).push(fadeRoute(const SandboxScreen()));
                            if (mounted) await _refreshProfile();
                          },
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: appSettings.surfaceColor,
                              border: Border.all(color: cAsh, width: 1.5),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.public_outlined,
                                  size: 20,
                                  color: cSmoke,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Sandbox',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 8,
                                    color: cSmoke,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
// Find Partners (desktop right rail - same destination as mobile)
Tooltip(
message: 'Find Partners',
child: LoreTap(
onTap: () => Navigator.of(context).push(fadeRoute(const CardDiscoveryScreen())),
child: Container(
width: 56,
height: 56,
decoration: BoxDecoration(
color: appSettings.surfaceColor,
border: Border.all(color: cGold.withValues(alpha: 0.5), width: 1.5),
borderRadius: BorderRadius.circular(14),
boxShadow: [
BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 12, offset: const Offset(0, 6)),
],
),
child: const Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.explore_outlined, size: 20, color: cGold),
SizedBox(height: 4),
Text('Partners', style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: cGold, letterSpacing: 1)),
],
),
),
),
),
const SizedBox(height: 12),
// Diary
                      Tooltip(
                        message: 'Diary',
                        child: LoreTap(
                          onTap: () => Navigator.of(
                            context,
                          ).push(fadeRoute(const DiaryScreen())),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: appSettings.bgColor,
                              border: Border.all(
                                color: cGold.withValues(alpha: 0.7),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: cGold.withValues(alpha: 0.25),
                                  blurRadius: 30,
                                  offset: const Offset(0, 12),
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.menu_book_outlined,
                                  size: 20,
                                  color: cGold,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Diary',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 8,
                                    color: cGold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // ── THE FLOATING MENU BUTTON ──
            if (appSettings.showFloatingButton && !isDesktop)
              FloatingMenuButton(items: _buildMenuItems()),
          ],
        ),
      ),
    );
  }

  List<FloatingMenuItem> _orderedMenuItems() {
    final items = _buildMenuItems();
    // Hide hidden blocks
    final visible = items
        .where((it) => !appSettings.isBlockHidden(it.blockKey))
        .toList();
    // Order by saved homeOrder, unknown keys keep their original order at the end
    final order = appSettings.homeOrder;
    if (order.isEmpty) return visible;
    visible.sort((a, b) {
      final ia = order.indexOf(a.blockKey);
      final ib = order.indexOf(b.blockKey);
      if (ia == -1 && ib == -1) return 0;
      if (ia == -1) return 1;
      if (ib == -1) return -1;
      return ia.compareTo(ib);
    });
    return visible;
  }

  Future<void> _moveHomeBlock(int index, int delta) async {
    final visible = _orderedMenuItems();
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= visible.length) return;
    final item = visible.removeAt(index);
    visible.insert(newIndex, item);
    await appSettings.setHomeOrder(visible.map((e) => e.blockKey).toList());
    if (mounted) setState(() {});
  }

  Widget _buildDesktopContinue() {
    final active = _roleplays.where((r) => !r.isArchived).toList()
      ..sort(
        (a, b) => (b.lastPostAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.lastPostAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
    if (active.isEmpty) return const SizedBox.shrink();
    final first = active.first;
    void openRp(_RPData rp) {
      Navigator.of(context).push(
        fadeRoute(
          RPRoomScreen(
            partnerName: rp.partner,
            partnerCode: rp.partnerCode,
            genre: rp.genre,
            sessionId: rp.id,
            title: rp.title,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONTINUE',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: cGold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          LoreTap(
            onTap: () => openRp(first),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: appSettings.surfaceColor,
                border: Border.all(color: cGold.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          first.hasTitle ? first.title : first.partner,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w300,
                            fontStyle: FontStyle.italic,
                            color: cParchment,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${first.partner} - ${first.genre} - ${first.posts} posts',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            color: cSmoke,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (first.yourTurn)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: cGold),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'YOUR TURN',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          color: cGold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 16, color: cSmoke),
                ],
              ),
            ),
          ),
          for (final rp in active.skip(1).take(3))
            LoreTap(
              onTap: () => openRp(rp),
              child: Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: appSettings.surfaceColor,
                  border: Border.all(color: cAsh),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        rp.hasTitle ? rp.title : rp.partner,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: cMist,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    if (rp.yourTurn)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Text(
                          'YOUR TURN',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 8,
                            color: cGold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    Text(
                      '${rp.posts}p',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        color: cSmoke,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, size: 14, color: cSmoke),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          LoreTap(
            onTap: () =>
                Navigator.of(context).push(fadeRoute(const DiaryScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: appSettings.surfaceColor,
                border: Border.all(color: cAsh),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.menu_book_outlined, size: 16, color: cGold),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Diary',
                      style: TextStyle(
                        fontSize: 14,
                        color: cMist,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: cSmoke),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeBlocks() {
    final items = _orderedMenuItems();
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'All blocks hidden. Turn them back on in Settings > Customize layout.',
          style: TextStyle(
            fontSize: 12,
            color: cSmoke,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++)
            Container(
              key: ValueKey(items[i].blockKey),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color:
                    appSettings.styleForBlock(items[i].blockKey).background ??
                    appSettings.surfaceColor,
                border: Border.all(color: cAsh, width: 1.5),
                borderRadius: BorderRadius.circular(12),
                boxShadow:
                    appSettings.styleForBlock(items[i].blockKey).glowEnabled
                    ? [
                        BoxShadow(
                          color:
                              (appSettings
                                          .styleForBlock(items[i].blockKey)
                                          .glowColor ??
                                      cGold)
                                  .withValues(alpha: 0.35),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical:
                      appSettings.styleForBlock(items[i].blockKey).size ==
                          'small'
                      ? 8
                      : appSettings.styleForBlock(items[i].blockKey).size ==
                            'large'
                      ? 22
                      : 12,
                  horizontal: 10,
                ),
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _moveHomeBlock(i, -1),
                          child: Icon(
                            Icons.keyboard_arrow_up,
                            size: 18,
                            color: i == 0 ? cAsh : cSmoke,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _moveHomeBlock(i, 1),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: i == items.length - 1 ? cAsh : cSmoke,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      items[i].icon,
                      size:
                          appSettings.styleForBlock(items[i].blockKey).size ==
                              'small'
                          ? 14
                          : appSettings.styleForBlock(items[i].blockKey).size ==
                                'large'
                          ? 22
                          : 18,
                      color:
                          appSettings.styleForBlock(items[i].blockKey).accent ??
                          items[i].accent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LoreTap(
                        onTap: items[i].onTap,
                        onLongPress: items[i].onLongPress,
                        child: Text(
                          items[i].label,
                          style: TextStyle(
                            fontSize:
                                appSettings
                                        .styleForBlock(items[i].blockKey)
                                        .size ==
                                    'small'
                                ? 12
                                : appSettings
                                          .styleForBlock(items[i].blockKey)
                                          .size ==
                                      'large'
                                ? 16
                                : 14,
                            color: cMist,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ),
                    if (items[i].badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: cGold),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${items[i].badge}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: cGold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, size: 16, color: cSmoke),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<FloatingMenuItem> _buildMenuItems() {
    final unread = _notifications.where((n) => !n.read).length;
    return [
      FloatingMenuItem(
        blockKey: AppSettings.blockNotifications,
        label: 'Notifications',
        icon: Icons.notifications_none,
        accent: cGold,
        badge: unread,
        onTap: _openNotifications,
        onLongPress: () =>
            BlockStyleSheet.show(context, AppSettings.blockNotifications),
      ),
      FloatingMenuItem(
        blockKey: AppSettings.blockRoleplays,
        label: 'Roleplays',
        icon: Icons.auto_stories_outlined,
        accent: cGold,
        // FIX: Only count active roleplays!
        badge: _roleplays.where((r) => !r.isArchived).isEmpty
            ? null
            : _roleplays.where((r) => !r.isArchived).length,
        onTap: _openRoleplays,
        onLongPress: () =>
            BlockStyleSheet.show(context, AppSettings.blockRoleplays),
      ),
      FloatingMenuItem(
        blockKey: AppSettings.blockBrainstorms,
        label: 'Preludes',
        icon: Icons.lightbulb_outline,
        accent: cIce,
        badge: _brainstorms.isEmpty ? null : _brainstorms.length,
        onTap: _openBrainstorms,
        onLongPress: () =>
            BlockStyleSheet.show(context, AppSettings.blockBrainstorms),
      ),
      FloatingMenuItem(
        blockKey: AppSettings.blockRequestCard,
        label: 'Request Card',
        icon: Icons.credit_card_outlined,
        accent: cMist,
        onTap: _openRequestCard,
        onLongPress: () =>
            BlockStyleSheet.show(context, AppSettings.blockRequestCard),
      ),
      FloatingMenuItem(
        blockKey: AppSettings.blockSettings,
        label: 'Settings',
        icon: Icons.tune,
        accent: cSmoke,
        onTap: _openSettings,
        onLongPress: () =>
            BlockStyleSheet.show(context, AppSettings.blockSettings),
      ),
    ];
  }

  // ── DESKTOP: FULL / OVERVIEW ────────────
  // Same content as mobile, centered at a comfortable reading width
  // so a 4K monitor doesn't stretch the profile card across the whole
  // screen.
  Widget _buildDesktopFullBody() {
    return Center(child: SizedBox(width: 900, child: _buildMobileBody()));
  }

  // DESKTOP: SPLIT
  // Left sidebar (fixed width) + right content panel (expands).
  // Capped at 1280 total so it doesn't stretch across a 4K monitor.
  // Side nav 280 + content ~1000 = comfortable reading width.
  Widget _buildDesktopSplitBody() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSideNav(),
            Expanded(child: _buildContentPanel()),
          ],
        ),
      ),
    );
  }

  // The persistent left rail shown in split mode.
  Widget _buildSideNav() {
    final unread = _notifications.where((n) => !n.read).length;
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: cAsh)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Back to overview ──
            LoreTap(
              onTap: () => setState(() => _activeBlock = null),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back_ios, size: 11, color: cSmoke),
                    const SizedBox(width: 8),
                    Text(
                      'OVERVIEW',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        color: cGold,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: cAsh, height: 1),

            // ── Mini profile ──
            LoreTap(
              onTap: () => setState(() => _activeBlock = 'profile'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: _activeBlock == 'profile'
                      ? cGold.withValues(alpha: 0.06)
                      : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      color: _activeBlock == 'profile'
                          ? cGold
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: cAsh),
                        color: cVoid.withValues(alpha: 0.4),
                      ),
                      child: const Icon(Icons.person, color: cSmoke, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _auth.currentName ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              fontStyle: FontStyle.italic,
                              color: cParchment,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _auth.currentCode ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: cSmoke,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: cAsh, height: 1),

            // ── Block list ──
            _railTileOverview(),
            _railTile(
              'notifications',
              Icons.notifications_none,
              'Notifications',
              badge: unread,
            ),
            _railTile('roleplays', Icons.auto_stories_outlined, 'Roleplays'),
            _railTile('preludes', Icons.lightbulb_outline, 'Preludes'),
            _railTile('card', Icons.credit_card_outlined, 'Request Card'),
            _railTile('settings', Icons.tune, 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _railTileOverview() {
    final active = _activeBlock == null;
    return LoreTap(
      onTap: () => setState(() => _activeBlock = null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: active ? cGold.withValues(alpha: 0.06) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: active ? cGold : Colors.transparent,
              width: 2,
            ),
            bottom: const BorderSide(color: cAsh, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.home_outlined, size: 16, color: active ? cGold : cSmoke),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Overview',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: cMist,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _railTile(String key, IconData icon, String label, {int? badge}) {
    final active = _activeBlock == key;
    final showBadge = badge != null && badge > 0;
    return LoreTap(
      onTap: () => setState(() => _activeBlock = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: active ? cGold.withValues(alpha: 0.06) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: active ? cGold : Colors.transparent,
              width: 2,
            ),
            bottom: const BorderSide(color: cAsh, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: active ? cGold : cSmoke),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: active ? cGold : cMist,
                ),
              ),
            ),
            if (showBadge)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cGold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    fontSize: 9,
                    color: cVoid,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Right-hand content panel — one of these per block.
  Widget _buildContentPanel() {
    switch (_activeBlock) {
      case 'notifications':
        return _panel(
          title: 'Notifications',
          child: _NotificationsContent(
            notifications: _notifications,
            roleplays: _roleplays,
            brainstorms: _brainstorms,
          ),
        );
      case 'roleplays':
        return _panel(
          title: 'Roleplays',
          child: _RoleplaysContent(
            roleplays: _roleplays,
            onEnter: (rp) => Navigator.of(context).push(
              fadeRoute(
                RPRoomScreen(
                  partnerName: rp.partner,
                  partnerCode: rp.partnerCode,
                  genre: rp.genre,
                  sessionId: rp.id,
                  title: rp.title,
                ),
              ),
            ),
            onArchive: (rp) async {
              await _fs.updateSessionStatus(rp.id, 'archived');
            },
            onUnarchive: (rp) async {
              await _fs.updateSessionStatus(rp.id, 'active');
            },
            onBlock: (rp) {
              showBlockDialog(
                context: context,
                partnerName: rp.partner,
                myCode: _auth.currentCode ?? '',
                partnerCode: rp.partnerCode,
                fs: _fs,
              );
            },
          ),
        );
      case 'preludes':
        return _panel(
          title: 'Preludes',
          child: _BrainstormContent(
            brainstorms: _brainstorms,
            onEnter: (b) => Navigator.of(context).push(
              fadeRoute(
                BrainstormRoomScreen(
                  partnerName: b.partner,
                  partnerCode: b.partnerCode,
                  genre: b.genre,
                  sessionId: b.id,
                ),
              ),
            ),
          ),
        );
      case 'card':
        return _panel(title: 'Request Card', child: _RequestCardContent());
      case 'settings':
        return _panel(title: 'Settings', child: const _SettingsContent());
      case 'profile':
        return _panel(
          title: 'Profile',
          child: _ProfileContent(
            profile: _profile,
            onRefresh: _refreshProfile,
          ), // <--- Add onRefresh
        );
      default:
        // Desktop overview: same home blocks as mobile, inside the split panel.
        // _buildMobileBody() already caps itself at 900 on desktop.
        return _buildMobileBody();
    }
  }

  // Shared chrome for every content panel: a title bar with a close
  // button, then the scrollable content underneath.
  Widget _panel({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: cAsh)),
          ),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                  color: cParchment,
                ),
              ),
              const Spacer(),
              LoreTap(
                onTap: () => setState(() => _activeBlock = null),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 18, color: cSmoke),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showDownloadDialog(BuildContext context) {
    // ⚠️ REPLACE THIS URL WITH YOUR ACTUAL GITHUB RELEASE APK LINK! ⚠️
    const String apkUrl =
        'https://github.com/VengefulRat/flutter_ex/releases/download/v8.4.5/flutter_ex-releases.apk';
    // REPLACE WITH YOUR ACTUAL GITHUB RELEASE WINDOWS ZIP LINK WHEN YOU TAG!
    const String windowsUrl =
        'https://github.com/VengefulRat/flutter_ex/releases/download/v8.4.5/LoreEx-Setup.exe';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cInk,
        shape: const RoundedRectangleBorder(),
        child: SingleChildScrollView(
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
                const Divider(color: cAsh, height: 1),
                const SizedBox(height: 16),
                const Text(
                  'WINDOWS PC',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cGold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Get Lore on your PC. Share this link to yourself, then open it on your PC to download.',
                  style: TextStyle(
                    fontSize: 13,
                    color: cMist,
                    fontStyle: FontStyle.italic,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.white,
                    child: QrImageView(data: windowsUrl, size: 120),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await Clipboard.setData(
                            const ClipboardData(text: windowsUrl),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: cInk,
                                content: Text(
                                  'PC link copied.',
                                  style: TextStyle(color: cGold),
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: cAsh),
                          ),
                          child: const Center(
                            child: Text(
                              'Copy PC link',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                color: cMist,
                                letterSpacing: 1,
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
                          await SharePlus.instance.share(
                            ShareParams(
                              text: 'Download Lore for Windows PC: $windowsUrl',
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          color: cParchment,
                          child: const Center(
                            child: Text(
                              'Share to yourself',
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
                const SizedBox(height: 12),
                const Text(
                  'HOW TO INSTALL ON PC:\n1. Share / Copy this link to yourself (email / WhatsApp).\n2. Open it on your PC.\n3. Download LoreEx-Setup.exe and run it. It installs to Program Files and updates in place.',
                  style: TextStyle(
                    fontSize: 12,
                    color: cParchment,
                    height: 1.6,
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
      ),
    );
  }
}

// ════════════════════════════════════════
// SETTINGS CONTENT
// ════════════════════════════════════════
class _SettingsContent extends StatefulWidget {
  const _SettingsContent();
  @override
  State<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<_SettingsContent> {
  final _auth = AuthService();
  Future<void> _confirmSignOutOthers() async {
    final confirm = await showDialog<bool>(
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
                'SIGN OUT OTHER DEVICES',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: cGold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This ends every other session on your account. The device '
                'you\'re on now stays signed in.\n\n'
                'Use this if you signed in on a phone you no longer have, '
                'or if your phone was stolen.',
                style: TextStyle(
                  fontSize: 13,
                  color: cMist,
                  fontStyle: FontStyle.italic,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: LoreTap(
                      onTap: () => Navigator.pop(ctx, false),
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
                    child: LoreTap(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: cGold.withValues(alpha: 0.85),
                        child: const Center(
                          child: Text(
                            'Sign out others',
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
    if (confirm != true) return;
    await _auth.signOutOtherDevices();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: cInk,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(),
        content: Text(
          'All other sessions ended.',
          style: TextStyle(color: cParchment),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appSettings.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _launchDonationPage() async {
    final Uri url = Uri.parse('https://ko-fi.com/loretherpapp');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: cInk,
          content: Text(
            'Could not open the donation page.',
            style: TextStyle(color: cParchment),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Home screen glow ──
        // Long-press the header to toggle developer tools. Nothing else
        // in the UI reveals the gesture — the dev section appears above
        // the fold once you know it's there.
        GestureDetector(
          onLongPress: () async {
            await appSettings.setDevModeUnlocked(!appSettings.devModeUnlocked);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: cInk,
                behavior: SnackBarBehavior.floating,
                shape: const RoundedRectangleBorder(),
                content: Text(
                  appSettings.devModeUnlocked
                      ? 'Developer tools unlocked'
                      : 'Developer tools hidden',
                  style: const TextStyle(color: cParchment),
                ),
              ),
            );
          },
          child: const Text(
            'HOME GLOW',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: cGold,
              letterSpacing: 3,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'The soft light in the corner of your home screen.',
          style: TextStyle(
            fontSize: 12,
            color: cSmoke,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            LoreTap(
              onTap: () => LoreColourPicker.show(
                context,
                current: appSettings.bgGlowColor,
                onPicked: (c) async => appSettings.setBgGlowColor(c),
              ),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: appSettings.bgGlowColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(1.0, -1.0),
                    radius: 1.4,
                    colors: [
                      Color.lerp(
                        appSettings.bgColor,
                        appSettings.bgGlowColor,
                        0.5,
                      )!,
                      appSettings.bgColor,
                    ],
                  ),
                  border: Border.all(color: cAsh),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(color: cAsh),
        const SizedBox(height: 16),

        // ── Customize ──
        const Text(
          'CUSTOMIZE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        LoreTap(
          onTap: () =>
              Navigator.of(context).push(fadeRoute(const CustomizeScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: cInk,
              border: Border.all(color: cAsh),
            ),
            child: Row(
              children: const [
                Icon(Icons.palette_outlined, size: 16, color: cSmoke),
                SizedBox(width: 12),
                Text(
                  'Customize layout',
                  style: TextStyle(
                    fontSize: 14,
                    color: cMist,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Spacer(),
                Icon(Icons.chevron_right, size: 16, color: cSmoke),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(color: cAsh),
        const SizedBox(height: 16),

        // ── Reference ──
        const Text(
          'REFERENCE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        LoreTap(
          onTap: () =>
              Navigator.of(context).push(fadeRoute(const GesturesScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: cInk,
              border: Border.all(color: cAsh),
            ),
            child: Row(
              children: const [
                Icon(Icons.touch_app_outlined, size: 16, color: cSmoke),
                SizedBox(width: 12),
                Text(
                  'Gestures & Shortcuts',
                  style: TextStyle(
                    fontSize: 14,
                    color: cMist,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Spacer(),
                Icon(Icons.chevron_right, size: 16, color: cSmoke),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        const Divider(color: cAsh),
        const SizedBox(height: 16),

        // ── Security ──
        const Text(
          'SECURITY',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        LoreTap(
          onTap: () => Navigator.of(
            context,
          ).push(fadeRoute(LockSetupScreen(isFirstTime: false))),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: cInk,
              border: Border.all(color: cAsh),
            ),
            child: Row(
              children: const [
                Icon(Icons.lock_outline, size: 16, color: cSmoke),
                SizedBox(width: 12),
                Text(
                  'PIN & Lock screen',
                  style: TextStyle(
                    fontSize: 14,
                    color: cMist,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Spacer(),
                Icon(Icons.chevron_right, size: 16, color: cSmoke),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        LoreTap(
          onTap: () =>
              Navigator.of(context).push(fadeRoute(const QRScannerScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: cInk,
              border: Border.all(color: cAsh),
            ),
            child: Row(
              children: const [
                Icon(Icons.qr_code_scanner, size: 16, color: cSmoke),
                SizedBox(width: 12),
                Text(
                  'Link Desktop (Web)',
                  style: TextStyle(
                    fontSize: 14,
                    color: cMist,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Spacer(),
                Icon(Icons.chevron_right, size: 16, color: cSmoke),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        LoreTap(
          onTap: _confirmSignOutOthers,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: cInk,
              border: Border.all(color: cAsh),
            ),
            child: Row(
              children: const [
                Icon(Icons.logout, size: 16, color: cSmoke),
                SizedBox(width: 12),
                Text(
                  'Sign out other devices',
                  style: TextStyle(
                    fontSize: 14,
                    color: cMist,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Spacer(),
                Icon(Icons.chevron_right, size: 16, color: cSmoke),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        const Divider(color: cAsh),
        const SizedBox(height: 16),

        // ── Appearance ──

        // ── Appearance ──
        const Text(
          'APPEARANCE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        _settingsToggle(
          'Card border effects',
          'Animated glows on discovery cards',
          appSettings.cardBorderEffects,
          (v) => appSettings.setCardBorderEffects(v),
        ),
        const SizedBox(height: 14),
        _settingsSegment(
          'Text size',
          ['Small', 'Medium', 'Large'],
          appSettings.textSize,
          (v) => appSettings.setTextSize(v),
        ),
        const SizedBox(height: 14),
        _settingsSegment(
          'Orientation',
          ['Portrait', 'Landscape', 'Both'],
          appSettings.orientation,
          (v) => appSettings.setOrientation(v),
        ),

        const SizedBox(height: 24),
        const Divider(color: cAsh),
        const SizedBox(height: 16),

        // ── Ambience ──
        const Text(
          'AMBIENCE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Lore reads the mood of your story and shifts the scene around it.',
          style: TextStyle(
            fontSize: 12,
            color: cSmoke,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        _settingsToggle(
          'Mood generator',
          'Shifts the background based on what you write',
          appSettings.aiMood,
          (v) => appSettings.setAiMood(v),
        ),

        const SizedBox(height: 24),
        const Divider(color: cAsh),
        const SizedBox(height: 16),

        // ── Notifications ──
        const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        _settingsToggle(
          'New post from partner',
          '',
          appSettings.notifNewPost,
          (v) => appSettings.setNotifNewPost(v),
        ),
        const SizedBox(height: 12),
        _settingsToggle(
          'New interest received',
          '',
          appSettings.notifInterest,
          (v) => appSettings.setNotifInterest(v),
        ),

        _settingsToggle(
          'Roleplay replies',
          'When your partner posts in an RP',
          appSettings.notifRpPost,
          (v) => appSettings.setNotifRpPost(v),
        ),
        const SizedBox(height: 12),
        _settingsToggle(
          'OOC messages',
          'Chat messages and media',
          appSettings.notifOoc,
          (v) => appSettings.setNotifOoc(v),
        ),
        const SizedBox(height: 12),
        _settingsToggle(
          'Prelude messages',
          'When your partner messages in a prelude',
          appSettings.notifBrainstorm,
          (v) => appSettings.setNotifBrainstorm(v),
        ),

        const SizedBox(height: 24),
        const Divider(color: cAsh),
        const SizedBox(height: 16),

        // ── RP Room ──
        const Text(
          'RP ROOM',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        _settingsToggle(
          'Auto-scroll to latest post',
          'On opening a room',
          appSettings.autoScroll,
          (v) => appSettings.setAutoScroll(v),
        ),
        const SizedBox(height: 14),
        _settingsSegment(
          'OOC bubble side',
          ['Left', 'Right'],
          appSettings.oocSide,
          (v) => appSettings.setOocSide(v),
        ),
        const SizedBox(height: 12),
        _settingsToggle(
          'Enter key behaviour',
          appSettings.enterToSend
              ? 'Press Enter to send, Shift+Enter for new line'
              : 'Press Shift+Enter to send, Enter for new line',
          appSettings.enterToSend,
          (v) => appSettings.setEnterToSend(v),
        ),

        const SizedBox(height: 24),
        const Divider(color: cAsh),
        const SizedBox(height: 16),

        // ── Sounds ──
        const Text(
          'SOUNDS',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        _settingsToggle(
          'App sounds',
          '',
          appSettings.soundEnabled,
          (v) => appSettings.setSoundEnabled(v),
        ),
        const SizedBox(height: 12),
        const _SoundSettings(),

        if (appSettings.devModeUnlocked) ...[
          const SizedBox(height: 24),
          const Divider(color: cAsh),
          const SizedBox(height: 16),
          const Text(
            'DEVELOPER',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: cEmber,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tools for testing Lore alone.',
            style: TextStyle(
              fontSize: 12,
              color: cSmoke,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),
          LoreTap(
            onTap: () async {
              final rpDemo = await DevTools.ensureDemoSession(status: 'active');
              final preludeDemo = await DevTools.ensureDemoSession(
                status: 'brainstorm',
              );
              if (rpDemo == null || preludeDemo == null) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: cInk,
                    content: Text(
                      'Could not create demo session. Have you set a PIN yet?',
                      style: TextStyle(color: cParchment),
                    ),
                  ),
                );
                return;
              }
              // Push RP first, then prelude on top of it —
              // so both rooms are open. Back from prelude lands in RP.
              Navigator.of(context).push(
                fadeRoute(
                  RPRoomScreen(
                    partnerName: rpDemo.partnerName,
                    partnerCode: rpDemo.partnerCode,
                    genre: rpDemo.genre,
                    sessionId: rpDemo.sessionId,
                  ),
                ),
              );
              Navigator.of(context).push(
                fadeRoute(
                  BrainstormRoomScreen(
                    partnerName: preludeDemo.partnerName,
                    partnerCode: preludeDemo.partnerCode,
                    genre: preludeDemo.genre,
                    sessionId: preludeDemo.sessionId,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              decoration: BoxDecoration(
                color: cInk,
                border: Border.all(color: cAsh),
              ),
              child: const Row(
                children: [
                  Icon(Icons.developer_mode, size: 16, color: cEmber),
                  SizedBox(width: 12),
                  Text(
                    'Open demo rooms',
                    style: TextStyle(
                      fontSize: 14,
                      color: cMist,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right, size: 16, color: cSmoke),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
          LoreTap(
            onTap: () async {
              await DevTools.clearDemoData();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: cInk,
                  content: Text(
                    'Demo data cleared',
                    style: TextStyle(color: cParchment),
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              decoration: BoxDecoration(
                color: cInk,
                border: Border.all(color: cAsh),
              ),
              child: const Row(
                children: [
                  Icon(Icons.delete_outline, size: 16, color: cSmoke),
                  SizedBox(width: 12),
                  Text(
                    'Clear demo data',
                    style: TextStyle(
                      fontSize: 14,
                      color: cSmoke,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right, size: 16, color: cSmoke),
                ],
              ),
            ),
          ),
        ], // ← This closes the devModeUnlocked if-spread
        // ── Support Section ──
        const SizedBox(height: 24),
        const Divider(color: cAsh),
        const SizedBox(height: 16),

        const Text(
          'SUPPORT',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Lore is ad-free and always will be. If you love the app and want to help cover the server costs, you can buy me a coffee.',
          style: TextStyle(
            fontSize: 12,
            color: cSmoke,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        LoreTap(
          onTap: _launchDonationPage,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: cInk,
              border: Border.all(color: cAsh),
            ),
            child: Row(
              children: const [
                Icon(Icons.favorite_outline, size: 16, color: cEmber),
                SizedBox(width: 12),
                Text(
                  'Donate to Lore',
                  style: TextStyle(
                    fontSize: 14,
                    color: cMist,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Spacer(),
                Icon(Icons.open_in_new, size: 14, color: cSmoke),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ─────────────────────
      ],
    ), // ← This correctly closes the Column's children list
  ); // ← This correctly closes the Padding
}

Widget _settingsToggle(
  String label,
  String subtitle,
  bool value,
  ValueChanged<bool> onChanged,
) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: cMist,
              fontWeight: FontWeight.w300,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: cSmoke,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    ),
    const SizedBox(width: 12),
    Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: cGold,
      inactiveTrackColor: cAsh,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  ],
);

Widget _settingsSegment(
  String label,
  List<String> options,
  String current,
  ValueChanged<String> onChanged,
) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        color: cMist,
        fontWeight: FontWeight.w300,
      ),
    ),
    const SizedBox(height: 8),
    Row(
      children: options.map((o) {
        final active = current == o;
        return LoreTap(
          onTap: () => onChanged(o),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: active ? cGold : cAsh),
              color: active ? cGold.withValues(alpha: 0.1) : Colors.transparent,
            ),
            child: Text(
              o,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                letterSpacing: 1,
                color: active ? cGold : cSmoke,
              ),
            ),
          ),
        );
      }).toList(),
    ),
  ],
);

// ════════════════════════════════════════
// ════════════════════════════════════════
class _CardData {
  final String code, name, genre, seeking, writingStyle, frequency, ageRating;
  final bool isOpen;
  final List<String> extraTags;
  final Color accentColor;
  final Color bgTint;
  final int frameSeed;
  final bool frameGlow, frameOrnate, frameDense;
  final bool foilEnabled;
  final double foilIntensity;
  final String? avatarUrl;
  const _CardData({
    required this.code,
    required this.name,
    required this.genre,
    required this.seeking,
    required this.writingStyle,
    required this.frequency,
    required this.ageRating,
    required this.isOpen,
    this.extraTags = const [],
    this.accentColor = cGold,
    this.bgTint = Colors.transparent,
    this.frameSeed = 7,
    this.frameGlow = true,
    this.frameOrnate = true,
    this.frameDense = false,
    this.foilEnabled = true,
    this.foilIntensity = 0.6,
    this.avatarUrl,
  });
}

_CardData _cardFromFirestore(Map<String, dynamic> d) {
  final tags = (d['tags'] as List<dynamic>? ?? [])
      .map((t) => t['label'] as String? ?? '')
      .toList();
  final code = d['code'] as String? ?? '';

  return _CardData(
    code: code,
    name:
        d['displayNameOriginal'] as String? ??
        d['displayName'] as String? ??
        '?',
    genre: tags.isNotEmpty ? tags.first : 'Freeform',
    seeking: d['bio'] as String? ?? '',
    writingStyle: d['writingStyle'] as String? ?? '',
    frequency: d['postFrequency'] as String? ?? '',
    ageRating: tags.any((t) => t == '18+')
        ? '18+'
        : tags.any((t) => t == '16+')
        ? '16+'
        : 'All ages',
    isOpen: d['isDiscoverable'] as bool? ?? false,
    accentColor: d['accentColor'] != null
        ? Color(d['accentColor'] as int)
        : cGold,
    bgTint: d['bgTint'] != null
        ? Color(d['bgTint'] as int)
        : Colors.transparent,
    extraTags: tags,
    frameSeed: d['requestCardSeed'] as int? ?? code.hashCode,
    frameGlow: d['requestCardGlow'] as bool? ?? true,
    frameOrnate: d['requestCardOrnate'] as bool? ?? true,
    frameDense: d['requestCardDense'] as bool? ?? false,
    foilEnabled: d['requestCardFoil'] as bool? ?? true,
    foilIntensity: (d['requestCardFoilLevel'] as num?)?.toDouble() ?? 0.6,
    avatarUrl: d['avatarUrl'] as String?, // <--- Now it parses cleanly
  );
}

const _allGenres = [
  'All',
  'Fantasy',
  'Sci-Fi',
  'Modern',
  'Historical',
  'Horror',
  'Romance',
  'Post-Apocalyptic',
  'Freeform',
];
const _allAges = ['All', 'All ages', '16+', '18+'];

class CardDiscoveryScreen extends StatefulWidget {
  const CardDiscoveryScreen({super.key});
  @override
  State<CardDiscoveryScreen> createState() => _CardDiscoveryScreenState();
}

class _CardDiscoveryScreenState extends State<CardDiscoveryScreen> {
  String _genre = 'All';
  String _age = 'All';
  String _search = '';
  final _searchCtrl = TextEditingController();
  final _fs = FirestoreService();
  final _auth = AuthService();

  List<_CardData> _allCards = [];
  Set<String> _hiddenCodes = {}; // blocked by me + blocked me
  bool _loading = true;
  late PageController _pageController;
  int _currentIndex = 0;

  void _resetPage() {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) _pageController.jumpToPage(0);
      });
    }
  }

  List<_CardData> get _filtered => _allCards.where((c) {
    if (_hiddenCodes.contains(c.code)) return false;
    final genreOk = _genre == 'All' || c.genre == _genre;
    final ageOk = _age == 'All' || c.ageRating == _age;
    final searchOk =
        _search.isEmpty ||
        c.name.toLowerCase().contains(_search.toLowerCase()) ||
        c.genre.toLowerCase().contains(_search.toLowerCase()) ||
        c.seeking.toLowerCase().contains(_search.toLowerCase());
    return genreOk && ageOk && searchOk;
  }).toList();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.88,
    ); // Shows a sliver of the next card
    appSettings.addListener(_onSettingsChanged);
    _loadAndListen();
  }

  Future<void> _loadAndListen() async {
    final myCode = _auth.currentCode ?? '';
    if (myCode.isNotEmpty) {
      final blocked = await _fs.getBlockedCodes(myCode);
      final blockedBy = await _fs.getWhoBlockedMe(myCode);
      if (mounted) setState(() => _hiddenCodes = {...blocked, ...blockedBy});
    }
    _fs.discoverableUsers().listen((users) {
      if (!mounted) return;
      setState(() {
        _allCards = users.map(_cardFromFirestore).toList();
        _loading = false;
      });
    });
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    appSettings.removeListener(_onSettingsChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openCardSheet(_CardData card) {
    RequestCardSheet.show(
      context,
      card: RequestCardView(
        name: card.name,
        code: card.code,
        genre: card.genre,
        bio: card.seeking,
        writingStyle: card.writingStyle,
        frequency: card.frequency,
        ageRating: card.ageRating,
        isOpen: card.isOpen,
        tags: card.extraTags,
        accent: card.accentColor,
        bgTint: card.bgTint,
        frame: CardFrameSpec(
          seed: card.frameSeed,
          accent: card.accentColor,
          glow: card.frameGlow,
          ornate: card.frameOrnate,
          dense: card.frameDense,
        ),
        foilEnabled: card.foilEnabled,
        foilSeed: card.frameSeed,
        foilIntensity: card.foilIntensity,
      ),
      canSendInterest: card.isOpen,
      onSendInterest: () => _showInterestDialog(card),
    );
  }

  void _showInterestDialog(_CardData card) {
    final msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: cInk,
        shape: const RoundedRectangleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send interest to ${card.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                  color: cParchment,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Write a short message about what kind of story you have in mind.',
                style: TextStyle(
                  fontSize: 12,
                  color: cSmoke,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: msgCtrl,
                maxLines: 4,
                style: const TextStyle(
                  fontSize: 13,
                  color: cParchment,
                  fontStyle: FontStyle.italic,
                ),
                decoration: const InputDecoration(
                  hintText: 'I had an idea about...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: cSmoke,
                    fontStyle: FontStyle.italic,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: cAsh),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: cSmoke),
                  ),
                  filled: false,
                ),
                cursorColor: cGold,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: LoreTap(
                      onTap: () => Navigator.of(context).pop(),
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
                              fontSize: 10,
                              color: cSmoke,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LoreTap(
                      onTap: () async {
                        Navigator.of(context).pop();
                        await FirestoreService().sendInterest(
                          toCode: card.code,
                          message: msgCtrl.text.trim(),
                          genre: card.genre,
                        );
                        sounds.play(SoundKey.interestSent);
                        if (context.mounted) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: cInk,
                              behavior: SnackBarBehavior.floating,
                              shape: const RoundedRectangleBorder(),
                              content: Text(
                                'Interest sent to ${card.name}',
                                style: const TextStyle(
                                  color: cParchment,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: cParchment,
                        child: const Center(
                          child: Text(
                            'Send',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: cVoid,
                              letterSpacing: 2,
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: appSettings.bgColor,
    body: SafeArea(
      child: Column(
        children: [
          LoreTopBar(
            onLogoTap: () => Navigator.of(
              context,
            ).pushAndRemoveUntil(fadeRoute(const HomeScreen()), (_) => false),
            trailing: LoreTap(
              onTap: () => Navigator.of(context).pop(),
              child: const Text(
                '← Home',
                style: TextStyle(fontSize: 11, color: cSmoke, letterSpacing: 1),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                setState(() => _search = v);
                _resetPage();
              },
              style: const TextStyle(fontSize: 14, color: cParchment),
              decoration: InputDecoration(
                hintText: 'Search by name, genre or keywords...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: cSmoke,
                  fontStyle: FontStyle.italic,
                ),
                prefixIcon: const Icon(Icons.search, color: cSmoke, size: 18),
                suffixIcon: _search.isNotEmpty
                    ? LoreTap(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                          _resetPage();
                        },
                        child: const Icon(Icons.close, color: cSmoke, size: 16),
                      )
                    : null,
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: cAsh),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: cSmoke),
                ),
                filled: true,
                fillColor: cInk,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              cursorColor: cGold,
            ),
          ),
          _FilterRow(
            options: _allGenres,
            selected: _genre,
            onSelect: (v) {
              setState(() => _genre = v);
              _resetPage();
            },
          ),
          _FilterRow(
            options: _allAges,
            selected: _age,
            accentColor: cEmber,
            onSelect: (v) {
              setState(() => _age = v);
              _resetPage();
            },
          ),
          const SizedBox(height: 12),

          // ── THE SWIPEABLE CARD DECK ──
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: cGold,
                      strokeWidth: 1,
                    ),
                  )
                : _filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No cards found.',
                      style: TextStyle(
                        fontSize: 14,
                        color: cSmoke,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : MediaQuery.sizeOf(context).width >= 900
                ? GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 340, // Max width of a card
                          childAspectRatio: 5 / 7, // Keeps the TCG ratio
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                        ),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      return _DiscoveryCard(
                        key: ValueKey(_filtered[i].code),
                        data: _filtered[i],
                        onTap: () => _openCardSheet(_filtered[i]),
                      );
                    },
                  )
                : PageView.builder(
                    controller: _pageController,
                    itemCount: _filtered.length,
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    itemBuilder: (_, i) {
                      return Center(
                        child: _DiscoveryCard(
                          key: ValueKey('${_filtered[i].code}_$i'),
                          data: _filtered[i],
                          onTap: () => _openCardSheet(_filtered[i]),
                        ),
                      );
                    },
                  ),
          ),
          // A small minimalist indicator at the bottom instead of the big slider
          if (!_loading && _filtered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 8),
              child: Text(
                'CARD ${_currentIndex + 1} OF ${_filtered.length}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: cSmoke,
                  letterSpacing: 3,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _FilterRow extends StatelessWidget {
  final List<String> options;
  final String selected;
  final Color accentColor;
  final ValueChanged<String> onSelect;
  const _FilterRow({
    required this.options,
    required this.selected,
    required this.onSelect,
    this.accentColor = cGold,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: ScrollConfiguration(
      behavior: NoGlowBehavior(),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        itemBuilder: (_, i) {
          final opt = options[i];
          final active = opt == selected;
          return LoreTap(
            onTap: () => onSelect(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: active
                    ? accentColor.withValues(alpha: 0.12)
                    : Colors.transparent,
                border: Border.all(color: active ? accentColor : cAsh),
              ),
              child: Center(
                child: Text(
                  opt,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: active ? accentColor : cSmoke,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _DiscoveryCard extends StatelessWidget {
  final _CardData data;
  final VoidCallback onTap;

  const _DiscoveryCard({super.key, required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Center(
          // FittedBox automatically scales the card down if the screen is too short (landscape)
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 320,
              height: 448, // 5:7 ratio
              child: HoloCardV2(
                accent: data.accentColor,
                intensity: 0.4,
                seed: data.frameSeed,
                gyroEnabled: false,
                child: RequestCardView(
                  name: data.name,
                  code: data.code,
                  genre: data.genre,
                  bio: data.seeking,
                  writingStyle: data.writingStyle,
                  frequency: data.frequency,
                  ageRating: data.ageRating,
                  isOpen: data.isOpen,
                  tags: data.extraTags,
                  accent: data.accentColor,
                  bgTint: data.bgTint,
                  avatarUrl: data.avatarUrl,
                  frame: CardFrameSpec(
                    seed: data.frameSeed,
                    accent: data.accentColor,
                    glow: data.frameGlow,
                    ornate: data.frameOrnate,
                    dense: data.frameDense,
                  ),
                  foilEnabled: data.foilEnabled,
                  foilSeed: data.frameSeed,
                  foilIntensity: data.foilIntensity,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── STRIP CONTENTS ──
class _ProfileContent extends StatefulWidget {
  final Map<String, dynamic>? profile;
  const _ProfileContent({this.profile, this.onRefresh});
  final VoidCallback? onRefresh;
  @override
  State<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<_ProfileContent> {
  bool _statsExpanded = false;
  final _auth = AuthService();
  final _fs = FirestoreService();
  late TextEditingController _bioCtrl;
  bool _editingBio = false;
  bool _codeRevealed = false;
  Uint8List? _localAvatarBytes;
  String? _localAvatarUrl;

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final bytes = await image.readAsBytes();

    // 1. Show locally immediately
    setState(() => _localAvatarBytes = bytes);

    if (!mounted) return;

    // 2. SHOW THE WAITER (Blocking Modal)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: cGold, strokeWidth: 2),
              SizedBox(height: 16),
              Text(
                'Uploading image...',
                style: TextStyle(
                  color: cParchment,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final ref = FirebaseStorage.instance.ref().child(
        'avatars/${_auth.currentCode}.jpg',
      );
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();

      final freshUrl = '$url?v=${DateTime.now().millisecondsSinceEpoch}';
      await NetworkImage(url).evict();

      await _fs.updateProfile({'avatarUrl': freshUrl});

      if (mounted) {
        widget.onRefresh?.call();

        // 3. CLOSE THE WAITER
        Navigator.of(context, rootNavigator: true).pop();

        // 4. UPDATE LOCAL STATE (This is where freshUrl belongs)
        setState(() {
          _localAvatarBytes = null;
          _localAvatarUrl = freshUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: cInk,
            content: Text(
              'Profile picture updated!',
              style: TextStyle(color: cGold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // CLOSE THE WAITER ON ERROR TOO
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cInk,
            content: Text('Upload failed: $e', style: TextStyle(color: cEmber)),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final bio = widget.profile?['bio'] as String? ?? '';
    _bioCtrl = TextEditingController(text: bio);
    appSettings.addListener(_onSettingsChanged);
  }

  @override
  void didUpdateWidget(_ProfileContent old) {
    super.didUpdateWidget(old);
    if (old.profile != widget.profile && !_editingBio) {
      _bioCtrl.text = widget.profile?['bio'] as String? ?? '';
    }
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _saveBio() async {
    await _fs.updateProfile({'bio': _bioCtrl.text.trim()});
    widget.onRefresh?.call();
    setState(() => _editingBio = false);
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name =
        widget.profile?['displayNameOriginal'] as String? ??
        _auth.currentName ??
        '—';
    final code = _auth.currentCode ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Avatar + name ──
        Row(
          children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cAsh),
                  image: _localAvatarBytes != null
                      ? DecorationImage(
                          image: MemoryImage(_localAvatarBytes!),
                          fit: BoxFit.cover,
                        )
                      : _localAvatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_localAvatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : (widget.profile?['avatarUrl'] != null
                            ? DecorationImage(
                                image: NetworkImage(
                                  widget.profile!['avatarUrl'],
                                ),
                                fit: BoxFit.cover,
                              )
                            : null),
                ),
                child:
                    _localAvatarBytes == null &&
                        widget.profile?['avatarUrl'] == null
                    ? const Icon(Icons.person, color: cSmoke, size: 28)
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                    fontStyle: FontStyle.italic,
                    color:
                        appSettings.textColourFor('profile_name') ?? cParchment,
                  ),
                ),
                const SizedBox(height: 4),
                _codeRevealed
                    ? Row(
                        children: [
                          Text(
                            code,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color:
                                  appSettings.textColourFor('profile_code') ??
                                  cGold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          LoreTap(
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => Dialog(
                                  backgroundColor: cInk,
                                  shape: const RoundedRectangleBorder(),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'COPY UNIQUE CODE',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 9,
                                            color: cEmber,
                                            letterSpacing: 4,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Only do this if you are transferring to a new device.\n\nNever give your unique code to anyone else — it is your permanent identity and cannot be changed.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: cMist,
                                            height: 1.7,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: LoreTap(
                                                onTap: () => Navigator.of(
                                                  ctx,
                                                ).pop(false),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: cAsh,
                                                    ),
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
                                              child: LoreTap(
                                                onTap: () =>
                                                    Navigator.of(ctx).pop(true),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                      ),
                                                  color: cEmber.withValues(
                                                    alpha: 0.8,
                                                  ),
                                                  child: const Center(
                                                    child: Text(
                                                      'Copy anyway',
                                                      style: TextStyle(
                                                        fontFamily: 'monospace',
                                                        fontSize: 9,
                                                        color: cParchment,
                                                        letterSpacing: 2,
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
                              if (confirm == true && context.mounted) {
                                final messenger = ScaffoldMessenger.of(context);
                                await Clipboard.setData(
                                  ClipboardData(text: code),
                                );
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    backgroundColor: cInk,
                                    behavior: SnackBarBehavior.floating,
                                    shape: const RoundedRectangleBorder(),
                                    content: const Text(
                                      'Unique code copied. Guard it carefully.',
                                      style: TextStyle(
                                        color: cParchment,
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                            child: const Icon(
                              Icons.copy,
                              size: 13,
                              color: cSmoke,
                            ),
                          ),
                          const SizedBox(width: 8),
                          LoreTap(
                            onTap: () => setState(() => _codeRevealed = false),
                            child: const Icon(
                              Icons.visibility_off,
                              size: 13,
                              color: cSmoke,
                            ),
                          ),
                        ],
                      )
                    : LoreTap(
                        onTap: () async {
                          final confirm = await showDialog<bool>(
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
                                      'UNIQUE CODE',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 9,
                                        color: cGold,
                                        letterSpacing: 4,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'This is your permanent identity on Lore. It cannot be changed or recovered.\n\nNever share it with anyone. It is only needed if you transfer to a new device.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: cMist,
                                        height: 1.7,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: LoreTap(
                                            onTap: () =>
                                                Navigator.of(ctx).pop(false),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
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
                                          child: LoreTap(
                                            onTap: () =>
                                                Navigator.of(ctx).pop(true),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              color: cGold.withValues(
                                                alpha: 0.15,
                                              ),
                                              child: const Center(
                                                child: Text(
                                                  'Reveal',
                                                  style: TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: 9,
                                                    color: cGold,
                                                    letterSpacing: 2,
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
                          if (confirm == true) {
                            setState(() => _codeRevealed = true);
                          }
                        },
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              size: 11,
                              color: cSmoke,
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'UNIQUE CODE — tap to reveal',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: cSmoke,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Bio ──
        _sectionLabel('BIO'),
        const SizedBox(height: 8),
        _editingBio
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _bioCtrl,
                    maxLines: 4,
                    style: TextStyle(
                      fontSize: appSettings.baseFontSize,
                      color: cMist,
                      fontStyle: FontStyle.italic,
                      height: 1.7,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cInk,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: const BorderSide(color: cGold),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: cGold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LoreTap(
                        onTap: () => setState(() => _editingBio = false),
                        child: const Text(
                          'cancel',
                          style: TextStyle(
                            fontSize: 11,
                            color: cSmoke,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      LoreTap(
                        onTap: _saveBio,
                        child: const Text(
                          'save',
                          style: TextStyle(
                            fontSize: 11,
                            color: cGold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : LoreTap(
                onTap: () => setState(() => _editingBio = true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: cAsh)),
                  child: Text(
                    _bioCtrl.text.isEmpty
                        ? 'Tap to add a bio...'
                        : _bioCtrl.text,
                    style: TextStyle(
                      fontSize: appSettings.baseFontSize,
                      color: _bioCtrl.text.isEmpty
                          ? cSmoke
                          : (appSettings.textColourFor('profile_bio') ?? cMist),
                      fontStyle: FontStyle.italic,
                      height: 1.7,
                    ),
                  ),
                ),
              ),

        const SizedBox(height: 24),
        _divider(),

        // ── Stats on card ──
        _buildStatsSection(),
        _divider(),

        // ── Privacy ──
        _sectionLabel('PRIVACY'),
        const SizedBox(height: 12),
        _toggle(
          'Discoverable',
          'Allow others to find your card',
          appSettings.discoverable,
          (v) async {
            appSettings.setDiscoverable(v);
            await FirestoreService().updateProfile({'isDiscoverable': v});
          },
        ),

        const SizedBox(height: 16),
        _divider(),

        // ── Account ──
        _sectionLabel('ACCOUNT'),
        const SizedBox(height: 12),

        // Transfer Account
        LoreTap(
          onTap: () async {
            final confirm = await showDialog<bool>(
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
                        'TRANSFER ACCOUNT',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          color: cEmber,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This will release your account from this device so you can log in on a new one.\n\nYou will be signed out. To recover your account, you will need your unique code.',
                        style: TextStyle(
                          fontSize: 13,
                          color: cMist,
                          height: 1.7,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: LoreTap(
                              onTap: () => Navigator.of(ctx).pop(false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
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
                            child: LoreTap(
                              onTap: () => Navigator.of(ctx).pop(true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                color: cEmber.withValues(alpha: 0.8),
                                child: const Center(
                                  child: Text(
                                    'Transfer',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 9,
                                      color: cParchment,
                                      letterSpacing: 2,
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
            if (confirm == true && context.mounted) {
              await appSettings.flushToCloud();
              await SandboxSync.flush();
              await _auth.releaseDeviceLock();
              await _auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  fadeRoute(
                    kIsWeb ? const LoginScreen() : const LandingScreen(),
                  ),
                  (_) => false,
                );
              }
            }
          },
          child: const Text(
            'Transfer to new device',
            style: TextStyle(
              fontSize: 13,
              color: cEmber,
              fontWeight: FontWeight.w300,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 16),

        LoreTap(
          onTap: () async {
            await appSettings.flushToCloud();
            await SandboxSync.flush();
            await AuthService().signOut();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                fadeRoute(kIsWeb ? const LoginScreen() : const LandingScreen()),
                (_) => false,
              );
            }
          },
          child: const Text(
            'Sign out',
            style: TextStyle(fontSize: 13, color: cSmoke, letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  // ── Helpers ──

  Widget _buildStatsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: () => setState(() => _statsExpanded = !_statsExpanded),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text(
                'STATS ON MY CARD',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: appSettings.textColourFor('section_header') ?? cGold,
                  letterSpacing: 4,
                ),
              ),
              const Spacer(),
              AnimatedRotation(
                turns: _statsExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 14,
                  color: cSmoke,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      _toggle(
        'Show stats on card',
        'Master switch for every stat below',
        appSettings.profileStatsMaster,
        (v) async {
          await appSettings.setProfileStatsMaster(v);
          setState(() {});
        },
      ),
      if (_statsExpanded) ...[
        const SizedBox(height: 12),
        ...AppSettings.statKeys.map((key) {
          final enabled =
              appSettings.profileStatsMaster &&
              (appSettings.profileStats[key] ?? false);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Opacity(
              opacity: appSettings.profileStatsMaster ? 1.0 : 0.4,
              child: _toggle(
                AppSettings.statLabels[key] ?? key,
                '',
                enabled,
                appSettings.profileStatsMaster
                    ? (v) async {
                        await appSettings.setProfileStatVisible(key, v);
                        setState(() {});
                      }
                    : (_) {},
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        const Text(
          'Worlds and Characters will show real numbers once sandbox sync is enabled.',
          style: TextStyle(
            fontSize: 11,
            color: cSmoke,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
        ),
      ],
      const SizedBox(height: 16),
    ],
  );

  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      fontFamily: 'monospace',
      fontSize: 9,
      color: appSettings.textColourFor('section_header') ?? cGold,
      letterSpacing: 4,
    ),
  );

  Widget _divider() => Container(
    height: 1,
    color: cAsh,
    margin: const EdgeInsets.only(bottom: 16),
  );

  Widget _toggle(
    String label,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: cMist,
                fontWeight: FontWeight.w300,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: cSmoke,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(width: 12),
      LoreTap(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 44,
          height: 24,
          decoration: BoxDecoration(
            color: value ? cGold : cAsh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(3),
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: cVoid,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

// ════════════════════════════════════════
// SOUND SETTINGS WIDGET
// ════════════════════════════════════════
class _SoundSettings extends StatefulWidget {
  const _SoundSettings();
  @override
  State<_SoundSettings> createState() => _SoundSettingsState();
}

class _SoundSettingsState extends State<_SoundSettings> {
  bool _masterMute = false;
  final Map<String, bool> _enabled = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await sounds.init();
    final master = sounds.masterMute;
    final map = <String, bool>{};
    for (final key in SoundKey.all) {
      map[key] = sounds.isEnabled(key) || master;
    }
    if (mounted) {
      setState(() {
        _masterMute = master;
        _enabled.addAll(map);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Master mute toggle
        _soundRow(
          label: 'All sounds',
          subtitle: 'Master mute',
          value: !_masterMute,
          onChanged: (v) async {
            await sounds.setMasterMute(!v);
            setState(() => _masterMute = !v);
          },
          icon: _masterMute ? Icons.volume_off : Icons.volume_up,
          color: cGold,
        ),
        const SizedBox(height: 12),
        Container(
          height: 1,
          color: cAsh.withValues(alpha: 0.5),
          margin: const EdgeInsets.only(bottom: 12),
        ),
        // Individual sound toggles
        ...SoundKey.all.map((key) {
          final label = SoundKey.labels[key] ?? key;
          final enabled = _enabled[key] ?? true;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _soundRow(
              label: label,
              value: enabled,
              muted: _masterMute,
              onChanged: _masterMute
                  ? null
                  : (v) async {
                      await sounds.setEnabled(key, v);
                      setState(() => _enabled[key] = v);
                    },
            ),
          );
        }),
      ],
    );
  }

  Widget _soundRow({
    required String label,
    String? subtitle,
    required bool value,
    bool muted = false,
    IconData? icon,
    Color? color,
    ValueChanged<bool>? onChanged,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color ?? cSmoke),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: muted && onChanged != null ? cSmoke : cMist,
                  fontWeight: FontWeight.w300,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: cSmoke,
                    letterSpacing: 1,
                  ),
                ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: color ?? cGold,
          inactiveThumbColor: cAsh,
          inactiveTrackColor: cInk,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

class _NotifData {
  final String title, subtitle, id, type;
  final Map<String, dynamic> data;
  bool read;
  _NotifData(
    this.title,
    this.subtitle,
    this.read, {
    this.id = '',
    this.type = '',
    this.data = const {},
  });
}

class _NotificationsContent extends StatefulWidget {
  final List<_NotifData> notifications;
  final List<_RPData> roleplays;
  final List<_RPData> brainstorms;
  const _NotificationsContent({
    required this.notifications,
    required this.roleplays,
    required this.brainstorms,
  });
  @override
  State<_NotificationsContent> createState() => _NotificationsContentState();
}

class _NotificationsContentState extends State<_NotificationsContent> {
  final _fs = FirestoreService();
  final _auth = AuthService();

  List<_RPData> get _roleplays => widget.roleplays;
  List<_RPData> get _brainstorms => widget.brainstorms;

  Future<void> _markRead(String id) async {
    if (id.isEmpty) return;
    await _fs.markNotificationRead(id);
  }

  Future<String> _respond(_NotifData n, bool accepted) async {
    final fromCode = n.data['fromCode'] as String? ?? '';
    final genre = n.data['genre'] as String? ?? '';
    if (fromCode.isEmpty) return '';

    final snap = await FirebaseFirestore.instance
        .collection('interests')
        .where('fromCode', isEqualTo: fromCode)
        .where('toCode', isEqualTo: _auth.currentCode)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return '';
    final interestId = snap.docs.first.id;
    final fromName =
        (snap.docs.first.data()['fromName'] as String?) ?? fromCode;

    final sessionId = await _fs.respondToInterest(
      interestId: interestId,
      fromCode: fromCode,
      fromName: fromName,
      genre: genre,
      accepted: accepted,
    );
    await _markRead(n.id);
    if (accepted && sessionId.isNotEmpty) sounds.play(SoundKey.sessionAccept);
    return sessionId;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notifications.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No notifications yet.',
            style: TextStyle(
              fontSize: 13,
              color: cSmoke,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final hasUnread = widget.notifications.any((n) => !n.read);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasUnread)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const Text(
                  'UNREAD',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cSmoke,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                LoreTap(
                  onTap: () async {
                    setState(() {
                      for (var n in widget.notifications) {
                        n.read = true;
                      }
                    });
                    await _fs.markAllNotificationsRead(_auth.currentCode!);
                  },
                  child: const Text(
                    'MARK ALL READ',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      color: cGold,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ...widget.notifications.map((n) {
          final isInterest = n.type == 'interest';
          final isAccepted = n.type == 'accepted';
          final isRpPost = n.type == 'rp_post';
          final isBrainstorm = n.type == 'brainstorm_message';
          final isOoc = n.type == 'ooc_message';
          final isInviteRequest = n.type == 'invite_request';
          final isSecurityWarning = n.type == 'security_warning';

          return Dismissible(
            key: ValueKey(n.id),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cEmber.withValues(alpha: 0.8),
                border: Border.all(color: cEmber),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(
                Icons.delete_outline,
                color: cParchment,
                size: 24,
              ),
            ),
            onDismissed: (_) {
              // Remove from the on-screen list IMMEDIATELY, not just
              // from Firestore. If we wait for Firestore to come back,
              // Flutter rebuilds with the dismissed widget still in
              // the tree and throws the red screen.
              setState(() {
                widget.notifications.removeWhere((x) => x.id == n.id);
              });
              _fs.deleteNotification(n.id);
            },
            child: LoreTap(
              onTap: (isRpPost || isBrainstorm || isOoc)
                  ? () async {
                      await _markRead(n.id);
                      setState(() => n.read = true);
                      final sessionId = n.data['sessionId'] as String? ?? '';
                      if (!context.mounted || sessionId.isEmpty) return;
                      final session = _roleplays.firstWhere(
                        (r) => r.id == sessionId,
                        orElse: () => _brainstorms.firstWhere(
                          (b) => b.id == sessionId,
                          orElse: () => const _RPData('', '', '', 0, false),
                        ),
                      );
                      if (isRpPost || isOoc) {
                        Navigator.of(context).push(
                          fadeRoute(
                            RPRoomScreen(
                              partnerName: session.partner,
                              partnerCode: session.partnerCode,
                              genre: session.genre,
                              sessionId: sessionId,
                            ),
                          ),
                        );
                      } else {
                        Navigator.of(context).push(
                          fadeRoute(
                            BrainstormRoomScreen(
                              partnerName: session.partner,
                              partnerCode: session.partnerCode,
                              genre: session.genre,
                              sessionId: sessionId,
                            ),
                          ),
                        );
                      }
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: HoloCardV2(
                  accent: !n.read && isAccepted
                      ? cGold
                      : !n.read && isInterest
                      ? cIce
                      : !n.read && isRpPost
                      ? cEmber
                      : !n.read && isBrainstorm
                      ? cMagic
                      : !n.read && isSecurityWarning
                      ? cEmber
                      : cSmoke,
                  intensity: 0.3,
                  seed: n.id.hashCode,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: n.read ? cInk.withValues(alpha: 0.6) : cInk,
                      border: Border.all(
                        color: !n.read && isAccepted
                            ? cGold.withValues(alpha: 0.5)
                            : !n.read && isInterest
                            ? cIce.withValues(alpha: 0.5)
                            : !n.read && isRpPost
                            ? cEmber.withValues(alpha: 0.4)
                            : !n.read && isBrainstorm
                            ? cMagic.withValues(alpha: 0.4)
                            : !n.read && isOoc
                            ? cSmoke.withValues(alpha: 0.5)
                            : !n.read && isSecurityWarning
                            ? cEmber.withValues(alpha: 0.7)
                            : n.read
                            ? cAsh
                            : cSmoke,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isAccepted)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                  color: n.read ? cSmoke : cGold,
                                ),
                              ),
                            if (isInterest)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Icon(
                                  Icons.mail_outline,
                                  size: 16,
                                  color: n.read ? cSmoke : cIce,
                                ),
                              ),
                            if (isRpPost)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: n.read ? cSmoke : cEmber,
                                ),
                              ),
                            if (isOoc)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Icon(
                                  Icons.chat_bubble_outline,
                                  size: 16,
                                  color: n.read ? cSmoke : cMist,
                                ),
                              ),
                            if (isInviteRequest)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Icon(
                                  Icons.card_giftcard_outlined,
                                  size: 16,
                                  color: n.read ? cSmoke : cVine,
                                ),
                              ),
                            if (isSecurityWarning)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Icon(
                                  Icons.shield_outlined,
                                  size: 16,
                                  color: n.read ? cSmoke : cEmber,
                                ),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: n.read
                                          ? cSmoke
                                          : isAccepted
                                          ? cGold
                                          : isInterest
                                          ? cIce
                                          : isRpPost
                                          ? cEmber
                                          : isBrainstorm
                                          ? cMagic
                                          : isOoc
                                          ? cMist
                                          : isInviteRequest
                                          ? cVine
                                          : isSecurityWarning
                                          ? cEmber
                                          : cParchment,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n.subtitle,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      color: cSmoke,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            LoreTap(
                              onTap: () async {
                                await _markRead(n.id);
                                setState(() => n.read = true);
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: n.read ? cAsh : cSmoke,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (isInterest && !n.read) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: LoreTap(
                                  onTap: () async {
                                    await _respond(n, false);
                                    setState(() => n.read = true);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: cAsh),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Decline',
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
                                child: LoreTap(
                                  onTap: () async {
                                    final sessionId = await _respond(n, true);
                                    setState(() => n.read = true);
                                    if (context.mounted) {
                                      showSessionStartChoice(
                                        context,
                                        partnerName:
                                            n.data['fromCode'] as String? ??
                                            '?',
                                        partnerCode:
                                            n.data['fromCode'] as String? ?? '',
                                        genre: n.data['genre'] as String? ?? '',
                                        sessionId: sessionId,
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    color: cParchment,
                                    child: const Center(
                                      child: Text(
                                        'Accept',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 9,
                                          color: cVoid,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (isInviteRequest && !n.read) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: LoreTap(
                                  onTap: () async {
                                    await _markRead(n.id);
                                    setState(() => n.read = true);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: cAsh),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Decline',
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
                                child: LoreTap(
                                  onTap: () async {
                                    final fromCode =
                                        n.data['fromCode'] as String? ?? '';
                                    final fromName =
                                        n.data['fromName'] as String? ??
                                        fromCode;
                                    final genre =
                                        n.data['genre'] as String? ?? '';
                                    await _markRead(n.id);
                                    setState(() => n.read = true);
                                    final sessionId = await FirestoreService()
                                        .respondToInterest(
                                          interestId: n.id,
                                          fromCode: fromCode,
                                          fromName: fromName,
                                          genre: genre,
                                          accepted: true,
                                        );
                                    if (context.mounted &&
                                        sessionId.isNotEmpty) {
                                      showSessionStartChoice(
                                        context,
                                        partnerName: fromName,
                                        partnerCode: fromCode,
                                        genre: genre,
                                        sessionId: sessionId,
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    color: cVine.withValues(alpha: 0.8),
                                    child: const Center(
                                      child: Text(
                                        'Accept',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 9,
                                          color: cParchment,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (isAccepted && !n.read) ...[
                          const SizedBox(height: 8),
                          LoreTap(
                            onTap: () async {
                              await _markRead(n.id);
                              setState(() => n.read = true);
                              if (context.mounted) {
                                final sessionId =
                                    n.data['sessionId'] as String? ?? '';
                                showSessionStartChoice(
                                  context,
                                  partnerName: n.subtitle.split(' · ').first,
                                  partnerCode:
                                      n.data['partnerCode'] as String? ?? '',
                                  genre: n.data['genre'] as String? ?? '',
                                  sessionId: sessionId,
                                );
                              }
                            },
                            child: const Text(
                              'Tap to choose how to begin →',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                color: cGold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                        if ((isRpPost || isBrainstorm || isOoc) && !n.read) ...[
                          const SizedBox(height: 8),
                          Text(
                            isRpPost
                                ? 'Tap to enter the RP room →'
                                : isBrainstorm
                                ? 'Tap to enter prelude →'
                                : 'Tap to open OOC →',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: isRpPost
                                  ? cEmber
                                  : isBrainstorm
                                  ? cMagic
                                  : cMist,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ], // Column children
                    ), // Column
                  ), // Container
                ), // HoloCardV2
              ), // Padding
            ), // LoreTap
          ); // Dismissible
        }), // map function
      ], // children list
    ); // return Column
  } // build method
} // <--- Closes _NotificationsContentState

class _RPData {
  final String partner, partnerCode, genre, id;
  final int posts;
  final bool yourTurn;
  final DateTime? lastPostAt;
  final String status;
  final String title;
  final String summary;
  final String? backgroundUrl;

  const _RPData(
    this.partner,
    this.partnerCode,
    this.genre,
    this.posts,
    this.yourTurn, {
    this.id = '',
    this.lastPostAt,
    this.status = 'active',
    this.title = '',
    this.summary = '',
    this.backgroundUrl,
  });

  bool get isArchived => status == 'archived';
  bool get hasTitle => title.trim().isNotEmpty;

  _RPData copyWithStatus(String newStatus) => _RPData(
    partner,
    partnerCode,
    genre,
    posts,
    yourTurn,
    id: id,
    lastPostAt: lastPostAt,
    status: newStatus,
    title: title,
    summary: summary,
    backgroundUrl: backgroundUrl,
  );
}

class _RoleplaysContent extends StatefulWidget {
  final List<_RPData> roleplays;
  final void Function(_RPData rp) onEnter;
  final Future<void> Function(_RPData rp)? onArchive;
  final Future<void> Function(_RPData rp)? onUnarchive;
  final void Function(_RPData rp)? onBlock;
  final Future<void> Function(_RPData rp)? onDelete;

  const _RoleplaysContent({
    required this.roleplays,
    required this.onEnter,
    this.onArchive,
    this.onUnarchive,
    this.onBlock,
    this.onDelete,
  });
  @override
  State<_RoleplaysContent> createState() => _RoleplaysContentState();
}

class _RoleplaysContentState extends State<_RoleplaysContent> {
  late List<_RPData> _items;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.roleplays);
  }

  List<_RPData> get _visible =>
      _items.where((r) => _showArchived || !r.isArchived).toList();

  int get _archivedCount => _items.where((r) => r.isArchived).length;

  Future<void> _archive(_RPData rp) async {
    await widget.onArchive?.call(rp);
    if (!mounted) return;
    setState(() {
      final i = _items.indexWhere((x) => x.id == rp.id);
      if (i != -1) _items[i] = _items[i].copyWithStatus('archived');
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: cInk,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
        content: Text(
          'Archived the story with ${rp.partner}.',
          style: const TextStyle(
            color: cParchment,
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Future<void> _unarchive(_RPData rp) async {
    await widget.onUnarchive?.call(rp);
    if (!mounted) return;
    setState(() {
      final i = _items.indexWhere((x) => x.id == rp.id);
      if (i != -1) _items[i] = _items[i].copyWithStatus('active');
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: cInk,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
        content: Text(
          'Restored the story with ${rp.partner}.',
          style: const TextStyle(
            color: cParchment,
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(_RPData rp) async {
    final confirm = await showDialog<bool>(
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
                'DELETE STORY PERMANENTLY',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: cEmber,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete the story with ${rp.partner}?\n\nThis will permanently erase all posts, OOC chats, and images. This cannot be undone.',
                style: const TextStyle(
                  fontSize: 13,
                  color: cMist,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
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
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: cEmber.withValues(alpha: 0.8),
                        child: const Center(
                          child: Text(
                            'Delete',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: cParchment,
                              letterSpacing: 2,
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

    if (confirm == true) {
      await widget.onDelete?.call(rp);
      if (!mounted) return;
      setState(() {
        _items.removeWhere((x) => x.id == rp.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: cInk,
          content: Text(
            'Story deleted.',
            style: TextStyle(color: cParchment, fontSize: 13),
          ),
        ),
      );
    }
  }
  // ───────────────

  void _openMenu(_RPData rp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cInk,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: cAsh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _menuTile(
              icon: Icons.delete_forever,
              title: 'Delete Story',
              subtitle: 'Permanently erase all messages and images.',
              color: cEmber,
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmDelete(rp);
              },
            ),

            // Header Info
            if (rp.hasTitle) ...[
              Text(
                rp.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                  color: cParchment,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                rp.partner,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: cSmoke,
                  letterSpacing: 2,
                ),
              ),
            ] else
              Text(
                rp.partner,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                  color: cParchment,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              '${rp.genre} · ${rp.posts} posts',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: cSmoke,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 20),

            // 1. CUSTOMIZE
            _menuTile(
              icon: Icons.color_lens_outlined,
              title: 'Customize Card',
              subtitle: 'Change title, image, and summary.',
              color: cGold,
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  fadeRoute(
                    _RPEditorScreen(
                      rp: rp,
                      onSave: (updatedRp) async {
                        setState(() {
                          final i = _items.indexWhere((x) => x.id == rp.id);
                          if (i != -1) _items[i] = updatedRp;
                        });
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // 2. ARCHIVE / RESTORE
            if (!rp.isArchived)
              _menuTile(
                icon: Icons.inventory_2_outlined,
                title: 'Archive',
                subtitle: 'Hide from your list. Restore any time.',
                color: cMist,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _archive(rp);
                },
              )
            else
              _menuTile(
                icon: Icons.unarchive_outlined,
                title: 'Restore',
                subtitle: 'Bring this story back to your active list.',
                color: cVine,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _unarchive(rp);
                },
              ),
            const SizedBox(height: 8),

            // 3. BLOCK USER
            if (widget.onBlock != null) ...[
              _menuTile(
                icon: Icons.block,
                title: 'Block this user',
                subtitle: 'Never see or hear from them again.',
                color: cEmber,
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onBlock?.call(rp);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(border: Border.all(color: cAsh)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: color,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: cSmoke,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show archived toggle
        if (_archivedCount > 0) ...[
          GestureDetector(
            onTap: () => setState(() => _showArchived = !_showArchived),
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: _showArchived ? cGold : cAsh),
                color: _showArchived
                    ? cGold.withValues(alpha: 0.06)
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  Icon(
                    _showArchived
                        ? Icons.visibility
                        : Icons.visibility_outlined,
                    size: 14,
                    color: _showArchived ? cGold : cSmoke,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _showArchived
                        ? 'Showing archived ($_archivedCount)'
                        : 'Show archived ($_archivedCount)',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      letterSpacing: 2,
                      color: _showArchived ? cGold : cSmoke,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Text(
                  _showArchived ? 'No stories yet.' : 'No active roleplays.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: cMist,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Send an interest to start a story.',
                  style: TextStyle(fontSize: 12, color: cSmoke),
                ),
              ],
            ),
          )
        else
          // THE NEW GRID
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.7, // 5:7 aspect ratio like a TCG card
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final rp = items[index];
              return _RPSelectionCard(
                rp: rp,
                onTap: () => widget.onEnter(rp),
                onLongPress: () => _openMenu(rp),
              );
            },
          ),
      ],
    );
  }
}

class _BrainstormContent extends StatelessWidget {
  final List<_RPData> brainstorms;
  final void Function(_RPData b) onEnter;
  const _BrainstormContent({required this.brainstorms, required this.onEnter});
  @override
  Widget build(BuildContext context) {
    if (brainstorms.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(
              'No preludes.',
              style: TextStyle(
                fontSize: 14,
                color: cMist,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w300,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Accept an interest to start planning.',
              style: TextStyle(fontSize: 12, color: cSmoke),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: brainstorms.length,
      itemBuilder: (context, index) {
        final b = brainstorms[index];
        return _RPSelectionCard(
          rp: b,
          onTap: () => onEnter(b),
          onLongPress: () {},
        );
      },
    );
  }
}

class _RequestCardContent extends StatefulWidget {
  @override
  State<_RequestCardContent> createState() => _RequestCardContentState();
}

class _RequestCardContentState extends State<_RequestCardContent> {
  final _fs = FirestoreService();
  final _auth = AuthService();
  String? _inviteCode;
  bool _loadingInvite = false;
  final _redeemCtrl = TextEditingController();
  bool _redeemLoading = false;
  String? _redeemError;
  bool _redeemSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadInviteCode();
  }

  Future<void> _redeemInviteCode() async {
    final code = _redeemCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _redeemLoading = true;
      _redeemError = null;
      _redeemSuccess = false;
    });
    final ownerCode = await _fs.validateInviteCode(code);
    if (!mounted) return;
    if (ownerCode == null) {
      setState(() {
        _redeemError = 'Invalid or already used code.';
        _redeemLoading = false;
      });
      return;
    }
    if (ownerCode == _auth.currentCode) {
      setState(() {
        _redeemError = 'You cannot use your own invite code.';
        _redeemLoading = false;
      });
      return;
    }
    await _fs.redeemInviteCode(
      inviteCode: code,
      fromCode: _auth.currentCode ?? '',
      fromName: _auth.currentName ?? '',
    );
    if (mounted) {
      _redeemCtrl.clear();
      setState(() {
        _redeemLoading = false;
        _redeemSuccess = true;
      });
    }
  }

  @override
  void dispose() {
    _redeemCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInviteCode() async {
    final code = _auth.currentCode;
    if (code == null) return;
    final invite = await _fs.getActiveInviteCode(code);
    if (mounted) setState(() => _inviteCode = invite);
  }

  void _showRedeemSheet(BuildContext context) {
    _redeemCtrl.clear();
    _redeemError = null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cInk,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 32,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ENTER A CODE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: cGold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _redeemCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  color: cParchment,
                  letterSpacing: 4,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: cVoid,
                  hintText: 'XXXXXXXX',
                  hintStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    color: cAsh,
                    letterSpacing: 3,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: cAsh),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: cGold.withValues(alpha: 0.6)),
                  ),
                  errorText: _redeemError,
                  errorStyle: const TextStyle(
                    fontSize: 11,
                    color: cEmber,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                onChanged: (_) => setSheet(() => _redeemError = null),
              ),
              const SizedBox(height: 16),
              LoreTap(
                onTap: _redeemLoading
                    ? null
                    : () async {
                        await _redeemInviteCode();
                        if (!mounted) return;
                        if (_redeemSuccess) {
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                        } else {
                          setSheet(() {});
                        }
                      },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: cVine.withValues(alpha: 0.8),
                  child: Center(
                    child: _redeemLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: cParchment,
                            ),
                          )
                        : const Text(
                            'Send request',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: cParchment,
                              letterSpacing: 2,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateInviteCode() async {
    final code = _auth.currentCode;
    if (code == null) return;
    setState(() => _loadingInvite = true);
    final invite = await _fs.generateInviteCode(code);
    if (mounted) {
      setState(() {
        _inviteCode = invite;
        _loadingInvite = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your public request card is visible to others browsing for a partner.',
          style: TextStyle(
            fontSize: 13,
            color: cMist,
            fontStyle: FontStyle.italic,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 16),
        // Preview of the card
        _CardPreview(),
        const SizedBox(height: 16),
        // Edit button — opens full screen editor
        LoreTap(
          onTap: () =>
              Navigator.of(context).push(fadeRoute(const _RequestCardEditor())),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: Border.all(color: cAsh)),
            child: const Center(
              child: Text(
                'Edit card',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: cSmoke,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ── Invite Code ──
        const Text(
          'INVITE CODE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: cGold,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 12),

        // MY CODE
        const Text(
          'MY CODE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 8,
            color: cSmoke,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Share this with someone so they can send you a direct brainstorm request.',
          style: TextStyle(
            fontSize: 11,
            color: cSmoke,
            fontStyle: FontStyle.italic,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        if (_inviteCode != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: cGold.withValues(alpha: 0.4)),
              color: cGold.withValues(alpha: 0.05),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _inviteCode!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      color: cGold,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                LoreTap(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _inviteCode!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: cInk,
                        behavior: SnackBarBehavior.floating,
                        shape: const RoundedRectangleBorder(),
                        content: const Text(
                          'Invite code copied',
                          style: TextStyle(
                            color: cParchment,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.copy, size: 16, color: cSmoke),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          LoreTap(
            onTap: _loadingInvite ? null : _generateInviteCode,
            child: Text(
              'Generate new code',
              style: TextStyle(
                fontSize: 11,
                color: _loadingInvite ? cSmoke : cEmber,
                letterSpacing: 1,
              ),
            ),
          ),
        ] else ...[
          LoreTap(
            onTap: _loadingInvite ? null : _generateInviteCode,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: cGold.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: _loadingInvite
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1,
                          color: cGold,
                        ),
                      )
                    : const Text(
                        'Generate invite code',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: cGold,
                          letterSpacing: 2,
                        ),
                      ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // ENTER A CODE
        const Text(
          'ENTER A CODE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 8,
            color: cSmoke,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Got someone\'s invite code? Enter it to send them a direct brainstorm request.',
          style: TextStyle(
            fontSize: 11,
            color: cSmoke,
            fontStyle: FontStyle.italic,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        if (_redeemSuccess) ...[
          const Text(
            'Request sent! Waiting for them to accept.',
            style: TextStyle(
              fontSize: 11,
              color: cVine,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          LoreTap(
            onTap: () => setState(() => _redeemSuccess = false),
            child: const Text(
              'Send another',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                color: cSmoke,
                letterSpacing: 1,
              ),
            ),
          ),
        ] else
          LoreTap(
            onTap: () => _showRedeemSheet(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(border: Border.all(color: cAsh)),
              child: const Center(
                child: Text(
                  'Enter a code',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: cMist,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Shared card state (simple static for now) ──
class _CardState {
  static String bio =
      'I write long, immersive posts and expect the same in return. My stories tend toward the dark and morally complex.';
  static String? avatarUrl;
  static List<_TagData> tags = [
    _TagData('Historical', cGold),
    _TagData('18+', cEmber),
    _TagData('Open to ideas', cVine),
  ];
  static Color accentColor = cGold;
  static _BorderStyle borderStyle = _BorderStyle.solid;
  static Color bgTint = Colors.transparent;
  static String writingStyle = 'Long form · Literary · Dark themes';
  static String frequency = '1–2 posts per day';

  // ── TCG card frame + foil (new) ──
  static int frameSeed = 7;
  static bool frameGlow = true;
  static bool frameOrnate = true;
  static bool frameDense = false;
  static bool foilEnabled = true;
  static double foilIntensity = 0.6;

  // Bumped when the editor saves. Anything showing the card listens
  // to this and rebuilds — so panels that are sitting in the background
  // while the editor is on top stay in sync without a navigation trip.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static void bump() => revision.value++;
}

class _TagData {
  String label;
  Color color;
  _TagData(this.label, this.color);
}

enum _BorderStyle { solid, double_, dashed, glow }

// ── Card preview (shown in strip) ──
class _CardPreview extends StatefulWidget {
  @override
  State<_CardPreview> createState() => _CardPreviewState();
}

class _CardPreviewState extends State<_CardPreview> {
  @override
  void initState() {
    super.initState();
    _CardState.revision.addListener(_onCardChanged);
  }

  @override
  void dispose() {
    _CardState.revision.removeListener(_onCardChanged);
    super.dispose();
  }

  void _onCardChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Derive genre + age rating from tags, same rules as discovery list.
    final tagLabels = _CardState.tags.map((t) => t.label).toList();
    final genre = tagLabels.isNotEmpty ? tagLabels.first : 'Freeform';
    final ageRating = tagLabels.any((t) => t == '18+')
        ? '18+'
        : tagLabels.any((t) => t == '16+')
        ? '16+'
        : 'All ages';

    final spec = CardFrameSpec(
      seed: _CardState.frameSeed,
      accent: _CardState.accentColor,
      glow: _CardState.frameGlow,
      ornate: _CardState.frameOrnate,
      dense: _CardState.frameDense,
    );

    return Center(
      child: SizedBox(
        width: 280,
        child: HoloCardV2(
          accent: _CardState.accentColor,
          intensity: _CardState.foilIntensity,
          enabled: _CardState.foilEnabled,
          seed: _CardState.frameSeed,
          child: RequestCardView(
            name: 'You',
            code: 'DEMO-A1B2',
            genre: genre,
            foilEnabled: false,
            bio: _CardState.bio,
            avatarUrl: _CardState.avatarUrl,
            writingStyle: _CardState.writingStyle,
            frequency: _CardState.frequency,
            ageRating: ageRating,
            isOpen: true,
            tags: tagLabels,
            accent: _CardState.accentColor,
            frame: spec,
            foilSeed: _CardState.frameSeed,
            foilIntensity: _CardState.foilIntensity,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════
// REQUEST CARD EDITOR  (full screen)
// ════════════════════════════════════════
class _RequestCardEditor extends StatefulWidget {
  const _RequestCardEditor();
  @override
  State<_RequestCardEditor> createState() => _RequestCardEditorState();
}

class _RequestCardEditorState extends State<_RequestCardEditor>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late TextEditingController _bioCtrl;
  late TextEditingController _styleCtrl;
  late TextEditingController _freqCtrl;
  late TextEditingController _newTagCtrl;
  Color _newTagColor = cGold;

  final _accentOptions = [
    cGold,
    cIce,
    cEmber,
    cMagic,
    cVine,
    const Color(0xFFa0c4a0),
    Colors.white70,
    cParchment,
  ];
  final _bgOptions = [
    Colors.transparent,
    cGold,
    cIce,
    cEmber,
    cMagic,
    cVine,
    const Color(0xFF1a1a2e),
    const Color(0xFF2e1a1a),
  ];
  final _tagColorOptions = [
    cGold,
    cIce,
    cEmber,
    cMagic,
    cVine,
    cParchment,
    Colors.white70,
    const Color(0xFFa0c4a0),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _bioCtrl = TextEditingController(text: _CardState.bio);
    _styleCtrl = TextEditingController(text: _CardState.writingStyle);
    _freqCtrl = TextEditingController(text: _CardState.frequency);
    _newTagCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _tab.dispose();
    _bioCtrl.dispose();
    _styleCtrl.dispose();
    _freqCtrl.dispose();
    _newTagCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    _CardState.bio = _bioCtrl.text.trim();
    _CardState.writingStyle = _styleCtrl.text.trim();
    _CardState.frequency = _freqCtrl.text.trim();

    // Persist to Firestore
    await FirestoreService().updateProfile({
      'bio': _CardState.bio,
      'writingStyle': _CardState.writingStyle,
      'postFrequency': _CardState.frequency,
      'accentColor': _CardState.accentColor.toARGB32(),
      'bgTint': _CardState.bgTint.toARGB32(),
      'borderStyle': _CardState.borderStyle.name,
      'tags': _CardState.tags
          .map((t) => {'label': t.label, 'color': t.color.toARGB32()})
          .toList(),
      // ── TCG card frame + foil ──
      'requestCardSeed': _CardState.frameSeed,
      'requestCardGlow': _CardState.frameGlow,
      'requestCardOrnate': _CardState.frameOrnate,
      'requestCardDense': _CardState.frameDense,
      'requestCardFoil': _CardState.foilEnabled,
      'requestCardFoilLevel': _CardState.foilIntensity,
    });

    _CardState.bump();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appSettings.bgColor,
      // Key fix: resizeToAvoidBottomInset moves content above keyboard
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: cAsh)),
              ),
              child: Row(
                children: [
                  LoreTap(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, color: cSmoke, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Request Card',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                      color: cParchment,
                    ),
                  ),
                  const Spacer(),
                  LoreTap(
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: cParchment,
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: cVoid,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Tab bar
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: cAsh)),
              ),
              child: TabBar(
                controller: _tab,
                indicatorColor: cGold,
                indicatorWeight: 1,
                labelColor: cGold,
                unselectedLabelColor: cSmoke,
                labelStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  letterSpacing: 2,
                ),
                tabs: const [
                  Tab(text: 'CONTENT'),
                  Tab(text: 'TAGS'),
                  Tab(text: 'APPEARANCE'),
                ],
              ),
            ),
            // Tabs — wrapped in Expanded so keyboard doesn't overflow
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _buildContentTab(),
                  _buildTagsTab(),
                  _buildAppearanceTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── CONTENT TAB ──
  Widget _buildContentTab() {
    return ScrollConfiguration(
      behavior: NoGlowBehavior(),
      child: SingleChildScrollView(
        // padding adapts when keyboard appears
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Bio'),
            TextField(
              controller: _bioCtrl,
              maxLines: null,
              minLines: 5,
              style: const TextStyle(
                fontSize: 14,
                color: cParchment,
                fontStyle: FontStyle.italic,
                height: 1.7,
              ),
              decoration: const InputDecoration(
                hintText:
                    'What kind of writer are you? What are you looking for?',
                hintStyle: TextStyle(
                  color: cSmoke,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: cAsh),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: cSmoke),
                ),
                filled: true,
                fillColor: cInk,
              ),
              cursorColor: cGold,
            ),
            const SizedBox(height: 20),
            _label('Writing style'),
            TextField(
              controller: _styleCtrl,
              style: const TextStyle(
                fontSize: 14,
                color: cParchment,
                fontStyle: FontStyle.italic,
              ),
              decoration: const InputDecoration(
                hintText: 'e.g. Long form · Literary · Dark themes',
                hintStyle: TextStyle(
                  color: cSmoke,
                  fontStyle: FontStyle.italic,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: cAsh),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: cSmoke),
                ),
                filled: true,
                fillColor: cInk,
              ),
              cursorColor: cGold,
            ),
            const SizedBox(height: 20),
            _label('Post frequency'),
            TextField(
              controller: _freqCtrl,
              style: const TextStyle(
                fontSize: 14,
                color: cParchment,
                fontStyle: FontStyle.italic,
              ),
              decoration: const InputDecoration(
                hintText: 'e.g. 1–2 posts per day',
                hintStyle: TextStyle(
                  color: cSmoke,
                  fontStyle: FontStyle.italic,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: cAsh),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: cSmoke),
                ),
                filled: true,
                fillColor: cInk,
              ),
              cursorColor: cGold,
            ),
          ],
        ),
      ),
    );
  }

  // ── TAGS TAB ──
  Widget _buildTagsTab() {
    return ScrollConfiguration(
      behavior: NoGlowBehavior(),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Current tags'),
            const SizedBox(height: 4),
            const Text(
              'Long press a tag to remove it.',
              style: TextStyle(
                fontSize: 11,
                color: cSmoke,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _CardState.tags
                  .map(
                    (t) => GestureDetector(
                      onLongPress: () =>
                          setState(() => _CardState.tags.remove(t)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: t.color.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.label,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: t.color,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.close,
                              size: 10,
                              color: t.color.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            _label('Add a tag'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _tagColorOptions
                  .map(
                    (c) => LoreTap(
                      onTap: () => setState(() => _newTagColor = c),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _newTagColor == c
                                ? Colors.white
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            LoreTap(
              onTap: () => LoreColourPicker.show(
                context,
                current: _newTagColor,
                onPicked: (c) => setState(() => _newTagColor = c),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(border: Border.all(color: cAsh)),
                child: const Center(
                  child: Text(
                    'Custom Colour',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: cSmoke,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newTagCtrl,
                    style: TextStyle(
                      fontSize: 13,
                      color: _newTagColor,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tag name...',
                      hintStyle: const TextStyle(
                        color: cSmoke,
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: _newTagColor.withValues(alpha: 0.4),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _newTagColor),
                      ),
                      filled: true,
                      fillColor: cInk,
                    ),
                    cursorColor: _newTagColor,
                  ),
                ),
                const SizedBox(width: 10),
                LoreTap(
                  onTap: () {
                    final label = _newTagCtrl.text.trim();
                    if (label.isEmpty) return;
                    setState(() {
                      _CardState.tags.add(_TagData(label, _newTagColor));
                      _newTagCtrl.clear();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    color: cParchment,
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: cVoid,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── APPEARANCE TAB ──
  Widget _buildAppearanceTab() {
    return ScrollConfiguration(
      behavior: NoGlowBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Preview'),
            const SizedBox(height: 10),
            _buildPreview(),
            const SizedBox(height: 24),
            _label('Accent colour'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _accentOptions
                  .map(
                    (c) => LoreTap(
                      onTap: () => setState(() => _CardState.accentColor = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _CardState.accentColor == c
                                ? Colors.white
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            LoreTap(
              onTap: () => LoreColourPicker.show(
                context,
                current: _CardState.accentColor,
                onPicked: (c) => setState(() => _CardState.accentColor = c),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(border: Border.all(color: cAsh)),
                child: const Center(
                  child: Text(
                    'Custom Colour',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: cSmoke,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _label('Background tint'),
            const SizedBox(height: 6),
            const Text(
              'Subtle colour wash behind the card.',
              style: TextStyle(
                fontSize: 11,
                color: cSmoke,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _bgOptions
                  .map(
                    (c) => LoreTap(
                      onTap: () => setState(() => _CardState.bgTint = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c == Colors.transparent ? cVoid : c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _CardState.bgTint == c ? Colors.white : cAsh,
                            width: _CardState.bgTint == c ? 2.5 : 1,
                          ),
                        ),
                        child: c == Colors.transparent
                            ? const Center(
                                child: Icon(
                                  Icons.block,
                                  size: 14,
                                  color: cSmoke,
                                ),
                              )
                            : null,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            LoreTap(
              onTap: () => LoreColourPicker.show(
                context,
                current: _CardState.bgTint,
                onPicked: (c) => setState(() => _CardState.bgTint = c),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(border: Border.all(color: cAsh)),
                child: const Center(
                  child: Text(
                    'Custom Colour',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: cSmoke,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _label('Frame'),
            const SizedBox(height: 4),
            const Text(
              'Shuffle cycles through procedurally generated variants.',
              style: TextStyle(
                fontSize: 11,
                color: cSmoke,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            LoreTap(
              onTap: () => setState(() {
                _CardState.frameSeed = Random().nextInt(1 << 30);
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: cGold.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.casino_outlined, size: 14, color: cGold),
                    SizedBox(width: 8),
                    Text(
                      'SHUFFLE FRAME',
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
            const SizedBox(height: 12),
            _frameToggle(
              'Glow',
              _CardState.frameGlow,
              (v) => setState(() => _CardState.frameGlow = v),
            ),
            const SizedBox(height: 8),
            _frameToggle(
              'Ornate corners',
              _CardState.frameOrnate,
              (v) => setState(() => _CardState.frameOrnate = v),
            ),
            const SizedBox(height: 8),
            _frameToggle(
              'Dense details',
              _CardState.frameDense,
              (v) => setState(() => _CardState.frameDense = v),
            ),
            const SizedBox(height: 24),
            _label('Foil'),
            const SizedBox(height: 4),
            const Text(
              'A holo effect that follows your finger across the card.',
              style: TextStyle(
                fontSize: 11,
                color: cSmoke,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            _frameToggle(
              'Shimmer',
              _CardState.foilEnabled,
              (v) => setState(() => _CardState.foilEnabled = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Strength',
                  style: TextStyle(
                    fontSize: 13,
                    color: cMist,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _CardState.foilIntensity.clamp(0.1, 1.0),
                    min: 0.1,
                    max: 1.0,
                    activeColor: cGold,
                    inactiveColor: cAsh,
                    onChanged: _CardState.foilEnabled
                        ? (v) => setState(() => _CardState.foilIntensity = v)
                        : null,
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${(_CardState.foilIntensity * 100).round()}%',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: cSmoke,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _frameToggle(String label, bool value, ValueChanged<bool> onChanged) =>
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: cMist,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: cGold,
            inactiveTrackColor: cAsh,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      );

  Widget _buildPreview() {
    final tagLabels = _CardState.tags.map((t) => t.label).toList();
    final genre = tagLabels.isNotEmpty ? tagLabels.first : 'Freeform';
    final ageRating = tagLabels.any((t) => t == '18+')
        ? '18+'
        : tagLabels.any((t) => t == '16+')
        ? '16+'
        : 'All ages';

    return Center(
      child: SizedBox(
        width: 260,
        child: HoloCardV2(
          accent: _CardState.accentColor,
          intensity: _CardState.foilIntensity,
          enabled: _CardState.foilEnabled,
          seed: _CardState.frameSeed,
          child: RequestCardView(
            name: 'You',
            code: 'DEMO-A1B2',
            genre: genre,
            bio: _CardState.bio,
            writingStyle: _CardState.writingStyle,
            frequency: _CardState.frequency,
            ageRating: ageRating,
            isOpen: true,
            tags: tagLabels,
            accent: _CardState.accentColor,
            bgTint: _CardState.bgTint,
            avatarUrl: _CardState.avatarUrl,
            frame: CardFrameSpec(
              seed: _CardState.frameSeed,
              accent: _CardState.accentColor,
              glow: _CardState.frameGlow,
              ornate: _CardState.frameOrnate,
              dense: _CardState.frameDense,
            ),
            foilEnabled: _CardState.foilEnabled,
            foilSeed: _CardState.frameSeed,
            foilIntensity: _CardState.foilIntensity,
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 9,
        color: cGold,
        letterSpacing: 3,
      ),
    ),
  );
}

class _ExpansionRoute extends StatelessWidget {
  final String title;
  final Widget child;
  const _ExpansionRoute({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: appSettings.bgColor,
    body: SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: cAsh)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(
                    Icons.arrow_back_ios,
                    color: cSmoke,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    fontStyle: FontStyle.italic,
                    color: cParchment,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ContinuePrefsSheet extends StatefulWidget {
  final List<_RPData> roleplays;
  final VoidCallback onChanged;
  const _ContinuePrefsSheet({required this.roleplays, required this.onChanged});
  @override
  State<_ContinuePrefsSheet> createState() => _ContinuePrefsSheetState();
}

class _ContinuePrefsSheetState extends State<_ContinuePrefsSheet> {
  @override
  Widget build(BuildContext context) {
    final mode = appSettings.continueMode;
    return Container(
      decoration: const BoxDecoration(
        color: cInk,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: cAsh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'CONTINUE CARD',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: cGold,
                    letterSpacing: 4,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 18, color: cSmoke),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose what shows in the Continue card at the bottom of home. Long-press that card any time to reopen this.',
              style: TextStyle(
                fontSize: 12,
                color: cSmoke,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            _modeTile(
              AppSettings.continueModeCycle,
              'Rotate through all',
              'Remind me of every story I have going.',
              mode,
            ),
            _modeTile(
              AppSettings.continueModePinned,
              'Pin one story',
              'Always show the same session. Good for a main RP.',
              mode,
            ),
            _modeTile(
              AppSettings.continueModeCycleSelected,
              'Rotate through selected',
              'Only cycle between the sessions I pick below.',
              mode,
            ),
            if (mode == AppSettings.continueModeCycleSelected) ...[
              const SizedBox(height: 20),
              const Text(
                'SELECTED STORIES',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: cGold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 10),
              if (widget.roleplays.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No stories to select yet.',
                    style: TextStyle(
                      fontSize: 12,
                      color: cSmoke,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ...widget.roleplays.map((rp) {
                  final selected = appSettings.continueIds.contains(rp.id);
                  return GestureDetector(
                    onTap: () async {
                      final current = List<String>.from(
                        appSettings.continueIds,
                      );
                      if (selected) {
                        current.remove(rp.id);
                      } else {
                        current.add(rp.id);
                      }
                      await appSettings.setContinueIds(current);
                      widget.onChanged();
                      if (mounted) setState(() {});
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: selected ? cGold : cAsh),
                        color: selected
                            ? cGold.withValues(alpha: 0.08)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected ? cGold : cSmoke,
                              ),
                              color: selected ? cGold : Colors.transparent,
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check,
                                    size: 11,
                                    color: cVoid,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rp.partner,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: selected ? cParchment : cMist,
                                    fontWeight: FontWeight.w300,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${rp.genre} · ${rp.posts} posts',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    color: cSmoke,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: cParchment,
                  child: const Center(
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: cVoid,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeTile(String mode, String title, String subtitle, String current) {
    final active = mode == current;
    return GestureDetector(
      onTap: () async {
        await appSettings.setContinueMode(mode);
        widget.onChanged();
        if (mounted) setState(() {});
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: active ? cGold : cAsh),
          color: active ? cGold.withValues(alpha: 0.06) : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: active ? cGold : cSmoke),
                color: active ? cGold : Colors.transparent,
              ),
              child: active
                  ? const Icon(Icons.check, size: 11, color: cVoid)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: active ? cParchment : cMist,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: cSmoke,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RPSelectionCard extends StatelessWidget {
  final _RPData rp;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _RPSelectionCard({
    required this.rp,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final myName = AuthService().currentName ?? 'You';
    final titleText = rp.hasTitle ? rp.title : rp.partner;
    final seed = rp.id.hashCode;
    final accent = rp.genre.toLowerCase().contains('fantasy')
        ? cGold
        : rp.genre.toLowerCase().contains('sci-fi')
        ? cIce
        : cMist;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Opacity(
        opacity: rp.isArchived ? 0.5 : 1.0,
        child: HoloCardV2(
          accent: accent,
          intensity: 0.4,
          seed: seed,
          bgColor: cInk,
          child: Container(
            decoration: BoxDecoration(
              color: cInk,
              border: Border.all(
                color: accent.withValues(alpha: 0.4),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4), // Frame inset
              child: CardFrame(
                spec: CardFrameSpec(
                  seed: seed,
                  accent: accent,
                  ornate: true,
                  glow: false,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Background Image (if any)
                      if (rp.backgroundUrl != null)
                        Image.network(
                          rp.backgroundUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                color: cGold,
                                strokeWidth: 1.5,
                              ),
                            );
                          },
                          errorBuilder: (_, _, _) => Container(
                            color: cInk, // Fallback background
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: cAsh,
                                size: 24,
                              ),
                            ),
                          ),
                        ),

                      // 3. Content
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top: Both Names
                            Text(
                              '$myName & ${rp.partner}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 7.5,
                                color: cSmoke,
                                letterSpacing: 1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),

                            // Center: Title
                            Center(
                              child: Text(
                                titleText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w300,
                                  fontStyle: FontStyle.italic,
                                  color: cParchment,
                                  height: 1.1,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // Summary (if any)
                            if (rp.summary.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                rp.summary,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 8,
                                  color: cMist,
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            const Spacer(),

                            // Bottom: Stats
                            Container(
                              padding: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: accent.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    rp.genre.toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 6.5,
                                      color: accent,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  Text(
                                    '${rp.posts}p',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 7,
                                      color: cSmoke,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RPEditorScreen extends StatefulWidget {
  final _RPData rp;
  final Function(_RPData) onSave;

  const _RPEditorScreen({required this.rp, required this.onSave});

  @override
  State<_RPEditorScreen> createState() => _RPEditorScreenState();
}

class _RPEditorScreenState extends State<_RPEditorScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _summaryCtrl;
  String? _bgUrl;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.rp.title);
    _summaryCtrl = TextEditingController(text: widget.rp.summary);
    _bgUrl = widget.rp.backgroundUrl;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() => _uploading = true);

    try {
      final ref = FirebaseStorage.instance.ref().child(
        'sessions/${widget.rp.id}/background.jpg',
      );
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();

      final freshUrl = '$url?v=${DateTime.now().millisecondsSinceEpoch}';
      await NetworkImage(url).evict();

      setState(() {
        _bgUrl = freshUrl;
        _uploading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cInk,
            content: Text(
              'Upload failed: $e',
              style: const TextStyle(color: cEmber),
            ),
          ),
        );
      }
    }
  }

  void _save() async {
    final newTitle = _titleCtrl.text.trim();
    final newSummary = _summaryCtrl.text.trim();

    await FirestoreService().updateSessionDetails(
      widget.rp.id,
      title: newTitle,
      summary: newSummary,
      backgroundUrl: _bgUrl,
    );

    final updated = _RPData(
      widget.rp.partner,
      widget.rp.partnerCode,
      widget.rp.genre,
      widget.rp.posts,
      widget.rp.yourTurn,
      id: widget.rp.id,
      lastPostAt: widget.rp.lastPostAt,
      status: widget.rp.status,
      title: newTitle,
      summary: newSummary,
      backgroundUrl: _bgUrl,
    );

    widget.onSave(updated);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appSettings.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: cAsh)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: cSmoke,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'CUSTOMIZE CARD',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: cGold,
                      letterSpacing: 4,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      color: cParchment,
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: cVoid,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _uploading ? null : _pickImage,
                        child: Container(
                          width: 200,
                          height: 280, // 5:7 ratio
                          decoration: BoxDecoration(
                            color: cInk,
                            border: Border.all(color: cAsh),
                            borderRadius: BorderRadius.circular(8),
                            image: _bgUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_bgUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _uploading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: cGold,
                                  ),
                                )
                              : (_bgUrl == null
                                    ? const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons
                                                  .add_photo_alternate_outlined,
                                              color: cSmoke,
                                              size: 32,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Add Background',
                                              style: TextStyle(
                                                color: cSmoke,
                                                fontFamily: 'monospace',
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : null),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'TITLE',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        color: cGold,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleCtrl,
                      style: const TextStyle(
                        fontSize: 16,
                        color: cParchment,
                        fontStyle: FontStyle.italic,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Give this story a name...',
                        hintStyle: TextStyle(color: cSmoke),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: cAsh),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: cGold),
                        ),
                      ),
                      cursorColor: cGold,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'SUMMARY',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        color: cGold,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _summaryCtrl,
                      maxLines: 4,
                      style: const TextStyle(
                        fontSize: 14,
                        color: cMist,
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'What is this story about?',
                        hintStyle: TextStyle(color: cSmoke),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: cAsh),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: cGold),
                        ),
                      ),
                      cursorColor: cGold,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════
// GLOBAL DOWNLOAD DIALOG
// ════════════════════════════════════════
void showDownloadDialog(BuildContext context) {
  // ⚠️ REPLACE THIS URL WITH YOUR ACTUAL GITHUB RELEASE APK LINK! ⚠️
  const String apkUrl =
      'https://github.com/VengefulRat/flutter_ex/releases/download/v8.4.5/flutter_ex-releases.apk';

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
