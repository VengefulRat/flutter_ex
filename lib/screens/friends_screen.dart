import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../widgets/shared.dart';
import '../widgets/holo_card_v2.dart';
import '../services/auth_service.dart';
import '../settings.dart';

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
      } else {
        grouped[code] = _FriendData(
          code: code,
          name: name,
          totalPosts: posts,
        );
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
                          return Container(
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
}