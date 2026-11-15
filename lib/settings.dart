import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';

// Single global instance
final appSettings = AppSettings();

// ════════════════════════════════════════
// BLOCK STYLE
// ════════════════════════════════════════
class BlockStyle {
  final Color? background;
  final Color? borderColor;
  final String borderStyle; // 'solid' | 'thick' | 'faded' | 'glow'
  final Color? accent;
  final String shape; // 'square' | 'rounded' | 'pill' | 'hexagon'

  const BlockStyle({
    this.background,
    this.borderColor,
    this.borderStyle = 'solid',
    this.accent,
    this.shape = 'square',
  });

  bool get isDefault =>
      background == null &&
      borderColor == null &&
      accent == null &&
      borderStyle == 'solid' &&
      shape == 'square';

  BlockStyle copyWith({
    Color? background,
    Color? borderColor,
    String? borderStyle,
    Color? accent,
    String? shape,
    bool clearBackground = false,
    bool clearBorderColor = false,
    bool clearAccent = false,
  }) => BlockStyle(
    background: clearBackground ? null : (background ?? this.background),
    borderColor: clearBorderColor ? null : (borderColor ?? this.borderColor),
    borderStyle: borderStyle ?? this.borderStyle,
    accent: clearAccent ? null : (accent ?? this.accent),
    shape: shape ?? this.shape,
  );

  Map<String, dynamic> toJson() => {
    if (background != null) 'bg': background!.toARGB32(),
    if (borderColor != null) 'bc': borderColor!.toARGB32(),
    'bs': borderStyle,
    if (accent != null) 'ac': accent!.toARGB32(),
    'sh': shape,
  };

  factory BlockStyle.fromJson(Map<String, dynamic> j) => BlockStyle(
    background: j['bg'] != null ? Color(j['bg'] as int) : null,
    borderColor: j['bc'] != null ? Color(j['bc'] as int) : null,
    borderStyle: j['bs'] as String? ?? 'solid',
    accent: j['ac'] != null ? Color(j['ac'] as int) : null,
    shape: j['sh'] as String? ?? 'square',
  );
}

// ════════════════════════════════════════
// APP SETTINGS
// ════════════════════════════════════════
class AppSettings extends ChangeNotifier {
  static const _kCardBorder = 'as_card_border';
  static const _kParchment = 'as_parchment';
  static const _kTextSize = 'as_text_size';
  static const _kOrientation = 'as_orientation';
  static const _kSound = 'as_sound';
  static const _kDefaultStyle = 'as_default_style';
  static const _kTextColours = 'as_text_colours_v2';
  static const _kTextColoursLegacy = 'as_text_colours';
  static const _kGradient = 'as_gradient';
  static const _kBorderColor = 'as_border_color';
  static const _kBorderStyle = 'as_border_style';
  static const _kAiMood = 'as_ai_mood';
  static const _kNotifPost = 'as_notif_post';
  static const _kNotifInterest = 'as_notif_interest';
  static const _kNotifBrain = 'as_notif_brain';
  static const _kAutoScroll = 'as_auto_scroll';
  static const _kOocSide = 'as_ooc_side';
  static const _kEnterToSend = 'as_enter_to_send';
  static const _kDiscoverable = 'as_discoverable';
  static const _kBgGlow = 'as_bg_glow';
  static const _kProfileStatsMaster = 'as_profile_stats_master';
  static const _kProfileStatsMap = 'as_profile_stats_map';
  static const _kContinueMode = 'as_continue_mode';
  static const _kContinueIds = 'as_continue_ids';
  static const _kContinueLastShown = 'as_continue_last_shown';
  static const _kBlockStyles = 'as_block_styles_v1';
  static const _kDevModeUnlocked = 'as_dev_mode_unlocked';
  static const _kAnimatedBorderThickness = 'as_animated_border_thickness';
  static const _kAnimatedBorderWaviness = 'as_animated_border_waviness';
  static const _kAnimatedBorderSpeed = 'as_animated_border_speed';
  static const _kAnimatedBorderOpacity = 'as_animated_border_opacity';
  static const _kAnimatedBorderPattern = 'as_animated_border_pattern';
  static const _kAnimatedBorderFrameOutset = 'as_animated_border_frame_outset';

  // ── Stat keys ──
  static const statActiveRPs = 'active_rps';
  static const statTotalPosts = 'total_posts';
  static const statBrainstormRooms = 'brainstorm_rooms';
  static const statWritingPartners = 'writing_partners';
  static const statDaysActive = 'days_active';
  static const statLastPost = 'last_post';
  static const statWorldsCreated = 'worlds_created';
  static const statCharactersCreated = 'characters_created';

  static const List<String> statKeys = [
    statActiveRPs,
    statTotalPosts,
    statBrainstormRooms,
    statWritingPartners,
    statDaysActive,
    statLastPost,
    statWorldsCreated,
    statCharactersCreated,
  ];

  List<String> _homeOrder = [];

  Future<void> setHomeOrder(List<String> order) async {
    _homeOrder = order;
    (await SharedPreferences.getInstance()).setStringList(
      'as_home_order',
      order,
    );
    _touch();
    notifyListeners();
  }

