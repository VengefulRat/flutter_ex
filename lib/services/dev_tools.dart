import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'crypto_service.dart';

/// Result of ensureDemoSession — everything the caller needs to open the room.
class DemoSession {
  final String sessionId;
  final String partnerCode;
  final String partnerName;
  final String genre;
  const DemoSession({
    required this.sessionId,
    required this.partnerCode,
    required this.partnerName,
    required this.genre,
  });
}

/// Developer tools for testing the app solo.
///
/// The trick: the fake partner is created with OUR public key. That means
/// the session key is encrypted twice — once to us, once to the fake
/// partner — but both encryptions can be decrypted with our private key.
/// So posts written by either side round-trip correctly.
///
/// Later this becomes "Experience mode" — a curated walkthrough session
/// for new users. Same machinery, different content.
class DevTools {
  static final _db = FirebaseFirestore.instance;
  static final _auth = AuthService();
  static final _crypto = CryptoService();

  /// Creates (or returns an existing) demo session with a fake partner.
  /// Returns null if a PIN hasn't been set (no RSA keypair on file).
  static Future<DemoSession?> ensureDemoSession({
    String partnerName = 'Echo',
    String genre = 'Fantasy',
    bool seedPosts = true,
    String status = 'active',
  }) async {
    final myCode = _auth.currentCode;
    final myName = _auth.currentName;
    if (myCode == null || myName == null) {
      print('[DevTools] Not signed in');
      return null;
    }

    // Reuse an existing demo session if there is one
    final existing = await _db
        .collection('sessions')
        .where('participants', arrayContains: myCode)
        .where('isDemo', isEqualTo: true)
        .where('status', isEqualTo: status)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);
      final fakeCode = participants.firstWhere(
        (p) => p != myCode,
        orElse: () => '',
      );
      final names = Map<String, dynamic>.from(data['participantNames'] ?? {});

      // Retroactively seed Echo's stats for demo sessions created
      // before this feature existed.
      await _seedFakePartnerStats(doc.id, fakeCode);

