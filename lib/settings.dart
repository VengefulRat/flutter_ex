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
  final Color? glowColor;
  final bool glowEnabled;
  final Color? accent;
  final String size;

  const BlockStyle({
    this.background,
    this.glowColor,
    this.glowEnabled = false,
    this.accent,
    this.size = 'normal',
  });

  bool get isDefault =>
      background == null && glowColor == null && !glowEnabled && accent == null && size == 'normal';

  BlockStyle copyWith({
    Color? background,
    Color? glowColor,
    bool? glowEnabled,
    Color? accent,
    String? size,
    bool clearBackground = false,
    bool clearGlowColor = false,
    bool clearAccent = false,
  }) => BlockStyle(
    background: clearBackground ? null : (background ?? this.background),
    glowColor: clearGlowColor ? null : (glowColor ?? this.glowColor),
    glowEnabled: glowEnabled ?? this.glowEnabled,
    accent: clearAccent ? null : (accent ?? this.accent),
    size: size ?? this.size,
  );

  Map<String, dynamic> toJson() => {
    if (background != null) 'bg': background!.toARGB32(),
    if (glowColor != null) 'gc': glowColor!.toARGB32(),
    'ge': glowEnabled,
    if (accent != null) 'ac': accent!.toARGB32(),
    if (size != 'normal') 'sz': size,
  };

  factory BlockStyle.fromJson(Map<String, dynamic> j) {
    // EDIT 10a migration: old tiles saved 'bc' (border colour),
    // 'bs' (border style), 'sh' (shape). Border style + shape are
    // retired — they were never read by the tile renderer. If a tile
    // had glow as its old border style, keep glow on and carry its
    // old border colour over as the glow colour, so nothing visually
    // disappears. Otherwise glow starts off.
    final hasNewGlow = j.containsKey('gc') || j.containsKey('ge');
    final legacyGlow = j['bs'] == 'glow';
    return BlockStyle(
      background: j['bg'] != null ? Color(j['bg'] as int) : null,
      glowColor: j['gc'] != null
          ? Color(j['gc'] as int)
          : (j['bc'] != null ? Color(j['bc'] as int) : null),
      glowEnabled: hasNewGlow ? (j['ge'] as bool? ?? false) : legacyGlow,
      accent: j['ac'] != null ? Color(j['ac'] as int) : null,
      size: j['sz'] as String? ?? 'normal',
    );
  }
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
  static const _kProfileGlowColor = 'as_profile_glow_color';
  static const _kShowLogo = 'as_show_logo';
  static const _kLogoText = 'as_logo_text';
  static const _kShowFloatingButton = 'as_show_fab';
  static const _kGyroEnabled = 'as_gyro_enabled';
  static const _kFloatingMenuColor = 'as_floating_menu_color';
  static const _kFanCardSize = 'as_fan_card_size';
  static const _kHiddenBlocks = 'as_hidden_blocks';
  static const _kRpHeaderShow = 'as_rp_header_show';
  static const _kRpHeaderSize = 'as_rp_header_size';
  static const _kRpHeaderAccent = 'as_rp_header_accent';
  static const _kRpMoodOverride = 'as_rp_mood_override';
  static const _kRpBgColor = 'as_rp_bg_color';
  static const _kRpParticlesOn = 'as_rp_particles_on';
  static const _kRpPostSize = 'as_rp_post_size';
  static const _kRpDisplayMode = 'as_rp_display_mode';
  static const _kRpEditorSize = 'as_rp_editor_size';
  static const _kRpShowLogSidebar = 'as_rp_show_log_sidebar';
  static const _kRpShowToolsSidebar = 'as_rp_show_tools_sidebar';
  static const _kRpShowOoc = 'as_rp_show_ooc';
  static const _kRpOocBadgeOn = 'as_rp_ooc_badge_on';
  static const _kPreludeHeaderShow = 'as_prelude_header_show';
  static const _kPreludeHeaderSize = 'as_prelude_header_size';
  static const _kPreludeHeaderAccent = 'as_prelude_header_accent';
  static const _kPreludeBgMode = 'as_prelude_bg_mode';
  static const _kPreludeBgColor = 'as_prelude_bg_color';
  static const _kPreludeMsgSize = 'as_prelude_msg_size';
  static const _kPreludeDensity = 'as_prelude_density';
  static const _kPreludeMsgStyle = 'as_prelude_msg_style';
  static const _kPreludeShowTimestamp = 'as_prelude_show_timestamp';
  static const _kPreludeShowAuthor = 'as_prelude_show_author';
  static const _kPreludeShowPinLabel = 'as_prelude_show_pin_label';
  static const _kPreludePinRule = 'as_prelude_pin_rule';
  static const _kPreludePinCharacter = 'as_prelude_pin_character';
  static const _kPreludePinWorld = 'as_prelude_pin_world';
  static const _kPreludePinPlot = 'as_prelude_pin_plot';
  static const _kPreludePinFilter = 'as_prelude_pin_filter';
  static const _kPreludeInputSize = 'as_prelude_input_size';
  static const _kPreludeChoiceSize = 'as_prelude_choice_size';
  static const _kDiaryHeaderShow = 'as_diary_header_show';
  static const _kDiaryHeaderSize = 'as_diary_header_size';
  static const _kDiaryBgMode = 'as_diary_bg_mode';
  static const _kDiaryBgColor = 'as_diary_bg_color';
  static const _kDiaryShowReminder = 'as_diary_show_reminder';
  static const _kDiaryShowStreak = 'as_diary_show_streak';
  static const _kDiaryCardSize = 'as_diary_card_size';
  static const _kDiaryShowAuthor = 'as_diary_show_author';
  static const _kDiaryShowStats = 'as_diary_show_stats';
  static const _kDiaryShowAvatars = 'as_diary_show_avatars';
  static const _kDiaryEntryHeaderShow = 'as_diary_entry_header_show';
  static const _kDiaryEntryHeaderSize = 'as_diary_entry_header_size';
  static const _kDiaryShowGenreBar = 'as_diary_show_genre_bar';
  static const _kDiaryChapterSize = 'as_diary_chapter_size';
  static const _kDiaryShowPreview = 'as_diary_show_preview';
  static const _kDiaryShowProgress = 'as_diary_show_progress';
  static const _kDiaryReadingSize = 'as_diary_reading_size';
  static const _kDiaryLineHeight = 'as_diary_line_height';
  static const _kDiaryShowToolbar = 'as_diary_show_toolbar';
  static const _kDiaryEditorPadding = 'as_diary_editor_padding';
  static const _kSandboxHeaderShow = 'as_sandbox_header_show';
  static const _kSandboxHeaderSize = 'as_sandbox_header_size';
  static const _kSandboxShowSpark = 'as_sandbox_show_spark';
  static const _kSandboxTabSize = 'as_sandbox_tab_size';
  static const _kSandboxShowFab = 'as_sandbox_show_fab';
  static const _kSandboxShowDeorum = 'as_sandbox_show_deorum';
  static const _kSandboxShowDecode = 'as_sandbox_show_decode';
  static const _kSandboxWorldCardSize = 'as_sandbox_world_card_size';
  static const _kSandboxShowWorldGenre = 'as_sandbox_show_world_genre';
  static const _kSandboxShowWorldOverview = 'as_sandbox_show_world_overview';
  static const _kSandboxShowWorldMapPill = 'as_sandbox_show_world_map_pill';
  static const _kSandboxShowWorldCounts = 'as_sandbox_show_world_counts';
  static const _kSandboxShowWorldDraft = 'as_sandbox_show_world_draft';
  static const _kSandboxCharCardSize = 'as_sandbox_char_card_size';
  static const _kSandboxShowCharPronouns = 'as_sandbox_show_char_pronouns';
  static const _kSandboxShowCharPersonality = 'as_sandbox_show_char_personality';
  static const _kSandboxShowCharWorld = 'as_sandbox_show_char_world';
  static const _kSandboxShowCharTypeBadge = 'as_sandbox_show_char_type_badge';
  static const _kSandboxShowCharFrame = 'as_sandbox_show_char_frame';
  static const _kSandboxEditorPadding = 'as_sandbox_editor_padding';
  static const _kSandboxShowWorldMapUpload = 'as_sandbox_show_world_map_upload';
  static const _kSandboxShowWorldGenreField = 'as_sandbox_show_world_genre_field';
  static const _kSandboxShowWorldToneField = 'as_sandbox_show_world_tone_field';
  static const _kSandboxListCardSize = 'as_sandbox_list_card_size';
  static const _kSandboxShowCharAvatar = 'as_sandbox_show_char_avatar';
  static const _kSandboxShowCharAccent = 'as_sandbox_show_char_accent';
  static const _kSandboxShowCharTypeToggle = 'as_sandbox_show_char_type_toggle';
  static const _kSandboxShowCharWorldRow = 'as_sandbox_show_char_world_row';
  static const _kSandboxShowCharAppearance = 'as_sandbox_show_char_appearance';
  static const _kSandboxShowCharPersonalityField = 'as_sandbox_show_char_personality_field';
  static const _kSandboxShowCharBackstory = 'as_sandbox_show_char_backstory';
  static const _kSandboxShowCharRelationships = 'as_sandbox_show_char_relationships';
  static const _kSandboxShowCharNotes = 'as_sandbox_show_char_notes';
  static const _kSandboxSparkTextSize = 'as_sandbox_spark_text_size';
  static const _kSandboxShowSparkLabels = 'as_sandbox_show_spark_labels';
  static const _kSandboxSparkPadding = 'as_sandbox_spark_padding';
  static const _kProfileGlowEnabled = 'as_profile_glow_enabled';
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
  // EDIT 9a: Glow is now its own thing, not a border style.
  // Frame colour drives the AnimatedBorder pattern, glow colour drives
  // only the soft halo. Separate so you can contrast them, e.g.
  // white Runes on a black glow.
  bool _profileGlowEnabled = false;
  Color _profileGlowColor = Colors.black;
  // Phase 1 - Level 2 customization
  bool _showLogo = true;
  String _logoText = 'LORE';
  bool _showFloatingButton = true;
  bool _gyroEnabled = true;
  Color _floatingMenuColor = const Color(0xFFC9A96E);
  String _fanCardSize = 'normal';
  Set<String> _hiddenBlocks = {};
  bool _rpHeaderShow = true;
  String _rpHeaderSize = 'M';
  Color _rpHeaderAccent = const Color(0xFFD1D41E);
  String _rpMoodOverride = 'off';
  Color _rpBgColor = const Color(0xFF050810);
  bool _rpParticlesOn = true;
  String _rpPostSize = 'M';
  String _rpDisplayMode = 'cards';
  String _rpEditorSize = 'M';
  bool _rpShowLogSidebar = true;
  bool _rpShowToolsSidebar = true;
  bool _rpShowOoc = true;
  bool _rpOocBadgeOn = true;
  bool _preludeHeaderShow = true;
  String _preludeHeaderSize = 'M';
  Color _preludeHeaderAccent = const Color(0xFF7AB8D4);
  String _preludeBgMode = 'global';
  Color _preludeBgColor = const Color(0xFF050810);
  String _preludeMsgSize = 'M';
  String _preludeDensity = 'comfortable';
  String _preludeMsgStyle = 'cards';
  bool _preludeShowTimestamp = true;
  bool _preludeShowAuthor = true;
  bool _preludeShowPinLabel = true;
  Color _preludePinRule = const Color(0xFFD4614A);
  Color _preludePinCharacter = const Color(0xFF9B6FD4);
  Color _preludePinWorld = const Color(0xFF7AB8D4);
  Color _preludePinPlot = const Color(0xFFC9A96E);
  String _preludePinFilter = 'all';
  String _preludeInputSize = 'M';
  String _preludeChoiceSize = 'M';
  bool _diaryHeaderShow = true;
  String _diaryHeaderSize = 'M';
  String _diaryBgMode = 'global';
  Color _diaryBgColor = const Color(0xFF050810);
  bool _diaryShowReminder = true;
  bool _diaryShowStreak = true;
  String _diaryCardSize = 'M';
  bool _diaryShowAuthor = true;
  bool _diaryShowStats = true;
  bool _diaryShowAvatars = true;
  bool _diaryEntryHeaderShow = true;
  String _diaryEntryHeaderSize = 'M';
  bool _diaryShowGenreBar = true;
  String _diaryChapterSize = 'M';
  bool _diaryShowPreview = true;
  bool _diaryShowProgress = true;
  String _diaryReadingSize = 'M';
  String _diaryLineHeight = 'comfortable';
  bool _diaryShowToolbar = true;
  String _diaryEditorPadding = 'comfortable';
  bool _sandboxHeaderShow = true;
  String _sandboxHeaderSize = 'M';
  bool _sandboxShowSpark = true;
  String _sandboxTabSize = 'M';
  bool _sandboxShowFab = true;
  bool _sandboxShowDeorum = true;
  bool _sandboxShowDecode = true;
  String _sandboxWorldCardSize = 'M';
  bool _sandboxShowWorldGenre = true;
  bool _sandboxShowWorldOverview = true;
  bool _sandboxShowWorldMapPill = true;
  bool _sandboxShowWorldCounts = true;
  bool _sandboxShowWorldDraft = true;
  String _sandboxCharCardSize = 'M';
  bool _sandboxShowCharPronouns = true;
  bool _sandboxShowCharPersonality = true;
  bool _sandboxShowCharWorld = true;
  bool _sandboxShowCharTypeBadge = true;
  bool _sandboxShowCharFrame = true;
  String _sandboxEditorPadding = 'comfortable';
  bool _sandboxShowWorldMapUpload = true;
  bool _sandboxShowWorldGenreField = true;
  bool _sandboxShowWorldToneField = true;
  String _sandboxListCardSize = 'M';
  bool _sandboxShowCharAvatar = true;
  bool _sandboxShowCharAccent = true;
  bool _sandboxShowCharTypeToggle = true;
  bool _sandboxShowCharWorldRow = true;
  bool _sandboxShowCharAppearance = true;
  bool _sandboxShowCharPersonalityField = true;
  bool _sandboxShowCharBackstory = true;
  bool _sandboxShowCharRelationships = true;
  bool _sandboxShowCharNotes = true;
  String _sandboxSparkTextSize = 'M';
  bool _sandboxShowSparkLabels = true;
  String _sandboxSparkPadding = 'comfortable';
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
    _rpHeaderShow = p.getBool(_kRpHeaderShow) ?? true;
    _rpHeaderSize = p.getString(_kRpHeaderSize) ?? 'M';
    final rpHA = p.getInt(_kRpHeaderAccent); if (rpHA != null) _rpHeaderAccent = Color(rpHA);
    _rpMoodOverride = p.getString(_kRpMoodOverride) ?? 'off';
    final rpBg = p.getInt(_kRpBgColor); if (rpBg != null) _rpBgColor = Color(rpBg);
    _rpParticlesOn = p.getBool(_kRpParticlesOn) ?? true;
    _rpPostSize = p.getString(_kRpPostSize) ?? 'M';
    _rpDisplayMode = p.getString(_kRpDisplayMode) ?? 'cards';
    _rpEditorSize = p.getString(_kRpEditorSize) ?? 'M';
    _rpShowLogSidebar = p.getBool(_kRpShowLogSidebar) ?? true;
    _rpShowToolsSidebar = p.getBool(_kRpShowToolsSidebar) ?? true;
    _rpShowOoc = p.getBool(_kRpShowOoc) ?? true;
    _rpOocBadgeOn = p.getBool(_kRpOocBadgeOn) ?? true;
    _preludeHeaderShow = p.getBool(_kPreludeHeaderShow) ?? true;
    _preludeHeaderSize = p.getString(_kPreludeHeaderSize) ?? 'M';
    final preHA = p.getInt(_kPreludeHeaderAccent); if (preHA != null) _preludeHeaderAccent = Color(preHA);
    _preludeBgMode = p.getString(_kPreludeBgMode) ?? 'global';
    final preBg = p.getInt(_kPreludeBgColor); if (preBg != null) _preludeBgColor = Color(preBg);
    _preludeMsgSize = p.getString(_kPreludeMsgSize) ?? 'M';
    _preludeDensity = p.getString(_kPreludeDensity) ?? 'comfortable';
    _preludeMsgStyle = p.getString(_kPreludeMsgStyle) ?? 'cards';
    _preludeShowTimestamp = p.getBool(_kPreludeShowTimestamp) ?? true;
    _preludeShowAuthor = p.getBool(_kPreludeShowAuthor) ?? true;
    _preludeShowPinLabel = p.getBool(_kPreludeShowPinLabel) ?? true;
    final preRule = p.getInt(_kPreludePinRule); if (preRule != null) _preludePinRule = Color(preRule);
    final preChar = p.getInt(_kPreludePinCharacter); if (preChar != null) _preludePinCharacter = Color(preChar);
    final preWorld = p.getInt(_kPreludePinWorld); if (preWorld != null) _preludePinWorld = Color(preWorld);
    final prePlot = p.getInt(_kPreludePinPlot); if (prePlot != null) _preludePinPlot = Color(prePlot);
    _preludePinFilter = p.getString(_kPreludePinFilter) ?? 'all';
    _preludeInputSize = p.getString(_kPreludeInputSize) ?? 'M';
    _preludeChoiceSize = p.getString(_kPreludeChoiceSize) ?? 'M';
    _diaryHeaderShow = p.getBool(_kDiaryHeaderShow) ?? true;
    _diaryHeaderSize = p.getString(_kDiaryHeaderSize) ?? 'M';
    _diaryBgMode = p.getString(_kDiaryBgMode) ?? 'global';
    final dBg = p.getInt(_kDiaryBgColor); if (dBg != null) _diaryBgColor = Color(dBg);
    _diaryShowReminder = p.getBool(_kDiaryShowReminder) ?? true;
    _diaryShowStreak = p.getBool(_kDiaryShowStreak) ?? true;
    _diaryCardSize = p.getString(_kDiaryCardSize) ?? 'M';
    _diaryShowAuthor = p.getBool(_kDiaryShowAuthor) ?? true;
    _diaryShowStats = p.getBool(_kDiaryShowStats) ?? true;
    _diaryShowAvatars = p.getBool(_kDiaryShowAvatars) ?? true;
    _diaryEntryHeaderShow = p.getBool(_kDiaryEntryHeaderShow) ?? true;
    _diaryEntryHeaderSize = p.getString(_kDiaryEntryHeaderSize) ?? 'M';
    _diaryShowGenreBar = p.getBool(_kDiaryShowGenreBar) ?? true;
    _diaryChapterSize = p.getString(_kDiaryChapterSize) ?? 'M';
    _diaryShowPreview = p.getBool(_kDiaryShowPreview) ?? true;
    _diaryShowProgress = p.getBool(_kDiaryShowProgress) ?? true;
    _diaryReadingSize = p.getString(_kDiaryReadingSize) ?? 'M';
    _diaryLineHeight = p.getString(_kDiaryLineHeight) ?? 'comfortable';
    _diaryShowToolbar = p.getBool(_kDiaryShowToolbar) ?? true;
    _diaryEditorPadding = p.getString(_kDiaryEditorPadding) ?? 'comfortable';
    _sandboxHeaderShow = p.getBool(_kSandboxHeaderShow) ?? true;
    _sandboxHeaderSize = p.getString(_kSandboxHeaderSize) ?? 'M';
    _sandboxShowSpark = p.getBool(_kSandboxShowSpark) ?? true;
    _sandboxTabSize = p.getString(_kSandboxTabSize) ?? 'M';
    _sandboxShowFab = p.getBool(_kSandboxShowFab) ?? true;
    _sandboxShowDeorum = p.getBool(_kSandboxShowDeorum) ?? true;
    _sandboxShowDecode = p.getBool(_kSandboxShowDecode) ?? true;
    _sandboxWorldCardSize = p.getString(_kSandboxWorldCardSize) ?? 'M';
    _sandboxShowWorldGenre = p.getBool(_kSandboxShowWorldGenre) ?? true;
    _sandboxShowWorldOverview = p.getBool(_kSandboxShowWorldOverview) ?? true;
    _sandboxShowWorldMapPill = p.getBool(_kSandboxShowWorldMapPill) ?? true;
    _sandboxShowWorldCounts = p.getBool(_kSandboxShowWorldCounts) ?? true;
    _sandboxShowWorldDraft = p.getBool(_kSandboxShowWorldDraft) ?? true;
    _sandboxCharCardSize = p.getString(_kSandboxCharCardSize) ?? 'M';
    _sandboxShowCharPronouns = p.getBool(_kSandboxShowCharPronouns) ?? true;
    _sandboxShowCharPersonality = p.getBool(_kSandboxShowCharPersonality) ?? true;
    _sandboxShowCharWorld = p.getBool(_kSandboxShowCharWorld) ?? true;
    _sandboxShowCharTypeBadge = p.getBool(_kSandboxShowCharTypeBadge) ?? true;
    _sandboxShowCharFrame = p.getBool(_kSandboxShowCharFrame) ?? true;
    _sandboxEditorPadding = p.getString(_kSandboxEditorPadding) ?? 'comfortable';
    _sandboxShowWorldMapUpload = p.getBool(_kSandboxShowWorldMapUpload) ?? true;
    _sandboxShowWorldGenreField = p.getBool(_kSandboxShowWorldGenreField) ?? true;
    _sandboxShowWorldToneField = p.getBool(_kSandboxShowWorldToneField) ?? true;
    _sandboxListCardSize = p.getString(_kSandboxListCardSize) ?? 'M';
    _sandboxShowCharAvatar = p.getBool(_kSandboxShowCharAvatar) ?? true;
    _sandboxShowCharAccent = p.getBool(_kSandboxShowCharAccent) ?? true;
    _sandboxShowCharTypeToggle = p.getBool(_kSandboxShowCharTypeToggle) ?? true;
    _sandboxShowCharWorldRow = p.getBool(_kSandboxShowCharWorldRow) ?? true;
    _sandboxShowCharAppearance = p.getBool(_kSandboxShowCharAppearance) ?? true;
    _sandboxShowCharPersonalityField = p.getBool(_kSandboxShowCharPersonalityField) ?? true;
    _sandboxShowCharBackstory = p.getBool(_kSandboxShowCharBackstory) ?? true;
    _sandboxShowCharRelationships = p.getBool(_kSandboxShowCharRelationships) ?? true;
    _sandboxShowCharNotes = p.getBool(_kSandboxShowCharNotes) ?? true;
    _sandboxSparkTextSize = p.getString(_kSandboxSparkTextSize) ?? 'M';
    _sandboxShowSparkLabels = p.getBool(_kSandboxShowSparkLabels) ?? true;
    _sandboxSparkPadding = p.getString(_kSandboxSparkPadding) ?? 'comfortable';
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
    // EDIT 9a migration: if no glow setting saved yet, inherit from the
    // old world — glow on iff old style was 'glow', glow colour = old
    // frame colour. So nobody's existing card suddenly loses its glow.
    final savedGlowEnabled = p.getBool(_kProfileGlowEnabled);
    _profileGlowEnabled = savedGlowEnabled ?? (_profileBorderStyle == 'glow');
    final savedGlowColor = p.getInt(_kProfileGlowColor);
    if (savedGlowColor != null) {
      _profileGlowColor = Color(savedGlowColor);
    } else {
      _profileGlowColor = _profileBorderColor;
    }
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
    // Glow fallback has to run AFTER the border colour is loaded,
    // otherwise it inherits the default, not your saved colour.
    if (savedGlowColor == null) {
      _profileGlowColor = _profileBorderColor;
    }

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
    'profileGlowEnabled': _profileGlowEnabled,
    'profileGlowColor': _profileGlowColor.toARGB32(),
    'showLogo': _showLogo,
    'logoText': _logoText,
    'showFloatingButton': _showFloatingButton,
    'gyroEnabled': _gyroEnabled,
    'floatingMenuColor': _floatingMenuColor.toARGB32(),
    'fanCardSize': _fanCardSize,
    'hiddenBlocks': _hiddenBlocks.toList(),
    'rpHeaderShow': _rpHeaderShow,
    'rpHeaderSize': _rpHeaderSize,
    'rpHeaderAccent': _rpHeaderAccent.toARGB32(),
    'rpMoodOverride': _rpMoodOverride,
    'rpBgColor': _rpBgColor.toARGB32(),
    'rpParticlesOn': _rpParticlesOn,
    'rpPostSize': _rpPostSize,
    'rpDisplayMode': _rpDisplayMode,
    'rpEditorSize': _rpEditorSize,
    'rpShowLogSidebar': _rpShowLogSidebar,
    'rpShowToolsSidebar': _rpShowToolsSidebar,
    'rpShowOoc': _rpShowOoc,
    'rpOocBadgeOn': _rpOocBadgeOn,
    'preludeHeaderShow': _preludeHeaderShow,
    'preludeHeaderSize': _preludeHeaderSize,
    'preludeHeaderAccent': _preludeHeaderAccent.toARGB32(),
    'preludeBgMode': _preludeBgMode,
    'preludeBgColor': _preludeBgColor.toARGB32(),
    'preludeMsgSize': _preludeMsgSize,
    'preludeDensity': _preludeDensity,
    'preludeMsgStyle': _preludeMsgStyle,
    'preludeShowTimestamp': _preludeShowTimestamp,
    'preludeShowAuthor': _preludeShowAuthor,
    'preludeShowPinLabel': _preludeShowPinLabel,
    'preludePinRule': _preludePinRule.toARGB32(),
    'preludePinCharacter': _preludePinCharacter.toARGB32(),
    'preludePinWorld': _preludePinWorld.toARGB32(),
    'preludePinPlot': _preludePinPlot.toARGB32(),
    'preludePinFilter': _preludePinFilter,
    'preludeInputSize': _preludeInputSize,
    'preludeChoiceSize': _preludeChoiceSize,
    'diaryHeaderShow': _diaryHeaderShow,
    'diaryHeaderSize': _diaryHeaderSize,
    'diaryBgMode': _diaryBgMode,
    'diaryBgColor': _diaryBgColor.toARGB32(),
    'diaryShowReminder': _diaryShowReminder,
    'diaryShowStreak': _diaryShowStreak,
    'diaryCardSize': _diaryCardSize,
    'diaryShowAuthor': _diaryShowAuthor,
    'diaryShowStats': _diaryShowStats,
    'diaryShowAvatars': _diaryShowAvatars,
    'diaryEntryHeaderShow': _diaryEntryHeaderShow,
    'diaryEntryHeaderSize': _diaryEntryHeaderSize,
    'diaryShowGenreBar': _diaryShowGenreBar,
    'diaryChapterSize': _diaryChapterSize,
    'diaryShowPreview': _diaryShowPreview,
    'diaryShowProgress': _diaryShowProgress,
    'diaryReadingSize': _diaryReadingSize,
    'diaryLineHeight': _diaryLineHeight,
    'diaryShowToolbar': _diaryShowToolbar,
    'diaryEditorPadding': _diaryEditorPadding,
    'sandboxHeaderShow': _sandboxHeaderShow,
    'sandboxHeaderSize': _sandboxHeaderSize,
    'sandboxShowSpark': _sandboxShowSpark,
    'sandboxTabSize': _sandboxTabSize,
    'sandboxShowFab': _sandboxShowFab,
    'sandboxShowDeorum': _sandboxShowDeorum,
    'sandboxShowDecode': _sandboxShowDecode,
    'sandboxWorldCardSize': _sandboxWorldCardSize,
    'sandboxShowWorldGenre': _sandboxShowWorldGenre,
    'sandboxShowWorldOverview': _sandboxShowWorldOverview,
    'sandboxShowWorldMapPill': _sandboxShowWorldMapPill,
    'sandboxShowWorldCounts': _sandboxShowWorldCounts,
    'sandboxShowWorldDraft': _sandboxShowWorldDraft,
    'sandboxCharCardSize': _sandboxCharCardSize,
    'sandboxShowCharPronouns': _sandboxShowCharPronouns,
    'sandboxShowCharPersonality': _sandboxShowCharPersonality,
    'sandboxShowCharWorld': _sandboxShowCharWorld,
    'sandboxShowCharTypeBadge': _sandboxShowCharTypeBadge,
    'sandboxShowCharFrame': _sandboxShowCharFrame,
    'sandboxEditorPadding': _sandboxEditorPadding,
    'sandboxShowWorldMapUpload': _sandboxShowWorldMapUpload,
    'sandboxShowWorldGenreField': _sandboxShowWorldGenreField,
    'sandboxShowWorldToneField': _sandboxShowWorldToneField,
    'sandboxListCardSize': _sandboxListCardSize,
    'sandboxShowCharAvatar': _sandboxShowCharAvatar,
    'sandboxShowCharAccent': _sandboxShowCharAccent,
    'sandboxShowCharTypeToggle': _sandboxShowCharTypeToggle,
    'sandboxShowCharWorldRow': _sandboxShowCharWorldRow,
    'sandboxShowCharAppearance': _sandboxShowCharAppearance,
    'sandboxShowCharPersonalityField': _sandboxShowCharPersonalityField,
    'sandboxShowCharBackstory': _sandboxShowCharBackstory,
    'sandboxShowCharRelationships': _sandboxShowCharRelationships,
    'sandboxShowCharNotes': _sandboxShowCharNotes,
    'sandboxSparkTextSize': _sandboxSparkTextSize,
    'sandboxShowSparkLabels': _sandboxShowSparkLabels,
    'sandboxSparkPadding': _sandboxSparkPadding,
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
    'notifRpPost': _notifRpPost,
    'notifOoc': _notifOoc,
    'notifBrainstorm': _notifBrainstorm,
    'discoverable': _discoverable,
    'enterToSend': _enterToSend,
    'homeOrder': _homeOrder,
  };

  void _applyCloudJson(Map<String, dynamic> j) {
    _cardBorderEffects = j['cardBorderEffects'] as bool? ?? _cardBorderEffects;
    _parchmentMode = j['parchmentMode'] as bool? ?? _parchmentMode;
    _textSize = j['textSize'] as String? ?? _textSize;
    _orientation = j['orientation'] as String? ?? _orientation;
    _soundEnabled = j['soundEnabled'] as bool? ?? _soundEnabled;
    _profileBorderStyle =
        j['profileBorderStyle'] as String? ?? _profileBorderStyle;
    _profileGlowEnabled =
        j['profileGlowEnabled'] as bool? ?? _profileGlowEnabled;
    _showLogo = j['showLogo'] as bool? ?? _showLogo;
    _logoText = j['logoText'] as String? ?? _logoText;
    _showFloatingButton = j['showFloatingButton'] as bool? ?? _showFloatingButton;
    _gyroEnabled = j['gyroEnabled'] as bool? ?? _gyroEnabled;
    if (j['floatingMenuColor'] is int) {
      _floatingMenuColor = Color(j['floatingMenuColor'] as int);
    }
    if (j['fanCardSize'] is String) {
      _fanCardSize = j['fanCardSize'] as String;
    }
    if (j['hiddenBlocks'] is List) {
      _hiddenBlocks = Set<String>.from((j['hiddenBlocks'] as List).map((e) => e.toString()));
    _rpHeaderShow = j['rpHeaderShow'] as bool? ?? _rpHeaderShow;
    _rpHeaderSize = j['rpHeaderSize'] as String? ?? _rpHeaderSize;
    if (j['rpHeaderAccent'] is int) _rpHeaderAccent = Color(j['rpHeaderAccent'] as int);
    _rpMoodOverride = j['rpMoodOverride'] as String? ?? _rpMoodOverride;
    if (j['rpBgColor'] is int) _rpBgColor = Color(j['rpBgColor'] as int);
    _rpParticlesOn = j['rpParticlesOn'] as bool? ?? _rpParticlesOn;
    _rpPostSize = j['rpPostSize'] as String? ?? _rpPostSize;
    _rpDisplayMode = j['rpDisplayMode'] as String? ?? _rpDisplayMode;
    _rpEditorSize = j['rpEditorSize'] as String? ?? _rpEditorSize;
    _rpShowLogSidebar = j['rpShowLogSidebar'] as bool? ?? _rpShowLogSidebar;
    _rpShowToolsSidebar = j['rpShowToolsSidebar'] as bool? ?? _rpShowToolsSidebar;
    _rpShowOoc = j['rpShowOoc'] as bool? ?? _rpShowOoc;
    _rpOocBadgeOn = j['rpOocBadgeOn'] as bool? ?? _rpOocBadgeOn;
    _preludeHeaderShow = j['preludeHeaderShow'] as bool? ?? _preludeHeaderShow;
    _preludeHeaderSize = j['preludeHeaderSize'] as String? ?? _preludeHeaderSize;
    if (j['preludeHeaderAccent'] is int) _preludeHeaderAccent = Color(j['preludeHeaderAccent'] as int);
    _preludeBgMode = j['preludeBgMode'] as String? ?? _preludeBgMode;
    if (j['preludeBgColor'] is int) _preludeBgColor = Color(j['preludeBgColor'] as int);
    _preludeMsgSize = j['preludeMsgSize'] as String? ?? _preludeMsgSize;
    _preludeDensity = j['preludeDensity'] as String? ?? _preludeDensity;
    _preludeMsgStyle = j['preludeMsgStyle'] as String? ?? _preludeMsgStyle;
    _preludeShowTimestamp = j['preludeShowTimestamp'] as bool? ?? _preludeShowTimestamp;
    _preludeShowAuthor = j['preludeShowAuthor'] as bool? ?? _preludeShowAuthor;
    _preludeShowPinLabel = j['preludeShowPinLabel'] as bool? ?? _preludeShowPinLabel;
    if (j['preludePinRule'] is int) _preludePinRule = Color(j['preludePinRule'] as int);
    if (j['preludePinCharacter'] is int) _preludePinCharacter = Color(j['preludePinCharacter'] as int);
    if (j['preludePinWorld'] is int) _preludePinWorld = Color(j['preludePinWorld'] as int);
    if (j['preludePinPlot'] is int) _preludePinPlot = Color(j['preludePinPlot'] as int);
    _preludePinFilter = j['preludePinFilter'] as String? ?? _preludePinFilter;
    _preludeInputSize = j['preludeInputSize'] as String? ?? _preludeInputSize;
    _preludeChoiceSize = j['preludeChoiceSize'] as String? ?? _preludeChoiceSize;
    _diaryHeaderShow = j['diaryHeaderShow'] as bool? ?? _diaryHeaderShow;
    _diaryHeaderSize = j['diaryHeaderSize'] as String? ?? _diaryHeaderSize;
    _diaryBgMode = j['diaryBgMode'] as String? ?? _diaryBgMode;
    if (j['diaryBgColor'] is int) _diaryBgColor = Color(j['diaryBgColor'] as int);
    _diaryShowReminder = j['diaryShowReminder'] as bool? ?? _diaryShowReminder;
    _diaryShowStreak = j['diaryShowStreak'] as bool? ?? _diaryShowStreak;
    _diaryCardSize = j['diaryCardSize'] as String? ?? _diaryCardSize;
    _diaryShowAuthor = j['diaryShowAuthor'] as bool? ?? _diaryShowAuthor;
    _diaryShowStats = j['diaryShowStats'] as bool? ?? _diaryShowStats;
    _diaryShowAvatars = j['diaryShowAvatars'] as bool? ?? _diaryShowAvatars;
    _diaryEntryHeaderShow = j['diaryEntryHeaderShow'] as bool? ?? _diaryEntryHeaderShow;
    _diaryEntryHeaderSize = j['diaryEntryHeaderSize'] as String? ?? _diaryEntryHeaderSize;
    _diaryShowGenreBar = j['diaryShowGenreBar'] as bool? ?? _diaryShowGenreBar;
    _diaryChapterSize = j['diaryChapterSize'] as String? ?? _diaryChapterSize;
    _diaryShowPreview = j['diaryShowPreview'] as bool? ?? _diaryShowPreview;
    _diaryShowProgress = j['diaryShowProgress'] as bool? ?? _diaryShowProgress;
    _diaryReadingSize = j['diaryReadingSize'] as String? ?? _diaryReadingSize;
    _diaryLineHeight = j['diaryLineHeight'] as String? ?? _diaryLineHeight;
    _diaryShowToolbar = j['diaryShowToolbar'] as bool? ?? _diaryShowToolbar;
    _diaryEditorPadding = j['diaryEditorPadding'] as String? ?? _diaryEditorPadding;
    _sandboxHeaderShow = j['sandboxHeaderShow'] as bool? ?? _sandboxHeaderShow;
    _sandboxHeaderSize = j['sandboxHeaderSize'] as String? ?? _sandboxHeaderSize;
    _sandboxShowSpark = j['sandboxShowSpark'] as bool? ?? _sandboxShowSpark;
    _sandboxTabSize = j['sandboxTabSize'] as String? ?? _sandboxTabSize;
    _sandboxShowFab = j['sandboxShowFab'] as bool? ?? _sandboxShowFab;
    _sandboxShowDeorum = j['sandboxShowDeorum'] as bool? ?? _sandboxShowDeorum;
    _sandboxShowDecode = j['sandboxShowDecode'] as bool? ?? _sandboxShowDecode;
    _sandboxWorldCardSize = j['sandboxWorldCardSize'] as String? ?? _sandboxWorldCardSize;
    _sandboxShowWorldGenre = j['sandboxShowWorldGenre'] as bool? ?? _sandboxShowWorldGenre;
    _sandboxShowWorldOverview = j['sandboxShowWorldOverview'] as bool? ?? _sandboxShowWorldOverview;
    _sandboxShowWorldMapPill = j['sandboxShowWorldMapPill'] as bool? ?? _sandboxShowWorldMapPill;
    _sandboxShowWorldCounts = j['sandboxShowWorldCounts'] as bool? ?? _sandboxShowWorldCounts;
    _sandboxShowWorldDraft = j['sandboxShowWorldDraft'] as bool? ?? _sandboxShowWorldDraft;
    _sandboxCharCardSize = j['sandboxCharCardSize'] as String? ?? _sandboxCharCardSize;
    _sandboxShowCharPronouns = j['sandboxShowCharPronouns'] as bool? ?? _sandboxShowCharPronouns;
    _sandboxShowCharPersonality = j['sandboxShowCharPersonality'] as bool? ?? _sandboxShowCharPersonality;
    _sandboxShowCharWorld = j['sandboxShowCharWorld'] as bool? ?? _sandboxShowCharWorld;
    _sandboxShowCharTypeBadge = j['sandboxShowCharTypeBadge'] as bool? ?? _sandboxShowCharTypeBadge;
    _sandboxShowCharFrame = j['sandboxShowCharFrame'] as bool? ?? _sandboxShowCharFrame;
    _sandboxEditorPadding = j['sandboxEditorPadding'] as String? ?? _sandboxEditorPadding;
    _sandboxShowWorldMapUpload = j['sandboxShowWorldMapUpload'] as bool? ?? _sandboxShowWorldMapUpload;
    _sandboxShowWorldGenreField = j['sandboxShowWorldGenreField'] as bool? ?? _sandboxShowWorldGenreField;
    _sandboxShowWorldToneField = j['sandboxShowWorldToneField'] as bool? ?? _sandboxShowWorldToneField;
    _sandboxListCardSize = j['sandboxListCardSize'] as String? ?? _sandboxListCardSize;
    _sandboxShowCharAvatar = j['sandboxShowCharAvatar'] as bool? ?? _sandboxShowCharAvatar;
    _sandboxShowCharAccent = j['sandboxShowCharAccent'] as bool? ?? _sandboxShowCharAccent;
    _sandboxShowCharTypeToggle = j['sandboxShowCharTypeToggle'] as bool? ?? _sandboxShowCharTypeToggle;
    _sandboxShowCharWorldRow = j['sandboxShowCharWorldRow'] as bool? ?? _sandboxShowCharWorldRow;
    _sandboxShowCharAppearance = j['sandboxShowCharAppearance'] as bool? ?? _sandboxShowCharAppearance;
    _sandboxShowCharPersonalityField = j['sandboxShowCharPersonalityField'] as bool? ?? _sandboxShowCharPersonalityField;
    _sandboxShowCharBackstory = j['sandboxShowCharBackstory'] as bool? ?? _sandboxShowCharBackstory;
    _sandboxShowCharRelationships = j['sandboxShowCharRelationships'] as bool? ?? _sandboxShowCharRelationships;
    _sandboxShowCharNotes = j['sandboxShowCharNotes'] as bool? ?? _sandboxShowCharNotes;
    _sandboxSparkTextSize = j['sandboxSparkTextSize'] as String? ?? _sandboxSparkTextSize;
    _sandboxShowSparkLabels = j['sandboxShowSparkLabels'] as bool? ?? _sandboxShowSparkLabels;
    _sandboxSparkPadding = j['sandboxSparkPadding'] as String? ?? _sandboxSparkPadding;
    }
    if (j['profileGlowColor'] is int) {
      _profileGlowColor = Color(j['profileGlowColor'] as int);
    }
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
    _notifRpPost = j['notifRpPost'] as bool? ?? _notifRpPost;
    _notifOoc = j['notifOoc'] as bool? ?? _notifOoc;
    _notifBrainstorm = j['notifBrainstorm'] as bool? ?? _notifBrainstorm;
    _discoverable = j['discoverable'] as bool? ?? _discoverable;

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
    await p.setBool(_kProfileGlowEnabled, _profileGlowEnabled);
    await p.setInt(_kProfileGlowColor, _profileGlowColor.toARGB32());
    await p.setBool(_kShowLogo, _showLogo);
    await p.setString(_kLogoText, _logoText);
    await p.setBool(_kShowFloatingButton, _showFloatingButton);
    await p.setBool(_kGyroEnabled, _gyroEnabled);
    await p.setInt(_kFloatingMenuColor, _floatingMenuColor.toARGB32());
    await p.setStringList(_kHiddenBlocks, _hiddenBlocks.toList());
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
  bool get profileGlowEnabled => _profileGlowEnabled;
  Color get profileGlowColor => _profileGlowColor;
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
        return 20.0;
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

  Future<void> setProfileGlowEnabled(bool v) async {
    _profileGlowEnabled = v;
    (await SharedPreferences.getInstance()).setBool(_kProfileGlowEnabled, v);
    _touch();
    notifyListeners();
  }

  Future<void> setProfileGlowColor(Color v) async {
    _profileGlowColor = v;
    (await SharedPreferences.getInstance()).setInt(
      _kProfileGlowColor,
      v.toARGB32(),
    );
    _touch();
    notifyListeners();
  }

  // --- Phase 1: Level 2 customization ---
  bool get showLogo => _showLogo;
  String get logoText => _logoText;
  bool get showFloatingButton => _showFloatingButton;
  bool get gyroEnabled => _gyroEnabled;
  Color get floatingMenuColor => _floatingMenuColor;
  String get fanCardSize => _fanCardSize;
  double get fanCardSizePx {
    switch (_fanCardSize) {
      case 'small':
        return 64;
      case 'large':
        return 100;
      default:
        return 82;
    }
  }
  Set<String> get hiddenBlocks => Set.unmodifiable(_hiddenBlocks);
  bool get rpHeaderShow => _rpHeaderShow;
  String get rpHeaderSize => _rpHeaderSize;
  Color get rpHeaderAccent => _rpHeaderAccent;
  String get rpMoodOverride => _rpMoodOverride;
  Color get rpBgColor => _rpBgColor;
  bool get rpParticlesOn => _rpParticlesOn;
  String get rpPostSize => _rpPostSize;
  String get rpDisplayMode => _rpDisplayMode;
  String get rpEditorSize => _rpEditorSize;
  bool get rpShowLogSidebar => _rpShowLogSidebar;
  bool get rpShowToolsSidebar => _rpShowToolsSidebar;
  bool get rpShowOoc => _rpShowOoc;
  bool get rpOocBadgeOn => _rpOocBadgeOn;
  bool get preludeHeaderShow => _preludeHeaderShow;
  String get preludeHeaderSize => _preludeHeaderSize;
  Color get preludeHeaderAccent => _preludeHeaderAccent;
  String get preludeBgMode => _preludeBgMode;
  Color get preludeBgColor => _preludeBgColor;
  String get preludeMsgSize => _preludeMsgSize;
  String get preludeDensity => _preludeDensity;
  String get preludeMsgStyle => _preludeMsgStyle;
  bool get preludeShowTimestamp => _preludeShowTimestamp;
  bool get preludeShowAuthor => _preludeShowAuthor;
  bool get preludeShowPinLabel => _preludeShowPinLabel;
  Color get preludePinRule => _preludePinRule;
  Color get preludePinCharacter => _preludePinCharacter;
  Color get preludePinWorld => _preludePinWorld;
  Color get preludePinPlot => _preludePinPlot;
  String get preludePinFilter => _preludePinFilter;
  String get preludeInputSize => _preludeInputSize;
  String get preludeChoiceSize => _preludeChoiceSize;
  bool get diaryHeaderShow => _diaryHeaderShow;
  String get diaryHeaderSize => _diaryHeaderSize;
  String get diaryBgMode => _diaryBgMode;
  Color get diaryBgColor => _diaryBgColor;
  bool get diaryShowReminder => _diaryShowReminder;
  bool get diaryShowStreak => _diaryShowStreak;
  String get diaryCardSize => _diaryCardSize;
  bool get diaryShowAuthor => _diaryShowAuthor;
  bool get diaryShowStats => _diaryShowStats;
  bool get diaryShowAvatars => _diaryShowAvatars;
  bool get diaryEntryHeaderShow => _diaryEntryHeaderShow;
  String get diaryEntryHeaderSize => _diaryEntryHeaderSize;
  bool get diaryShowGenreBar => _diaryShowGenreBar;
  String get diaryChapterSize => _diaryChapterSize;
  bool get diaryShowPreview => _diaryShowPreview;
  bool get diaryShowProgress => _diaryShowProgress;
  String get diaryReadingSize => _diaryReadingSize;
  String get diaryLineHeight => _diaryLineHeight;
  bool get diaryShowToolbar => _diaryShowToolbar;
  String get diaryEditorPadding => _diaryEditorPadding;
  bool get sandboxHeaderShow => _sandboxHeaderShow;
  String get sandboxHeaderSize => _sandboxHeaderSize;
  bool get sandboxShowSpark => _sandboxShowSpark;
  String get sandboxTabSize => _sandboxTabSize;
  bool get sandboxShowFab => _sandboxShowFab;
  bool get sandboxShowDeorum => _sandboxShowDeorum;
  bool get sandboxShowDecode => _sandboxShowDecode;
  String get sandboxWorldCardSize => _sandboxWorldCardSize;
  bool get sandboxShowWorldGenre => _sandboxShowWorldGenre;
  bool get sandboxShowWorldOverview => _sandboxShowWorldOverview;
  bool get sandboxShowWorldMapPill => _sandboxShowWorldMapPill;
  bool get sandboxShowWorldCounts => _sandboxShowWorldCounts;
  bool get sandboxShowWorldDraft => _sandboxShowWorldDraft;
  String get sandboxCharCardSize => _sandboxCharCardSize;
  bool get sandboxShowCharPronouns => _sandboxShowCharPronouns;
  bool get sandboxShowCharPersonality => _sandboxShowCharPersonality;
  bool get sandboxShowCharWorld => _sandboxShowCharWorld;
  bool get sandboxShowCharTypeBadge => _sandboxShowCharTypeBadge;
  bool get sandboxShowCharFrame => _sandboxShowCharFrame;
  String get sandboxEditorPadding => _sandboxEditorPadding;
  bool get sandboxShowWorldMapUpload => _sandboxShowWorldMapUpload;
  bool get sandboxShowWorldGenreField => _sandboxShowWorldGenreField;
  bool get sandboxShowWorldToneField => _sandboxShowWorldToneField;
  String get sandboxListCardSize => _sandboxListCardSize;
  bool get sandboxShowCharAvatar => _sandboxShowCharAvatar;
  bool get sandboxShowCharAccent => _sandboxShowCharAccent;
  bool get sandboxShowCharTypeToggle => _sandboxShowCharTypeToggle;
  bool get sandboxShowCharWorldRow => _sandboxShowCharWorldRow;
  bool get sandboxShowCharAppearance => _sandboxShowCharAppearance;
  bool get sandboxShowCharPersonalityField => _sandboxShowCharPersonalityField;
  bool get sandboxShowCharBackstory => _sandboxShowCharBackstory;
  bool get sandboxShowCharRelationships => _sandboxShowCharRelationships;
  bool get sandboxShowCharNotes => _sandboxShowCharNotes;
  String get sandboxSparkTextSize => _sandboxSparkTextSize;
  bool get sandboxShowSparkLabels => _sandboxShowSparkLabels;
  String get sandboxSparkPadding => _sandboxSparkPadding;
  bool isBlockHidden(String id) => _hiddenBlocks.contains(id);

  Future<void> setShowLogo(bool v) async {
    _showLogo = v;
    (await SharedPreferences.getInstance()).setBool(_kShowLogo, v);
    _touch();
    notifyListeners();
  }

  Future<void> setLogoText(String v) async {
    _logoText = v;
    (await SharedPreferences.getInstance()).setString(_kLogoText, v);
    _touch();
    notifyListeners();
  }

  Future<void> setShowFloatingButton(bool v) async {
    _showFloatingButton = v;
    (await SharedPreferences.getInstance()).setBool(_kShowFloatingButton, v);
    _touch();
    notifyListeners();
  }

  Future<void> setGyroEnabled(bool v) async {
    _gyroEnabled = v;
    (await SharedPreferences.getInstance()).setBool(_kGyroEnabled, v);
    _touch();
    notifyListeners();
  }

  Future<void> setFanCardSize(String v) async {
    _fanCardSize = v;
    (await SharedPreferences.getInstance()).setString(_kFanCardSize, v);
    notifyListeners();
  }

  Future<void> setFloatingMenuColor(Color v) async {
    _floatingMenuColor = v;
    (await SharedPreferences.getInstance()).setInt(_kFloatingMenuColor, v.toARGB32());
    _touch();
    notifyListeners();
  }

  Future<void> setBlockHidden(String id, bool hidden) async {
    if (hidden) {
      _hiddenBlocks.add(id);
    } else {
      _hiddenBlocks.remove(id);
    }
    (await SharedPreferences.getInstance()).setStringList(_kHiddenBlocks, _hiddenBlocks.toList());
    _touch();
    notifyListeners();
  }


  Future<void> setRpHeaderShow(bool v) async { _rpHeaderShow = v; (await SharedPreferences.getInstance()).setBool(_kRpHeaderShow, v); _touch(); notifyListeners(); }
  Future<void> setRpHeaderSize(String v) async { _rpHeaderSize = v; (await SharedPreferences.getInstance()).setString(_kRpHeaderSize, v); _touch(); notifyListeners(); }
  Future<void> setRpHeaderAccent(Color v) async { _rpHeaderAccent = v; (await SharedPreferences.getInstance()).setInt(_kRpHeaderAccent, v.toARGB32()); _touch(); notifyListeners(); }
  Future<void> setRpMoodOverride(String v) async { _rpMoodOverride = v; (await SharedPreferences.getInstance()).setString(_kRpMoodOverride, v); _touch(); notifyListeners(); }
  Future<void> setRpBgColor(Color v) async { _rpBgColor = v; (await SharedPreferences.getInstance()).setInt(_kRpBgColor, v.toARGB32()); _touch(); notifyListeners(); }
  Future<void> setRpParticlesOn(bool v) async { _rpParticlesOn = v; (await SharedPreferences.getInstance()).setBool(_kRpParticlesOn, v); _touch(); notifyListeners(); }
  Future<void> setRpPostSize(String v) async { _rpPostSize = v; (await SharedPreferences.getInstance()).setString(_kRpPostSize, v); _touch(); notifyListeners(); }
  Future<void> setRpDisplayMode(String v) async { _rpDisplayMode = v; (await SharedPreferences.getInstance()).setString(_kRpDisplayMode, v); _touch(); notifyListeners(); }
  Future<void> setRpEditorSize(String v) async { _rpEditorSize = v; (await SharedPreferences.getInstance()).setString(_kRpEditorSize, v); _touch(); notifyListeners(); }
  Future<void> setRpShowLogSidebar(bool v) async { _rpShowLogSidebar = v; (await SharedPreferences.getInstance()).setBool(_kRpShowLogSidebar, v); _touch(); notifyListeners(); }
  Future<void> setRpShowToolsSidebar(bool v) async { _rpShowToolsSidebar = v; (await SharedPreferences.getInstance()).setBool(_kRpShowToolsSidebar, v); _touch(); notifyListeners(); }
  Future<void> setRpShowOoc(bool v) async { _rpShowOoc = v; (await SharedPreferences.getInstance()).setBool(_kRpShowOoc, v); _touch(); notifyListeners(); }
  Future<void> setRpOocBadgeOn(bool v) async { _rpOocBadgeOn = v; (await SharedPreferences.getInstance()).setBool(_kRpOocBadgeOn, v); _touch(); notifyListeners(); }
  Future<void> setPreludeHeaderShow(bool v) async { _preludeHeaderShow = v; (await SharedPreferences.getInstance()).setBool(_kPreludeHeaderShow, v); _touch(); notifyListeners(); }
  Future<void> setPreludeHeaderSize(String v) async { _preludeHeaderSize = v; (await SharedPreferences.getInstance()).setString(_kPreludeHeaderSize, v); _touch(); notifyListeners(); }
  Future<void> setPreludeHeaderAccent(Color v) async { _preludeHeaderAccent = v; (await SharedPreferences.getInstance()).setInt(_kPreludeHeaderAccent, v.toARGB32()); _touch(); notifyListeners(); }
  Future<void> setPreludeBgMode(String v) async { _preludeBgMode = v; (await SharedPreferences.getInstance()).setString(_kPreludeBgMode, v); _touch(); notifyListeners(); }
  Future<void> setPreludeBgColor(Color v) async { _preludeBgColor = v; (await SharedPreferences.getInstance()).setInt(_kPreludeBgColor, v.toARGB32()); _touch(); notifyListeners(); }
  Future<void> setPreludeMsgSize(String v) async { _preludeMsgSize = v; (await SharedPreferences.getInstance()).setString(_kPreludeMsgSize, v); _touch(); notifyListeners(); }
  Future<void> setPreludeDensity(String v) async { _preludeDensity = v; (await SharedPreferences.getInstance()).setString(_kPreludeDensity, v); _touch(); notifyListeners(); }
  Future<void> setPreludeMsgStyle(String v) async { _preludeMsgStyle = v; (await SharedPreferences.getInstance()).setString(_kPreludeMsgStyle, v); _touch(); notifyListeners(); }
  Future<void> setPreludeShowTimestamp(bool v) async { _preludeShowTimestamp = v; (await SharedPreferences.getInstance()).setBool(_kPreludeShowTimestamp, v); _touch(); notifyListeners(); }
  Future<void> setPreludeShowAuthor(bool v) async { _preludeShowAuthor = v; (await SharedPreferences.getInstance()).setBool(_kPreludeShowAuthor, v); _touch(); notifyListeners(); }
  Future<void> setPreludeShowPinLabel(bool v) async { _preludeShowPinLabel = v; (await SharedPreferences.getInstance()).setBool(_kPreludeShowPinLabel, v); _touch(); notifyListeners(); }
  Future<void> setPreludePinRule(Color v) async { _preludePinRule = v; (await SharedPreferences.getInstance()).setInt(_kPreludePinRule, v.toARGB32()); _touch(); notifyListeners(); }
  Future<void> setPreludePinCharacter(Color v) async { _preludePinCharacter = v; (await SharedPreferences.getInstance()).setInt(_kPreludePinCharacter, v.toARGB32()); _touch(); notifyListeners(); }
  Future<void> setPreludePinWorld(Color v) async { _preludePinWorld = v; (await SharedPreferences.getInstance()).setInt(_kPreludePinWorld, v.toARGB32()); _touch(); notifyListeners(); }
  Future<void> setPreludePinPlot(Color v) async { _preludePinPlot = v; (await SharedPreferences.getInstance()).setInt(_kPreludePinPlot, v.toARGB32()); _touch(); notifyListeners(); }
  Future<void> setPreludePinFilter(String v) async { _preludePinFilter = v; (await SharedPreferences.getInstance()).setString(_kPreludePinFilter, v); _touch(); notifyListeners(); }
  Future<void> setPreludeInputSize(String v) async { _preludeInputSize = v; (await SharedPreferences.getInstance()).setString(_kPreludeInputSize, v); _touch(); notifyListeners(); }
  Future<void> setPreludeChoiceSize(String v) async { _preludeChoiceSize = v; (await SharedPreferences.getInstance()).setString(_kPreludeChoiceSize, v); _touch(); notifyListeners(); }
  Future<void> setDiaryHeaderShow(bool v) async { _diaryHeaderShow = v; (await SharedPreferences.getInstance()).setBool(_kDiaryHeaderShow, v); _touch(); notifyListeners(); }
  Future<void> setDiaryHeaderSize(String v) async { _diaryHeaderSize = v; (await SharedPreferences.getInstance()).setString(_kDiaryHeaderSize, v); _touch(); notifyListeners(); }
  Future<void> setDiaryBgMode(String v) async { _diaryBgMode = v; (await SharedPreferences.getInstance()).setString(_kDiaryBgMode, v); _touch(); notifyListeners(); }
  Future<void> setDiaryBgColor(Color v) async { _diaryBgColor = v; (await SharedPreferences.getInstance()).setInt(_kDiaryBgColor, v.toARGB32()); _touch(); notifyListeners(); }
  Future<void> setDiaryShowReminder(bool v) async { _diaryShowReminder = v; (await SharedPreferences.getInstance()).setBool(_kDiaryShowReminder, v); _touch(); notifyListeners(); }
  Future<void> setDiaryShowStreak(bool v) async { _diaryShowStreak = v; (await SharedPreferences.getInstance()).setBool(_kDiaryShowStreak, v); _touch(); notifyListeners(); }
  Future<void> setDiaryCardSize(String v) async { _diaryCardSize = v; (await SharedPreferences.getInstance()).setString(_kDiaryCardSize, v); _touch(); notifyListeners(); }
  Future<void> setDiaryShowAuthor(bool v) async { _diaryShowAuthor = v; (await SharedPreferences.getInstance()).setBool(_kDiaryShowAuthor, v); _touch(); notifyListeners(); }
  Future<void> setDiaryShowStats(bool v) async { _diaryShowStats = v; (await SharedPreferences.getInstance()).setBool(_kDiaryShowStats, v); _touch(); notifyListeners(); }
  Future<void> setDiaryShowAvatars(bool v) async { _diaryShowAvatars = v; (await SharedPreferences.getInstance()).setBool(_kDiaryShowAvatars, v); _touch(); notifyListeners(); }
  Future<void> setDiaryEntryHeaderShow(bool v) async { _diaryEntryHeaderShow = v; (await SharedPreferences.getInstance()).setBool(_kDiaryEntryHeaderShow, v); _touch(); notifyListeners(); }
  Future<void> setDiaryEntryHeaderSize(String v) async { _diaryEntryHeaderSize = v; (await SharedPreferences.getInstance()).setString(_kDiaryEntryHeaderSize, v); _touch(); notifyListeners(); }
  Future<void> setDiaryShowGenreBar(bool v) async { _diaryShowGenreBar = v; (await SharedPreferences.getInstance()).setBool(_kDiaryShowGenreBar, v); _touch(); notifyListeners(); }
  Future<void> setDiaryChapterSize(String v) async { _diaryChapterSize = v; (await SharedPreferences.getInstance()).setString(_kDiaryChapterSize, v); _touch(); notifyListeners(); }
  Future<void> setDiaryShowPreview(bool v) async { _diaryShowPreview = v; (await SharedPreferences.getInstance()).setBool(_kDiaryShowPreview, v); _touch(); notifyListeners(); }
  Future<void> setDiaryShowProgress(bool v) async { _diaryShowProgress = v; (await SharedPreferences.getInstance()).setBool(_kDiaryShowProgress, v); _touch(); notifyListeners(); }
  Future<void> setDiaryReadingSize(String v) async { _diaryReadingSize = v; (await SharedPreferences.getInstance()).setString(_kDiaryReadingSize, v); _touch(); notifyListeners(); }
  Future<void> setDiaryLineHeight(String v) async { _diaryLineHeight = v; (await SharedPreferences.getInstance()).setString(_kDiaryLineHeight, v); _touch(); notifyListeners(); }
  Future<void> setDiaryShowToolbar(bool v) async { _diaryShowToolbar = v; (await SharedPreferences.getInstance()).setBool(_kDiaryShowToolbar, v); _touch(); notifyListeners(); }
  Future<void> setDiaryEditorPadding(String v) async { _diaryEditorPadding = v; (await SharedPreferences.getInstance()).setString(_kDiaryEditorPadding, v); _touch(); notifyListeners(); }
  Future<void> setSandboxHeaderShow(bool v) async { _sandboxHeaderShow = v; (await SharedPreferences.getInstance()).setBool(_kSandboxHeaderShow, v); _touch(); notifyListeners(); }
  Future<void> setSandboxHeaderSize(String v) async { _sandboxHeaderSize = v; (await SharedPreferences.getInstance()).setString(_kSandboxHeaderSize, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowSpark(bool v) async { _sandboxShowSpark = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowSpark, v); _touch(); notifyListeners(); }
  Future<void> setSandboxTabSize(String v) async { _sandboxTabSize = v; (await SharedPreferences.getInstance()).setString(_kSandboxTabSize, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowFab(bool v) async { _sandboxShowFab = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowFab, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowDeorum(bool v) async { _sandboxShowDeorum = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowDeorum, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowDecode(bool v) async { _sandboxShowDecode = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowDecode, v); _touch(); notifyListeners(); }
  Future<void> setSandboxWorldCardSize(String v) async { _sandboxWorldCardSize = v; (await SharedPreferences.getInstance()).setString(_kSandboxWorldCardSize, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowWorldGenre(bool v) async { _sandboxShowWorldGenre = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowWorldGenre, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowWorldOverview(bool v) async { _sandboxShowWorldOverview = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowWorldOverview, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowWorldMapPill(bool v) async { _sandboxShowWorldMapPill = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowWorldMapPill, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowWorldCounts(bool v) async { _sandboxShowWorldCounts = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowWorldCounts, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowWorldDraft(bool v) async { _sandboxShowWorldDraft = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowWorldDraft, v); _touch(); notifyListeners(); }
  Future<void> setSandboxCharCardSize(String v) async { _sandboxCharCardSize = v; (await SharedPreferences.getInstance()).setString(_kSandboxCharCardSize, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowCharPronouns(bool v) async { _sandboxShowCharPronouns = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowCharPronouns, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowCharPersonality(bool v) async { _sandboxShowCharPersonality = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowCharPersonality, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowCharWorld(bool v) async { _sandboxShowCharWorld = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowCharWorld, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowCharTypeBadge(bool v) async { _sandboxShowCharTypeBadge = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowCharTypeBadge, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowCharFrame(bool v) async { _sandboxShowCharFrame = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowCharFrame, v); _touch(); notifyListeners(); }
  Future<void> setSandboxEditorPadding(String v) async { _sandboxEditorPadding = v; (await SharedPreferences.getInstance()).setString(_kSandboxEditorPadding, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowWorldMapUpload(bool v) async { _sandboxShowWorldMapUpload = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowWorldMapUpload, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowWorldGenreField(bool v) async { _sandboxShowWorldGenreField = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowWorldGenreField, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowWorldToneField(bool v) async { _sandboxShowWorldToneField = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowWorldToneField, v); _touch(); notifyListeners(); }
  Future<void> setSandboxListCardSize(String v) async { _sandboxListCardSize = v; (await SharedPreferences.getInstance()).setString(_kSandboxListCardSize, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowCharAvatar(bool v) async { _sandboxShowCharAvatar = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowCharAvatar, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowCharAccent(bool v) async { _sandboxShowCharAccent = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowCharAccent, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowCharTypeToggle(bool v) async { _sandboxShowCharTypeToggle = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowCharTypeToggle, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowCharWorldRow(bool v) async { _sandboxShowCharWorldRow = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowCharWorldRow, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowCharAppearance(bool v) async { _sandboxShowCharAppearance = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowCharAppearance, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowCharPersonalityField(bool v) async { _sandboxShowCharPersonalityField = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowCharPersonalityField, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowCharBackstory(bool v) async { _sandboxShowCharBackstory = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowCharBackstory, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowCharRelationships(bool v) async { _sandboxShowCharRelationships = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowCharRelationships, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowCharNotes(bool v) async { _sandboxShowCharNotes = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowCharNotes, v); _touch(); notifyListeners(); }
  Future<void> setSandboxSparkTextSize(String v) async { _sandboxSparkTextSize = v; (await SharedPreferences.getInstance()).setString(_kSandboxSparkTextSize, v); _touch(); notifyListeners(); }
  Future<void> setSandboxShowSparkLabels(bool v) async { _sandboxShowSparkLabels = v; (await SharedPreferences.getInstance()).setBool(_kSandboxShowSparkLabels, v); _touch(); notifyListeners(); }
  Future<void> setSandboxSparkPadding(String v) async { _sandboxSparkPadding = v; (await SharedPreferences.getInstance()).setString(_kSandboxSparkPadding, v); _touch(); notifyListeners(); }

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
    if (v != 'waves' &&
        v != 'spikes' &&
        v != 'gears' &&
        v != 'dice' &&
        v != 'swords' &&
        v != 'leaves' &&
        v != 'shields' &&
        v != 'flames' &&
        v != 'stars' &&
        v != 'runes' &&
        v != 'thorns' &&
        v != 'feathers' &&
        v != 'claws')
      return;
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
    _rpHeaderShow = true;
    _rpHeaderSize = 'M';
    _rpHeaderAccent = const Color(0xFFD1D41E);
    _rpMoodOverride = 'off';
    _rpBgColor = const Color(0xFF050810);
    _rpParticlesOn = true;
    _rpPostSize = 'M';
    _rpDisplayMode = 'cards';
    _rpEditorSize = 'M';
    _rpShowLogSidebar = true;
    _rpShowToolsSidebar = true;
    _rpShowOoc = true;
    _rpOocBadgeOn = true;
    _preludeHeaderShow = true;
    _preludeHeaderSize = 'M';
    _preludeHeaderAccent = const Color(0xFF7AB8D4);
    _preludeBgMode = 'global';
    _preludeBgColor = const Color(0xFF050810);
    _preludeMsgSize = 'M';
    _preludeDensity = 'comfortable';
    _preludeMsgStyle = 'cards';
    _preludeShowTimestamp = true;
    _preludeShowAuthor = true;
    _preludeShowPinLabel = true;
    _preludePinRule = const Color(0xFFD4614A);
    _preludePinCharacter = const Color(0xFF9B6FD4);
    _preludePinWorld = const Color(0xFF7AB8D4);
    _preludePinPlot = const Color(0xFFC9A96E);
    _preludePinFilter = 'all';
    _preludeInputSize = 'M';
    _preludeChoiceSize = 'M';
    _diaryHeaderShow = true;
    _diaryHeaderSize = 'M';
    _diaryBgMode = 'global';
    _diaryBgColor = const Color(0xFF050810);
    _diaryShowReminder = true;
    _diaryShowStreak = true;
    _diaryCardSize = 'M';
    _diaryShowAuthor = true;
    _diaryShowStats = true;
    _diaryShowAvatars = true;
    _diaryEntryHeaderShow = true;
    _diaryEntryHeaderSize = 'M';
    _diaryShowGenreBar = true;
    _diaryChapterSize = 'M';
    _diaryShowPreview = true;
    _diaryShowProgress = true;
    _diaryReadingSize = 'M';
    _diaryLineHeight = 'comfortable';
    _diaryShowToolbar = true;
    _diaryEditorPadding = 'comfortable';
    _notifNewPost = true;
    _notifInterest = true;
    _autoScroll = true;
    _oocSide = 'Right';
    _discoverable = true;
    _profileBorderStyle = 'solid';
    _profileGlowEnabled = false;
    _profileGlowColor = Colors.black;
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
    _enterToSend = false;
    _discoverable = true;
    _homeOrder = [];
    _devModeUnlocked = false;
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
    await p.remove(_kProfileGlowColor);
    await p.remove(_kProfileGlowEnabled);
    await p.remove(_kAiMood);
    await p.remove(_kRpHeaderShow);
    await p.remove(_kRpHeaderSize);
    await p.remove(_kRpHeaderAccent);
    await p.remove(_kRpMoodOverride);
    await p.remove(_kRpBgColor);
    await p.remove(_kRpParticlesOn);
    await p.remove(_kRpPostSize);
    await p.remove(_kRpDisplayMode);
    await p.remove(_kRpEditorSize);
    await p.remove(_kRpShowLogSidebar);
    await p.remove(_kRpShowToolsSidebar);
    await p.remove(_kRpShowOoc);
    await p.remove(_kRpOocBadgeOn);
    await p.remove(_kPreludeHeaderShow);
    await p.remove(_kPreludeHeaderSize);
    await p.remove(_kPreludeHeaderAccent);
    await p.remove(_kPreludeBgMode);
    await p.remove(_kPreludeBgColor);
    await p.remove(_kPreludeMsgSize);
    await p.remove(_kPreludeDensity);
    await p.remove(_kPreludeMsgStyle);
    await p.remove(_kPreludeShowTimestamp);
    await p.remove(_kPreludeShowAuthor);
    await p.remove(_kPreludeShowPinLabel);
    await p.remove(_kPreludePinRule);
    await p.remove(_kPreludePinCharacter);
    await p.remove(_kPreludePinWorld);
    await p.remove(_kPreludePinPlot);
    await p.remove(_kPreludePinFilter);
    await p.remove(_kPreludeInputSize);
    await p.remove(_kPreludeChoiceSize);
    await p.remove(_kDiaryHeaderShow);
    await p.remove(_kDiaryHeaderSize);
    await p.remove(_kDiaryBgMode);
    await p.remove(_kDiaryBgColor);
    await p.remove(_kDiaryShowReminder);
    await p.remove(_kDiaryShowStreak);
    await p.remove(_kDiaryCardSize);
    await p.remove(_kDiaryShowAuthor);
    await p.remove(_kDiaryShowStats);
    await p.remove(_kDiaryShowAvatars);
    await p.remove(_kDiaryEntryHeaderShow);
    await p.remove(_kDiaryEntryHeaderSize);
    await p.remove(_kDiaryShowGenreBar);
    await p.remove(_kDiaryChapterSize);
    await p.remove(_kDiaryShowPreview);
    await p.remove(_kDiaryShowProgress);
    await p.remove(_kDiaryReadingSize);
    await p.remove(_kDiaryLineHeight);
    await p.remove(_kDiaryShowToolbar);
    await p.remove(_kDiaryEditorPadding);
    await p.remove(_kSandboxHeaderShow);
    await p.remove(_kSandboxHeaderSize);
    await p.remove(_kSandboxShowSpark);
    await p.remove(_kSandboxTabSize);
    await p.remove(_kSandboxShowFab);
    await p.remove(_kSandboxShowDeorum);
    await p.remove(_kSandboxShowDecode);
    await p.remove(_kSandboxWorldCardSize);
    await p.remove(_kSandboxShowWorldGenre);
    await p.remove(_kSandboxShowWorldOverview);
    await p.remove(_kSandboxShowWorldMapPill);
    await p.remove(_kSandboxShowWorldCounts);
    await p.remove(_kSandboxShowWorldDraft);
    await p.remove(_kSandboxCharCardSize);
    await p.remove(_kSandboxShowCharPronouns);
    await p.remove(_kSandboxShowCharPersonality);
    await p.remove(_kSandboxShowCharWorld);
    await p.remove(_kSandboxShowCharTypeBadge);
    await p.remove(_kSandboxShowCharFrame);
    await p.remove(_kSandboxEditorPadding);
    await p.remove(_kSandboxShowWorldMapUpload);
    await p.remove(_kSandboxShowWorldGenreField);
    await p.remove(_kSandboxShowWorldToneField);
    await p.remove(_kSandboxListCardSize);
    await p.remove(_kSandboxShowCharAvatar);
    await p.remove(_kSandboxShowCharAccent);
    await p.remove(_kSandboxShowCharTypeToggle);
    await p.remove(_kSandboxShowCharWorldRow);
    await p.remove(_kSandboxShowCharAppearance);
    await p.remove(_kSandboxShowCharPersonalityField);
    await p.remove(_kSandboxShowCharBackstory);
    await p.remove(_kSandboxShowCharRelationships);
    await p.remove(_kSandboxShowCharNotes);
    await p.remove(_kSandboxSparkTextSize);
    await p.remove(_kSandboxShowSparkLabels);
    await p.remove(_kSandboxSparkPadding);
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
    await p.remove('as_home_order');
    await p.remove(_kDevModeUnlocked);
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