  static const Map<String, String> statLabels = {
    statActiveRPs: 'Active Roleplays',
    statTotalPosts: 'Total Posts',
    statBrainstormRooms: 'Preludes',
    statWritingPartners: 'Writing Partners',
    statDaysActive: 'Days Active',
    statLastPost: 'Last Post',
    statWorldsCreated: 'Worlds Created',
    statCharactersCreated: 'Characters Created',
  };

  // ── Block keys ──
  static const blockProfile = 'profile';
  static const blockNotifications = 'notifications';
  static const blockRoleplays = 'roleplays';
  static const blockBrainstorms = 'Preludes';
  static const blockRequestCard = 'request_card';
  static const blockSettings = 'settings';

  static const List<String> blockKeys = [
    blockProfile,
    blockNotifications,
    blockRoleplays,
    blockBrainstorms,
    blockRequestCard,
    blockSettings,
  ];

  static const Map<String, String> blockLabels = {
    blockProfile: 'Profile Card',
    blockNotifications: 'Notifications',
    blockRoleplays: 'Roleplays',
    blockBrainstorms: 'Preludes',
    blockRequestCard: 'Request Card',
    blockSettings: 'Settings',
  };

  // ── Text colour keys ──
  static const textKeyPostContent = 'post_content';
  static const textKeyCharName = 'char_name';
  static const textKeyLocationName = 'location_name';
  static const textKeyOoc = 'ooc';
  static const textKeyBrainstorm = 'Preludes';
  static const textKeyStripLabel = 'strip_label';
  static const textKeyTimestamp = 'timestamp';
  static const textKeyProfileName = 'profile_name';
  static const textKeyProfileBio = 'profile_bio';
  static const textKeyProfileCode = 'profile_code';
  static const textKeySectionHeader = 'section_header';
  static const textKeyButtonText = 'button_text';
  static const textKeyPartnerName = 'partner_name';

  static const Map<String, String> textKeyLabels = {
    textKeyPostContent: 'Post content',
    textKeyCharName: 'Character name',
    textKeyLocationName: 'Location name',
    textKeyOoc: 'OOC messages',
    textKeyBrainstorm: 'Brainstorm text',
    textKeyStripLabel: 'Strip labels',
    textKeyTimestamp: 'Timestamps',
    textKeyProfileName: 'Profile name',
    textKeyProfileBio: 'Profile bio',
    textKeyProfileCode: 'Profile code',
    textKeySectionHeader: 'Section headers',
    textKeyButtonText: 'Button text',
    textKeyPartnerName: 'Partner name',
  };

  /// Which text colour keys each block owns.
  static const Map<String, List<String>> blockTextKeys = {
    blockProfile: [textKeyProfileName, textKeyProfileBio, textKeyProfileCode],
    blockRoleplays: [
      textKeyPostContent,
      textKeyCharName,
      textKeyLocationName,
      textKeyTimestamp,
      textKeyPartnerName,
      textKeyOoc,
    ],
    blockBrainstorms: [textKeyBrainstorm],
    blockSettings: [textKeySectionHeader, textKeyStripLabel, textKeyButtonText],
    blockNotifications: [],
    blockRequestCard: [],
  };

  // ── Continue band modes ──
  static const continueModePinned = 'pinned';
  static const continueModeCycle = 'cycle';
  static const continueModeCycleSelected = 'cycle_selected';

  // ── State ──
  bool _cardBorderEffects = true;
  bool _parchmentMode = false;
  String _textSize = 'Medium';
  String _orientation = 'Both';
  bool _soundEnabled = true;
  Map<String, Color> _textColours = {};
  List<Color> _profileGradient = [
    const Color(0xFF080808),
    const Color(0xFF0E0E0E),
  ];
  Color _bgGlowColor = const Color(0xFFC9A96E);
  Color _profileBorderColor = const Color(0xFF2a2a2a);
  double _animatedBorderThickness = 3.0;
  double _animatedBorderWaviness = 4.0;
  double _animatedBorderSpeed = 1.0;
  double _animatedBorderOpacity = 0.7;
  String _animatedBorderPattern = 'waves';
  double _animatedBorderFrameOutset = 10.0;
  String _profileBorderStyle = 'solid';
  bool _aiMood = true;
  bool _notifNewPost = true;
  bool _notifRpPost = true;
  bool _notifOoc = true;
  bool _notifBrainstorm = true;
  bool _notifInterest = true;
  bool _autoScroll = true;
  final String _defaultStyle = 'Novella';
  String _oocSide = 'Right';
  bool _enterToSend = false;
  bool _discoverable = true;

  bool _profileStatsMaster = true;
  Map<String, bool> _profileStats = {
    statActiveRPs: true,
    statTotalPosts: true,
    statBrainstormRooms: true,
    statWritingPartners: true,
    statDaysActive: true,
    statLastPost: true,
    statWorldsCreated: false,
    statCharactersCreated: false,
  };

  String _continueMode = continueModeCycle;
  List<String> _continueIds = [];
  String? _continueLastShown;

  Map<String, BlockStyle> _blockStyles = {};

  bool _devModeUnlocked = false;