      return DemoSession(
        sessionId: doc.id,
        partnerCode: fakeCode,
        partnerName: names[fakeCode] as String? ?? partnerName,
        genre: data['genre'] as String? ?? genre,
      );
    }

    // Need the current user's public key on file to clone it onto the fake
    final myDoc = await _db.collection('users').doc(myCode).get();
    final myPubKey = myDoc.data()?['publicKey'] as String?;
    if (myPubKey == null) {
      print('[DevTools] No public key on file — set a PIN first');
      return null;
    }

    // Create the fake partner, using OUR public key so we can decrypt both sides
    final fakeCode = _randomCode();
    await _db.collection('users').doc(fakeCode).set({
      'code': fakeCode,
      'displayName': partnerName.toLowerCase(),
      'displayNameOriginal': partnerName,
      'uid': 'demo-${DateTime.now().millisecondsSinceEpoch}',
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
      'isDiscoverable': false,
      'deviceLocked': false,
      'genres': [genre],
      'bio': 'A quiet voice at the edge of the story.',
      'writingStyle': 'Descriptive · Atmospheric · Slow burn',
      'postFrequency': 'Whenever you are',
      'publicKey': myPubKey, // ← the whole trick
      'isDemo': true,
    });

    // Create the session
    final sessionRef = await _db.collection('sessions').add({
      'participants': [myCode, fakeCode],
      'participantNames': {myCode: myName, fakeCode: partnerName},
      'genre': genre,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'lastPostAt': FieldValue.serverTimestamp(),
      'postCount': 0,
      'isDemo': true,
    });

    // Create the session key. Encrypted once to me and once to "fake" —
    // both use our public key, so both decrypt with our private key.
    try {
      await _crypto.createSessionKey(
        sessionId: sessionRef.id,
        myCode: myCode,
        partnerCode: fakeCode,
      );
    } catch (e) {
      print('[DevTools] createSessionKey failed: $e');
    }

    // Give Echo a stat block so the PARTNER STATS panel has content.
    try {
      await _seedFakePartnerStats(sessionRef.id, fakeCode);
    } catch (e) {
      print('[DevTools] seedFakePartnerStats failed: $e');
    }

    if (seedPosts && status == 'active') {
      await _seedPosts(sessionRef.id, fakeCode, partnerName);
    }

    return DemoSession(
      sessionId: sessionRef.id,
      partnerCode: fakeCode,
      partnerName: partnerName,
      genre: genre,
    );
  }

  /// Seeds a stat block for the fake partner so partner-stats display
  /// works in the demo room. Idempotent — won't clobber if one exists.
  static Future<void> _seedFakePartnerStats(
    String sessionId,
    String fakeCode,
  ) async {
    if (fakeCode.isEmpty) return;
    final ref = _db
        .collection('sessions')
        .doc(sessionId)
        .collection('stats')
        .doc(fakeCode);
    final existing = await ref.get();
    if (existing.exists) return;

    await ref.set({
      'name': 'Echo',
      'useTiles': false,
      'stats': [
        {
          'name': 'Vitality',
          'value': 320,
          'isPool': true,
          'maxValue': 320,
          'barColor': 0xFF7BAF7B, // muted green
          'barStyle': 'stripe',
          'segments': 10,
        },
        {
          'name': 'Focus',
          'value': 180,
          'isPool': true,
          'maxValue': 180,
          'barColor': 0xFF7AB8D4, // ice blue
          'barStyle': 'blocks',
          'segments': 12,
        },
        {
          'name': 'Wounds',
          'value': 40,
          'isPool': true,
          'maxValue': 40,
          'barColor': 0xFFD4614A, // ember red
          'barStyle': 'cuts',
          'segments': 8,
        },
      ],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    final p1 = List.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join();
    final p2 = List.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join();
    return 'LR-$p1-$p2';
  }

  static Future<void> _seedPosts(
    String sessionId,
    String fakeCode,
    String fakeName,
  ) async {
    final sessionKey = await _crypto.getSessionKey(
      sessionId: sessionId,
      myCode: fakeCode,
    );
    if (sessionKey == null) {
      print('[DevTools] No session key — skipping seed posts');
      return;
    }

    final seeds = <({String content, String? location})>[
      (
        content:
            'The inn at Whitethorn sits at the edge of the moor, its '
            'windows flickering with a light that never quite reaches the '
            'road. Travellers say the barkeep knows every name before it '
            'is spoken.',
        location: 'Whitethorn Inn',
      ),
      (
        content:
            'Rain began before dawn. It fell steady and grey, turning the '
            'cobbles to slate and the smell of wet stone into something '
            'almost like memory. I waited by the north gate, as we agreed.',
        location: 'North Gate',
      ),
      (
        content:
            'The letter was sealed with wax the colour of dried blood. It '
            'bore no name — only the mark of the Ninth House, which has '
            'not been seen in these lands for two hundred years.',
        location: null,
      ),
    ];

    for (final seed in seeds) {
      final enc = await _crypto.encryptContent(seed.content, sessionKey);
      await _db.collection('sessions').doc(sessionId).collection('posts').add({
        'authorCode': fakeCode,
        'authorName': fakeName,
        'characterName': fakeName,
        'locationName': seed.location,
        'content': enc['cipher']!,
        'contentIv': enc['iv'],
        'quotedPostId': null,
        'quotedContent': null,
        'quotedContentIv': null,
        'quotedAuthor': null,
        'encrypted': true,
        'createdAt': FieldValue.serverTimestamp(),
        'edited': false,
      });
    }

    await _db.collection('sessions').doc(sessionId).update({
      'postCount': seeds.length,
    });
  }

  /// Wipes every demo user and demo session this user has created.
  /// Useful when iterating on seeded content.
  static Future<void> clearDemoData() async {
    final myCode = _auth.currentCode;
    if (myCode == null) return;

    // Collect the fake partner codes from MY demo sessions only,
    // so we never delete another user's demo partner.
    final fakeCodes = <String>{};

    // Demo sessions + their posts
    final sessions = await _db
        .collection('sessions')
        .where('participants', arrayContains: myCode)
        .where('isDemo', isEqualTo: true)
        .get();
    for (final s in sessions.docs) {
      final participants = List<String>.from(
        (s.data()['participants'] as List?) ?? [],
      );
      for (final p in participants) {
        if (p != myCode) fakeCodes.add(p);
      }
      // Delete all subcollections before deleting the parent session
      final subcollections = ['posts', 'ooc', 'brainstorm', 'stats', 'log'];
      for (final sub in subcollections) {
        final docs = await s.reference.collection(sub).get();
        for (final doc in docs.docs) {
          await doc.reference.delete();
        }
      }

      await s.reference.delete();

      // Demo users — only the fake partners from MY sessions.
      for (final fakeCode in fakeCodes) {
        final userDoc = await _db.collection('users').doc(fakeCode).get();
        if (userDoc.exists && userDoc.data()?['isDemo'] == true) {
          await userDoc.reference.delete();
        }
      }
    }
  }
}
