import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../widgets/shared.dart';
import '../widgets/holo_card_v2.dart';
import '../services/auth_service.dart';
import '../settings.dart';
import '../services/firestore_service.dart';
import 'rp_room.dart';
import 'brainstorm_room.dart';

class FriendsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> rps; // We'll pass the raw data from HomeScreen
  const FriendsScreen({super.key, required this.rps});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendData {
  final String code;
  String name;
  int totalPosts;
  String presence = 'offline'; // Default value
  String avatarUrl = '';       // Default value
  List<Map<String, dynamic>> sessions = [];
  
  _FriendData({
    required this.code,
    required this.name,
    required this.totalPosts,
  });
}

class _FriendsScreenState extends State<FriendsScreen> {
  bool _loading = true;
  List<_FriendData> _friends = [];
  String _sortBy = 'posts'; // posts | az | recent

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final grouped = <String, _FriendData>{};
    
    // 1. Group by partner code and sum up posts
    for (final rp in widget.rps) {
      final code = rp['partnerCode'] as String? ?? '';
      if (code.isEmpty) continue;
      
      final posts = rp['posts'] as int? ?? 0;
      final name = rp['partner'] as String? ?? code;
      
      if (grouped.containsKey(code)) {
        grouped[code]!.totalPosts += posts;
        grouped[code]!.sessions.add(rp);
      } else {
        grouped[code] = _FriendData(
          code: code,
          name: name,
          totalPosts: posts,
        );
        grouped[code]!.sessions.add(rp);
      }
    }

    // 2. Fetch their public profiles (for avatar + presence)
    final db = FirebaseFirestore.instance;
    final updatedFriends = <_FriendData>[];
    
    for (final friend in grouped.values) {
      try {
        final doc = await db.collection('users').doc(friend.code).get();
        if (doc.exists) {
          final data = doc.data()!;
          friend.presence = data['presence'] as String? ?? 'offline';
          friend.avatarUrl = data['avatarUrl'] as String? ?? '';
          friend.name = data['displayNameOriginal'] as String? ?? friend.name;
        }
      } catch (_) {}
      updatedFriends.add(friend);
    }