  final _auth = AuthService();
  Timer? _cloudDebounce;

  // ════════════════════════════════════════
  // LOAD (local only)
  // ════════════════════════════════════════
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _cardBorderEffects = p.getBool(_kCardBorder) ?? true;
    _parchmentMode = p.getBool(_kParchment) ?? false;
    _textSize = p.getString(_kTextSize) ?? 'Medium';
    _orientation = p.getString(_kOrientation) ?? 'Both';
    _soundEnabled = p.getBool(_kSound) ?? true;
    _aiMood = p.getBool(_kAiMood) ?? true;
    _notifNewPost = p.getBool(_kNotifPost) ?? true;
    _notifRpPost = p.getBool('as_notif_rp_post') ?? true;
    _notifOoc = p.getBool('as_notif_ooc') ?? true;
    _notifBrainstorm = p.getBool('as_notif_brainstorm') ?? true;
    _notifInterest = p.getBool(_kNotifInterest) ?? true;
    _autoScroll = p.getBool(_kAutoScroll) ?? true;
    _oocSide = p.getString(_kOocSide) ?? 'Right';
    _enterToSend = p.getBool(_kEnterToSend) ?? false;
    _discoverable = p.getBool(_kDiscoverable) ?? true;
    _profileBorderStyle = p.getString(_kBorderStyle) ?? 'solid';
    _animatedBorderThickness = p.getDouble(_kAnimatedBorderThickness) ?? 3.0;
    _animatedBorderWaviness = p.getDouble(_kAnimatedBorderWaviness) ?? 4.0;
    _animatedBorderSpeed = p.getDouble(_kAnimatedBorderSpeed) ?? 1.0;
    _animatedBorderOpacity = p.getDouble(_kAnimatedBorderOpacity) ?? 0.7;
    _animatedBorderPattern = p.getString(_kAnimatedBorderPattern) ?? 'waves';
    _animatedBorderFrameOutset =
        p.getDouble(_kAnimatedBorderFrameOutset) ?? 10.0;
    _profileStatsMaster = p.getBool(_kProfileStatsMaster) ?? true;
    _continueMode = p.getString(_kContinueMode) ?? continueModeCycle;
    _continueIds = p.getStringList(_kContinueIds) ?? [];
    _continueLastShown = p.getString(_kContinueLastShown);
    _devModeUnlocked = p.getBool(_kDevModeUnlocked) ?? false;
    _homeOrder = p.getStringList('as_home_order') ?? [];

    final bg = p.getInt(_kBgGlow);
    if (bg != null) _bgGlowColor = Color(bg);
    final bc = p.getInt(_kBorderColor);
    if (bc != null) _profileBorderColor = Color(bc);

    // Text colours — new format first, then legacy migration
    final tcNew = p.getString(_kTextColours);
    if (tcNew != null) {
      try {
        final decoded = jsonDecode(tcNew) as Map;
        _textColours = decoded.map(
          (k, v) => MapEntry(k as String, Color(v as int)),
        );
      } catch (_) {}
    } else {
      final tcOld = p.getString(_kTextColoursLegacy);
      if (tcOld != null) {
        try {
          final list = jsonDecode(tcOld) as List;
          for (final e in list) {
            final m = Map<String, dynamic>.from(e as Map);
            final k = m['key'] as String?;
            final c = m['color'] as int?;
            if (k != null && c != null) _textColours[k] = Color(c);
          }
          // Persist in new format and drop the old key
          await p.setString(
            _kTextColours,
            jsonEncode(_textColours.map((k, v) => MapEntry(k, v.toARGB32()))),
          );
          await p.remove(_kTextColoursLegacy);
        } catch (_) {}
      }
    }

    final gRaw = p.getString(_kGradient);
    if (gRaw != null) {
      try {
        final list = jsonDecode(gRaw) as List;
        _profileGradient = list.map((v) => Color(v as int)).toList();
      } catch (_) {}
    }

    final statsRaw = p.getString(_kProfileStatsMap);
    if (statsRaw != null) {
      try {
        final decoded = jsonDecode(statsRaw) as Map;
        final merged = Map<String, bool>.from(_profileStats);
        for (final k in statKeys) {
          if (decoded.containsKey(k) && decoded[k] is bool) {
            merged[k] = decoded[k] as bool;
          }
        }
        _profileStats = merged;
      } catch (_) {}
    }

    final bsRaw = p.getString(_kBlockStyles);
    if (bsRaw != null) {
      try {
        final decoded = jsonDecode(bsRaw) as Map;
        _blockStyles = decoded.map(
          (k, v) => MapEntry(
            k as String,
            BlockStyle.fromJson(Map<String, dynamic>.from(v as Map)),
          ),
        );
      } catch (_) {}
    }

