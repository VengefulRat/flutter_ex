import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../settings.dart';

class FriendsStrip extends StatelessWidget {
  final VoidCallback onFindFriends;
  final void Function(String code) onFriendTap;

  const FriendsStrip({
    super.key,
    required this.onFindFriends,
    required this.onFriendTap,
  });

  @override
  Widget build(BuildContext context) {
    final myCode = AuthService().currentCode;
    if (myCode == null) return const SizedBox.shrink();

    final style = appSettings.styleForBlock(AppSettings.blockSettings);
    final borderColor = style.borderColor ?? cAsh;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(myCode)
          .collection('friends')
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final hasFriends = docs.isNotEmpty;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          decoration: BoxDecoration(
            color: style.background ?? cInk,
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row (like the Settings full-width block)
              InkWell(
                onTap: hasFriends ? null : onFindFriends, // Tap header to find if empty
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Row(children: [
                    Icon(Icons.people_outline, size: 18, color: style.accent ?? cSmoke),
                    const SizedBox(width: 12),
                    const Text('FRIENDS', style: TextStyle(
                        fontFamily: 'monospace', fontSize: 9,
                        color: cSmoke, letterSpacing: 2)),
                    const Spacer(),
                    if (!hasFriends)
                      const Text('FIND →', style: TextStyle(
                          fontFamily: 'monospace', fontSize: 9,
                          color: cGold, letterSpacing: 1)),
                  ]),
                ),
              ),
              // Horizontal friend list
              if (hasFriends)
                SizedBox(
                  height: 72,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final friendCode = docs[i].id;
                      return _FriendAvatar(
                        code: friendCode,
                        onTap: () => onFriendTap(friendCode),
                      );
                    },
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Text('Find partners to start building your circle.',
                      style: TextStyle(fontSize: 12, color: cSmoke,
                          fontStyle: FontStyle.italic)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FriendAvatar extends StatelessWidget {
  final String code;
  final VoidCallback onTap;
  const _FriendAvatar({required this.code, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(code).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(width: 60);
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name = data['displayNameOriginal'] as String? ?? '?';
        final status = data['statusText'] as String? ?? '';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
        final color = data['accentColor'] != null ? Color(data['accentColor'] as int) : cGold;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 110,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cVoid.withValues(alpha: 0.4),
              border: Border.all(color: cAsh),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cInk,
                    border: Border.all(color: color),
                  ),
                  child: Center(child: Text(initial,
                      style: TextStyle(fontSize: 14, color: color,
                          fontWeight: FontWeight.w300))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11,
                              color: cParchment, fontWeight: FontWeight.w300)),
                      if (status.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(status, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9,
                                color: cSmoke, fontStyle: FontStyle.italic,
                                height: 1.2)),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}