    if (mounted) {
      setState(() {
        _friends = updatedFriends;
        _loading = false;
        _sortFriends();
      });
    }
  }

  void _sortFriends() {
    switch (_sortBy) {
      case 'az':
        _friends.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'posts':
      default:
        _friends.sort((a, b) => b.totalPosts.compareTo(a.totalPosts));
    }
  }

  Color _presenceColor(String presence) {
    switch (presence) {
      case 'online': return cVine;
      case 'away': return cGold;
      case 'dnd': return cEmber;
      default: return cSmoke;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appSettings.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: cSmoke, size: 16),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'FRIENDS',
          style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: cGold, letterSpacing: 4),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Sort Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Text('SORT BY:', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: cSmoke, letterSpacing: 2)),
                const SizedBox(width: 16),
                _sortChip('Most Posts', 'posts'),
                const SizedBox(width: 8),
                _sortChip('A-Z', 'az'),
              ],
            ),
          ),
          
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: cGold, strokeWidth: 1))
                : _friends.isEmpty
                    ? const Center(child: Text('No friends yet.', style: TextStyle(color: cSmoke, fontStyle: FontStyle.italic)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _friends.length,
                          itemBuilder: (context, index) {
                          final f = _friends[index];
                          return GestureDetector(
                            onLongPress: () => _showFriendActions(f),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: HoloCardV2(
                              accent: _presenceColor(f.presence),
                              intensity: 0.2,
                              seed: f.code.hashCode,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: appSettings.surfaceColor,
                                  border: Border.all(color: cAsh),
                                ),
                                child: Row(
                                  children: [
                                    // Avatar
                                    Stack(
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: cInk,
                                            border: Border.all(color: cAsh),
                                            image: f.avatarUrl.isNotEmpty 
                                                ? DecorationImage(image: NetworkImage(f.avatarUrl), fit: BoxFit.cover)
                                                : null,
                                          ),
                                          child: f.avatarUrl.isEmpty ? const Icon(Icons.person, color: cSmoke) : null,
                                        ),
                                        Positioned(
                                          bottom: 0, right: 0,
                                          child: Container(
                                            width: 12, height: 12,
                                            decoration: BoxDecoration(
                                              color: _presenceColor(f.presence),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: appSettings.surfaceColor, width: 2),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Name & Stats
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            f.name,
                                            style: const TextStyle(fontSize: 16, color: cParchment, fontStyle: FontStyle.italic, fontWeight: FontWeight.w300),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${f.totalPosts} total posts together',
                                            style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: cSmoke, letterSpacing: 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            )
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _sortChip(String label, String value) {
    final active = _sortBy == value;
    return LoreTap(
      onTap: () {
        setState(() { _sortBy = value; _sortFriends(); });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: active ? cGold : cAsh),
          color: active ? cGold.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: active ? cGold : cSmoke),
        ),
      ),
    );
  }
    void _showFriendActions(_FriendData friend) {
    final fs = FirestoreService();
    final myCode = AuthService().currentCode ?? '';

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
                decoration: BoxDecoration(color: cAsh, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              friend.name.toUpperCase(),
              style: const TextStyle(fontSize: 18, color: cParchment, fontStyle: FontStyle.italic, fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: 16),
            
            _actionTile(Icons.menu_book, 'Open Stories', cGold, () {
              Navigator.pop(ctx);
              _showStoriesSheet(friend);
            }),
            
            _actionTile(Icons.archive_outlined, 'Archive all stories', cMist, () async {
              Navigator.pop(ctx);
              for (final s in friend.sessions) {
                if (s['status'] != 'archived') {
                  await fs.updateSessionStatus(s['sessionId'], 'archived');
                }
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: cInk, content: Text('All stories archived.', style: TextStyle(color: cParchment))),
                );
                _loadFriends(); // Refresh the list
              }
            }),

            _actionTile(Icons.block, 'Block User', cEmber, () async {
              Navigator.pop(ctx);
              await fs.blockUser(myCode: myCode, blockedCode: friend.code, archiveSessions: true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: cInk, content: Text('User blocked.', style: TextStyle(color: cEmber))),
                );
                _loadFriends(); // Refresh the list
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return LoreTap(
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
            Text(title, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w300)),
          ],
        ),
      ),
    );
  }

  void _showStoriesSheet(_FriendData friend) {
    final activeStories = friend.sessions.where((s) => s['status'] != 'archived').toList();
    
    if (activeStories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: cInk, content: Text('No active stories with this user.', style: TextStyle(color: cParchment))),
      );
      return;
    }

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
            const Text('SELECT STORY', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: cGold, letterSpacing: 2)),
            const SizedBox(height: 16),
            ...activeStories.map((s) {
              final isBrainstorm = s['status'] == 'brainstorm';
              final title = (s['title'] as String?)?.isNotEmpty == true ? s['title'] : s['genre'];
              
              return LoreTap(
                onTap: () {
                  Navigator.pop(ctx); // Close sheet
                  Navigator.pop(context); // Close friends screen
                  
                  if (isBrainstorm) {
                    Navigator.of(context).push(fadeRoute(BrainstormRoomScreen(
                      partnerName: friend.name,
                      partnerCode: friend.code,
                      genre: s['genre'] ?? '',
                      sessionId: s['sessionId'],
                    )));
                  } else {
                    Navigator.of(context).push(fadeRoute(RPRoomScreen(
                      partnerName: friend.name,
                      partnerCode: friend.code,
                      genre: s['genre'] ?? '',
                      sessionId: s['sessionId'],
                      title: s['title'] ?? '',
                    )));
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(border: Border.all(color: cAsh)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontSize: 15, color: cParchment, fontStyle: FontStyle.italic)),
                            const SizedBox(height: 4),
                            Text('${s['posts']} posts · ${isBrainstorm ? "Prelude" : "Roleplay"}', style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: cSmoke)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 16, color: cSmoke),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}