    notifyListeners();
  }

  // ════════════════════════════════════════
  // CLOUD SYNC
  // ════════════════════════════════════════
  //
  // Call syncFromCloud() once after login / restore. Local changes are
  // debounced up to Firestore so a user dragging a colour slider doesn't
  // fire 60 writes.
  //
  // What syncs: appearance, text colours, block styles, continue prefs,
  // notification prefs, sound prefs. What doesn't: PIN / lock settings
  // (those are handled separately via the auth flow) and continueLastShown
  // (per-device rotation state — doesn't make sense to sync).

  /// Pull from Firestore. Cloud wins on first load. If cloud has nothing
  /// yet, push local up as the baseline.
  Future<void> syncFromCloud() async {
    final code = _auth.currentCode;
    if (code == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(code)
          .get();
      final data = doc.data();
      if (data == null) return;

      final raw = data['preferences'] as String?;
      if (raw == null) {
        // Account has never synced. Reset to defaults first so a
        // previous user's settings on this device don't get pushed
        // into this account's cloud copy.
        await resetForSignOut();
        await _pushToCloudNow(code);
        return;
      }

      final decoded = jsonDecode(raw) as Map;
      _applyCloudJson(Map<String, dynamic>.from(decoded));
      await _saveAllToPrefs();
      notifyListeners();
    } catch (e) {
      print('[settings] syncFromCloud failed: $e');
    }
  }

  /// Force a push to Firestore immediately. Called on sign-out so pending
  /// changes aren't lost to the debounce window.
  Future<void> flushToCloud() async {
    _cloudDebounce?.cancel();
    final code = _auth.currentCode;
    if (code == null) return;
    await _pushToCloudNow(code);
  }

  void _touch() {
    _cloudDebounce?.cancel();
    _cloudDebounce = Timer(const Duration(seconds: 2), () {
      final code = _auth.currentCode;
      if (code == null) return;
      _pushToCloudNow(code);
    });
  }

  Future<void> _pushToCloudNow(String code) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(code).update({
        'preferences': jsonEncode(_serializeAll()),
        'homeOrder': _homeOrder,
        'enterToSend': _enterToSend,
        'preferencesUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[settings] cloud push failed: $e');
    }
  }

  Map<String, dynamic> _serializeAll() => {
    'cardBorderEffects': _cardBorderEffects,
    'parchmentMode': _parchmentMode,
    'textSize': _textSize,
    'orientation': _orientation,
    'soundEnabled': _soundEnabled,
    'textColours': _textColours.map((k, v) => MapEntry(k, v.toARGB32())),
    'profileGradient': _profileGradient.map((c) => c.toARGB32()).toList(),
    'bgGlowColor': _bgGlowColor.toARGB32(),
    'profileBorderColor': _profileBorderColor.toARGB32(),
    'profileBorderStyle': _profileBorderStyle,
    'animatedBorderThickness': _animatedBorderThickness,
    'animatedBorderWaviness': _animatedBorderWaviness,
    'animatedBorderSpeed': _animatedBorderSpeed,
    'animatedBorderOpacity': _animatedBorderOpacity,
    'animatedBorderPattern': _animatedBorderPattern,
    'animatedBorderFrameOutset': _animatedBorderFrameOutset,
    'aiMood': _aiMood,
    'notifNewPost': _notifNewPost,
    'notifInterest': _notifInterest,
    'autoScroll': _autoScroll,
    'oocSide': _oocSide,
    'profileStatsMaster': _profileStatsMaster,
    'profileStats': _profileStats,
    'continueMode': _continueMode,
    'continueIds': _continueIds,
    'blockStyles': _blockStyles.map((k, v) => MapEntry(k, v.toJson())),
  };

  void _applyCloudJson(Map<String, dynamic> j) {
    _cardBorderEffects = j['cardBorderEffects'] as bool? ?? _cardBorderEffects;
    _parchmentMode = j['parchmentMode'] as bool? ?? _parchmentMode;
    _textSize = j['textSize'] as String? ?? _textSize;
    _orientation = j['orientation'] as String? ?? _orientation;
    _soundEnabled = j['soundEnabled'] as bool? ?? _soundEnabled;
    _profileBorderStyle =
        j['profileBorderStyle'] as String? ?? _profileBorderStyle;
    _animatedBorderThickness =
        (j['animatedBorderThickness'] as num?)?.toDouble() ??
        _animatedBorderThickness;
    _animatedBorderWaviness =
        (j['animatedBorderWaviness'] as num?)?.toDouble() ??
        _animatedBorderWaviness;
    _animatedBorderSpeed =
        (j['animatedBorderSpeed'] as num?)?.toDouble() ?? _animatedBorderSpeed;
    _animatedBorderOpacity =
        (j['animatedBorderOpacity'] as num?)?.toDouble() ??
        _animatedBorderOpacity;
    _animatedBorderPattern =
        j['animatedBorderPattern'] as String? ?? _animatedBorderPattern;
    _animatedBorderFrameOutset =
        (j['animatedBorderFrameOutset'] as num?)?.toDouble() ??
            _animatedBorderFrameOutset;
    _aiMood = j['aiMood'] as bool? ?? _aiMood;
    _notifNewPost = j['notifNewPost'] as bool? ?? _notifNewPost;
    _notifInterest = j['notifInterest'] as bool? ?? _notifInterest;
    _autoScroll = j['autoScroll'] as bool? ?? _autoScroll;
    _oocSide = j['oocSide'] as String? ?? _oocSide;
    _profileStatsMaster =
        j['profileStatsMaster'] as bool? ?? _profileStatsMaster;
    _continueMode = j['continueMode'] as String? ?? _continueMode;
    _continueIds = List<String>.from(j['continueIds'] ?? _continueIds);
    _enterToSend = j['enterToSend'] as bool? ?? _enterToSend;

    if (j['bgGlowColor'] is int) {
      _bgGlowColor = Color(j['bgGlowColor'] as int);
    }
    if (j['profileBorderColor'] is int) {
      _profileBorderColor = Color(j['profileBorderColor'] as int);
    }
    if (j['textColours'] is Map) {
      _textColours = (j['textColours'] as Map).map(
        (k, v) => MapEntry(k as String, Color(v as int)),
      );
    }
    if (j['profileGradient'] is List) {
      _profileGradient = (j['profileGradient'] as List)
          .map((v) => Color(v as int))
          .toList();
    }
    if (j['profileStats'] is Map) {
      final merged = Map<String, bool>.from(_profileStats);
      (j['profileStats'] as Map).forEach((k, v) {
        if (v is bool) merged[k as String] = v;
      });
      _profileStats = merged;
    }
    _homeOrder = List<String>.from(j['homeOrder'] ?? _homeOrder);
    if (j['blockStyles'] is Map) {
      _blockStyles = (j['blockStyles'] as Map).map(
        (k, v) => MapEntry(
          k as String,
          BlockStyle.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
      );
    }
  }

  Future<void> _saveAllToPrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kCardBorder, _cardBorderEffects);
    await p.setBool(_kParchment, _parchmentMode);
    await p.setString(_kTextSize, _textSize);
    await p.setString(_kOrientation, _orientation);
    await p.setBool(_kSound, _soundEnabled);
    await p.setString(_kBorderStyle, _profileBorderStyle);
    await p.setDouble(_kAnimatedBorderThickness, _animatedBorderThickness);
    await p.setDouble(_kAnimatedBorderWaviness, _animatedBorderWaviness);
    await p.setDouble(_kAnimatedBorderSpeed, _animatedBorderSpeed);
    await p.setDouble(_kAnimatedBorderOpacity, _animatedBorderOpacity);
    await p.setString(_kAnimatedBorderPattern, _animatedBorderPattern);
    await p.setDouble(_kAnimatedBorderFrameOutset, _animatedBorderFrameOutset);
    await p.setBool(_kAiMood, _aiMood);
    await p.setBool(_kNotifPost, _notifNewPost);
    await p.setBool('as_notif_rp_post', _notifRpPost);
    await p.setBool('as_notif_ooc', _notifOoc);
    await p.setBool('as_notif_brainstorm', _notifBrainstorm);
    await p.setBool(_kNotifInterest, _notifInterest);
    await p.setBool(_kAutoScroll, _autoScroll);
    await p.setString(_kOocSide, _oocSide);
    await p.setString(_kDefaultStyle, _defaultStyle);
    await p.setBool(_kProfileStatsMaster, _profileStatsMaster);
    await p.setString(_kContinueMode, _continueMode);
    await p.setStringList(_kContinueIds, _continueIds);
    await p.setInt(_kBgGlow, _bgGlowColor.toARGB32());
    await p.setInt(_kBorderColor, _profileBorderColor.toARGB32());
    await p.setString(
      _kTextColours,
      jsonEncode(_textColours.map((k, v) => MapEntry(k, v.toARGB32()))),
    );
    await p.setString(
      _kGradient,
      jsonEncode(_profileGradient.map((c) => c.toARGB32()).toList()),
    );
    await p.setString(_kProfileStatsMap, jsonEncode(_profileStats));
    await p.setString(
      _kBlockStyles,
      jsonEncode(_blockStyles.map((k, v) => MapEntry(k, v.toJson()))),
    );
    await p.setBool(_kEnterToSend, _enterToSend);
    await p.setStringList('as_home_order', _homeOrder);
  }

  // ════════════════════════════════════════
  // GETTERS
  // ════════════════════════════════════════
  bool get cardBorderEffects => _cardBorderEffects;
  bool get parchmentMode => _parchmentMode;
  String get textSize => _textSize;
  String get orientation => _orientation;
  bool get devModeUnlocked => _devModeUnlocked;
  bool get soundEnabled => _soundEnabled;
  List<Color> get profileGradient => List.unmodifiable(_profileGradient);
  Color get profileBorderColor => _profileBorderColor;
  String get profileBorderStyle => _profileBorderStyle;
  double get animatedBorderThickness => _animatedBorderThickness;
  double get animatedBorderWaviness => _animatedBorderWaviness;
  double get animatedBorderSpeed => _animatedBorderSpeed;
  double get animatedBorderOpacity => _animatedBorderOpacity;
  String get animatedBorderPattern => _animatedBorderPattern;
  double get animatedBorderFrameOutset => _animatedBorderFrameOutset;
  bool get aiMood => _aiMood;
  bool get notifNewPost => _notifNewPost;
  bool get notifInterest => _notifInterest;
  bool get autoScroll => _autoScroll;
  String get oocSide => _oocSide;
  bool get enterToSend => _enterToSend;
  bool get discoverable => _discoverable;
  bool get profileStatsMaster => _profileStatsMaster;
  Map<String, bool> get profileStats => Map.unmodifiable(_profileStats);
  String get continueMode => _continueMode;
  List<String> get continueIds => List.unmodifiable(_continueIds);
  String? get continueLastShown => _continueLastShown;
  bool get notifRpPost => _notifRpPost;
  bool get notifOoc => _notifOoc;
  bool get notifBrainstorm => _notifBrainstorm;

  // Legacy API — kept for compatibility with the old Settings UI. Will be
  // removed when that UI is replaced by per-block long-press.
  List<Map<String, dynamic>> get textColours => _textColours.entries
      .map(
        (e) => {
          'key': e.key,
          'label': textKeyLabels[e.key] ?? e.key,
          'color': e.value.toARGB32(),
        },
      )
      .toList();

  List<String> get homeOrder => List.unmodifiable(_homeOrder);

  Color? textColourFor(String key) => _textColours[key];

  /// The text colour keys owned by a block, for the long-press sheet.
  List<String> textKeysForBlock(String blockKey) =>
      blockTextKeys[blockKey] ?? const [];

  /// True if the block has any colours currently set.
  bool blockHasCustomText(String blockKey) =>
      textKeysForBlock(blockKey).any((k) => _textColours.containsKey(k));

  // ── Block styles ──
  BlockStyle styleForBlock(String blockKey) =>
      _blockStyles[blockKey] ?? const BlockStyle();

  Map<String, BlockStyle> get blockStyles => Map.unmodifiable(_blockStyles);

  bool isStatVisible(String key) {
    if (!_profileStatsMaster) return false;
    return _profileStats[key] ?? false;
  }

  List<String> get visibleStatKeys => statKeys.where(isStatVisible).toList();

  double get baseFontSize {
    switch (_textSize) {
      case 'Small':
        return 12.0;
      case 'Large':
        return 17.0;
      default:
        return 14.0;
    }
  }

  Color get bgColor =>
      _parchmentMode ? const Color(0xFF1a1814) : const Color(0xFF080808);

  Color get surfaceColor =>
      _parchmentMode ? const Color(0xFF221e1a) : const Color(0xFF0E0E0E);

  Color get bgGlowColor => _bgGlowColor;

  // ════════════════════════════════════════
  // SETTERS
  // ════════════════════════════════════════
  Future<void> setCardBorderEffects(bool v) async {
    _cardBorderEffects = v;
    (await SharedPreferences.getInstance()).setBool(_kCardBorder, v);
    _touch();
    notifyListeners();
  }

  Future<void> setParchmentMode(bool v) async {
    _parchmentMode = v;
    (await SharedPreferences.getInstance()).setBool(_kParchment, v);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarIconBrightness: v ? Brightness.dark : Brightness.light,
      ),
    );
    _touch();
    notifyListeners();
  }

  Future<void> setTextSize(String v) async {
    _textSize = v;
    (await SharedPreferences.getInstance()).setString(_kTextSize, v);
    _touch();
    notifyListeners();
  }

  Future<void> setOrientation(String v) async {
    _orientation = v;
    (await SharedPreferences.getInstance()).setString(_kOrientation, v);
    switch (v) {
      case 'Portrait':
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        break;
      case 'Landscape':
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        break;
      default:
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    _touch();
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool v) async {
    _soundEnabled = v;
    (await SharedPreferences.getInstance()).setBool(_kSound, v);
    _touch();
    notifyListeners();
  }

  Future<void> setProfileGradient(List<Color> v) async {
    _profileGradient = List.from(v);
    (await SharedPreferences.getInstance()).setString(
      _kGradient,
      jsonEncode(v.map((c) => c.toARGB32()).toList()),
    );
    _touch();
    notifyListeners();
  }

  Future<void> setBgGlowColor(Color v) async {
    _bgGlowColor = v;
    (await SharedPreferences.getInstance()).setInt(_kBgGlow, v.toARGB32());
    _touch();
    notifyListeners();
  }

  Future<void> setProfileBorderColor(Color v) async {
    _profileBorderColor = v;
    (await SharedPreferences.getInstance()).setInt(_kBorderColor, v.toARGB32());
    _touch();
    notifyListeners();
  }

  Future<void> setProfileBorderStyle(String v) async {
    _profileBorderStyle = v;
    (await SharedPreferences.getInstance()).setString(_kBorderStyle, v);
    _touch();
    notifyListeners();
  }

  Future<void> setAnimatedBorderThickness(double v) async {
    _animatedBorderThickness = v;
    (await SharedPreferences.getInstance()).setDouble(
      _kAnimatedBorderThickness,
      v,
    );
    _touch();
    notifyListeners();
  }

  Future<void> setAnimatedBorderWaviness(double v) async {
    _animatedBorderWaviness = v;
    (await SharedPreferences.getInstance()).setDouble(
      _kAnimatedBorderWaviness,
      v,
    );
    _touch();
    notifyListeners();
  }

  Future<void> setAnimatedBorderSpeed(double v) async {
    _animatedBorderSpeed = v;
    (await SharedPreferences.getInstance()).setDouble(_kAnimatedBorderSpeed, v);
    _touch();
    notifyListeners();
  }

  Future<void> setAnimatedBorderOpacity(double v) async {
    _animatedBorderOpacity = v;
    (await SharedPreferences.getInstance()).setDouble(
      _kAnimatedBorderOpacity,
      v,
    );
    _touch();
    notifyListeners();
  }

  Future<void> setAnimatedBorderPattern(String v) async {
        if (v != 'waves' && v != 'spikes' && v != 'gears' && v != 'dice' && v != 'swords' && v != 'leaves' && v != 'shields' && v != 'flames' && v != 'stars' && v != 'runes' && v != 'thorns' && v != 'feathers' && v != 'claws') return;
    _animatedBorderPattern = v;
    (await SharedPreferences.getInstance()).setString(
      _kAnimatedBorderPattern,
      v,
    );
    _touch();
    notifyListeners();
  }

  Future<void> setAnimatedBorderFrameOutset(double v) async {
    _animatedBorderFrameOutset = v;
    (await SharedPreferences.getInstance()).setDouble(
      _kAnimatedBorderFrameOutset,
      v,
    );
    _touch();
    notifyListeners();
  }

  Future<void> setAiMood(bool v) async {
    _aiMood = v;
    (await SharedPreferences.getInstance()).setBool(_kAiMood, v);
    _touch();
    notifyListeners();
  }

  Future<void> setNotifNewPost(bool v) async {
    _notifNewPost = v;
    (await SharedPreferences.getInstance()).setBool(_kNotifPost, v);
    _touch();
    notifyListeners();
  }

  Future<void> setNotifInterest(bool v) async {
    _notifInterest = v;
    (await SharedPreferences.getInstance()).setBool(_kNotifInterest, v);
    _touch();
    notifyListeners();
  }

  Future<void> setNotifRpPost(bool v) async {
    _notifRpPost = v;
    (await SharedPreferences.getInstance()).setBool('as_notif_rp_post', v);
    _touch();
    notifyListeners();
  }

  Future<void> setNotifOoc(bool v) async {
    _notifOoc = v;
    (await SharedPreferences.getInstance()).setBool('as_notif_ooc', v);
    _touch();
    notifyListeners();
  }

  Future<void> setNotifBrainstorm(bool v) async {
    _notifBrainstorm = v;
    (await SharedPreferences.getInstance()).setBool('as_notif_brainstorm', v);
    _touch();
    notifyListeners();
  }

  Future<void> setAutoScroll(bool v) async {
    _autoScroll = v;
    (await SharedPreferences.getInstance()).setBool(_kAutoScroll, v);
    _touch();
    notifyListeners();
  }

  Future<void> setOocSide(String v) async {
    _oocSide = v;
    (await SharedPreferences.getInstance()).setString(_kOocSide, v);
    _touch();
    notifyListeners();
  }

  Future<void> setEnterToSend(bool v) async {
    _enterToSend = v;
    (await SharedPreferences.getInstance()).setBool(_kEnterToSend, v);
    _touch();
    notifyListeners();
  }

  Future<void> setDiscoverable(bool v) async {
    _discoverable = v;
    (await SharedPreferences.getInstance()).setBool(_kDiscoverable, v);
    // Note: also written to users/{code}.isDiscoverable via FirestoreService.
    // Deliberately NOT synced through preferences to avoid two sources of truth.
    notifyListeners();
  }

  Future<void> setProfileStatsMaster(bool v) async {
    _profileStatsMaster = v;
    (await SharedPreferences.getInstance()).setBool(_kProfileStatsMaster, v);
    _touch();
    notifyListeners();
  }

  Future<void> setProfileStatVisible(String key, bool v) async {
    if (!statKeys.contains(key)) return;
    _profileStats[key] = v;
    (await SharedPreferences.getInstance()).setString(
      _kProfileStatsMap,
      jsonEncode(_profileStats),
    );
    _touch();
    notifyListeners();
  }

  Future<void> setContinueMode(String v) async {
    if (v != continueModePinned &&
        v != continueModeCycle &&
        v != continueModeCycleSelected) {
      return;
    }
    _continueMode = v;
    (await SharedPreferences.getInstance()).setString(_kContinueMode, v);
    _touch();
    notifyListeners();
  }

  Future<void> setContinueIds(List<String> ids) async {
    _continueIds = List.from(ids);
    (await SharedPreferences.getInstance()).setStringList(
      _kContinueIds,
      _continueIds,
    );
    _touch();
    notifyListeners();
  }

  Future<void> setContinueLastShown(String? id) async {
    _continueLastShown = id;
    final p = await SharedPreferences.getInstance();
    if (id == null) {
      await p.remove(_kContinueLastShown);
    } else {
      await p.setString(_kContinueLastShown, id);
    }
    // No _touch() — per-device bookkeeping, doesn't sync.
  }

  // ── Text colour setters ──

  Future<void> setTextColour(String key, Color? colour) async {
    if (colour == null) {
      _textColours.remove(key);
    } else {
      _textColours[key] = colour;
    }
    (await SharedPreferences.getInstance()).setString(
      _kTextColours,
      jsonEncode(_textColours.map((k, v) => MapEntry(k, v.toARGB32()))),
    );
    _touch();
    notifyListeners();
  }

  /// Legacy — the old flat-list setter. Kept so the old Settings UI keeps
  /// building until we remove it.
  Future<void> setTextColours(List<Map<String, dynamic>> v) async {
    _textColours.clear();
    for (final e in v) {
      final k = e['key'] as String?;
      final c = e['color'] as int?;
      if (k != null && c != null) _textColours[k] = Color(c);
    }
    (await SharedPreferences.getInstance()).setString(
      _kTextColours,
      jsonEncode(_textColours.map((k, v) => MapEntry(k, v.toARGB32()))),
    );
    _touch();
    notifyListeners();
  }

  /// Resets every in-memory setting to its default and writes those
  /// defaults to SharedPreferences. Called on sign-out so the next
  /// account doesn't inherit the last one's appearance.
  Future<void> resetForSignOut() async {
    _cardBorderEffects = true;
    _parchmentMode = false;
    _textSize = 'Medium';
    _orientation = 'Both';
    _soundEnabled = true;
    _aiMood = true;
    _notifNewPost = true;
    _notifInterest = true;
    _autoScroll = true;
    _oocSide = 'Right';
    _discoverable = true;
    _profileBorderStyle = 'solid';
    _animatedBorderThickness = 3.0;
    _animatedBorderWaviness = 4.0;
    _animatedBorderSpeed = 1.0;
    _animatedBorderOpacity = 0.7;
    _animatedBorderPattern = 'waves';
    _animatedBorderFrameOutset = 10.0;
    _profileStatsMaster = true;
    _continueMode = continueModeCycle;
    _continueIds = [];
    _continueLastShown = null;
    _bgGlowColor = const Color(0xFFC9A96E);
    _profileBorderColor = const Color(0xFF2a2a2a);
    _profileGradient = [const Color(0xFF080808), const Color(0xFF0E0E0E)];
    _textColours = {};
    _blockStyles = {};
    _notifRpPost = true;
    _notifOoc = true;
    _notifBrainstorm = true;
    _profileStats = {
      statActiveRPs: true,
      statTotalPosts: true,
      statBrainstormRooms: true,
      statWritingPartners: true,
      statDaysActive: true,
      statLastPost: true,
      statWorldsCreated: false,
      statCharactersCreated: false,
    };

    final p = await SharedPreferences.getInstance();
    await p.remove(_kCardBorder);
    await p.remove(_kParchment);
    await p.remove(_kTextSize);
    await p.remove(_kOrientation);
    await p.remove(_kSound);
    await p.remove(_kTextColours);
    await p.remove(_kTextColoursLegacy);
    await p.remove(_kGradient);
    await p.remove(_kBorderColor);
    await p.remove(_kBorderStyle);
    await p.remove(_kAiMood);
    await p.remove(_kNotifPost);
    await p.remove(_kNotifInterest);
    await p.remove(_kNotifBrain);
    await p.remove(_kAutoScroll);
    await p.remove(_kOocSide);
    await p.remove(_kDiscoverable);
    await p.remove(_kBgGlow);
    await p.remove(_kProfileStatsMaster);
    await p.remove(_kProfileStatsMap);
    await p.remove(_kContinueMode);
    await p.remove(_kContinueIds);
    await p.remove(_kContinueLastShown);
    await p.remove(_kBlockStyles);
    await p.remove(_kEnterToSend);
    await p.remove(_kAnimatedBorderThickness);
    await p.remove(_kAnimatedBorderWaviness);
    await p.remove(_kAnimatedBorderSpeed);
    await p.remove(_kAnimatedBorderOpacity);
    await p.remove(_kAnimatedBorderPattern);
    await p.remove(_kAnimatedBorderFrameOutset);

    // Cancel any in-flight debounce so a stale push doesn't fire after
    // the next user is signed in.
    _cloudDebounce?.cancel();

    notifyListeners();
  }

  Future<void> setDevModeUnlocked(bool v) async {
    _devModeUnlocked = v;
    (await SharedPreferences.getInstance()).setBool(_kDevModeUnlocked, v);
    notifyListeners();
  }

  // ── Block style setters ──

  Future<void> setBlockStyle(String blockKey, BlockStyle style) async {
    if (style.isDefault) {
      _blockStyles.remove(blockKey);
    } else {
      _blockStyles[blockKey] = style;
    }
    (await SharedPreferences.getInstance()).setString(
      _kBlockStyles,
      jsonEncode(_blockStyles.map((k, v) => MapEntry(k, v.toJson()))),
    );
    _touch();
    notifyListeners();
  }

  /// Full reset — tile appearance and all text colours owned by the block.
  Future<void> resetBlock(String blockKey) async {
    _blockStyles.remove(blockKey);
    for (final key in textKeysForBlock(blockKey)) {
      _textColours.remove(key);
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kBlockStyles,
      jsonEncode(_blockStyles.map((k, v) => MapEntry(k, v.toJson()))),
    );
    await p.setString(
      _kTextColours,
      jsonEncode(_textColours.map((k, v) => MapEntry(k, v.toARGB32()))),
    );
    _touch();
    notifyListeners();
  }
}
