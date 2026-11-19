import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/shared.dart';
import '../widgets/colour_picker.dart';
import '../settings.dart';
import '../screens/rp_room.dart';
import '../widgets/session_log.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/sound_service.dart';

// ════════════════════════════════════════
// SESSION START CHOICE  (card modal)
// ════════════════════════════════════════

// Call this when a request is accepted.
// Shows two cards: Brainstorm first, or go straight to RP.
void showSessionStartChoice(
  BuildContext context, {
  required String partnerName,
  required String partnerCode,
  required String genre,
  String sessionId = '',
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _SessionStartModal(
      partnerName: partnerName,
      partnerCode: partnerCode,
      genre: genre,
      sessionId: sessionId,
    ),
  );
}

class _SessionStartModal extends StatelessWidget {
  final String partnerName;
  final String partnerCode;
  final String genre;
  final String sessionId;
  const _SessionStartModal({
    required this.partnerName,
    required this.partnerCode,
    required this.genre,
    this.sessionId = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: cInk,
        border: Border(top: BorderSide(color: cAsh)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 32, height: 3,
              decoration: BoxDecoration(
                color: cAsh, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Text(
            partnerName,
            style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w300,
              fontStyle: FontStyle.italic, color: cParchment,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            genre,
            style: const TextStyle(
              fontFamily: 'monospace', fontSize: 10,
              color: cGold, letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'accepted your interest. How would you like to begin?',
            style: TextStyle(
              fontSize: 13, color: cSmoke,
              fontStyle: FontStyle.italic, height: 1.6,
            ),
          ),
          const SizedBox(height: 24),

          // Two cards
          Row(
            children: [
              // Brainstorm first
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.lightbulb_outline,
                  title: 'PRELUDE',
                  subtitle: 'Plan the story together before you begin writing.',
                  accentColor: cIce,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(fadeRoute(
                      BrainstormRoomScreen(
                        partnerName: partnerName,
                        partnerCode: partnerCode,
                        genre: genre,
                        sessionId: sessionId,
                      ),
                    ));
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Go straight to RP
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.auto_stories_outlined,
                  title: 'Write Now',
                  subtitle: 'Jump straight into the story. Figure it out as you go.',
                  accentColor: cGold,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(fadeRoute(
                      RPRoomScreen(
                        partnerName: partnerName,
                        partnerCode: partnerCode,
                        genre: genre,
                        sessionId: sessionId,
                      ),
                    ));
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Text(
                'Not yet',
                style: TextStyle(
                  fontFamily: 'monospace', fontSize: 9,
                  color: cSmoke, letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });
  @override State<_ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<_ChoiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.accentColor.withValues(alpha: 0.08)
              : cVoid,
          border: Border.all(
            color: _pressed ? widget.accentColor : cAsh,
            width: _pressed ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(widget.icon, color: widget.accentColor, size: 28),
            const SizedBox(height: 14),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w300,
                fontStyle: FontStyle.italic, color: widget.accentColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.subtitle,
              style: const TextStyle(
                fontSize: 12, color: cSmoke,
                fontStyle: FontStyle.italic, height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════
// BRAINSTORM ROOM SCREEN
// ════════════════════════════════════════
class BrainstormRoomScreen extends StatefulWidget {
  final String partnerName;
  final String partnerCode;
  final String genre;
  final String sessionId;
  const BrainstormRoomScreen({
    super.key,
    required this.partnerName,
    required this.partnerCode,
    required this.genre,
    this.sessionId = '',
  });
  @override State<BrainstormRoomScreen> createState() =>
      _BrainstormRoomScreenState();
}

class _BrainstormRoomScreenState extends State<BrainstormRoomScreen> {
  final List<_BSMessage> _messages = [];
  final _fs = FirestoreService();
  final _auth = AuthService();
  StreamSubscription? _msgSub;
  bool _loading = true;

  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.sessionId.isNotEmpty) _subscribeToMessages();
  }

    void _subscribeToMessages() {
    final myCode = _auth.currentCode ?? '';
    _msgSub = _fs.brainstormMessages(widget.sessionId).listen((data) {
      final msgs = data.map((d) {
        final typeStr = d['type'] as String? ?? 'chat';
        return _BSMessage(
          id: d['id'] as String? ?? '',
          author: d['authorName'] as String? ?? '?',
          content: d['content'] as String? ?? '',
          isUser: d['authorCode'] == myCode,
          timestamp: _parseTimestamp(d['createdAt']),
          type: _bsTypeFromString(typeStr),
        ); // _BSMessage
      }).toList();
      if (mounted) {
        setState(() { _messages..clear()..addAll(msgs); _loading = false; });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
          }
        });
      }
    }, onError: (e) {
      print('[prelude] messages stream error: $e');
      if (mounted) setState(() => _loading = false);
    });
  }

  DateTime _parseTimestamp(dynamic value) {
    try {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }

  _BSType _bsTypeFromString(String s) {
    switch (s) {
      case 'worldPin':  return _BSType.worldPin;
      case 'plotPoint': return _BSType.plotPoint;
      case 'rule':      return _BSType.rule;
      case 'character': return _BSType.character;
      default:          return _BSType.chat;
    }
  }

  String _bsTypeToString(_BSType t) {
    switch (t) {
      case _BSType.worldPin:  return 'worldPin';
      case _BSType.plotPoint: return 'plotPoint';
      case _BSType.rule:      return 'rule';
      case _BSType.character: return 'character';
      default:                return 'chat';
    }
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    sounds.play(SoundKey.brainstormMsg);

        if (widget.sessionId.isNotEmpty) {
      _fs.addBrainstormMessage(
        sessionId: widget.sessionId,
        content: text,
        type: 'chat',
      ).catchError((e) {
        print('[prelude] send failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: cInk,
            content: Text('Could not send message.',
                style: TextStyle(color: cParchment)),
          ));
        }
      });
        } else {
      if (!mounted) return;
      setState(() => _messages.add(_BSMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        author: _auth.currentName ?? 'You',
        content: text, isUser: true,
        timestamp: DateTime.now(), type: _BSType.chat,
      )));
    }
  }

  void _showPinMenu(_BSMessage msg) {
    if (!mounted) return;
    final isPinned = msg.type != _BSType.chat;
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
                width: 32, height: 3,
                decoration: BoxDecoration(
                    color: cAsh, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isPinned ? 'PINNED AS ${_noteConfig(msg.type).label.toUpperCase()}'
                       : 'PIN THIS MESSAGE',
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 9,
                  color: cGold, letterSpacing: 4),
            ),
            const SizedBox(height: 6),
            Text(
              '"${msg.content.length > 80 ? '${msg.content.substring(0, 80)}…' : msg.content}"',
              style: const TextStyle(
                  fontSize: 12, color: cSmoke,
                  fontStyle: FontStyle.italic, height: 1.5),
            ),
            const SizedBox(height: 20),
            if (isPinned)
              _pinMenuTile(
                icon: Icons.close,
                label: 'Unpin',
                subtitle: 'Return to chat.',
                color: cSmoke,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _setPin(msg, _BSType.chat);
                },
              )
            else ...[
              _pinMenuTile(
                icon: Icons.gavel_outlined,
                label: 'Rule',
                subtitle: 'A law of the world or the story.',
                color: cEmber,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _setPin(msg, _BSType.rule);
                },
              ),
              _pinMenuTile(
                icon: Icons.person_outline,
                label: 'Character',
                subtitle: 'A person, creature, or faction.',
                color: cMagic,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _setPin(msg, _BSType.character);
                },
              ),
              _pinMenuTile(
                icon: Icons.public,
                label: 'World',
                subtitle: 'A place, culture, or setting detail.',
                color: cIce,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _setPin(msg, _BSType.worldPin);
                },
              ),
              _pinMenuTile(
                icon: Icons.timeline,
                label: 'Plot',
                subtitle: 'An intention for where the story goes.',
                color: cGold,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _setPin(msg, _BSType.plotPoint);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pinMenuTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
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
                  Text(label,
                      style: TextStyle(
                          fontSize: 14, color: color,
                          fontWeight: FontWeight.w300,
                          fontStyle: FontStyle.italic)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: cSmoke,
                          fontStyle: FontStyle.italic, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

    Future<void> _setPin(_BSMessage msg, _BSType type) async {
    if (msg.id.isEmpty) return;
    if (widget.sessionId.isEmpty) {
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((m) => m.id == msg.id);
        if (i != -1) {
          _messages[i] = _BSMessage(
            id: _messages[i].id,
            author: _messages[i].author,
            content: _messages[i].content,
            isUser: _messages[i].isUser,
            timestamp: _messages[i].timestamp,
            type: type,
          );
        }
      });
      sounds.play(SoundKey.brainstormMsg);
      return;
    }
    try {
      await _fs.setBrainstormMessageType(
        sessionId: widget.sessionId,
        messageId: msg.id,
        type: _bsTypeToString(type),
      );
      sounds.play(SoundKey.brainstormMsg);
    } catch (e) {
      print('[prelude] setPin failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: cInk,
        content: Text('Could not update pin.',
            style: TextStyle(color: cParchment)),
      ));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appSettings.bgColor,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ]),
      ),
    );
  }

  Widget _buildTopBar() {
    final size = appSettings.preludeHeaderSize;
    final nameSize = size == 'S' ? 13.0 : size == 'L' ? 19.0 : 16.0;
    final padV = size == 'S' ? 8.0 : size == 'L' ? 16.0 : 12.0;
    final accent = appSettings.preludeHeaderAccent;
    final backBtn = GestureDetector(onTap: () => Navigator.of(context).pop(), child: const Icon(Icons.arrow_back_ios, color: cSmoke, size: 16));
    final beginBtn = GestureDetector(onTap: () => _confirmLaunchRP(), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), color: cParchment, child: const Text('Begin RP →', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cVoid, letterSpacing: 1))));
    final menuBtn = GestureDetector(onTap: _showPreludeMenu, child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.more_horiz, size: 18, color: cSmoke)));
    if (!appSettings.preludeHeaderShow) {
      return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: cAsh))), child: Row(children: [backBtn, const Spacer(), beginBtn, const SizedBox(width: 8), menuBtn]));
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: padV),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: cAsh))),
      child: Row(children: [
        backBtn,
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.partnerName, style: TextStyle(fontSize: nameSize, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic, color: cParchment)),
          Text(widget.genre, style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: cSmoke, letterSpacing: 2)),
        ]),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(border: Border.all(color: accent.withValues(alpha: 0.4))), child: Text('PRELUDE', style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: accent, letterSpacing: 3))),
        const SizedBox(width: 12),
        beginBtn,
        const SizedBox(width: 8),
        menuBtn,
      ]),
    );
  }

  Widget _buildMessageList() {
    if (_loading && widget.sessionId.isNotEmpty) {
      return const Center(child: SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: cSmoke)));
    }
    if (_messages.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: const Text('No messages yet.\nStart planning the story.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cSmoke,
                fontStyle: FontStyle.italic, height: 1.8)),
      ));
    }
    return ScrollConfiguration(
      behavior: NoGlowBehavior(),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        itemCount: _messages.length,
        itemBuilder: (_, i) => _buildMessage(_messages[i]),
      ),
    );
  }

  Widget _buildMessage(_BSMessage msg) {
    // Same card shape as RP _PostCard: full-width, dark fill,
    // thin cAsh border, coloured left accent.
    final isPinned = msg.type != _BSType.chat;
    final config = _noteConfig(msg.type);
    final accent = isPinned
        ? config.color
        : (msg.isUser ? cGold : cSmoke);

    return GestureDetector(
      onLongPress: () => _showPinMenu(msg),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF08080A).withValues(alpha: 0.82),
          border: Border(
            left: BorderSide(color: accent, width: isPinned ? 2 : 1),
            top: const BorderSide(color: cAsh),
            right: const BorderSide(color: cAsh),
            bottom: const BorderSide(color: cAsh),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  if (isPinned) ...[
                    Icon(config.icon, size: 12, color: config.color),
                    const SizedBox(width: 6),
                    Text(
                      config.label.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 8,
                        color: config.color,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      msg.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: isPinned
                            ? config.color
                            : (msg.isUser
                                ? cGold
                                : (appSettings.textColourFor('partner_name') ??
                                    cMist)),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  Text(
                    _timeLabel(msg.timestamp),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      color: appSettings.textColourFor('timestamp') ?? cSmoke,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                msg.content,
                style: TextStyle(
                  fontSize: 14,
                  color: appSettings.textColourFor('prelude') ?? cParchment,
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: cInk,
        border: const Border(top: BorderSide(color: cAsh)),
      ),
      child: Row(children: [
        // Input
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(border: Border.all(color: cAsh)),
            child: TextField(
              controller: _msgCtrl,
              maxLines: null,
              style: const TextStyle(
                fontSize: 14, color: cParchment,
                fontStyle: FontStyle.italic,
              ),
              decoration: const InputDecoration(
                hintText: 'Say something...',
                hintStyle: TextStyle(
                  fontSize: 13, color: cSmoke,
                  fontStyle: FontStyle.italic,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              cursorColor: cGold,
              onSubmitted: (_) => _send(),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Send
        GestureDetector(
          onTap: _send,
          child: Container(
            width: 36, height: 36,
            color: cParchment,
            child: const Icon(Icons.arrow_upward, color: cVoid, size: 16),
          ),
        ),
      ]),
    );
  }

  Widget _preChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: active ? cGold : cAsh), color: active ? cGold.withValues(alpha: 0.08) : Colors.transparent),
        child: Text(label, style: TextStyle(fontFamily: 'monospace', fontSize: 9, letterSpacing: 1, color: active ? cGold : cSmoke)),
      ),
    );
  }
  Widget _preColorRow(String label, Color current, ValueChanged<Color> onPicked) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, color: cMist, fontWeight: FontWeight.w300)),
        const Spacer(),
        LoreTap(
          onTap: () => LoreColourPicker.show(context, current: current, onPicked: onPicked),
          child: Container(width: 28, height: 28, decoration: BoxDecoration(color: current, shape: BoxShape.circle, border: Border.all(color: Colors.white24))),
        ),
      ]),
    );
  }
  Widget _preToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, color: cMist, fontWeight: FontWeight.w300)),
        const Spacer(),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36, height: 20,
            decoration: BoxDecoration(color: value ? cGold : cAsh, borderRadius: BorderRadius.circular(10)),
            child: Align(alignment: value ? Alignment.centerRight : Alignment.centerLeft, child: Container(width: 16, height: 16, margin: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
          ),
        ),
      ]),
    );
  }
  Widget _preSizeRow(String label, String current, ValueChanged<String> onPick) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, color: cMist, fontWeight: FontWeight.w300)),
        const Spacer(),
        _preChip('S', current == 'S', () => onPick('S')),
        const SizedBox(width: 6),
        _preChip('M', current == 'M', () => onPick('M')),
        const SizedBox(width: 6),
        _preChip('L', current == 'L', () => onPick('L')),
      ]),
    );
  }
  void _showPreludeCustomize() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: cInk,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void refresh() { setSheetState(() {}); setState(() {}); }
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 32, height: 3, decoration: BoxDecoration(color: cAsh, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Text('PRELUDE CUSTOMIZE', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cGold, letterSpacing: 4)),
                const SizedBox(height: 12),
                const Text('HEADER', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cSmoke, letterSpacing: 3)),
                _preToggle('Show header', appSettings.preludeHeaderShow, (v) { appSettings.setPreludeHeaderShow(v); refresh(); }),
                if (appSettings.preludeHeaderShow) ...[ _preSizeRow('Header size', appSettings.preludeHeaderSize, (v) { appSettings.setPreludeHeaderSize(v); refresh(); }), _preColorRow('Header accent', appSettings.preludeHeaderAccent, (c) { appSettings.setPreludeHeaderAccent(c); refresh(); }), ],
                const Text('BACKGROUND', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cSmoke, letterSpacing: 3)),
                Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 6), child: Wrap(spacing: 6, children: [ _preChip('Global', appSettings.preludeBgMode == 'global', () { appSettings.setPreludeBgMode('global'); refresh(); }), _preChip('Fixed', appSettings.preludeBgMode == 'fixed', () { appSettings.setPreludeBgMode('fixed'); refresh(); }), ])),
                if (appSettings.preludeBgMode == 'fixed') _preColorRow('Background colour', appSettings.preludeBgColor, (c) { appSettings.setPreludeBgColor(c); refresh(); }),
                const Text('MESSAGES', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cSmoke, letterSpacing: 3)),
                _preSizeRow('Message size', appSettings.preludeMsgSize, (v) { appSettings.setPreludeMsgSize(v); refresh(); }),
                Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 6), child: Row(children: [ const Text('Density', style: TextStyle(fontSize: 12, color: cMist, fontWeight: FontWeight.w300)), const Spacer(), _preChip('Compact', appSettings.preludeDensity == 'compact', () { appSettings.setPreludeDensity('compact'); refresh(); }), const SizedBox(width: 6), _preChip('Comfortable', appSettings.preludeDensity == 'comfortable', () { appSettings.setPreludeDensity('comfortable'); refresh(); }), ])),
                Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 6), child: Row(children: [ const Text('Style', style: TextStyle(fontSize: 12, color: cMist, fontWeight: FontWeight.w300)), const Spacer(), _preChip('Cards', appSettings.preludeMsgStyle == 'cards', () { appSettings.setPreludeMsgStyle('cards'); refresh(); }), const SizedBox(width: 6), _preChip('Bubbles', appSettings.preludeMsgStyle == 'bubbles', () { appSettings.setPreludeMsgStyle('bubbles'); refresh(); }), const SizedBox(width: 6), _preChip('Compact', appSettings.preludeMsgStyle == 'compact', () { appSettings.setPreludeMsgStyle('compact'); refresh(); }), ])),
                _preToggle('Show timestamps', appSettings.preludeShowTimestamp, (v) { appSettings.setPreludeShowTimestamp(v); refresh(); }),
                _preToggle('Show authors', appSettings.preludeShowAuthor, (v) { appSettings.setPreludeShowAuthor(v); refresh(); }),
                _preToggle('Show pin labels', appSettings.preludeShowPinLabel, (v) { appSettings.setPreludeShowPinLabel(v); refresh(); }),
                const Text('PIN COLOURS', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cSmoke, letterSpacing: 3)),
                _preColorRow('Rule', appSettings.preludePinRule, (c) { appSettings.setPreludePinRule(c); refresh(); }),
                _preColorRow('Character', appSettings.preludePinCharacter, (c) { appSettings.setPreludePinCharacter(c); refresh(); }),
                _preColorRow('World', appSettings.preludePinWorld, (c) { appSettings.setPreludePinWorld(c); refresh(); }),
                _preColorRow('Plot', appSettings.preludePinPlot, (c) { appSettings.setPreludePinPlot(c); refresh(); }),
                const Text('FILTER + INPUT', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cSmoke, letterSpacing: 3)),
                Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 6), child: Row(children: [ const Text('Show', style: TextStyle(fontSize: 12, color: cMist, fontWeight: FontWeight.w300)), const Spacer(), _preChip('All', appSettings.preludePinFilter == 'all', () { appSettings.setPreludePinFilter('all'); refresh(); }), const SizedBox(width: 6), _preChip('Pins', appSettings.preludePinFilter == 'pins', () { appSettings.setPreludePinFilter('pins'); refresh(); }), const SizedBox(width: 6), _preChip('Chat', appSettings.preludePinFilter == 'chat', () { appSettings.setPreludePinFilter('chat'); refresh(); }), ])),
                _preSizeRow('Input size', appSettings.preludeInputSize, (v) { appSettings.setPreludeInputSize(v); refresh(); }),
                _preSizeRow('Choice card size', appSettings.preludeChoiceSize, (v) { appSettings.setPreludeChoiceSize(v); refresh(); }),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _showPreludeMenu() {
        if (!mounted) return;
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
                width: 32, height: 3,
                decoration: BoxDecoration(
                  color: cAsh, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            _preludeMenuTile(
              icon: Icons.tune,
              title: 'Customize Prelude',
              subtitle: 'Header, background, messages, pins and input.',
              color: cGold,
              onTap: () { Navigator.of(ctx).pop(); _showPreludeCustomize(); },
            ),
            const SizedBox(height: 8),
            _preludeMenuTile(
              icon: Icons.do_not_disturb_alt,
              title: 'Not a match',
              subtitle:
                  'Close this prelude. You can still reach out again later.',
              color: cSmoke,
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmNotAMatch();
              },
            ),
            const SizedBox(height: 8),
            _preludeMenuTile(
              icon: Icons.block,
              title: 'Block this user',
              subtitle: 'Never see or hear from them again.',
              color: cEmber,
              onTap: () {
                Navigator.of(ctx).pop();
                showBlockDialog(
                  context: context,
                  partnerName: widget.partnerName,
                  myCode: _auth.currentCode ?? '',
                  partnerCode: widget.partnerCode,
                  fs: _fs,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _preludeMenuTile({
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

  Future<void> _confirmNotAMatch() async {
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
                'CLOSE THIS PRELUDE',
                style: TextStyle(
                  fontFamily: 'monospace', fontSize: 9,
                  color: cSmoke, letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Close the prelude with ${widget.partnerName}? '
                'It will be removed from both of your lists. '
                'Nothing you wrote here is lost — you can reach '
                'out again later if you change your mind.',
                style: const TextStyle(
                  fontSize: 13, color: cMist,
                  fontStyle: FontStyle.italic, height: 1.7,
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: cAsh)),
                      child: const Center(child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'monospace', fontSize: 9,
                          color: cSmoke, letterSpacing: 2,
                        ),
                      )),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: cSmoke.withValues(alpha: 0.5),
                      child: const Center(child: Text(
                        'Close',
                        style: TextStyle(
                          fontFamily: 'monospace', fontSize: 9,
                          color: cParchment, letterSpacing: 2,
                        ),
                      )),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
        if (confirm != true) return;
    if (!mounted) return;
    await _archivePrelude();
  }

  Future<void> _archivePrelude() async {
    if (widget.sessionId.isNotEmpty) {
      try {
        await _fs.updateSessionStatus(widget.sessionId, 'archived');
      } catch (_) {}
    }
        if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      backgroundColor: cInk,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
      content: Text(
        'Prelude with ${widget.partnerName} closed.',
        style: const TextStyle(
          color: cParchment, fontSize: 13, fontStyle: FontStyle.italic),
      ),
    ));
  }

  /// Walks every pinned note in this prelude and writes it into the
  /// session log under the matching section. Runs once on Begin RP.
  /// Chat messages are skipped — only pins carry forward.
  Future<void> _importPinsToLog() async {
    if (widget.sessionId.isEmpty) return;
    final pins = _messages.where((m) => m.type != _BSType.chat).toList();
    if (pins.isEmpty) return;

    final log = SessionLog.forSession(widget.sessionId);
    await log.load();

    for (final pin in pins) {
      final title = _autoTitle(pin.content);
      final body = pin.content;
      try {
        switch (pin.type) {
          case _BSType.rule:
            await log.addRule(title, body);
            break;
          case _BSType.character:
            await log.addCharacter(title, body, CharacterRole.side);
            break;
          case _BSType.worldPin:
            await log.addLocation(title, body);
            break;
          case _BSType.plotPoint:
            await log.addNote('Plot · $title', body);
            break;
          case _BSType.chat:
            break;
        }
      } catch (e) {
        print('[prelude] import pin failed (${pin.type}): $e');
      }
    }
  }

  String _autoTitle(String s) {
    final first = s.split(RegExp(r'[\n\.!?]')).first.trim();
    if (first.isEmpty) return 'Note';
    if (first.length <= 40) return first;
    return '${first.substring(0, 40)}…';
  }

  /// The Begin RP flow:
  ///   1. Import pins into the session log
  ///   2. Flip session status from 'brainstorm' to 'active'
  ///      (moves it from Preludes → Roleplays in both users' lists)
  ///   3. Replace this screen with the RP room (back goes to home)
  Future<void> _beginRP() async {
    try {
      await _importPinsToLog();
    } catch (e) {
      print('[prelude] importPinsToLog failed: $e');
    }

    if (widget.sessionId.isNotEmpty) {
      try {
        await _fs.updateSessionStatus(widget.sessionId, 'active');
      } catch (e) {
        print('[prelude] status change failed: $e');
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(fadeRoute(
      RPRoomScreen(
        partnerName: widget.partnerName,
        partnerCode: widget.partnerCode,
        genre: widget.genre,
        sessionId: widget.sessionId,
      ),
    ));
  }


  void _confirmLaunchRP() {
        if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: cInk,
        shape: const RoundedRectangleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Begin the RP?',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w300,
                fontStyle: FontStyle.italic, color: cParchment,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start writing with ${widget.partnerName}. This prelude room stays open — you can always come back.',
              style: const TextStyle(
                fontSize: 13, color: cSmoke,
                fontStyle: FontStyle.italic, height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(border: Border.all(color: cAsh)),
                    child: const Center(child: Text(
                      'Not yet',
                      style: TextStyle(
                        fontFamily: 'monospace', fontSize: 10,
                        color: cSmoke, letterSpacing: 2,
                      ),
                    )),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    _beginRP();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: cParchment,
                    child: const Center(child: Text(
                      'Let\'s go →',
                      style: TextStyle(
                        fontFamily: 'monospace', fontSize: 10,
                        color: cVoid, letterSpacing: 2,
                      ),
                    )),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  String _timeLabel(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  _NoteConfig _noteConfig(_BSType type) {
    switch (type) {
      case _BSType.chat:      return _NoteConfig(Icons.chat_bubble_outline, 'Chat', cSmoke);
      case _BSType.worldPin:  return _NoteConfig(Icons.public, 'World', cIce);
      case _BSType.plotPoint: return _NoteConfig(Icons.timeline, 'Plot', cGold);
      case _BSType.rule:      return _NoteConfig(Icons.gavel_outlined, 'Rule', cEmber);
      case _BSType.character: return _NoteConfig(Icons.person_outline, 'Character', cMagic);
    }
  }

}

// ── Data models ──
enum _BSType { chat, worldPin, plotPoint, rule, character }

class _BSMessage {
  final String id;
  final String author;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final _BSType type;
  const _BSMessage({
    required this.id,
    required this.author,
    required this.content,
    required this.isUser,
    required this.timestamp,
    required this.type,
  });
}

class _NoteConfig {
  final IconData icon;
  final String label;
  final Color color;
  const _NoteConfig(this.icon, this.label, this.color);
}
