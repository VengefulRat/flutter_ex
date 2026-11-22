import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dart_sentiment/dart_sentiment.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../theme.dart';
import '../widgets/shared.dart';
import '../widgets/rp_tools.dart';
import '../widgets/session_log.dart';
import '../widgets/colour_picker.dart';
import '../models/world.dart';
import '../settings.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/crypto_service.dart';
import '../services/sound_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui' as ui;
import '../widgets/holo_card_v2.dart';
import '../widgets/card_frame.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────
// DISPLAY MODE
// ─────────────────────────────────────────
enum RPDisplayMode { cards, bubbles, classical }

// ─────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────
class RPPost {
  final String id;
  final String author;
  final bool isUser;
  String content;
  final DateTime timestamp;
  final int wordCount;
  String? quotedContent;
  String? quotedAuthor;
  final Color textColor;
  final double fontSize;
  final bool bold;
  final bool italic;
  final String? characterName;
  final String? locationName;

  RPPost({
    required this.id,
    required this.author,
    required this.isUser,
    required this.content,
    required this.timestamp,
    this.quotedContent,
    this.quotedAuthor,
    this.textColor = cParchment,
    this.fontSize = 15,
    this.bold = false,
    this.italic = true,
    this.characterName,
    this.locationName,
  }) : wordCount = content.trim().split(RegExp(r'\s+')).length;
}

class OOCMessage {
  final String author;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? mediaUrl;
  final bool isEncryptedMedia;

  OOCMessage({
    required this.author,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.mediaUrl,
    this.isEncryptedMedia = false,
  });
}

// ─────────────────────────────────────────
// MOOD ENGINE
// ─────────────────────────────────────────
enum StoryMood { neutral, dark, tense, warm, eerie, battle, rain, snow }

class MoodEngine {
  static final _sentiment = Sentiment();

  static const _genreWeights = <StoryMood, Map<String, int>>{
    StoryMood.rain: {
      'rain': 3,
      'storm': 3,
      'downpour': 4,
      'drizzle': 3,
      'thunder': 3,
      'lightning': 3,
      'puddle': 2,
      'soaked': 2,
      'drenched': 3,
      'grey sky': 4,
      'gray sky': 4,
      'overcast': 3,
      'monsoon': 4,
      'torrent': 3,
      'flood': 3,
    },
    StoryMood.snow: {
      'snow': 3,
      'blizzard': 4,
      'frost': 3,
      'frozen': 3,
      'bleak': 2,
      'tundra': 4,
      'glacier': 4,
      'ice storm': 5,
      'snowfall': 3,
      'frostbite': 4,
      'bitter cold': 4,
      'freezing': 3,
      'white out': 4,
      'avalanche': 4,
    },
    StoryMood.battle: {
      'battle': 4,
      'war': 3,
      'sword': 3,
      'blood': 3,
      'clash': 3,
      'combat': 4,
      'wound': 3,
      'blade': 2,
      'charge': 2,
      'siege': 4,
      'skirmish': 4,
      'slaughter': 4,
      'carnage': 5,
      'armor': 2,
      'arrow': 2,
      'gunshot': 4,
      'explosion': 4,
      'sniper': 4,
      'ambush': 4,
      'rifle': 3,
    },
    StoryMood.eerie: {
      'ghost': 4,
      'haunt': 4,
      'horror': 4,
      'terror': 4,
      'sinister': 4,
      'whisper': 2,
      'shadow moved': 5,
      'pale': 2,
      'hollow': 3,
      'void': 3,
      'cursed': 4,
      'wrongness': 4,
      'unnatural': 4,
      'grinned': 2,
      'crawled': 2,
      'crept': 2,
      'vanished': 2,
      'shapeless': 4,
      'ritual': 3,
    },
    StoryMood.dark: {
      'death': 4,
      'dead': 3,
      'grave': 3,
      'mourning': 4,
      'despair': 5,
      'loss': 2,
      'grief': 4,
      'hollow': 3,
      'hopeless': 5,
      'forsaken': 4,
      'doomed': 4,
      'shattered': 3,
      'broken': 2,
      'ruin': 3,
      'ash': 2,
      'wept': 3,
      'wept silently': 5,
      'no way out': 5,
      'resigned': 3,
    },
    StoryMood.tense: {
      'danger': 3,
      'escape': 3,
      'chase': 4,
      'urgent': 3,
      'panic': 4,
      'trap': 3,
      'cornered': 4,
      'heartbeat': 3,
      'sweat': 2,
      'breathless': 4,
      'raced': 3,
      'sprinted': 3,
      'alarm': 3,
      'timer': 3,
      'seconds left': 5,
      'no time': 4,
      'closing in': 5,
      'locked': 2,
      'ticking': 3,
    },
    StoryMood.warm: {
      'love': 3,
      'smile': 2,
      'laugh': 2,
      'hope': 3,
      'joy': 3,
      'warmth': 3,
      'embrace': 3,
      'tender': 3,
      'gentle': 2,
      'soft light': 4,
      'firelight': 4,
      'safe': 3,
      'peace': 3,
      'grateful': 3,
      'cherish': 4,
      'comfort': 3,
      'together': 2,
      'home': 2,
      'laughter': 3,
      'relief': 3,
    },
  };

  static (StoryMood, int) _genreScore(String lower) {
    final scores = <StoryMood, int>{};
    for (final entry in _genreWeights.entries) {
      int total = 0;
      for (final kw in entry.value.entries) {
        if (lower.contains(kw.key)) total += kw.value;
      }
      if (total > 0) scores[entry.key] = total;
    }
    if (scores.isEmpty) return (StoryMood.neutral, 0);
    final top = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return (top.key, top.value);
  }

  static StoryMood detectMood(String text) {
    final lower = text.toLowerCase();
    final (genreMood, genreScore) = _genreScore(lower);

    final result = _sentiment.analysis(text, emoji: true);
    final comparative = (result['comparative'] as num?)?.toDouble() ?? 0.0;
    final wordCount = (result['words'] as List?)?.length ?? 0;

    if (genreScore >= 4) return genreMood;

    if (genreScore >= 1) {
      if (genreMood == StoryMood.warm && comparative > 0.3) {
        return StoryMood.warm;
      }
      if (genreMood == StoryMood.dark && comparative < -0.3) {
        return StoryMood.dark;
      }
      if (genreMood == StoryMood.tense && comparative < -0.1) {
        return StoryMood.tense;
      }
      if (genreMood == StoryMood.eerie && comparative < -0.2) {
        return StoryMood.eerie;
      }
      if (genreScore >= 2) return genreMood;
    }

    if (wordCount < 2 && genreScore == 0) return StoryMood.neutral;

    if (comparative <= -0.6) return StoryMood.dark;
    if (comparative <= -0.3) return StoryMood.tense;
    if (comparative >= 0.4) return StoryMood.warm;

    return StoryMood.neutral;
  }

  static Color bgColor(StoryMood mood) {
    switch (mood) {
      case StoryMood.dark:
        return const Color(0xFF06060E);
      case StoryMood.tense:
        return const Color(0xFF0C0606);
      case StoryMood.warm:
        return const Color(0xFF0C0904);
      case StoryMood.eerie:
        return const Color(0xFF050806);
      case StoryMood.battle:
        return const Color(0xFF0C0505);
      case StoryMood.rain:
        return const Color(0xFF050810);
      case StoryMood.snow:
        return const Color(0xFF060810);
      case StoryMood.neutral:
        return cVoid;
    }
  }

  static String moodLabel(StoryMood mood) {
    switch (mood) {
      case StoryMood.dark:
        return 'Dark';
      case StoryMood.tense:
        return 'Tense';
      case StoryMood.warm:
        return 'Warm';
      case StoryMood.eerie:
        return 'Eerie';
      case StoryMood.battle:
        return 'Battle';
      case StoryMood.rain:
        return 'Rain';
      case StoryMood.snow:
        return 'Snow';
      case StoryMood.neutral:
        return 'Neutral';
    }
  }
}

// ─────────────────────────────────────────
// PARTICLES
// ─────────────────────────────────────────
class Particle {
  double x, y, vx, vy, size, opacity;
  final StoryMood type;

  Particle(this.type, double width, double height)
    : x = 0,
      y = 0,
      vx = 0,
      vy = 0,
      size = 1,
      opacity = 0 {
    reset(width, height);
  }

  void reset(double w, double h) {
    final rnd = Random();
    switch (type) {
      case StoryMood.rain:
        x = rnd.nextDouble() * w;
        y = -10;
        vx = rnd.nextDouble() * 1.5 - 0.5;
        vy = rnd.nextDouble() * 10 + 10;
        size = rnd.nextDouble() * 1.5 + 0.5;
        opacity = rnd.nextDouble() * 0.5 + 0.2;
        break;
      case StoryMood.snow:
        x = rnd.nextDouble() * w;
        y = -10;
        vx = rnd.nextDouble() * 1.2 - 0.6;
        vy = rnd.nextDouble() * 1.5 + 0.5;
        size = rnd.nextDouble() * 4 + 1.5;
        opacity = rnd.nextDouble() * 0.6 + 0.3;
        break;
      case StoryMood.battle:
        x = rnd.nextDouble() * w;
        y = h + 5;
        vx = rnd.nextDouble() * 4 - 2;
        vy = -(rnd.nextDouble() * 8 + 4);
        size = rnd.nextDouble() * 3 + 1;
        opacity = rnd.nextDouble() * 0.7 + 0.3;
        break;
      case StoryMood.tense:
        x = rnd.nextDouble() < 0.5 ? -5 : w + 5;
        y = rnd.nextDouble() * h;
        vx = x < 0 ? rnd.nextDouble() * 3 + 2 : -(rnd.nextDouble() * 3 + 2);
        vy = rnd.nextDouble() * 0.6 - 0.3;
        size = rnd.nextDouble() * 1.5 + 0.5;
        opacity = rnd.nextDouble() * 0.5 + 0.2;
        break;
      case StoryMood.eerie:
        x = rnd.nextDouble() * w;
        y = rnd.nextDouble() * h;
        vx = rnd.nextDouble() * 0.6 - 0.3;
        vy = -(rnd.nextDouble() * 0.8 + 0.2);
        size = rnd.nextDouble() * 5 + 2;
        opacity = rnd.nextDouble() * 0.25 + 0.05;
        break;
      case StoryMood.dark:
        x = rnd.nextDouble() * w;
        y = -10;
        vx = rnd.nextDouble() * 0.8 - 0.4;
        vy = rnd.nextDouble() * 0.8 + 0.3;
        size = rnd.nextDouble() * 2.5 + 0.5;
        opacity = rnd.nextDouble() * 0.4 + 0.1;
        break;
      case StoryMood.warm:
        x = rnd.nextDouble() * w;
        y = h + 5;
        vx = rnd.nextDouble() * 1.2 - 0.6;
        vy = -(rnd.nextDouble() * 1.5 + 0.5);
        size = rnd.nextDouble() * 3 + 1;
        opacity = rnd.nextDouble() * 0.5 + 0.15;
        break;
      default:
        x = rnd.nextDouble() * w;
        y = rnd.nextDouble() * h;
        vx = rnd.nextDouble() * 0.4 - 0.2;
        vy = -(rnd.nextDouble() * 0.4 + 0.1);
        size = rnd.nextDouble() * 2 + 0.5;
        opacity = rnd.nextDouble() * 0.1 + 0.02;
    }
  }

  bool update(double w, double h) {
    x += vx;
    y += vy;
    return y > h + 10 || x < -10 || x > w + 10;
  }
}

class MoodParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final StoryMood mood;
  MoodParticlePainter(this.particles, this.mood);

  Color get _particleColor {
    switch (mood) {
      case StoryMood.rain:
        return const Color(0xFF7AB8D4);
      case StoryMood.snow:
        return Colors.white;
      case StoryMood.battle:
        return const Color(0xFFD4614A);
      case StoryMood.eerie:
        return const Color(0xFF6aff8a);
      case StoryMood.warm:
        return const Color(0xFFC9A96E);
      case StoryMood.dark:
        return const Color(0xFF7060C0);
      case StoryMood.tense:
        return const Color(0xFFCC3030);
      default:
        return const Color(0xFF5a5a5a);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      paint.color = _particleColor.withValues(alpha: p.opacity * 0.5);
      if (mood == StoryMood.rain) {
        paint.strokeWidth = p.size;
        canvas.drawLine(
          Offset(p.x, p.y),
          Offset(p.x + p.vx * 2, p.y + p.vy * 1.5),
          paint..style = PaintingStyle.stroke,
        );
      } else if (mood == StoryMood.tense) {
        paint.strokeWidth = p.size;
        canvas.drawLine(
          Offset(p.x, p.y),
          Offset(p.x - p.vx * 6, p.y),
          paint..style = PaintingStyle.stroke,
        );
      } else if (mood == StoryMood.battle) {
        paint.strokeWidth = p.size * 0.6;
        canvas.drawLine(
          Offset(p.x, p.y),
          Offset(p.x - p.vx, p.y - p.vy),
          paint..style = PaintingStyle.stroke,
        );
      } else {
        canvas.drawCircle(
          Offset(p.x, p.y),
          p.size,
          paint..style = PaintingStyle.fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─────────────────────────────────────────
// SHARED: selectable post text
// ─────────────────────────────────────────
Widget _selectablePostText({
  required String text,
  required TextStyle style,
  required void Function(String) onAddToLog,
  void Function(String)? onSelectionChanged,
}) {
  return Text(text, style: style);
}

// ─────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────
double _rpPostScale() => appSettings.rpPostSize == 'S'
    ? 0.85
    : appSettings.rpPostSize == 'L'
    ? 1.35
    : 1.0;
double _rpEditorScale() => appSettings.rpEditorSize == 'S'
    ? 0.85
    : appSettings.rpEditorSize == 'L'
    ? 1.35
    : 1.0;

class RPRoomScreen extends StatefulWidget {
  final String partnerName;
  final String partnerCode;
  final String genre;
  final String sessionId;
  final String title;
  const RPRoomScreen({
    super.key,
    required this.partnerName,
    required this.partnerCode,
    required this.genre,
    this.sessionId = '',
    this.title = '',
  });

    // Which session is currently open, if any. Used by notification routing
  // so tapping a notification for the room you're already in doesn't
  // stack a duplicate copy on top.
  static String? openSessionId;

  @override
  State<RPRoomScreen> createState() => _RPRoomScreenState();
}

class _RPRoomScreenState extends State<RPRoomScreen>
    with TickerProviderStateMixin {
  final List<RPPost> _posts = [];
  final List<OOCMessage> _oocMessages = [];

  ui.FragmentShader? _moodShader;
  late AnimationController _shaderTimeCtrl;

  Future<void> _loadMoodShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/rp_mood.frag',
      );
      if (mounted) setState(() => _moodShader = program.fragmentShader());
    } catch (e) {
      debugPrint('Failed to load mood shader: $e');
    }
  }

  Future<String?> _promptForMediaUrl() async {
    final ctrl = TextEditingController();
    try {
      return await _promptForMediaUrlDialog(ctrl);
    } finally {
      ctrl.dispose();
    }
  }

  Future<String?> _promptForMediaUrlDialog(TextEditingController ctrl) async {
    final result = await showDialog<String>(
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
                'ATTACH MEDIA',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: cGold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Paste a link to an Image, GIF, Video (YouTube), or Audio track.',
                style: TextStyle(
                  fontSize: 13,
                  color: cMist,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(fontSize: 14, color: cParchment),
                decoration: const InputDecoration(
                  hintText: 'https://...',
                  hintStyle: TextStyle(color: cSmoke),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: cAsh),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: cGold),
                  ),
                  filled: true,
                  fillColor: cVoid,
                ),
                cursorColor: cGold,
              ),
              const SizedBox(height: 20),
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
                      onTap: () => Navigator.pop(ctx, ctrl.text.trim()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: cGold,
                        child: const Center(
                          child: Text(
                            'Attach',
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
          ),
        ),
      ),
    );
    return result;
  }

  Future<void> _sendEncryptedMediaUrl(String url) async {
    if (widget.sessionId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _oocMessages.add(
          OOCMessage(
            author: _auth.currentName ?? 'You',
            content: url,
            isUser: true,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollOocToBottom();
      return;
    }

    try {
      await _fs.addOocMessage(sessionId: widget.sessionId, content: url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cInk,
          content: Text(
            'Send failed: $e',
            style: const TextStyle(color: cParchment),
          ),
        ),
      );
    }
    _scrollOocToBottom();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: cInk,
        content: Text(
          'Compressing and encrypting...',
          style: TextStyle(color: cGold),
        ),
      ),
    );

    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      Uint8List bytes;
