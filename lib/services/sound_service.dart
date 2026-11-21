import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
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
  static const notificationVolume = 'sound_notification_volume';

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
    await init();
    await _prefs?.setBool(SoundKey.masterMute, value);
  }

  Future<void> setEnabled(String key, bool value) async {
    await init();
    await _prefs?.setBool(key, value);
  }

  Future<void> play(String key) async {
    await init();
    if (!isEnabled(key)) return;
    final file = _files[key];
    if (file == null) return;
    try {
      // Fresh player per play: concurrent chimes overlap instead of
      // cutting each other off via a shared player's stop().
      final player = AudioPlayer();
      if (masterMute) return;
await player.setVolume(notificationVolume * masterVolume);

      // Tell Android this is a notification sound, not media,
      // and do NOT request audio focus from other apps.
      await player.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none, // Keeps it from ducking other apps
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
        ),
      ));

      await player.play(AssetSource(file));

      // Dispose once it finishes (or after 5s max, in case completion
      // never fires for a short asset).
      Future.any([
        player.onPlayerComplete.first,
        Future.delayed(const Duration(seconds: 5)),
      ]).then((_) => player.dispose());
    } catch (e) {
      debugPrint('[SoundService] play failed ($key): $e');
    }
  }

  double get notificationVolume =>
      _prefs?.getDouble(SoundKey.notificationVolume) ?? 0.5;

  Future<void> setNotificationVolume(double value) async {
    await init();
    final v = value.clamp(0.0, 1.0);
    await _prefs?.setDouble(SoundKey.notificationVolume, v);
  }

  double get masterVolume =>
      _prefs?.getDouble('sound_master_volume') ?? 1.0;

  Future<void> setMasterVolume(double value) async {
    await init();
    final v = value.clamp(0.0, 1.0);
    await _prefs?.setDouble('sound_master_volume', v);
  }

  void dispose() {
    // No long-lived players anymore — each play() creates and
    // disposes its own. Nothing to clean up.
  }
}

// Global shorthand
final sounds = SoundService.instance;
