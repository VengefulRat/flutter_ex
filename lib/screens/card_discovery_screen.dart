import 'package:flutter/material.dart';
import '../theme.dart';
import '../settings.dart';
import '../widgets/shared.dart';
import '../widgets/card_frame.dart';
import '../widgets/request_card_view.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/sound_service.dart';
import '../widgets/holo_card_v2.dart';
import 'home_screen.dart';

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