try {
  final compressedFile = await FlutterImageCompress.compressAndGetFile(
    image.path,
    targetPath,
    quality: 70,
    minWidth: 1024,
    minHeight: 1024,
  );
  if (compressedFile != null) {
    bytes = await compressedFile.readAsBytes();
  } else {
    bytes = await image.readAsBytes();
  }
} catch (_) {
  // Windows / unsupported format: fall back to raw picked bytes
  bytes = await image.readAsBytes();
}

      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: cInk,
              content: Text(
                'Image is too large (Max 5MB).',
                style: TextStyle(color: cEmber),
              ),
            ),
          );
        }
        return;
      }

      final sessionKey = await _fs.getSessionKeyForMedia(widget.sessionId);
      if (sessionKey == null) throw 'Could not get session key';

      final encryptedData = await CryptoService().encryptBytes(
        bytes,
        sessionKey,
      );
      final storageRef = FirebaseStorage.instance.ref().child(
        'sessions/${widget.sessionId}/media/${DateTime.now().millisecondsSinceEpoch}.enc',
      );

      final uploadBytes = Uint8List.fromList(
        encryptedData['iv']! + encryptedData['cipher']!,
      );
      await storageRef.putData(uploadBytes);

      await _fs.sendEncryptedOocMedia(
        sessionId: widget.sessionId,
        storagePath: storageRef.fullPath,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } catch (e) {
      if (mounted) {
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

  Timer? _selectionDebounce;

  final _fs = FirestoreService();
  final _auth = AuthService();
  StreamSubscription? _postsSub;
  StreamSubscription? _oocSub;
  bool _loadingPosts = true;

  final _editorCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _editorFocus = FocusNode();
  bool _editorExpanded = false;

  bool _bold = false;
  bool _italic = true;
  double _fontSize = 15;
  Color _fontColor = cParchment;

  bool _aiMoodEnabled = true;
  double _moodIntensity = 0.5;
  bool _moodLockedByUser = false;
  final List<StoryMood> _moodHistory = [];

  StoryMood _currentMood = StoryMood.rain;
  late AnimationController _moodCtrl;
  late Animation<Color?> _bgAnim;
  Color _fromColor = cVoid;

  late AnimationController _particleCtrl;
  final List<Particle> _particles = [];
  final _rnd = Random();
  final _particleTick = ValueNotifier<int>(0);
  Size _canvasSize = Size.zero;

  bool _desktopOOCExpanded = false;
  bool _desktopLogCollapsed = false;
  bool _desktopToolsCollapsed = false;
  bool get _desktopFocusMode => _desktopLogCollapsed && _desktopToolsCollapsed;
  bool _oocOpen = false;
  int _oocUnread = 0;
  int _oocTotalNonUser = 0;

  final _oocCtrl = TextEditingController();
  final _oocFocus = FocusNode();
  final _oocFocus2 = FocusNode();
  final _oocScrollCtrl = ScrollController();

  bool _settingsOpen = false;
  late String _sessionTitle;

  final List<RPNote> _notes = [];
  StatBlock? _myStats;
  final ValueNotifier<StatBlock?> _partnerStatsN = ValueNotifier(null);
  StreamSubscription? _statsSub;
  Timer? _statsSaveDebounce;
  final List<WorldEntry> _importedWorlds = [];
  final List<CharacterEntry> _importedCharacters = [];
  List<CharacterEntry> get _switcherCharacters => _importedCharacters.isNotEmpty ? _importedCharacters : _sandboxCharacters;
  List<WorldEntry> _sandboxWorlds = [];
  List<CharacterEntry> _sandboxCharacters = [];

  List<String> get _availableLocations {
    final locs = <String>[];
    for (final w in _importedWorlds) {
      for (final l in w.locations) {
        if (l.name.isNotEmpty && !locs.contains(l.name)) locs.add(l.name);
      }
    }
    return locs;
  }

  String? _expandedPostId;
  String? _quotingPostId;
  String? _editingPostId;

  RPDisplayMode _displayMode = RPDisplayMode.cards;

  CharacterEntry? _activeCharacter;
  String? _activeLocation;

  bool _draftSaved = false;
  static const _draftDebounce = Duration(milliseconds: 800);
  DateTime? _lastTyped;
  String _selectedText = '';

  SessionLog get _log => SessionLog.forSession(
    widget.sessionId.isEmpty ? 'default' : widget.sessionId,
  );

  @override
  void initState() {
    RPRoomScreen.openSessionId = widget.sessionId;
    super.initState();
    _sessionTitle = widget.title;
    _aiMoodEnabled = appSettings.aiMood;
    _displayMode = RPDisplayMode.values.firstWhere(
      (m) => m.name == appSettings.rpDisplayMode,
      orElse: () => RPDisplayMode.cards,
    );
    appSettings.addListener(_onSettingsChanged);
    if (widget.sessionId.isNotEmpty && _sessionTitle.isEmpty) {
      _loadSessionTitle();
    }

    _moodCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    final toColor = MoodEngine.bgColor(_currentMood);
    _fromColor = toColor;
    _bgAnim = ColorTween(
      begin: _fromColor,
      end: toColor,
    ).animate(CurvedAnimation(parent: _moodCtrl, curve: Curves.easeInOut));

    _particleCtrl =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 50),
          )
          ..addListener(_onParticleTick)
          ..repeat();

    _shaderTimeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _loadMoodShader();
    _initParticles();
    _loadDraft();
    _editorCtrl.addListener(_onEditorChanged);

    if (widget.sessionId.isNotEmpty) {
      _subscribeToFirestore();
      _subscribeToStats();
      _log.load();
    }
    _loadSandboxData();
  }

  @override
  void dispose() {
    if (RPRoomScreen.openSessionId == widget.sessionId) {
      RPRoomScreen.openSessionId = null;
    }
    appSettings.removeListener(_onSettingsChanged);
    _selectionDebounce?.cancel();
    _editorCtrl.removeListener(_onEditorChanged);
    _postsSub?.cancel();
    _oocSub?.cancel();
    _statsSub?.cancel();
    _statsSaveDebounce?.cancel();
    _partnerStatsN.dispose();
    _moodCtrl.dispose();
    _particleCtrl.dispose();
    _shaderTimeCtrl.dispose();
    _particleTick.dispose();
    _editorCtrl.dispose();
    _scrollCtrl.dispose();
    _editorFocus.dispose();
    _oocFocus.dispose();
    _oocFocus2.dispose();
    _oocCtrl.dispose();
    _oocScrollCtrl.dispose();
    super.dispose();
  }

  void _subscribeToFirestore() {
    _postsSub = _fs.sessionPosts(widget.sessionId).listen((data) {
      final myCode = _auth.currentCode ?? '';

      final wasAtBottom =
          !_scrollCtrl.hasClients ||
          (_scrollCtrl.position.maxScrollExtent - _scrollCtrl.position.pixels) <
              100;

      final posts = data.map((d) {
        final isUser = d['authorCode'] == myCode;
        return RPPost(
          id: d['id'] as String,
          author: d['authorName'] as String? ?? '?',
          isUser: isUser,
          content: d['content'] as String? ?? '',
          timestamp: (d['createdAt'] != null)
              ? (d['createdAt'] as dynamic).toDate()
              : DateTime.now(),
          quotedContent: d['quotedContent'] as String?,
          quotedAuthor: d['quotedAuthor'] as String?,
          characterName: d['characterName'] as String?,
          locationName: d['locationName'] as String?,
          textColor: d['textColor'] != null
              ? Color(d['textColor'] as int)
              : cParchment,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(posts);
        _loadingPosts = false;
      });

      if (wasAtBottom && appSettings.autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }, onError: _handleStreamError);

    _oocSub = _fs.oocMessages(widget.sessionId).listen((data) {
      final myCode = _auth.currentCode ?? '';
      final msgs = data.map((d) {
        final isUser = d['authorCode'] == myCode;
        return OOCMessage(
          author: d['authorName'] as String? ?? '?',
          content: d['content'] as String? ?? '',
          isUser: isUser,
          timestamp: (d['createdAt'] != null)
              ? (d['createdAt'] as dynamic).toDate()
              : DateTime.now(),
          mediaUrl: d['mediaUrl'] as String?,
          isEncryptedMedia: d['isEncryptedMedia'] as bool? ?? false,
        );
      }).toList();
      if (mounted) {
        setState(() {
          final newNonUser = msgs.where((m) => !m.isUser).length;
          final isFirstLoad = _oocMessages.isEmpty && _oocTotalNonUser == 0;
          final oocVisible = _oocOpen || _desktopOOCExpanded;
          if (!isFirstLoad && !oocVisible && newNonUser > _oocTotalNonUser) {
            _oocUnread += newNonUser - _oocTotalNonUser;
          }
          _oocTotalNonUser = newNonUser;
          _oocMessages
            ..clear()
            ..addAll(msgs);
        });
      }
    }, onError: _handleStreamError);
  }

  void _handleStreamError(Object e) {
    if (!mounted) return;
    setState(() => _loadingPosts = false);
    final msg = e.toString().contains('permission-denied')
        ? 'Lost access to this session.'
        : 'Could not load session.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: cInk,
        behavior: SnackBarBehavior.floating,
        content: Text(msg, style: const TextStyle(color: cParchment)),
      ),
    );
  }

  void _subscribeToStats() {
    _statsSub = _fs.sessionStats(widget.sessionId).listen((statsMap) {
      if (!mounted) return;
      final myCode = _auth.currentCode ?? '';

      if (_myStats == null && statsMap.containsKey(myCode)) {
        setState(() => _myStats = statsMap[myCode]);
      }

      StatBlock? partner;
      for (final e in statsMap.entries) {
        if (e.key != myCode && e.key.isNotEmpty) {
          partner = e.value;
          break;
        }
      }
      _partnerStatsN.value = partner;
    }, onError: (e) => print('[stats] STREAM ERROR: $e'));
  }

  void _saveMyStats(StatBlock? block) {
    if (!mounted) return;
    setState(() => _myStats = block);
    if (widget.sessionId.isEmpty) {
      return;
    }
    _statsSaveDebounce?.cancel();
    _statsSaveDebounce = Timer(const Duration(milliseconds: 500), () {
      _fs.saveSessionStats(widget.sessionId, block);
    });
  }

  Future<void> _loadSandboxData() async {
    final worlds = await SandboxStorage.loadWorlds();
    final chars = await SandboxStorage.loadCharacters();

    // Load saved import IDs from Firestore
    if (widget.sessionId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.sessionId)
            .get();
        final data = doc.data();
        if (data != null) {
          final charIds = List<String>.from(data['importedCharacterIds'] ?? []);
          final worldIds = List<String>.from(data['importedWorldIds'] ?? []);

          for (final id in charIds) {
            final match = chars.where((c) => c.id == id).firstOrNull;
            if (match != null && !_importedCharacters.any((c) => c.id == id)) {
              _importedCharacters.add(match);
            }
          }
          for (final id in worldIds) {
            final match = worlds.where((w) => w.id == id).firstOrNull;
            if (match != null && !_importedWorlds.any((w) => w.id == id)) {
              _importedWorlds.add(match);
            }
          }
        }
      } catch (e) {
        print('Failed to load imports: $e');
      }
    }

    if (mounted) {
      setState(() {
        _sandboxWorlds = worlds;
        _sandboxCharacters = chars;
      });
    }
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {
      _aiMoodEnabled = appSettings.aiMood;
      _displayMode = RPDisplayMode.values.firstWhere(
        (m) => m.name == appSettings.rpDisplayMode,
        orElse: () => RPDisplayMode.cards,
      );
      _initParticles();
    });
  }

  String get _draftKey =>
      'draft_${widget.sessionId.isEmpty ? 'default' : widget.sessionId}';

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_draftKey) ?? '';
    if (saved.isNotEmpty && mounted) {
      setState(() {
        _editorCtrl.text = saved;
        _draftSaved = true;
      });
    }
  }

  Future<void> _saveDraft(String text) async {
    final prefs = await SharedPreferences.getInstance();
    if (text.isEmpty) {
      await prefs.remove(_draftKey);
      if (mounted) setState(() => _draftSaved = false);
    } else {
      await prefs.setString(_draftKey, text);
      if (mounted) setState(() => _draftSaved = true);
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
    if (mounted) setState(() => _draftSaved = false);
  }

  void _scrollOocToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_oocScrollCtrl.hasClients) {
        _oocScrollCtrl.animateTo(
          _oocScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendOocMessage() async {
    final text = _oocCtrl.text.trim();
    if (text.isEmpty) return;

    sounds.play(SoundKey.oocMsg);

    if (widget.sessionId.isNotEmpty) {
      try {
        await _fs.addOocMessage(sessionId: widget.sessionId, content: text);
        _oocCtrl.clear();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: cInk,
              content: Text(
                'Send failed: $e',
                style: const TextStyle(color: cParchment),
              ),
            ),
          );
        }
      }
    } else {
      _oocCtrl.clear();
      setState(
        () => _oocMessages.add(
          OOCMessage(
            author: _auth.currentName ?? 'You',
            content: text,
            isUser: true,
            timestamp: DateTime.now(),
          ),
        ),
      );
    }
    _scrollOocToBottom();
  }

  void _onEditorChanged() {
    final text = _editorCtrl.text;
    _lastTyped = DateTime.now();
    final captured = _lastTyped;
    Future.delayed(_draftDebounce, () {
      if (_lastTyped == captured && mounted) _saveDraft(text);
    });
    if (!mounted) return;
    setState(() {});
  }

  void _initParticles() {
    _particles.clear();
    if (!appSettings.rpParticlesOn) return;
    final base = switch (_currentMood) {
      StoryMood.rain => 45,
      StoryMood.snow => 28,
      StoryMood.battle => 32,
      StoryMood.tense => 18,
      StoryMood.eerie => 15,
      StoryMood.dark => 14,
      StoryMood.warm => 22,
      StoryMood.neutral => 0,
    };
    final count = (base * (0.4 + _moodIntensity * 1.2)).round();
    for (int i = 0; i < count; i++) {
      final p = Particle(_currentMood, 400, 800);
      p.y = _rnd.nextDouble() * 800;
      _particles.add(p);
    }
  }

  void _onParticleTick() {
    if (!mounted || _canvasSize == Size.zero) return;
    for (final p in _particles) {
      if (p.update(_canvasSize.width, _canvasSize.height)) {
        p.reset(_canvasSize.width, _canvasSize.height);
      }
    }
    _particleTick.value++;
  }

  void _setMood(StoryMood mood, {String? reason}) {
    if (!mounted) return;
    if (mood == _currentMood) return;
    setState(() {
      _fromColor = _bgAnim.value ?? _fromColor;
      _currentMood = mood;
      final toColor = MoodEngine.bgColor(mood);
      _bgAnim = ColorTween(
        begin: _fromColor,
        end: toColor,
      ).animate(CurvedAnimation(parent: _moodCtrl, curve: Curves.easeInOut));
      _moodCtrl.forward(from: 0);
      _initParticles();
    });
    _particleTick.value++;

    if (widget.sessionId.isNotEmpty && reason != 'silent') {
      _log.addEvent(
        title: 'Mood · ${MoodEngine.moodLabel(mood)}',
        body: 'The room shifted to ${MoodEngine.moodLabel(mood)}.',
        source: 'mood',
        meta: {'mood': mood.name},
      );
    }
  }

  void _setMoodManual(StoryMood mood) {
    if (!mounted) return;
    setState(() => _moodLockedByUser = true);
    sounds.play(SoundKey.moodSwitch);
    _setMood(mood);
  }

  void _unlockMood() {
    if (!mounted) return;
    _moodHistory.clear();
    setState(() => _moodLockedByUser = false);
  }

  void _analyseAndSetMood(String text) {
    if (!_aiMoodEnabled || _moodLockedByUser) return;
    final detected = MoodEngine.detectMood(text);

    _moodHistory.add(detected);
    if (_moodHistory.length > 3) _moodHistory.removeAt(0);

    final counts = <StoryMood, int>{};
    for (final m in _moodHistory) {
      counts[m] = (counts[m] ?? 0) + 1;
    }
    final dominant = counts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    _setMood(dominant);
  }

  bool _sending = false;

  Future<void> _submitPost() async {
    final text = _editorCtrl.text.trim();
    if (text.isEmpty) return;
    if (_sending) return;
    if (mounted) setState(() => _sending = true);

    if (_editingPostId != null) {
      final postId = _editingPostId!;
      if (widget.sessionId.isNotEmpty) {
        try {
          await _fs.editPost(
            sessionId: widget.sessionId,
            postId: postId,
            newContent: text,
            textColor: _activeCharacter?.accentColor ?? _fontColor,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: cInk,
                content: Text(
                  'Save failed: $e',
                  style: const TextStyle(color: cParchment),
                ),
              ),
            );
          }
          if (mounted) setState(() => _sending = false);
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        final i = _posts.indexWhere((p) => p.id == postId);
        if (i != -1) {
          _posts[i] = RPPost(
            id: _posts[i].id,
            author: _posts[i].author,
            isUser: _posts[i].isUser,
            content: text,
            timestamp: _posts[i].timestamp,
            quotedContent: _posts[i].quotedContent,
            quotedAuthor: _posts[i].quotedAuthor,
            characterName: _posts[i].characterName,
            locationName: _posts[i].locationName,
            textColor: _posts[i].textColor,
            fontSize: _posts[i].fontSize,
            bold: _posts[i].bold,
            italic: _posts[i].italic,
          );
        }
        _editorCtrl.text = '';
        _editingPostId = null;
        _editorExpanded = false;
        _sending = false;
      });
      await _clearDraft();
      return;
    }

    RPPost? quotedPost;
    if (_quotingPostId != null) {
      for (final p in _posts) {
        if (p.id == _quotingPostId) {
          quotedPost = p;
          break;
        }
      }
    }

    _analyseAndSetMood(text);

    if (widget.sessionId.isNotEmpty) {
      try {
        await _fs.addPost(
          sessionId: widget.sessionId,
          content: text,
          quotedContent: quotedPost?.content.substring(
            0,
            min(100, quotedPost.content.length),
          ),
          quotedAuthor: quotedPost != null
              ? (quotedPost.characterName ?? quotedPost.author)
              : null,
          characterName: _activeCharacter?.name,
          locationName: _activeLocation,
          textColor: _activeCharacter?.accentColor ?? _fontColor,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: cInk,
              content: Text(
                'Post failed: $e',
                style: const TextStyle(color: cParchment),
              ),
            ),
          );
        }
        if (mounted) setState(() => _sending = false);
        return;
      }
      await _clearDraft();
      sounds.play(SoundKey.rpPost);
      if (mounted) {
        setState(() {
          _editorCtrl.text = '';
          _quotingPostId = null;
          _editorExpanded = false;
          _sending = false;
        });
      }
    } else {
      if (!mounted) return;
      final displayName =
          _activeCharacter?.name ?? (_auth.currentName ?? 'You');
      final postColor = _activeCharacter != null
          ? _activeCharacter!.accentColor
          : _fontColor;
      setState(() {
        _posts.add(
          RPPost(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            author: displayName,
            isUser: true,
            content: text,
            timestamp: DateTime.now(),
            quotedContent: quotedPost?.content.substring(
              0,
              min(100, quotedPost.content.length),
            ),
            quotedAuthor: quotedPost?.characterName ?? quotedPost?.author,
            textColor: postColor,
            fontSize: _fontSize * _rpEditorScale(),
            bold: _bold,
            italic: _italic,
            characterName: _activeCharacter?.name,
            locationName: _activeLocation,
          ),
        );
        _editorCtrl.text = '';
        _quotingPostId = null;
        _editorExpanded = false;
        _sending = false;
      });
      _clearDraft();
    }
  }

  Future<void> _deletePost(String id) async {
    if (!mounted) return;
    final i = _posts.indexWhere((p) => p.id == id);
    if (i == -1) return;
    final original = _posts[i];
    setState(() => _posts.removeAt(i));

    if (widget.sessionId.isNotEmpty) {
      try {
        await _fs.deletePost(sessionId: widget.sessionId, postId: id);
      } catch (e) {
        if (mounted) {
          setState(() => _posts.insert(i, original));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: cInk,
              content: Text(
                'Delete failed: $e',
                style: const TextStyle(color: cParchment),
              ),
            ),
          );
        }
      }
    }
  }

  void _quotePost(String id) {
    if (!mounted) return;
    setState(() {
      _quotingPostId = id;
      _editorExpanded = true;
    });
    _editorFocus.requestFocus();
  }

  void _editPost(RPPost post) {
    if (!mounted) return;
    _editorCtrl.text = post.content;
    setState(() {
      _editingPostId = post.id;
      _quotingPostId = null;
      _editorExpanded = true;
    });
    _editorFocus.requestFocus();
  }

  Future<void> _loadSessionTitle() async {
    try {
      final sessions = await _fs.mySessions().first;
      final match = sessions.where((s) => s['id'] == widget.sessionId);
      if (match.isNotEmpty && mounted) {
        final t = match.first['title'] as String? ?? '';
        if (t.isNotEmpty) setState(() => _sessionTitle = t);
      }
    } catch (_) {}
  }

  Future<void> _editSessionTitle() async {
    final ctrl = TextEditingController(text: _sessionTitle);
    final result = await showDialog<String>(
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
                'SESSION TITLE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: cGold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Give this story a name. Both of you can see and change it.',
                style: TextStyle(
                  fontSize: 12,
                  color: cSmoke,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 15,
                  color: cParchment,
                  fontStyle: FontStyle.italic,
                ),
                decoration: const InputDecoration(
                  hintText: 'The Whitethorn Heist...',
                  hintStyle: TextStyle(
                    color: cSmoke,
                    fontStyle: FontStyle.italic,
                  ),
                  filled: true,
                  fillColor: cVoid,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: cAsh),
                    borderRadius: BorderRadius.zero,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: cGold),
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                cursorColor: cGold,
              ),
              const SizedBox(height: 20),
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
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, ctrl.text),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: cParchment,
                        child: const Center(
                          child: Text(
                            'Save',
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
    ctrl.dispose();
    if (result == null) return;
    if (!mounted) return;
    final newTitle = result.trim();
    setState(() => _sessionTitle = newTitle);
    if (widget.sessionId.isNotEmpty) {
      try {
        await _fs.updateSessionTitle(widget.sessionId, newTitle);
      } catch (e) {
        print('[session] title update failed: $e');
      }
    }
  }

  void _openLog() {
    if (!mounted) return;
    if (widget.sessionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: cInk,
          content: Text(
            'The log is available in shared rooms.',
            style: TextStyle(color: cParchment),
          ),
        ),
      );
      return;
    }
    SessionLogSheet.show(context, widget.sessionId);
  }

  void _addToLogFromText(String selectedText) {
    if (!mounted) return;
    if (widget.sessionId.isEmpty) return;
    SessionLogSheet.promptFromSelection(
      context: context,
      sessionId: widget.sessionId,
      selectedText: selectedText,
    );
  }

  void _onSelectionChanged(String text) {
    final t = text.trim();
    if (t == _selectedText) return;
    if (!mounted) return;
    setState(() => _selectedText = t);

    if (kIsWeb && t.isNotEmpty) {
      _selectionDebounce?.cancel();
      _selectionDebounce = Timer(const Duration(milliseconds: 800), () {
        if (mounted && _selectedText == t) {
          _addSelectionToLog();
        }
      });
    }
  }

  Future<void> _addSelectionToLog() async {
    final text = _selectedText;
    if (text.isEmpty) return;
    if (!mounted) return;
    setState(() => _selectedText = '');
    _selectionDebounce?.cancel();
    _addToLogFromText(text);
  }

  void _dismissSelection() {
    if (!mounted) return;
    setState(() => _selectedText = '');
  }

  Widget _buildSelectionPill() {
    final preview = _selectedText.length > 40
        ? '${_selectedText.substring(0, 40)}…'
        : _selectedText;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: cInk,
          border: Border.all(color: cGold.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.text_fields, size: 14, color: cSmoke),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '"$preview"',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: cMist,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _addSelectionToLog,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                color: cGold,
                child: const Text(
                  'Add to log',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cVoid,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: _dismissSelection,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 14, color: cSmoke),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    if (isDesktop) {
      return Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.keyF &&
              !HardwareKeyboard.instance.isControlPressed &&
              !HardwareKeyboard.instance.isMetaPressed &&
              !HardwareKeyboard.instance.isAltPressed) {
            if (_editorFocus.hasFocus || _oocFocus.hasFocus || _oocFocus2.hasFocus) {
              return KeyEventResult.ignored;
            }
            final primary = FocusManager.instance.primaryFocus;
            if (primary != null && primary.context?.widget is EditableText) {
              return KeyEventResult.ignored;
            }
            setState(() {
              if (_desktopFocusMode) {
                _desktopLogCollapsed = false;
                _desktopToolsCollapsed = false;
              } else {
                _desktopLogCollapsed = true;
                _desktopToolsCollapsed = true;
              }
            });
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: _buildDesktopLayout(),
      );
    }
    return _buildMobileLayout();
  }

  Color _effectiveBg(Color moodColor) {
    if (appSettings.rpMoodOverride == 'fixed') return appSettings.rpBgColor;
    if (appSettings.rpMoodOverride == 'tint') {
      return Color.lerp(moodColor, appSettings.rpBgColor, 0.5) ?? moodColor;
    }
    return moodColor;
  }

  Widget _buildDesktopLayout() {
    return AnimatedBuilder(
      animation: _moodCtrl,
      builder: (_, child) {
        final bg = _effectiveBg(_bgAnim.value ?? cVoid);
        return Scaffold(
          backgroundColor: bg,
          body: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    _canvasSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return RepaintBoundary(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _particleTick,
                        builder: (_, _, _) => CustomPaint(
                          painter: MoodParticlePainter(
                            _particles,
                            _currentMood,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Sidebar (Session Log)
                          if (appSettings.rpShowLogSidebar &&
                              !_desktopLogCollapsed)
                            SizedBox(
                              width: 300,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black12,
                                  border: Border(
                                    right: BorderSide(color: cAsh),
                                  ),
                                ),
                                child: SessionLogView(
                                  log: _log,
                                  isSidebar: true,
                                ),
                              ),
                            ),

                          // Center (Posts + Editor)
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 960,
                                ),
                                child: Column(
                                  children: [
                                    Expanded(child: _buildPostList()),
                                    _buildFullEditor(),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Right Sidebar (Tools + OOC)
                          if (appSettings.rpShowToolsSidebar &&
                              !_desktopToolsCollapsed)
                            SizedBox(
                              width: 320,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black12,
                                  border: Border(left: BorderSide(color: cAsh)),
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: RPToolsPanel(
                                        isSidebar: true,
                                        notes: _notes,
                                        myStats: _myStats,
                                        partnerStats: _partnerStatsN.value,
                                        partnerName: widget.partnerName,
                                        importedWorlds: _importedWorlds,
                                        importedCharacters: _importedCharacters,
                                        availableWorlds: _sandboxWorlds,
                                        availableCharacters: _sandboxCharacters,
                                        onDiceRolled: (msg) {
                                          if (widget.sessionId.isNotEmpty) {
                                            _fs.addOocMessage(
                                              sessionId: widget.sessionId,
                                              content: msg,
                                              isSystem: true,
                                            );
                                            _log.addEvent(
                                              title: 'Dice roll',
                                              body: msg,
                                              source: 'dice',
                                            );
                                          }
                                        },
                                        onMyStatsChanged: (block) =>
                                            _saveMyStats(block),
                                        onImportWorld: (w) {
                                          setState(() {
                                            if (!_importedWorlds.any(
                                              (x) => x.id == w.id,
                                            )) {
                                              _importedWorlds.add(w);
                                            }
                                          });
                                          if (widget.sessionId.isNotEmpty) {
                                            _log.addWorldEntry(w);
                                            _fs.saveImportedItems(
                                              widget.sessionId,
                                              _importedCharacters
                                                  .map((c) => c.id)
                                                  .toList(),
                                              _importedWorlds
                                                  .map((w) => w.id)
                                                  .toList(),
                                            );
                                          }
                                        },
                                        onImportCharacter: (c) {
                                          setState(() {
                                            if (!_importedCharacters.any(
                                              (x) => x.id == c.id,
                                            )) {
                                              _importedCharacters.add(c);
                                            }
                                          });
                                          if (widget.sessionId.isNotEmpty) {
                                            _log.addCharacterEntry(c);
                                            _fs.saveImportedItems(
                                              widget.sessionId,
                                              _importedCharacters
                                                  .map((c) => c.id)
                                                  .toList(),
                                              _importedWorlds
                                                  .map((w) => w.id)
                                                  .toList(),
                                            );
                                          }
                                        },
                                        onRemoveWorld: (w) {
                                          setState(
                                            () => _importedWorlds.removeWhere(
                                              (x) => x.id == w.id,
                                            ),
                                          );
                                          if (widget.sessionId.isNotEmpty) {
                                            _fs.saveImportedItems(
                                              widget.sessionId,
                                              _importedCharacters
                                                  .map((c) => c.id)
                                                  .toList(),
                                              _importedWorlds
                                                  .map((w) => w.id)
                                                  .toList(),
                                            );
                                          }
                                        },
                                        onRemoveCharacter: (c) {
                                          setState(
                                            () =>
                                                _importedCharacters.removeWhere(
                                                  (x) => x.id == c.id,
                                                ),
                                          );
                                          if (widget.sessionId.isNotEmpty) {
                                            _fs.saveImportedItems(
                                              widget.sessionId,
                                              _importedCharacters
                                                  .map((c) => c.id)
                                                  .toList(),
                                              _importedWorlds
                                                  .map((w) => w.id)
                                                  .toList(),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    const Divider(color: cAsh, height: 1),
                                    if (appSettings.rpShowOoc)
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        curve: Curves.easeInOut,
                                        height: _desktopOOCExpanded ? 300 : 50,
                                        child: Column(
                                          children: [
                                            Material(
                                              color: cInk,
                                              child: InkWell(
                                                onTap: () {
                                                  setState(
                                                    () => _desktopOOCExpanded =
                                                        !_desktopOOCExpanded,
                                                  );
                                                  if (_desktopOOCExpanded) {
                                                    _oocUnread = 0;
                                                    _scrollOocToBottom();
                                                  }
                                                },
                                                child: Container(
                                                  height: 50,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                      ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        border: Border(
                                                          bottom: BorderSide(
                                                            color: cAsh,
                                                          ),
                                                        ),
                                                      ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      const Text(
                                                        'OOC CHAT',
                                                        style: TextStyle(
                                                          fontFamily:
                                                              'monospace',
                                                          fontSize: 11,
                                                          color: cIce,
                                                          letterSpacing: 4,
                                                        ),
                                                      ),
                                                      if (_oocUnread > 0 && !_desktopFocusMode && appSettings.rpOocBadgeOn)
                                                        _OocBadge(
                                                          count: _oocUnread,
                                                        ),
                                                      Icon(
                                                        _desktopOOCExpanded
                                                            ? Icons
                                                                  .keyboard_arrow_down
                                                            : Icons
                                                                  .keyboard_arrow_up,
                                                        size: 16,
                                                        color: cSmoke,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (_desktopOOCExpanded)
                                              Expanded(
                                                child: _buildOOCDesktopWidget(),
                                              ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom selection pill
              if (!kIsWeb &&
                  _selectedText.isNotEmpty &&
                  !_desktopOOCExpanded &&
                  !_settingsOpen)
                Positioned(
                  left: 300,
                  right: 320,
                  bottom: 100,
                  child: _buildSelectionPill(),
                ),

              // Settings Overlay
              if (_settingsOpen)
                Positioned(
                  right: 0,
                  top: 60,
                  bottom: 0,
                  child: _buildSettingsPanel(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout() {
    return AnimatedBuilder(
      animation: _moodCtrl,
      builder: (_, child) {
        final moodColor = _effectiveBg(MoodEngine.bgColor(_currentMood));
        return Scaffold(
          backgroundColor: cVoid,
          body: Stack(
            children: [
              // ── BACKGROUND: Shader + Particles ──
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    _canvasSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );

                    return AnimatedBuilder(
                      animation: _shaderTimeCtrl,
                      builder: (_, _) {
                        return Stack(
                          children: [
                            if (_moodShader != null)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _MoodShaderPainter(
                                    shader: _moodShader!,
                                    time: _shaderTimeCtrl.value * 10.0,
                                    moodColor: moodColor,
                                    intensity: _moodIntensity,
                                  ),
                                ),
                              ),
                            Positioned.fill(
                              child: ValueListenableBuilder<int>(
                                valueListenable: _particleTick,
                                builder: (_, _, _) => CustomPaint(
                                  painter: MoodParticlePainter(
                                    _particles,
                                    _currentMood,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // ── FOREGROUND: The actual room UI ──
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(child: _buildPostList()),
                    if (_editorExpanded)
                      _buildFullEditor()
                    else
                      _buildCollapsedEditor(),
                  ],
                ),
              ),

              // ── OVERLAYS (OOC, Settings, Selection) ──
              if (!_oocOpen && appSettings.rpShowOoc)
                Positioned(
                  right: 16,
                  bottom: _editorExpanded ? 320 : 90,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _oocOpen = true;
                        _oocUnread = 0;
                      });
                      _scrollOocToBottom();
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: cInk,
                            shape: BoxShape.circle,
                            border: Border.all(color: cAsh),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            color: cSmoke,
                            size: 20,
                          ),
                        ),
                        if (_oocUnread > 0 && !_desktopFocusMode && appSettings.rpOocBadgeOn)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: _OocBadge(count: _oocUnread),
                          ),
                      ],
                    ),
                  ),
                ),
              if (_oocOpen) _buildOOCPanel(),
              if (_settingsOpen) _buildSettingsPanel(),
              if (!kIsWeb &&
                  _selectedText.isNotEmpty &&
                  !_oocOpen &&
                  !_settingsOpen)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: _editorExpanded ? 340 : 100,
                  child: _buildSelectionPill(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    if (!appSettings.rpHeaderShow) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            LoreTap(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.arrow_back_ios, color: cSmoke, size: 16),
            ),
            const Spacer(),
            LoreTap(
              onTap: () => setState(() => _settingsOpen = !_settingsOpen),
              child: const Icon(Icons.tune, color: cSmoke, size: 18),
            ),
          ],
        ),
      );
    }
    final titleSize = appSettings.rpHeaderSize == 'S'
        ? 13.0
        : appSettings.rpHeaderSize == 'L'
        ? 20.0
        : 16.0;
    final subSize = appSettings.rpHeaderSize == 'S'
        ? 8.0
        : appSettings.rpHeaderSize == 'L'
        ? 10.0
        : 9.0;
    final vPad = appSettings.rpHeaderSize == 'S'
        ? 8.0
        : appSettings.rpHeaderSize == 'L'
        ? 16.0
        : 12.0;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: 8,
          sigmaY: 8,
        ), // <-- The frosted glass blur
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: vPad),
          decoration: BoxDecoration(
            color: cInk.withValues(alpha: 0.65), // More transparent
            border: Border(
              bottom: BorderSide(color: appSettings.rpHeaderAccent),
            ),
          ),
          child: Row(
            children: [
              LoreTap(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(
                  Icons.arrow_back_ios,
                  color: cSmoke,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LoreTap(
                  onTap: _editSessionTitle,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_sessionTitle.isNotEmpty)
                        Text(
                          _sessionTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w300,
                            fontStyle: FontStyle.italic,
                            color: cParchment,
                          ),
                        )
                      else
                        Text(
                          widget.partnerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w300,
                            fontStyle: FontStyle.italic,
                            color: cParchment,
                          ),
                        ),
                      Text(
                        _sessionTitle.isNotEmpty
                            ? '${widget.partnerName} · ${widget.genre}'
                            : widget.genre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: subSize,
                          color: cSmoke,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_aiMoodEnabled)
                LoreTap(
                  onTap: _moodLockedByUser ? _unlockMood : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _moodLockedByUser
                            ? cSmoke
                            : cMagic.withValues(alpha: 0.5),
                      ),
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_moodLockedByUser) ...[
                          const Icon(
                            Icons.lock_outline,
                            size: 9,
                            color: cSmoke,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            MoodEngine.moodLabel(_currentMood),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: cSmoke,
                              letterSpacing: 2,
                            ),
                          ),
                        ] else ...[
                          const Text(
                            '✦',
                            style: TextStyle(fontSize: 9, color: cMagic),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            MoodEngine.moodLabel(_currentMood).toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: cMagic,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Tooltip(
                message: MediaQuery.sizeOf(context).width >= 900
                    ? 'Log (Ctrl+B)'
                    : 'Log',
                child: LoreTap(
                  onTap: () {
                    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
                    if (isDesktop) {
                      setState(
                        () => _desktopLogCollapsed = !_desktopLogCollapsed,
                      );
                    } else {
                      _openLog();
                    }
                  },
                  child: Icon(
                    _desktopLogCollapsed
                        ? Icons.menu_book_outlined
                        : Icons.menu_book,
                    color: _desktopLogCollapsed ? cSmoke : cGold,
                    size: MediaQuery.sizeOf(context).width >= 900 ? 16 : 18,
                  ),
                ),
              ),
              SizedBox(width: MediaQuery.sizeOf(context).width >= 900 ? 8 : 12),
              Tooltip(
                message: MediaQuery.sizeOf(context).width >= 900
                    ? 'Tools (Ctrl+T)'
                    : 'Tools',
                child: LoreTap(
                  onTap: () {
                    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
                    if (isDesktop) {
                      setState(
                        () => _desktopToolsCollapsed = !_desktopToolsCollapsed,
                      );
                    } else {
                      _openToolsPanel();
                    }
                  },
                  child: Icon(
                    _desktopToolsCollapsed
                        ? Icons.construction_outlined
                        : Icons.construction,
                    color: _desktopToolsCollapsed ? cSmoke : cGold,
                    size: MediaQuery.sizeOf(context).width >= 900 ? 16 : 18,
                  ),
                ),
              ),
              SizedBox(width: MediaQuery.sizeOf(context).width >= 900 ? 8 : 12),
              // Desktop only: Focus mode - collapse both, tap again to restore.
              if (MediaQuery.sizeOf(context).width >= 900)
                Tooltip(
                  message: 'Focus (F)',
                  child: LoreTap(
                    onTap: () => setState(() {
                      if (_desktopFocusMode) {
                        _desktopLogCollapsed = false;
                        _desktopToolsCollapsed = false;
                      } else {
                        _desktopLogCollapsed = true;
                        _desktopToolsCollapsed = true;
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _desktopFocusMode ? cGold : cAsh,
                        ),
                        color: _desktopFocusMode
                            ? cGold.withValues(alpha: 0.12)
                            : Colors.transparent,
                      ),
                      child: Text(
                        _desktopFocusMode ? 'EXIT FOCUS' : 'FOCUS',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          color: _desktopFocusMode ? cGold : cSmoke,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              if (MediaQuery.sizeOf(context).width >= 900)
                const SizedBox(width: 8),
              LoreTap(
                onTap: () => setState(() => _settingsOpen = !_settingsOpen),
                child: const Icon(Icons.tune, color: cSmoke, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostList() {
    if (_loadingPosts && widget.sessionId.isNotEmpty) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: cSmoke),
        ),
      );
    }
    if (_posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'The story begins here.\nWrite the first post.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: cSmoke,
              fontStyle: FontStyle.italic,
              height: 1.8,
            ),
          ),
        ),
      );
    }
    switch (_displayMode) {
      case RPDisplayMode.cards:
        return _buildCardsView();
      case RPDisplayMode.bubbles:
        return _buildBubblesView();
      case RPDisplayMode.classical:
        return _buildClassicalView();
    }
  }

  Widget _buildCardsView() {
    return SelectionArea(
      onSelectionChanged: (value) =>
          _onSelectionChanged(value?.plainText ?? ''),
      contextMenuBuilder: (context, state) {
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: [
            ...state.contextMenuButtonItems,
            ContextMenuButtonItem(
              label: 'Add to log',
              onPressed: () {
                state.hideToolbar();
                _addSelectionToLog();
              },
            ),
          ],
        );
      },
      child: ScrollConfiguration(
        behavior: NoGlowBehavior(),
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: EdgeInsets.fromLTRB(
            MediaQuery.of(context).size.width > 900 ? 8 : 12,
            MediaQuery.of(context).size.width > 900 ? 8 : 12,
            MediaQuery.of(context).size.width > 900 ? 8 : 12,
            8,
          ),
          itemCount: _posts.length,
          itemBuilder: (_, i) => _PostCard(
            post: _posts[i],
            isExpanded: _expandedPostId == _posts[i].id,
            onTap: () => setState(
              () => _expandedPostId = _expandedPostId == _posts[i].id
                  ? null
                  : _posts[i].id,
            ),
            onLongPress: () => _showPostActions(_posts[i]),
            onQuote: () => _quotePost(_posts[i].id),
            onEdit: _posts[i].isUser ? () => _editPost(_posts[i]) : null,
            onMore: () => _showPostActions(_posts[i]),
            onAddToLog: _addToLogFromText,
            onSelectionChanged: _onSelectionChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildBubblesView() {
    return SelectionArea(
      onSelectionChanged: (value) =>
          _onSelectionChanged(value?.plainText ?? ''),
      contextMenuBuilder: (context, state) {
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: [
            ...state.contextMenuButtonItems,
            ContextMenuButtonItem(
              label: 'Add to log',
              onPressed: () {
                state.hideToolbar();
                _addSelectionToLog();
              },
            ),
          ],
        );
      },
      child: ScrollConfiguration(
        behavior: NoGlowBehavior(),
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: EdgeInsets.fromLTRB(
            12,
            MediaQuery.of(context).size.width > 900 ? 10 : 16,
            12,
            8,
          ),
          itemCount: _posts.length,
          itemBuilder: (_, i) {
            final post = _posts[i];
            final isUser = post.isUser;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.width > 900 ? 10 : 16,
              ),
              child: Row(
                mainAxisAlignment: isUser
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser) ...[
                    Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 8, top: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cAsh,
                        border: Border.all(color: cSmoke),
                      ),
                      child: Center(
                        child: Text(
                          post.author.isNotEmpty
                              ? post.author[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: cMist,
                          ),
                        ),
                      ),
                    ),
                  ],
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72,
                      ),
                      child: Column(
                        crossAxisAlignment: isUser
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onLongPress: () => _showPostActions(post),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                bottom: 4,
                                left: 2,
                                right: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    post.characterName ?? post.author,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 9,
                                      letterSpacing: 2,
                                      color: isUser
                                          ? (appSettings.textColourFor(
                                                  'char_name',
                                                ) ??
                                                (post.textColor == cParchment
                                                    ? cGold
                                                    : post.textColor))
                                          : (appSettings.textColourFor(
                                                  'partner_name',
                                                ) ??
                                                cMist),
                                    ),
                                  ),
                                  if (post.locationName != null) ...[
                                    const Text(
                                      ' · ',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 9,
                                        color: cSmoke,
                                      ),
                                    ),
                                    Text(
                                      post.locationName!,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 9,
                                        color:
                                            appSettings.textColourFor(
                                              'location_name',
                                            ) ??
                                            cSmoke,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width > 900
                                  ? 12
                                  : 14,
                              vertical: MediaQuery.of(context).size.width > 900
                                  ? 8
                                  : 12,
                            ),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? Color.lerp(
                                      cVoid,
                                      cGold,
                                      0.15,
                                    )!.withValues(alpha: 0.85)
                                  : const Color(
                                      0xFF08080A,
                                    ).withValues(alpha: 0.82),
                              border: Border.all(
                                color: isUser
                                    ? cGold.withValues(alpha: 0.3)
                                    : cAsh,
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(2),
                                topRight: const Radius.circular(2),
                                bottomLeft: Radius.circular(isUser ? 2 : 0),
                                bottomRight: Radius.circular(isUser ? 0 : 2),
                              ),
                            ),
                            child: _selectablePostText(
                              text: post.content,
                              style: TextStyle(
                                fontSize: post.fontSize * _rpPostScale(),
                                color:
                                    appSettings.textColourFor('post_content') ??
                                    post.textColor,
                                fontStyle: post.italic
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                                fontWeight: post.bold
                                    ? FontWeight.bold
                                    : FontWeight.w300,
                                height: 1.7,
                              ),
                              onAddToLog: _addToLogFromText,
                              onSelectionChanged: _onSelectionChanged,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 4,
                              left: 2,
                              right: 2,
                            ),
                            child: Text(
                              '${post.wordCount}w',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 8,
                                color: cSmoke,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isUser) const SizedBox(width: 8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildClassicalView() {
    return SelectionArea(
      onSelectionChanged: (value) =>
          _onSelectionChanged(value?.plainText ?? ''),
      contextMenuBuilder: (context, state) {
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: [
            ...state.contextMenuButtonItems,
            ContextMenuButtonItem(
              label: 'Add to log',
              onPressed: () {
                state.hideToolbar();
                _addSelectionToLog();
              },
            ),
          ],
        );
      },
      child: ScrollConfiguration(
        behavior: NoGlowBehavior(),
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: EdgeInsets.fromLTRB(
            MediaQuery.of(context).size.width > 900 ? 16 : 24,
            MediaQuery.of(context).size.width > 900 ? 16 : 24,
            MediaQuery.of(context).size.width > 900 ? 16 : 24,
            8,
          ),
          itemCount: _posts.length,
          itemBuilder: (_, i) {
            final post = _posts[i];
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.width > 900 ? 18 : 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onLongPress: () => _showPostActions(post),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Text(
                          (post.characterName ?? post.author).toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            letterSpacing: 4,
                            color: post.isUser
                                ? (appSettings.textColourFor('char_name') ??
                                      (post.textColor == cParchment
                                          ? cGold
                                          : post.textColor.withValues(
                                              alpha: 0.9,
                                            )))
                                : (appSettings.textColourFor('partner_name') ??
                                      cMist),
                          ),
                        ),
                        if (post.locationName != null) ...[
                          const Text(
                            '  ·  ',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: cSmoke,
                            ),
                          ),
                          Text(
                            post.locationName!.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              letterSpacing: 2,
                              color:
                                  appSettings.textColourFor('location_name') ??
                                  cSmoke,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (post.quotedContent != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: cSmoke, width: 2),
                          ),
                        ),
                        child: Text(
                          '${post.quotedAuthor ?? ""}: ${post.quotedContent}...',
                          style: const TextStyle(
                            fontSize: 11,
                            color: cSmoke,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  _selectablePostText(
                    text: post.content,
                    style: TextStyle(
                      fontSize: post.fontSize * _rpPostScale(),
                      color:
                          appSettings.textColourFor('post_content') ??
                          post.textColor,
                      fontStyle: post.italic
                          ? FontStyle.italic
                          : FontStyle.normal,
                      fontWeight: post.bold ? FontWeight.bold : FontWeight.w300,
                      height: 2.0,
                    ),
                    onAddToLog: _addToLogFromText,
                    onSelectionChanged: _onSelectionChanged,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: cAsh, height: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '${post.wordCount}w',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 8,
                            color:
                                appSettings.textColourFor('timestamp') ??
                                cSmoke,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: cAsh, height: 1)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openToolsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => ValueListenableBuilder<StatBlock?>(
          valueListenable: _partnerStatsN,
          builder: (_, partnerStats, _) => RPToolsPanel(
            isSidebar: false,
            notes: _notes,
            myStats: _myStats,
            partnerStats: partnerStats,
            partnerName: widget.partnerName,
            importedWorlds: _importedWorlds,
            importedCharacters: _importedCharacters,
            availableWorlds: _sandboxWorlds,
            availableCharacters: _sandboxCharacters,
            onDiceRolled: (msg) {
              if (widget.sessionId.isNotEmpty) {
                _fs.addOocMessage(
                  sessionId: widget.sessionId,
                  content: msg,
                  isSystem: true,
                );
                _log.addEvent(title: 'Dice roll', body: msg, source: 'dice');
              } else {
                setState(
                  () => _oocMessages.add(
                    OOCMessage(
                      author: 'System',
                      content: msg,
                      isUser: false,
                      timestamp: DateTime.now(),
                    ),
                  ),
                );
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: cInk,
                  behavior: SnackBarBehavior.floating,
                  shape: const RoundedRectangleBorder(),
                  duration: const Duration(seconds: 3),
                  content: Text(
                    msg,
                    style: const TextStyle(
                      fontSize: 16,
                      color: cParchment,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              );
            },
            onMyStatsChanged: (block) {
              _saveMyStats(block);
              setModalState(() {});
            },
            onImportWorld: (w) {
              setState(() {
                if (!_importedWorlds.any((x) => x.id == w.id)) {
                  _importedWorlds.add(w);
                }
              });
              if (widget.sessionId.isNotEmpty) {
                _log.addWorldEntry(w);
                _fs.saveImportedItems(
                  widget.sessionId,
                  _importedCharacters.map((c) => c.id).toList(),
                  _importedWorlds.map((w) => w.id).toList(),
                );
              }
              setModalState(() {});
            },
            onImportCharacter: (c) {
              setState(() {
                if (!_importedCharacters.any((x) => x.id == c.id)) {
                  _importedCharacters.add(c);
                  _fs.saveImportedItems(
                    widget.sessionId,
                    _importedCharacters.map((c) => c.id).toList(),
                    _importedWorlds.map((w) => w.id).toList(),
                  );
                }
              });
              if (widget.sessionId.isNotEmpty) {
                _log.addCharacterEntry(c);
              }
              setModalState(() {});
            },
            onRemoveWorld: (w) {
              setState(() => _importedWorlds.removeWhere((x) => x.id == w.id));
              if (widget.sessionId.isNotEmpty) {
                _fs.saveImportedItems(
                  widget.sessionId,
                  _importedCharacters.map((c) => c.id).toList(),
                  _importedWorlds.map((w) => w.id).toList(),
                );
              }
              setModalState(() {});
            },
            onRemoveCharacter: (c) {
              setState(
                () => _importedCharacters.removeWhere((x) => x.id == c.id),
              );
              if (widget.sessionId.isNotEmpty) {
                _fs.saveImportedItems(
                  widget.sessionId,
                  _importedCharacters.map((c) => c.id).toList(),
                  _importedWorlds.map((w) => w.id).toList(),
                );
              }
              setModalState(() {});
            },
          ),
        ),
      ),
    );
  }

  void _showPostActions(RPPost post) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: cInk,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: cAsh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _actionTile(Icons.format_quote, 'Quote this post', () {
              Navigator.pop(context);
              _quotePost(post.id);
            }),
            _actionTile(Icons.menu_book_outlined, 'Add to log', () {
              Navigator.pop(context);
              _addToLogFromText(post.content);
            }),
            if (post.isUser) ...[
              _actionTile(Icons.edit_outlined, 'Edit post', () {
                Navigator.pop(context);
                _editPost(post);
              }),
              _actionTile(Icons.delete_outline, 'Delete post', () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
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
                            'DELETE POST?',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: cEmber,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'This cannot be undone.',
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
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(ctx, false),
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
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(ctx, true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    color: cEmber,
                                    child: const Center(
                                      child: Text(
                                        'Delete',
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
                      ),
                    ),
                  ),
                );
                if (confirmed == true) _deletePost(post.id);
              }, color: cEmber),
            ],
            if (post.isUser) ...[
              _actionTile(Icons.edit_outlined, 'Edit post', () {
                Navigator.pop(context);
                _editPost(post);
              }),
              _actionTile(Icons.delete_outline, 'Delete post', () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
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
                            'DELETE POST?',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: cEmber,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'This cannot be undone.',
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
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(ctx, false),
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
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(ctx, true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    color: cEmber,
                                    child: const Center(
                                      child: Text(
                                        'Delete',
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
                      ),
                    ),
                  ),
                );
                if (confirmed == true) _deletePost(post.id);
              }, color: cEmber),
            ],

            _actionTile(Icons.copy, 'Copy text', () {
              Clipboard.setData(ClipboardData(text: post.content));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: cInk,
                  content: Text('Copied', style: TextStyle(color: cParchment)),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color color = cMist,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: cAsh)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCharacterSwitcher() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cInk,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(),
      builder: (_) => Container(
        height: 340,
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'WRITING AS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      color: cSmoke,
                      letterSpacing: 3,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 18, color: cSmoke),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── THE CARD DECK ──
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _switcherCharacters.length + 1, // +1 for "Myself"
                itemBuilder: (context, index) {
                  // First item is always "Myself"
                  if (index == 0) {
                    final isSelected = _activeCharacter == null;
                    return _CharacterSwitcherCard(
                      isSelected: isSelected,
                      name: _auth.currentName ?? 'Myself',
                      pronouns: 'You',
                      avatarUrl: null, // Fallback to icon
                      accent: cGold,
                      onTap: () {
                        setState(() => _activeCharacter = null);
                        Navigator.pop(context);
                      },
                    );
                  }

                  // The rest are imported characters
                  final c = _switcherCharacters[index - 1];
                  final isSelected = _activeCharacter?.id == c.id;

                  return _CharacterSwitcherCard(
                    isSelected: isSelected,
                    name: c.name,
                    pronouns: '${c.pronouns} · ${c.age}',
                    avatarUrl: c.avatarUrl,
                    accent: c.accentColor,
                    onTap: () {
                      setState(() => _activeCharacter = c);
                      Navigator.pop(context);
                      if (widget.sessionId.isNotEmpty) {
                        _log.addEvent(
                          title: 'Writing as ${c.name}',
                          body: 'Switched to ${c.name}.',
                          source: 'character',
                          meta: {'characterId': c.id, 'characterName': c.name},
                        );
                      }
                    },
                  );
                },
              ),
            ),

            if (_switcherCharacters.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  'Import characters from the Tools panel first to use character switching.',
                  style: TextStyle(
                    fontSize: 12,
                    color: cSmoke,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedEditor() {
    final charColor = _activeCharacter?.accentColor ?? cGold;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            border: const Border(top: BorderSide(color: cAsh)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _editorExpanded = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: cAsh),
                      color: cInk,
                    ),
                    child: Text(
                      _draftSaved
                          ? 'Draft restored...'
                          : 'Continue the story...',
                      style: TextStyle(
                        fontSize: 14,
                        color: _draftSaved
                            ? charColor.withValues(alpha: 0.6)
                            : cSmoke,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _showCharacterSwitcher,
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _activeCharacter != null
                          ? charColor.withValues(alpha: 0.5)
                          : cAsh,
                    ),
                    color: _activeCharacter != null
                        ? charColor.withValues(alpha: 0.08)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 16,
                    color: _activeCharacter != null ? charColor : cSmoke,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullEditor() {
    final charColor = _activeCharacter?.accentColor ?? _fontColor;
    final displayName = _activeCharacter?.name ?? 'You';
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(
              alpha: 0.6,
            ), // Slightly darker for typing contrast
            border: const Border(top: BorderSide(color: cAsh)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_editingPostId != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cIce.withValues(alpha: 0.06),
                    border: Border(
                      bottom: BorderSide(color: cIce.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 12, color: cIce),
                      const SizedBox(width: 8),
                      const Text(
                        'editing post',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          color: cIce,
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      LoreTap(
                        onTap: () => setState(() {
                          _editingPostId = null;
                          _editorCtrl.text = '';
                        }),
                        child: const Text(
                          'cancel',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 8,
                            color: cSmoke,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_activeCharacter != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: charColor.withValues(alpha: 0.06),
                    border: Border(
                      bottom: BorderSide(
                        color: charColor.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: charColor,
                        ),
                      ),
                      Text(
                        displayName,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          color: charColor,
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _activeCharacter = null),
                        child: const Text(
                          'exit character',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 8,
                            color: cSmoke,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_availableLocations.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: cAsh)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: cSmoke,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _activeLocation = null),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _activeLocation == null
                                        ? cSmoke.withValues(alpha: 0.2)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: _activeLocation == null
                                          ? cSmoke
                                          : cAsh,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: const Text(
                                    'none',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 8,
                                      color: cSmoke,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                              ..._availableLocations.map(
                                (loc) => GestureDetector(
                                  onTap: () {
                                    setState(() => _activeLocation = loc);
                                    if (widget.sessionId.isNotEmpty) {
                                      _log.addEvent(
                                        title: 'Location · $loc',
                                        body: 'The scene moved to $loc.',
                                        source: 'location',
                                        meta: {'locationName': loc},
                                      );
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _activeLocation == loc
                                          ? cGold.withValues(alpha: 0.15)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _activeLocation == loc
                                            ? cGold.withValues(alpha: 0.5)
                                            : cAsh,
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: Text(
                                      loc,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 8,
                                        color: _activeLocation == loc
                                            ? cGold
                                            : cSmoke,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_quotingPostId != null) _buildQuotePreview(),
              _buildFormattingBar(),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ScrollConfiguration(
                  behavior: NoGlowBehavior(),
                  child: Focus(
                    onKeyEvent: (node, event) {
                      final isDesktop =
                          MediaQuery.sizeOf(context).width >= 900 || kIsWeb;
                      if (!isDesktop) return KeyEventResult.ignored;
                      if (event is KeyDownEvent) {
                        final isCtrl =
                            HardwareKeyboard.instance.isControlPressed ||
                            HardwareKeyboard.instance.isMetaPressed;
                        if (isCtrl &&
                            event.logicalKey == LogicalKeyboardKey.keyB) {
                          if (MediaQuery.sizeOf(context).width >= 900) {
                            setState(
                              () =>
                                  _desktopLogCollapsed = !_desktopLogCollapsed,
                            );
                          } else {
                            _openLog();
                          }
                          return KeyEventResult.handled;
                        }
                        if (isCtrl &&
                            event.logicalKey == LogicalKeyboardKey.keyT) {
                          if (MediaQuery.sizeOf(context).width >= 900) {
                            setState(
                              () => _desktopToolsCollapsed =
                                  !_desktopToolsCollapsed,
                            );
                          } else {
                            _openToolsPanel();
                          }
                          return KeyEventResult.handled;
                        }
                        final isEnter =
                            event.logicalKey == LogicalKeyboardKey.enter ||
                            event.logicalKey == LogicalKeyboardKey.numpadEnter;
                        final isShift =
                            HardwareKeyboard.instance.isShiftPressed;

                        if (isEnter) {
                          if (appSettings.enterToSend && !isShift) {
                            _submitPost();
                            return KeyEventResult.handled;
                          } else if (!appSettings.enterToSend && isShift) {
                            _submitPost();
                            return KeyEventResult.handled;
                          }
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _editorCtrl,
                      focusNode: _editorFocus,
                      maxLines: null,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: _fontSize * _rpEditorScale(),
                        color: _activeCharacter != null
                            ? charColor
                            : _fontColor,
                        fontStyle: _italic
                            ? FontStyle.italic
                            : FontStyle.normal,
                        fontWeight: _bold ? FontWeight.bold : FontWeight.w300,
                        height: 1.8,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Write your post...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: cSmoke,
                          fontStyle: FontStyle.italic,
                        ),
                        border: InputBorder.none,
                      ),
                      cursorColor: cGold,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Row(
                  children: [
                    Row(
                      children: [
                        Text(
                          '$_wordCount words',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: cSmoke,
                            letterSpacing: 1,
                          ),
                        ),
                        if (_draftSaved && _editorCtrl.text.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.circle, size: 5, color: cVine),
                          const SizedBox(width: 4),
                          const Text(
                            'saved',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 8,
                              color: cVine,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() {
                        _editorExpanded = false;
                        _quotingPostId = null;
                        _editingPostId = null;
                        _editorCtrl.text = '';
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: cAsh),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: cSmoke,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    LoreTap(
                      onTap: _sending ? null : _submitPost,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        color: _editorCtrl.text.trim().isEmpty
                            ? cAsh
                            : _editingPostId != null
                            ? cIce.withValues(alpha: 0.8)
                            : cParchment,
                        child: Text(
                          _sending
                              ? 'Posting...'
                              : _editingPostId != null
                              ? 'Save'
                              : 'Post',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: _editorCtrl.text.trim().isEmpty
                                ? cSmoke
                                : cVoid,
                            letterSpacing: 1,
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
  }

  int get _wordCount {
    final text = _editorCtrl.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  Widget _buildQuotePreview() {
    RPPost? post;
    for (final p in _posts) {
      if (p.id == _quotingPostId) {
        post = p;
        break;
      }
    }
    if (post == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _quotingPostId != null) {
          setState(() => _quotingPostId = null);
        }
      });
      return const SizedBox.shrink();
    }
    final preview = post.content.substring(0, min(80, post.content.length));
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: cSmoke, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${post.characterName ?? post.author}: $preview...',
              style: const TextStyle(
                fontSize: 12,
                color: cSmoke,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _quotingPostId = null),
            child: const Icon(Icons.close, size: 14, color: cSmoke),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattingBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showCharacterSwitcher,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _activeCharacter != null
                    ? (_activeCharacter!.accentColor).withValues(alpha: 0.12)
                    : Colors.transparent,
                border: Border.all(
                  color: _activeCharacter != null
                      ? _activeCharacter!.accentColor.withValues(alpha: 0.5)
                      : cAsh,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 12,
                    color: _activeCharacter != null
                        ? _activeCharacter!.accentColor
                        : cSmoke,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _activeCharacter?.name ?? 'Self',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      letterSpacing: 1,
                      color: _activeCharacter != null
                          ? _activeCharacter!.accentColor
                          : cSmoke,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          _fmtBtn(
            'B',
            _bold,
            () => setState(() => _bold = !_bold),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: cMist,
            ),
          ),
          _fmtBtn(
            'I',
            _italic,
            () => setState(() => _italic = !_italic),
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 13,
              color: cMist,
            ),
          ),
          const SizedBox(width: 6),
          _fmtLabel('Size'),
          ...[12.0, 14.0, 16.0, 18.0, 22.0].map(
            (s) => _fmtBtn(
              s.toInt().toString(),
              _fontSize == s,
              () => setState(() => _fontSize = s),
              style: const TextStyle(
                fontSize: 10,
                color: cMist,
                fontFamily: 'monospace',
              ),
            ),
          ),
          if (_activeCharacter == null) ...[
            const SizedBox(width: 6),
            _fmtLabel('Colour'),
            ...[
              cParchment,
              cGold,
              cIce,
              cEmber,
              cMagic,
              cVine,
              Colors.white,
              const Color(0xFFa0c4a0),
            ].map(
              (c) => GestureDetector(
                onTap: () => setState(() => _fontColor = c),
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _fontColor == c
                          ? Colors.white
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fmtBtn(
    String label,
    bool active,
    VoidCallback onTap, {
    TextStyle? style,
  }) {
    return LoreTap(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? cAsh : Colors.transparent,
          border: Border.all(color: active ? cSmoke : cAsh),
        ),
        child: Text(
          label,
          style: style ?? const TextStyle(fontSize: 12, color: cMist),
        ),
      ),
    );
  }

  Widget _fmtLabel(String t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        t,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 9,
          color: cSmoke,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildOOCPanel() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: const BoxDecoration(
          color: cInk,
          border: Border(top: BorderSide(color: cAsh)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'OOC',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: cIce,
                      letterSpacing: 4,
                    ),
                  ),
                  if (_oocUnread > 0 && !_desktopFocusMode && appSettings.rpOocBadgeOn)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _OocBadge(count: _oocUnread),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _oocOpen = false),
                    child: const Icon(Icons.close, color: cSmoke, size: 18),
                  ),
                ],
              ),
            ),
            const Divider(color: cAsh, height: 1),
            Expanded(
              child: ScrollConfiguration(
                behavior: NoGlowBehavior(),
                child: ListView.builder(
                  controller: _oocScrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: _oocMessages.length,
                  itemBuilder: (_, i) {
                    final msg = _oocMessages[i];
                    return Align(
                      alignment: msg.isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: msg.isUser ? cAsh : cVoid,
                          border: Border.all(color: cAsh),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!msg.isUser)
                              Text(
                                msg.author,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 9,
                                  color:
                                      appSettings.textColourFor(
                                        'partner_name',
                                      ) ??
                                      cIce,
                                  letterSpacing: 2,
                                ),
                              ),
                            if (msg.content.isNotEmpty)
                              _OocLinkText(
                                text: msg.content,
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      appSettings.textColourFor('ooc') ?? cMist,
                                  height: 1.5,
                                ),
                              ),
                            if (msg.mediaUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _OocMediaPreview(
                                  msg.mediaUrl!,
                                  isEncrypted: msg.isEncryptedMedia,
                                  sessionId: widget.sessionId,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: cAsh)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: cInk,
                        builder: (ctx) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.link, color: cGold),
                              title: const Text(
                                'Paste Web Link',
                                style: TextStyle(color: cParchment),
                              ),
                              onTap: () async {
                                Navigator.pop(ctx);
                                final mediaUrl = await _promptForMediaUrl();
                                if (mediaUrl != null && mediaUrl.isNotEmpty) {
                                  _sendEncryptedMediaUrl(mediaUrl);
                                }
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.image, color: cIce),
                              title: const Text(
                                'Upload Image',
                                style: TextStyle(color: cParchment),
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                _pickAndUploadImage();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: cAsh),
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 18,
                        color: cSmoke,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (!kIsWeb) return KeyEventResult.ignored;
                        if (event is KeyDownEvent) {
                          final isEnter =
                              event.logicalKey == LogicalKeyboardKey.enter ||
                              event.logicalKey ==
                                  LogicalKeyboardKey.numpadEnter;
                          final isShift =
                              HardwareKeyboard.instance.isShiftPressed;
                          if (isEnter) {
                            if (appSettings.enterToSend && !isShift) {
                              _sendOocMessage();
                              return KeyEventResult.handled;
                            } else if (!appSettings.enterToSend && isShift) {
                              _sendOocMessage();
                              return KeyEventResult.handled;
                            }
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: _oocCtrl,
                        focusNode: _oocFocus2,
                        style: const TextStyle(fontSize: 13, color: cParchment),
                        decoration: const InputDecoration(
                          hintText: 'Out of character...',
                          hintStyle: TextStyle(fontSize: 13, color: cSmoke),
                          border: InputBorder.none,
                        ),
                        cursorColor: cIce,
                      ),
                    ),
                  ),
                  LoreTap(
                    onTap: _sendOocMessage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      color: cAsh,
                      child: const Text(
                        'Send',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: cMist,
                          letterSpacing: 1,
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
    );
  }

  Widget _buildSettingsPanel() {
    return Positioned(
      right: 0,
      top: 60,
      bottom: 16,
      child: Container(
        width: 270,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height - 76,
        ),
        decoration: BoxDecoration(
          color: cInk,
          border: Border.all(color: cAsh),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Text(
                      'SETTINGS',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        color: cGold,
                        letterSpacing: 3,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _settingsOpen = false),
                      child: const Icon(Icons.close, size: 14, color: cSmoke),
                    ),
                  ],
                ),
              ),
              const Divider(color: cAsh, height: 1),
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: Text(
                  'DISPLAY MODE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cSmoke,
                    letterSpacing: 3,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Row(
                  children: [
                    _modeBtn(
                      RPDisplayMode.cards,
                      Icons.credit_card_outlined,
                      'Cards',
                    ),
                    const SizedBox(width: 6),
                    _modeBtn(
                      RPDisplayMode.bubbles,
                      Icons.chat_bubble_outline,
                      'Bubbles',
                    ),
                    const SizedBox(width: 6),
                    _modeBtn(
                      RPDisplayMode.classical,
                      Icons.article_outlined,
                      'Classical',
                    ),
                  ],
                ),
              ),
              const Divider(color: cAsh, height: 1),
              _settingToggle('Scene Mood', _aiMoodEnabled, (v) {
                appSettings.setAiMood(v);
              }),
              if (_aiMoodEnabled) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 10, 14, 4),
                  child: Text(
                    'MOOD INTENSITY',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      color: cSmoke,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Row(
                    children: [
                      const Text(
                        'Subtle',
                        style: TextStyle(fontSize: 10, color: cSmoke),
                      ),
                      Expanded(
                        child: Slider(
                          value: _moodIntensity,
                          onChanged: (v) {
                            setState(() => _moodIntensity = v);
                            _initParticles();
                            _particleTick.value++;
                          },
                          activeColor: cGold,
                          inactiveColor: cAsh,
                        ),
                      ),
                      const Text(
                        'Dramatic',
                        style: TextStyle(fontSize: 10, color: cSmoke),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 4, 14, 6),
                  child: Text(
                    'MOOD CONTROL',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      color: cSmoke,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      GestureDetector(
                        onTap: _unlockMood,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: !_moodLockedByUser ? cMagic : cAsh,
                            ),
                            color: !_moodLockedByUser
                                ? cMagic.withValues(alpha: 0.1)
                                : Colors.transparent,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '✦',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: !_moodLockedByUser ? cMagic : cSmoke,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'AUTO',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 9,
                                  letterSpacing: 1,
                                  color: !_moodLockedByUser ? cMagic : cSmoke,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ...StoryMood.values.map((m) {
                        final isActive = _moodLockedByUser && m == _currentMood;
                        return GestureDetector(
                          onTap: () => _setMoodManual(m),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isActive ? cGold : cAsh,
                              ),
                              color: isActive
                                  ? cGold.withValues(alpha: 0.08)
                                  : Colors.transparent,
                            ),
                            child: Text(
                              MoodEngine.moodLabel(m),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                letterSpacing: 1,
                                color: isActive ? cGold : cSmoke,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                if (_moodLockedByUser)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: GestureDetector(
                      onTap: _unlockMood,
                      child: const Text(
                        '← return control to AI',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          color: cMagic,
                          letterSpacing: 1,
                          decoration: TextDecoration.underline,
                          decorationColor: cMagic,
                        ),
                      ),
                    ),
                  ),
              ],
              _buildRpCustomizeSection(),
              const Divider(color: cAsh, height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _settingsOpen = false);
                    showBlockDialog(
                      context: context,
                      partnerName: widget.partnerName,
                      myCode: _auth.currentCode ?? '',
                      partnerCode: widget.partnerCode,
                      fs: _fs,
                    );
                  },
                  child: Row(
                    children: const [
                      Icon(Icons.block, size: 14, color: cEmber),
                      SizedBox(width: 8),
                      Text(
                        'Block this user',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          color: cEmber,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRpCustomizeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: cAsh, height: 1),
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Text(
            'RP ROOM CUSTOMIZE',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: cSmoke,
              letterSpacing: 3,
            ),
          ),
        ),
        _settingToggle(
          'Show header',
          appSettings.rpHeaderShow,
          (v) => appSettings.setRpHeaderShow(v),
        ),
        if (appSettings.rpHeaderShow) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Row(
              children: [
                const Text(
                  'Header size',
                  style: TextStyle(
                    fontSize: 12,
                    color: cMist,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const Spacer(),
                _rpChip(
                  'S',
                  appSettings.rpHeaderSize == 'S',
                  () => appSettings.setRpHeaderSize('S'),
                ),
                const SizedBox(width: 6),
                _rpChip(
                  'M',
                  appSettings.rpHeaderSize == 'M',
                  () => appSettings.setRpHeaderSize('M'),
                ),
                const SizedBox(width: 6),
                _rpChip(
                  'L',
                  appSettings.rpHeaderSize == 'L',
                  () => appSettings.setRpHeaderSize('L'),
                ),
              ],
            ),
          ),
          _rpColorRow(
            'Header accent',
            appSettings.rpHeaderAccent,
            (c) => appSettings.setRpHeaderAccent(c),
          ),
        ],
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Text(
            'BACKGROUND',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: cSmoke,
              letterSpacing: 3,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: Wrap(
            spacing: 6,
            children: [
              _rpChip(
                'Mood',
                appSettings.rpMoodOverride == 'off',
                () => appSettings.setRpMoodOverride('off'),
              ),
              _rpChip(
                'Tint',
                appSettings.rpMoodOverride == 'tint',
                () => appSettings.setRpMoodOverride('tint'),
              ),
              _rpChip(
                'Fixed',
                appSettings.rpMoodOverride == 'fixed',
                () => appSettings.setRpMoodOverride('fixed'),
              ),
            ],
          ),
        ),
        if (appSettings.rpMoodOverride != 'off')
          _rpColorRow(
            'Background colour',
            appSettings.rpBgColor,
            (c) => appSettings.setRpBgColor(c),
          ),
        _settingToggle(
          'Particles',
          appSettings.rpParticlesOn,
          (v) => appSettings.setRpParticlesOn(v),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Text(
            'SIZES',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: cSmoke,
              letterSpacing: 3,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: Row(
            children: [
              const Text(
                'Post size',
                style: TextStyle(
                  fontSize: 12,
                  color: cMist,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const Spacer(),
              _rpChip(
                'S',
                appSettings.rpPostSize == 'S',
                () => appSettings.setRpPostSize('S'),
              ),
              const SizedBox(width: 6),
              _rpChip(
                'M',
                appSettings.rpPostSize == 'M',
                () => appSettings.setRpPostSize('M'),
              ),
              const SizedBox(width: 6),
              _rpChip(
                'L',
                appSettings.rpPostSize == 'L',
                () => appSettings.setRpPostSize('L'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: Row(
            children: [
              const Text(
                'Editor size',
                style: TextStyle(
                  fontSize: 12,
                  color: cMist,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const Spacer(),
              _rpChip(
                'S',
                appSettings.rpEditorSize == 'S',
                () => appSettings.setRpEditorSize('S'),
              ),
              const SizedBox(width: 6),
              _rpChip(
                'M',
                appSettings.rpEditorSize == 'M',
                () => appSettings.setRpEditorSize('M'),
              ),
              const SizedBox(width: 6),
              _rpChip(
                'L',
                appSettings.rpEditorSize == 'L',
                () => appSettings.setRpEditorSize('L'),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Text(
            'PANELS',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: cSmoke,
              letterSpacing: 3,
            ),
          ),
        ),
        _settingToggle(
          'Session Log sidebar',
          appSettings.rpShowLogSidebar,
          (v) => appSettings.setRpShowLogSidebar(v),
        ),
        _settingToggle(
          'Tools sidebar',
          appSettings.rpShowToolsSidebar,
          (v) => appSettings.setRpShowToolsSidebar(v),
        ),
        _settingToggle(
          'OOC panel',
          appSettings.rpShowOoc,
          (v) => appSettings.setRpShowOoc(v),
        ),
        _settingToggle(
          'OOC unread badge',
          appSettings.rpOocBadgeOn,
          (v) => appSettings.setRpOocBadgeOn(v),
        ),
        _settingToggle('Mute all sounds', sounds.masterMute, (v) async {
          await sounds.setMasterMute(v);
          setState(() {});
        }),
        // Notification volume slider
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Notification volume',
                    style: TextStyle(
                      fontSize: 12,
                      color: cMist,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(sounds.notificationVolume * 100).round()}%',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: cGold,
                    ),
                  ),
                ],
              ),
              Slider(
                value: sounds.notificationVolume,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                activeColor: cGold,
                inactiveColor: cAsh,
                onChanged: (v) {
                  sounds.setNotificationVolume(v);
                  setState(() {});
                },
              ),
              const Text(
                'OOC DING, new post chime, all notification sounds.',
                style: TextStyle(
                  fontSize: 10,
                  color: cSmoke,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rpChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: active ? cGold : cAsh),
          color: active ? cGold.withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            letterSpacing: 1,
            color: active ? cGold : cSmoke,
          ),
        ),
      ),
    );
  }

  Widget _rpColorRow(
    String label,
    Color current,
    ValueChanged<Color> onPicked,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: cMist,
              fontWeight: FontWeight.w300,
            ),
          ),
          const Spacer(),
          LoreTap(
            onTap: () => LoreColourPicker.show(
              context,
              current: current,
              onPicked: onPicked,
            ),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: current,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeBtn(RPDisplayMode mode, IconData icon, String label) {
    final active = _displayMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          appSettings.setRpDisplayMode(mode.name);
          setState(() {
            _displayMode = mode;
            _settingsOpen = false;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? cGold.withValues(alpha: 0.1) : Colors.transparent,
            border: Border.all(color: active ? cGold : cAsh),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: active ? cGold : cSmoke),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 8,
                  letterSpacing: 1,
                  color: active ? cGold : cSmoke,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingToggle(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: cMist,
              fontWeight: FontWeight.w300,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 20,
              decoration: BoxDecoration(
                color: value ? cGold : cAsh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: cVoid,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOOCDesktopWidget() {
    return Column(
      children: [
        Expanded(
          child: ScrollConfiguration(
            behavior: NoGlowBehavior(),
            child: ListView.builder(
              controller: _oocScrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _oocMessages.length,
              itemBuilder: (_, i) {
                final msg = _oocMessages[i];
                return Align(
                  alignment: msg.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    constraints: const BoxConstraints(maxWidth: 260),
                    decoration: BoxDecoration(
                      color: msg.isUser ? cAsh : cVoid,
                      border: Border.all(color: cAsh),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!msg.isUser)
                          Text(
                            msg.author,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color:
                                  appSettings.textColourFor('partner_name') ??
                                  cIce,
                              letterSpacing: 2,
                            ),
                          ),
                        if (msg.content.isNotEmpty)
                          _OocLinkText(
                            text: msg.content,
                            style: TextStyle(
                              fontSize: 13,
                              color: appSettings.textColourFor('ooc') ?? cMist,
                              height: 1.5,
                            ),
                          ),
                        if (msg.mediaUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _OocMediaPreview(
                              msg.mediaUrl!,
                              isEncrypted: msg.isEncryptedMedia,
                              sessionId: widget.sessionId,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: cAsh)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () async {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: cInk,
                    builder: (ctx) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.link, color: cGold),
                          title: const Text(
                            'Paste Web Link',
                            style: TextStyle(color: cParchment),
                          ),
                          onTap: () async {
                            Navigator.pop(ctx);
                            final mediaUrl = await _promptForMediaUrl();
                            if (mediaUrl != null && mediaUrl.isNotEmpty) {
                              _sendEncryptedMediaUrl(mediaUrl);
                            }
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.image, color: cIce),
                          title: const Text(
                            'Upload Image',
                            style: TextStyle(color: cParchment),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _pickAndUploadImage();
                          },
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(border: Border.all(color: cAsh)),
                  child: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 18,
                    color: cSmoke,
                  ),
                ),
              ),
              Expanded(
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (!kIsWeb) return KeyEventResult.ignored;
                    if (event is KeyDownEvent) {
                      final isEnter =
                          event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.numpadEnter;
                      final isShift = HardwareKeyboard.instance.isShiftPressed;
                      if (isEnter) {
                        if (appSettings.enterToSend && !isShift) {
                          _sendOocMessage();
                          return KeyEventResult.handled;
                        } else if (!appSettings.enterToSend && isShift) {
                          _sendOocMessage();
                          return KeyEventResult.handled;
                        }
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _oocCtrl,
                    focusNode: _oocFocus,
                    style: const TextStyle(fontSize: 13, color: cParchment),
                    decoration: const InputDecoration(
                      hintText: 'Out of character...',
                      hintStyle: TextStyle(fontSize: 13, color: cSmoke),
                      border: InputBorder.none,
                    ),
                    cursorColor: cIce,
                  ),
                ),
              ),
              LoreTap(
                onTap: () async {
                  final text = _oocCtrl.text.trim();
                  if (text.isEmpty) return;
                  sounds.play(SoundKey.oocMsg);
                  if (widget.sessionId.isNotEmpty) {
                    try {
                      await _fs.addOocMessage(
                        sessionId: widget.sessionId,
                        content: text,
                      );
                      _oocCtrl.clear();
                      _scrollOocToBottom();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: cInk,
                            content: Text(
                              'Send failed: $e',
                              style: const TextStyle(color: cParchment),
                            ),
                          ),
                        );
                      }
                    }
                  } else {
                    if (!mounted) return;
                    _oocCtrl.clear();
                    setState(
                      () => _oocMessages.add(
                        OOCMessage(
                          author: _auth.currentName ?? 'You',
                          content: text,
                          isUser: true,
                          timestamp: DateTime.now(),
                        ),
                      ),
                    );
                    _scrollOocToBottom();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  color: cAsh,
                  child: const Text(
                    'Send',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: cMist,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CharacterSwitcherCard extends StatelessWidget {
  final bool isSelected;
  final String name;
  final String pronouns;
  final String? avatarUrl;
  final Color accent;
  final VoidCallback onTap;

  const _CharacterSwitcherCard({
    required this.isSelected,
    required this.name,
    required this.pronouns,
    this.avatarUrl,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final seed = name.hashCode;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: HoloCardV2(
          accent: isSelected ? cGold : accent,
          intensity: isSelected ? 0.6 : 0.3,
          seed: seed,
          bgColor: cInk,
          child: Container(
            width: 140,
            decoration: BoxDecoration(
              color: cInk,
              border: Border.all(
                color: isSelected ? cGold : accent.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: CardFrame(
                spec: CardFrameSpec(
                  seed: seed,
                  accent: isSelected ? cGold : accent,
                  ornate: isSelected,
                  glow: false,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image (supports GIFs automatically)
                      if (avatarUrl != null)
                        Image.network(
                          avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(),
                        )
                      else
                        Container(
                          color: cInk,
                          child: const Center(
                            child: Icon(Icons.person, size: 40, color: cSmoke),
                          ),
                        ),

                      // Scrim
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.9),
                            ],
                            stops: const [0.4, 1.0],
                          ),
                        ),
                      ),

                      // Text
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 14,
                                fontWeight: FontWeight.w300,
                                fontStyle: FontStyle.italic,
                                color: isSelected ? cGold : cParchment,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pronouns,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 7.5,
                                color: cSmoke,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Selected Checkmark
                      if (isSelected)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: cGold,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 12,
                              color: cVoid,
                            ),
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
    ); // <--- Closes GestureDetector
  } // <--- Closes build method
} // <--- Closes _CharacterSwitcherCard (Changed comment)

class _OocMediaPreview extends StatefulWidget {
  final String url;
  final bool isEncrypted;
  final String? sessionId;
  const _OocMediaPreview(this.url, {this.isEncrypted = false, this.sessionId});

  @override
  State<_OocMediaPreview> createState() => _OocMediaPreviewState();
}

class _OocMediaPreviewState extends State<_OocMediaPreview> {
  Uint8List? _decryptedBytes;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isEncrypted) {
      _downloadAndDecrypt();
    }
  }

  Future<void> _downloadAndDecrypt() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final sessionId = widget.sessionId;
      if (sessionId == null || sessionId.isEmpty) {
        throw 'No session';
      }

      final storageRef = FirebaseStorage.instance.ref().child(widget.url);
      final downloadBytes = await storageRef.getData();

      if (downloadBytes == null) throw 'Empty file';

      final iv = downloadBytes.sublist(0, 12);
      final cipher = downloadBytes.sublist(12);

      final sessionKey = await FirestoreService().getSessionKeyForMedia(
        sessionId,
      );
      if (sessionKey == null) throw 'No key';

      final decrypted = await CryptoService().decryptBytes(
        cipherBytes: cipher,
        ivBytes: iv,
        sessionKey: sessionKey,
      );

      if (decrypted == null) throw 'Decryption failed';

      if (mounted) {
        setState(() {
          _decryptedBytes = decrypted;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // ── NEW: Full Screen Image Viewer ──
  void _openFullScreen(BuildContext context, ImageProvider imageProvider) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 1.0,
              maxScale: 4.0,
              child: Image(image: imageProvider, fit: BoxFit.contain),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.isEncrypted) {
      if (_loading) {
        return const SizedBox(
          height: 100,
          child: Center(
            child: CircularProgressIndicator(strokeWidth: 1, color: cGold),
          ),
        );
      }
      if (_error != null) {
        return Text(
          '[Encrypted image failed: $_error]',
          style: const TextStyle(fontSize: 11, color: cEmber),
        );
      }
      if (_decryptedBytes != null) {
        return GestureDetector(
          onTap: () => _openFullScreen(context, MemoryImage(_decryptedBytes!)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                _decryptedBytes!,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      }
    }

    final lower = widget.url.toLowerCase();
    final isImage =
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.contains('tenor.com') ||
        lower.contains('imgur.com');

    if (isImage) {
      return GestureDetector(
        onTap: () => _openFullScreen(context, NetworkImage(widget.url)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              widget.url,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 100,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 1,
                          color: cGold,
                        ),
                      ),
                    ),
              errorBuilder: (_, _, _) => const Text(
                '[Image failed to load]',
                style: TextStyle(fontSize: 11, color: cEmber),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: cGold.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, size: 14, color: cGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.url,
              style: const TextStyle(fontSize: 11, color: cGold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _OocBadge extends StatefulWidget {
  final int count;
  const _OocBadge({required this.count});
  @override
  State<_OocBadge> createState() => _OocBadgeState();
}

class _OocLinkText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const _OocLinkText({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    final urlReg = RegExp(r'https?://[^\s]+');
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in urlReg.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: style));
      }
      final url = m.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: style.copyWith(
            color: cIce,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
        ),
      );
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: style));
    }
    // SelectableText = long-press / drag to copy on phone + PC
    return SelectableText.rich(TextSpan(children: spans));
  }
}

class _OocBadgeState extends State<_OocBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) =>
          Transform.scale(scale: 1.0 + _c.value * 0.15, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: cGold,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cInk),
        ),
        child: Text(
          '${widget.count}',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: cInk,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final RPPost post;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onQuote;
  final VoidCallback? onEdit;
  final VoidCallback? onMore;
  final void Function(String selectedText)? onAddToLog;
  final void Function(String selectedText)? onSelectionChanged;

  const _PostCard({
    required this.post,
    required this.isExpanded,
    required this.onTap,
    required this.onLongPress,
    this.onQuote,
    this.onEdit,
    this.onMore,
    this.onAddToLog,
    this.onSelectionChanged,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;
  late AnimationController _ctrl;
  late Animation<double> _expand;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expand = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    if (widget.isExpanded) _ctrl.value = 1;
  }

  @override
  void didUpdateWidget(_PostCard old) {
    super.didUpdateWidget(old);
    if (widget.isExpanded != old.isExpanded) {
      if (widget.isExpanded) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _hoverIcon(IconData icon, String tip, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Icon(icon, size: 14, color: cMist),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final preview = post.content.length > 120
        ? '${post.content.substring(0, 120)}...'
        : post.content;
    final nameColor = post.isUser
        ? (post.textColor == cParchment ? cGold : post.textColor)
        : cMist;

    final isDesktop = MediaQuery.of(context).size.width > 900;
    return MouseRegion(
      onEnter: (_) {
        if (isDesktop) setState(() => _hovering = true);
      },
      onExit: (_) {
        if (isDesktop) setState(() => _hovering = false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: EdgeInsets.only(bottom: isDesktop ? 6 : 10),
          decoration: BoxDecoration(
            color: const Color(0xFF08080A).withValues(alpha: 0.82),
            border: Border(
              left: BorderSide(
                color: post.isUser ? nameColor : cSmoke,
                width: post.isUser ? 2 : 1,
              ),
              top: const BorderSide(color: cAsh),
              right: const BorderSide(color: cAsh),
              bottom: const BorderSide(color: cAsh),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.quotedContent != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: cSmoke, width: 2)),
                  ),
                  child: Text(
                    '${post.quotedAuthor ?? ""}: ${post.quotedContent}...',
                    style: const TextStyle(
                      fontSize: 11,
                      color: cSmoke,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              GestureDetector(
                onLongPress: widget.onLongPress,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: Row(
                    children: [
                      Text(
                        post.characterName ?? post.author,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: nameColor,
                          letterSpacing: 2,
                        ),
                      ),
                      if (post.locationName != null) ...[
                        const Text(
                          ' · ',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: cSmoke,
                          ),
                        ),
                        Text(
                          post.locationName!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: cSmoke,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (_hovering && isDesktop) ...[
                        if (widget.onQuote != null)
                          _hoverIcon(
                            Icons.format_quote,
                            'Quote',
                            widget.onQuote!,
                          ),
                        if (widget.onEdit != null)
                          _hoverIcon(
                            Icons.edit_outlined,
                            'Edit',
                            widget.onEdit!,
                          ),
                        if (widget.onMore != null)
                          _hoverIcon(Icons.more_horiz, 'More', widget.onMore!),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        '${post.wordCount} words',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          color: cSmoke,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: widget.isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: _selectablePostText(
                  text: preview,
                  style: TextStyle(
                    fontSize: post.fontSize * _rpPostScale(),
                    color: post.textColor.withValues(alpha: 0.7),
                    fontStyle: post.italic
                        ? FontStyle.italic
                        : FontStyle.normal,
                    fontWeight: post.bold ? FontWeight.bold : FontWeight.w300,
                    height: 1.7,
                  ),
                  onAddToLog: widget.onAddToLog ?? (_) {},
                  onSelectionChanged: widget.onSelectionChanged,
                ),
              ),
              SizeTransition(
                sizeFactor: _expand,
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: cAsh)),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _selectablePostText(
                        text: post.content,
                        style: TextStyle(
                          fontSize: post.fontSize * _rpPostScale(),
                          color: post.textColor,
                          fontStyle: post.italic
                              ? FontStyle.italic
                              : FontStyle.normal,
                          fontWeight: post.bold
                              ? FontWeight.bold
                              : FontWeight.w300,
                          height: 1.9,
                        ),
                        onAddToLog: widget.onAddToLog ?? (_) {},
                        onSelectionChanged: widget.onSelectionChanged,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${post.timestamp.hour.toString().padLeft(2, '0')}:${post.timestamp.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          color: cSmoke,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final Color moodColor;
  final double intensity;

  _MoodShaderPainter({
    required this.shader,
    required this.time,
    required this.moodColor,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, moodColor.r);
    shader.setFloat(4, moodColor.g);
    shader.setFloat(5, moodColor.b);
    shader.setFloat(6, intensity * 1.5); // Scale up a bit so it's visible

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _MoodShaderPainter old) =>
      old.time != time ||
      old.moodColor != moodColor ||
      old.intensity != intensity;
}
