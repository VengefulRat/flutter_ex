import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════
// SOUND KEYS
// ════════════════════════════════════════
class SoundKey {
  static const rpPost        = 'sound_rp_post';
  static const brainstormMsg = 'sound_brainstorm_msg';
  static const oocMsg        = 'sound_ooc_msg';
  static const interestSent  = 'sound_interest_sent';
  static const sessionAccept = 'sound_session_accept';
  static const moodSwitch    = 'sound_mood_switch';
  static const masterMute    = 'sound_master_mute';

  static const all = [
    rpPost,
    brainstormMsg,
    oocMsg,
    interestSent,
    sessionAccept,
    moodSwitch,
  ];

  static const labels = {
    rpPost:        'RP post sent',
    brainstormMsg: 'Prelude message',
    oocMsg:        'OOC message',
    interestSent:  'Interest sent',
    sessionAccept: 'Session accepted',
    moodSwitch:    'Mood shift',
  };
}

// ════════════════════════════════════════
// SOUND SERVICE — singleton
// ════════════════════════════════════════
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final _pool = <String, AudioPlayer>{};
  SharedPreferences? _prefs;
  bool _loaded = false;

  // Sound file map
  static const _files = {
    SoundKey.rpPost:        'sounds/chime.mp3',
    SoundKey.brainstormMsg: 'sounds/writing_on_parchment.mp3',
    SoundKey.oocMsg:        'sounds/chime2.mp3',
    SoundKey.interestSent:  'sounds/folding_paper.mp3',
    SoundKey.sessionAccept: 'sounds/stamp.mp3',
    SoundKey.moodSwitch:    'sounds/page_turn.mp3',
  };

  Future<void> init() async {
    if (_loaded) return;
    _prefs = await SharedPreferences.getInstance();
    _loaded = true;
  }

  bool get masterMute => _prefs?.getBool(SoundKey.masterMute) ?? false;

  bool isEnabled(String key) {
    if (masterMute) return false;
    return _prefs?.getBool(key) ?? true;
  }

  Future<void> setMasterMute(bool value) async {
    await _prefs?.setBool(SoundKey.masterMute, value);
  }

  Future<void> setEnabled(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  Future<void> play(String key) async {
    await init();
    if (!isEnabled(key)) return;
    final file = _files[key];
    if (file == null) return;
    try {
      // Get or create the player for this key
      _pool[key] ??= AudioPlayer();
      final player = _pool[key]!;

      // ── THE FIX ──
      // Tell Android this is a notification sound, not media, 
      // and do NOT request audio focus from other apps.
      await player.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          usageType: AndroidUsageType.notification,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
        ),
      ));
      // ──────────────

      await player.stop();
      await player.play(AssetSource(file));
    } catch (_) {}
  }

  void dispose() {
    for (final p in _pool.values) {
      p.dispose();
    }
    _pool.clear();
  }
}

// Global shorthand
final sounds = SoundService.instance;
