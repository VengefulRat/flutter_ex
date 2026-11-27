// The Firebase SDK is faked here; Firestore rules are tested in the emulator.
// ignore_for_file: subtype_of_sealed_class

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/screens/rp_room.dart';
import 'package:lore/services/rp_story_export.dart';
import 'package:lore/services/rp_story_import.dart';
import 'package:lore/services/staged_restore_service.dart';
import 'package:lore/services/staged_story_publish.dart';
import 'package:lore/services/staged_story_review.dart';
import 'package:lore/services/staged_story_upload.dart';

class _App extends Fake implements FirebaseApp {
  _App(String projectId)
    : options = FirebaseOptions(
        apiKey: 'demo',
        appId: 'demo',
        messagingSenderId: 'demo',
        projectId: projectId,
      );

  @override
  final FirebaseOptions options;

  @override
  String get name => 'review-test';
}

class _User extends Fake implements User {
  _User(this.uid);

  @override
  final String uid;
  @override
  bool get isAnonymous => false;
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.app, this.user);

  @override
  final FirebaseApp app;
  User? user;

  @override
  User? get currentUser => user;
}

class _Functions extends Fake implements FirebaseFunctions {
  _Functions(this.store);
  final _Firestore store;
  bool fail = false;

  @override
  FirebaseApp get app => store.app;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    if (name != 'finalizeStagedRestore') {
      throw StateError('Unexpected function.');
    }
    return _Callable(this);
  }
}

class _Callable extends Fake implements HttpsCallable {
  _Callable(this.functions);
  final _Functions functions;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    if (functions.fail) throw StateError('Finalization failed.');
    final path = 'sessions_v2/${parameters['sessionId']}/restore/state';
    final state = functions.store.documents[path]!;
    if (state['status'] != 'approved' ||
        state['reviewVersion'] != parameters['reviewVersion']) {
      throw StateError('The restore changed.');
    }
    state['status'] = 'completed';
    return _Result<T>({'status': 'completed'} as T);
  }
}

class _Result<T> extends Fake implements HttpsCallableResult<T> {
  _Result(this.data);
  @override
  final T data;
}

class _Metadata extends Fake implements SnapshotMetadata {
  _Metadata(this.pending, this.cached);

  final bool pending;
  final bool cached;

  @override
  bool get hasPendingWrites => pending;

  @override
  bool get isFromCache => cached;
}

class _DocumentSnapshot<T> extends Fake implements DocumentSnapshot<T> {
  _DocumentSnapshot(this.value, this.metadata);

  final T? value;
  @override
  final SnapshotMetadata metadata;

  @override
  T? data() => value;

  @override
  bool get exists => value != null;
}

class _QueryDocument extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _QueryDocument(this.id, this.value, this.reference);

  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  final DocumentReference<Map<String, dynamic>> reference;

  @override
  Map<String, dynamic> data() => Map.of(value);
}

class _QuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _QuerySnapshot(this.docs, this.metadata);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  final SnapshotMetadata metadata;
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.store, this.path);

  final _Firestore store;
  @override
  final String path;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(store, '${this.path}/$path');

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    if (options?.source != Source.server) {
      throw StateError('Expected server read.');
    }
    return _DocumentSnapshot(
      store.documents[path] == null ? null : Map.of(store.documents[path]!),
      _Metadata(store.pending, store.cached),
    );
  }
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.path);

  final _Firestore store;
  @override
  final String path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(store, '${this.path}/$path');

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    if (options?.source != Source.server) {
      throw StateError('Expected server read.');
    }
    store.beforeQuery?.call(path);
    final prefix = '$path/';
    return _QuerySnapshot([
      for (final entry in store.documents.entries)
        if (entry.key.startsWith(prefix) &&
            !entry.key.substring(prefix.length).contains('/'))
          _QueryDocument(
            entry.key.substring(prefix.length),
            entry.value,
            _Document(store, entry.key),
          ),
    ], _Metadata(store.pending, store.cached));
  }
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.store);

  final _Firestore store;
  final updates = <String, Map<String, dynamic>>{};
  final sets = <String, Map<String, dynamic>>{};

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async => _DocumentSnapshot(
    store.documents[reference.path] as T?,
    _Metadata(false, false),
  );

  @override
  Transaction update(DocumentReference reference, Map<String, dynamic> data) {
    updates[reference.path] = data;
    return this;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    sets[reference.path] = Map<String, dynamic>.from(
      data as Map<String, dynamic>,
    );
    return this;
  }
}

class _Batch extends Fake implements WriteBatch {
  _Batch(this.store);

  final _Firestore store;
  final writes = <String, Map<String, dynamic>?>{};

  @override
  void delete(DocumentReference document) => writes[document.path] = null;

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    writes[document.path] = Map<String, dynamic>.from(
      data as Map<String, dynamic>,
    );
  }

  @override
  Future<void> commit() async {
    store.batchCount++;
    if (store.batchCount == store.failBatchAt) {
      throw StateError('Simulated batch failure.');
    }
    for (final entry in writes.entries) {
      if (entry.value == null) {
        store.documents.remove(entry.key);
      } else {
        store.documents[entry.key] = entry.value!;
      }
    }
  }
}

class _Firestore extends Fake implements FirebaseFirestore {
  _Firestore([String projectId = 'demo-review']) : app = _App(projectId);

  @override
  final FirebaseApp app;
  final documents = <String, Map<String, dynamic>>{};
  bool pending = false;
  bool cached = false;
  int batchCount = 0;
  int? failBatchAt;
  int transactionCount = 0;
  void Function(int)? beforeTransaction;
  void Function(String)? beforeQuery;

  @override
  WriteBatch batch() => _Batch(this);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    transactionCount++;
    beforeTransaction?.call(transactionCount);
    final transaction = _Transaction(this);
    final result = await transactionHandler(transaction);
    documents.addAll(transaction.sets);
    for (final entry in transaction.updates.entries) {
      documents[entry.key]!.addAll(entry.value);
    }
    return result;
  }
}

void main() {
  testWidgets('read-only room post renders restored formatting', (
    tester,
  ) async {
    final post = RPPost.fromData({
      'id': 'post',
      'authorCode': 'bob',
      'authorName': 'Bob',
      'content': 'Story',
      'contentRuns': '[{"text":"Story","bold":true}]',
      'createdAt': Timestamp(1, 0),
    }, 'bob');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReadOnlyRPPost(post: post)),
      ),
    );
    final richText = tester.widget<RichText>(
      find.text('Story', findRichText: true),
    );
    final span = richText.text as TextSpan;
    expect(span.children!.single.style!.fontWeight, FontWeight.bold);
  });

  const statePath = 'sessions_v2/room/restore/state';
  const postsPath = '$statePath/posts';
  const metadataPath = '$statePath/metadata';
  const metadataJson =
      '{"format":"lore-rp-story","version":1,'
      '"exportedAt":"2026-01-01T00:00:00.000Z","sessionId":"old-room",'
      '"session":{"chapters":["Chapter 1"],"postChapters":{"earlier":"Chapter 1"}},'
      '"postCount":0,"posts":[]}';
  late _Firestore firestore;
  late StagedStoryReviewService service;
  late _Functions functions;

  Map<String, dynamic> post(int time, String content) => {
    'authorCode': 'author',
    'authorName': 'Earlier name',
    'createdAt': Timestamp(time, 0),
    'content': content,
    'contentIv': 'nonce',
    'quotedContent': 'quote',
    'quotedContentIv': 'nonce',
    'encrypted': true,
  };
  Future<String?> decrypt(String cipher, String iv) async =>
      cipher == 'metadata' ? metadataJson : 'plain:$cipher';
  Future<StagedStoryReview> load() => service.load(
    sessionId: 'room',
    reviewerCode: 'reviewer',
    decrypt: decrypt,
  );

  setUp(() {
    firestore = _Firestore();
    service = StagedStoryReviewService(firestore);
    functions = _Functions(firestore);
    firestore.documents[statePath] = {
      'status': 'review',
      'importerCode': 'importer',
      'reviewerCode': 'reviewer',
      'postCount': 2,
      'metadataCount': 1,
      'reviewVersion': 1,
      'decisionVersion': 0,
    };
    firestore.documents['$postsPath/later'] = post(2, 'second');
    firestore.documents['$postsPath/earlier'] = post(1, 'first');
    firestore.documents['$metadataPath/000000'] = {
      'cipher': 'metadata',
      'iv': 'nonce',
    };
  });

  test(
    'loads and decrypts the complete server snapshot before approval',
    () async {
      final review = await load();
      expect(review.posts.map((post) => post.id), ['earlier', 'later']);
      expect(review.posts.first.data['content'], 'plain:first');
      expect(review.posts.first.data['quotedContent'], 'plain:quote');
      expect(review.posts.first.data['authorName'], 'Earlier name');
      expect(review.session['chapters'], ['Chapter 1']);
      expect(review.sourceSessionId, 'old-room');
      expect(
        () => (review.session['chapters'] as List).clear(),
        throwsUnsupportedError,
      );
      expect(review.posts.first.data.containsKey('contentIv'), isFalse);
      expect(() => review.posts.clear(), throwsUnsupportedError);
      expect(
        () => review.posts.first.data['content'] = 'changed',
        throwsUnsupportedError,
      );
      await service.decide(review, approve: true);
      expect(firestore.documents[statePath]!['status'], 'approved');
      expect(firestore.documents[statePath]!['decisionVersion'], 1);
    },
  );

  test(
    'rejects incomplete, cached, pending or undecryptable snapshots',
    () async {
      firestore.documents.remove('$postsPath/later');
      await expectLater(load(), throwsStateError);
      firestore.documents['$postsPath/later'] = post(2, 'second');
      final metadata = firestore.documents.remove('$metadataPath/000000')!;
      await expectLater(load(), throwsFormatException);
      firestore.documents['$metadataPath/000000'] = metadata;
      firestore.cached = true;
      await expectLater(load(), throwsStateError);
      firestore.cached = false;
      firestore.pending = true;
      await expectLater(load(), throwsStateError);
      firestore.pending = false;
      await expectLater(
        service.load(
          sessionId: 'room',
          reviewerCode: 'reviewer',
          decrypt: (_, _) async => null,
        ),
        throwsStateError,
      );
      expect(firestore.documents[statePath]!['status'], 'review');
    },
  );

  test(
    'cannot decide on an outdated review and can reject a fresh one',
    () async {
      final oldReview = await load();
      firestore.documents[statePath]!['reviewVersion'] = 2;
      await expectLater(
        service.decide(oldReview, approve: true),
        throwsStateError,
      );
      await expectLater(
        service.decide(oldReview, approve: false),
        throwsStateError,
      );
      final newReview = await load();
      await service.decide(newReview, approve: false);
      expect(firestore.documents[statePath]!['status'], 'rejected');
      expect(firestore.documents[statePath]!['decisionVersion'], 2);
    },
  );

  test(
    'detects changes while decrypting and refuses non-demo projects',
    () async {
      await expectLater(
        service.load(
          sessionId: 'room',
          reviewerCode: 'reviewer',
          decrypt: (cipher, iv) async {
            firestore.documents[statePath]!['reviewVersion'] = 2;
            return cipher == 'metadata' ? metadataJson : 'plain:$cipher';
          },
        ),
        throwsStateError,
      );
      expect(
        () => StagedStoryReviewService(_Firestore('production')),
        throwsStateError,
      );
    },
  );

  test('publishing rejects a different functions project', () {
    expect(
      () => StagedStoryPublishService(
        firestore,
        functions: _Functions(_Firestore('demo-other')),
      ),
      throwsStateError,
    );
  });

  test('stages the backup and loads the frozen posts for review', () async {
    firestore.documents.clear();
    firestore.documents['sessions_v2/room'] = {
      'participants': ['importer', 'reviewer'],
    };
    final aes = AesGcm.with256bits();
    final key = await aes.newSecretKey();
    final summary = String.fromCharCode(0x1f680) * 20000;
    final backup = RpStoryBackup(
      sessionId: 'old-room',
      exportedAt: DateTime.utc(2026),
      session: {
        'chapters': ['Chapter 1'],
        'postChapters': {'post': 'Chapter 1'},
        'participantNames': {'old': 'Earlier name'},
        'summary': summary,
      },
      posts: [
        StoryPost('post', {
          'authorCode': 'old',
          'authorName': 'Earlier name',
          'content': 'Story',
          'createdAt': Timestamp(1, 1000),
        }),
      ],
    );
    await StagedStoryUploadService(firestore).stage(
      sessionId: 'room',
      importerCode: 'importer',
      reviewerCode: 'reviewer',
      backup: backup,
      authorCodes: {'old': 'reviewer'},
      encrypt: (plain) async {
        final box = await aes.encrypt(utf8.encode(plain), secretKey: key);
        return {
          'cipher': base64.encode(box.cipherText + box.mac.bytes),
          'iv': base64.encode(box.nonce),
        };
      },
    );
    expect(firestore.documents[statePath]!['status'], 'review');
    Future<String?> decryptRoom(String cipher, String iv) async {
      final bytes = base64.decode(cipher);
      return utf8.decode(
        await aes.decrypt(
          SecretBox(
            bytes.sublist(0, bytes.length - 16),
            nonce: base64.decode(iv),
            mac: Mac(bytes.sublist(bytes.length - 16)),
          ),
          secretKey: key,
        ),
      );
    }

    final review = await service.load(
      sessionId: 'room',
      reviewerCode: 'reviewer',
      decrypt: decryptRoom,
    );
    expect(review.posts.single.data['content'], 'Story');
    expect(review.posts.single.data['authorCode'], 'reviewer');
    expect(review.session['chapters'], ['Chapter 1']);
    expect(review.session['postChapters'], {'post': 'Chapter 1'});
    expect(review.session['participantNames'], {'old': 'Earlier name'});
    expect(review.session['summary'], summary);
    expect(firestore.documents[statePath]!['metadataCount'], greaterThan(1));
    await service.decide(review, approve: true);
    expect(firestore.documents[statePath]!['decisionVersion'], 1);
    Future<void> publish() =>
        StagedStoryPublishService(firestore, functions: functions).publish(
          sessionId: 'room',
          importerCode: 'importer',
          backup: backup,
          authorCodes: {'old': 'reviewer'},
          decrypt: decryptRoom,
        );
    backup.session['chapters'] = ['Changed'];
    await expectLater(publish(), throwsFormatException);
    expect(firestore.documents['sessions_v2/room/posts/post'], isNull);
    backup.session['chapters'] = ['Chapter 1'];
    firestore.documents['sessions_v2/room/posts/unexpected'] = {
      'content': 'existing',
    };
    await expectLater(publish(), throwsFormatException);
    expect(firestore.documents['sessions_v2/room/posts/unexpected'], isNotNull);
    firestore.documents.remove('sessions_v2/room/posts/unexpected');
    functions.fail = true;
    await expectLater(publish(), throwsStateError);
    expect(firestore.documents[statePath]!['status'], 'approved');
    functions.fail = false;
    await publish();
    expect(firestore.documents[statePath]!['status'], 'completed');
    functions.fail = true;
    await publish();
    backup.posts.single.data['content'] = 'Different backup';
    await expectLater(publish(), throwsFormatException);
    backup.posts.single.data['content'] = 'Story';
    functions.fail = false;
    expect(
      firestore.documents['sessions_v2/room/posts/post'],
      firestore.documents['$postsPath/post'],
    );
    expect(
      firestore.documents['sessions_v2/room/story_metadata/000000'],
      firestore.documents['$metadataPath/000000'],
    );
  });

  test('retries a partially uploaded multi-batch story', () async {
    firestore.documents.clear();
    firestore.documents['sessions_v2/room'] = {
      'participants': ['importer', 'reviewer'],
    };
    final backup = RpStoryBackup(
      sessionId: 'old-room',
      exportedAt: DateTime.utc(2026),
      session: {},
      posts: [
        for (var i = 0; i < 401; i++)
          StoryPost('post-$i', {
            'authorCode': 'old',
            'authorName': 'Writer',
            'content': 'Story $i',
            'createdAt': Timestamp(i, 0),
          }),
      ],
    );
    Future<void> stage() => StagedStoryUploadService(firestore).stage(
      sessionId: 'room',
      importerCode: 'importer',
      reviewerCode: 'reviewer',
      backup: backup,
      authorCodes: {'old': 'importer'},
      encrypt: (_) async => {
        'cipher': base64.encode(List.filled(16, 0)),
        'iv': base64.encode(List.filled(12, 0)),
      },
    );
    firestore.failBatchAt = 2;
    await expectLater(stage(), throwsStateError);
    expect(firestore.documents[statePath]!['status'], 'uploading');
    expect(
      firestore.documents.keys
          .where((key) => key.startsWith('$postsPath/'))
          .length,
      400,
    );
    firestore.failBatchAt = null;
    await stage();
    expect(firestore.documents[statePath]!['status'], 'review');
    expect(
      firestore.documents.keys
          .where((key) => key.startsWith('$postsPath/'))
          .length,
      401,
    );
  });

  test(
    'resumes publishing approved posts without overwriting existing data',
    () async {
      firestore.documents.clear();
      firestore.documents['sessions_v2/room'] = {
        'participants': ['importer', 'reviewer'],
      };
      final aes = AesGcm.with256bits();
      final key = await aes.newSecretKey();
      final backup = RpStoryBackup(
        sessionId: 'old-room',
        exportedAt: DateTime.utc(2026),
        session: {
          'chapters': ['Chapter 1'],
        },
        posts: [
          for (var i = 0; i < 12; i++)
            StoryPost('post-$i', {
              'authorCode': 'old',
              'authorName': 'Writer',
              'content': 'Story $i',
              'createdAt': Timestamp(i, 0),
            }),
        ],
      );
      Future<Map<String, String>> encryptRoom(String text) async {
        final box = await aes.encrypt(utf8.encode(text), secretKey: key);
        return {
          'cipher': base64.encode(box.cipherText + box.mac.bytes),
          'iv': base64.encode(box.nonce),
        };
      }

      Future<String?> decryptRoom(String cipher, String iv) async {
        final bytes = base64.decode(cipher);
        return utf8.decode(
          await aes.decrypt(
            SecretBox(
              bytes.sublist(0, bytes.length - 16),
              nonce: base64.decode(iv),
              mac: Mac(bytes.sublist(bytes.length - 16)),
            ),
            secretKey: key,
          ),
        );
      }

      await StagedStoryUploadService(firestore).stage(
        sessionId: 'room',
        importerCode: 'importer',
        reviewerCode: 'reviewer',
        backup: backup,
        authorCodes: {'old': 'importer'},
        encrypt: encryptRoom,
      );
      final review = await service.load(
        sessionId: 'room',
        reviewerCode: 'reviewer',
        decrypt: decryptRoom,
      );
      await service.decide(review, approve: true);
      Future<void> publish() =>
          StagedStoryPublishService(firestore, functions: functions).publish(
            sessionId: 'room',
            importerCode: 'importer',
            backup: backup,
            authorCodes: {'old': 'importer'},
            decrypt: decryptRoom,
          );
      backup.posts.first.data['content'] = 'Wrong backup';
      await expectLater(publish(), throwsFormatException);
      backup.posts.first.data['content'] = 'Story 0';
      firestore.failBatchAt = firestore.batchCount + 2;
      await expectLater(publish(), throwsStateError);
      expect(firestore.documents[statePath]!['status'], 'approved');
      expect(
        firestore.documents.keys
            .where((key) => key.startsWith('sessions_v2/room/posts/'))
            .length,
        10,
      );
      firestore.failBatchAt = null;
      await publish();
      expect(firestore.documents[statePath]!['status'], 'completed');
      expect(
        firestore.documents.keys
            .where((key) => key.startsWith('sessions_v2/room/posts/'))
            .length,
        12,
      );
    },
  );

  test(
    'does not publish an outdated verification or lose timestamps',
    () async {
      firestore.documents.clear();
      firestore.documents['sessions_v2/room'] = {
        'participants': ['importer', 'reviewer'],
      };
      final backup = RpStoryBackup(
        sessionId: 'old-room',
        exportedAt: DateTime.utc(2026),
        session: {},
        posts: [
          StoryPost('post', {
            'authorCode': 'old',
            'authorName': 'Writer',
            'content': 'Story',
            'createdAt': Timestamp(1, 123),
          }),
        ],
      );
      Future<void> stage() => StagedStoryUploadService(firestore).stage(
        sessionId: 'room',
        importerCode: 'importer',
        reviewerCode: 'reviewer',
        backup: backup,
        authorCodes: {'old': 'importer'},
        encrypt: (_) async => {
          'cipher': base64.encode(List.filled(16, 0)),
          'iv': base64.encode(List.filled(12, 0)),
        },
      );
      await expectLater(stage(), throwsFormatException);
      expect(firestore.documents.containsKey(statePath), isFalse);
      backup.posts.single.data['createdAt'] = Timestamp(1, 0);
      firestore.beforeTransaction = (number) {
        if (number == 3) {
          firestore.documents[statePath]!['reviewVersion'] = 2;
        }
      };
      await expectLater(stage(), throwsStateError);
      expect(firestore.documents[statePath]!['status'], 'verifying');
      firestore.beforeTransaction = null;
      await stage();
      expect(firestore.documents[statePath]!['reviewVersion'], 3);
      expect(firestore.documents[statePath]!['status'], 'review');
    },
  );

  test(
    'leaves a mismatched frozen set retryable and never requests review',
    () async {
      firestore.documents.clear();
      firestore.documents['sessions_v2/room'] = {
        'participants': ['importer', 'reviewer'],
      };
      final backup = RpStoryBackup(
        sessionId: 'old-room',
        exportedAt: DateTime.utc(2026),
        session: {},
        posts: [
          StoryPost('post', {
            'authorCode': 'old',
            'authorName': 'Writer',
            'content': 'Story',
            'createdAt': Timestamp(1, 0),
          }),
        ],
      );
      Future<void> stage() => StagedStoryUploadService(firestore).stage(
        sessionId: 'room',
        importerCode: 'importer',
        reviewerCode: 'reviewer',
        backup: backup,
        authorCodes: {'old': 'importer'},
        encrypt: (_) async => {
          'cipher': base64.encode(List.filled(16, 0)),
          'iv': base64.encode(List.filled(12, 0)),
        },
      );
      firestore.beforeQuery = (path) {
        if (path == postsPath &&
            firestore.documents[statePath]?['status'] == 'verifying') {
          firestore.documents['$postsPath/post']!['authorName'] = 'Changed';
        }
      };
      await expectLater(stage(), throwsFormatException);
      expect(firestore.documents[statePath]!['status'], 'verifying');
      firestore.beforeQuery = null;
      await stage();
      expect(firestore.documents[statePath]!['status'], 'review');
      expect(firestore.documents['$postsPath/post']!['authorName'], 'Writer');
    },
  );

  test('two accounts share a key and restore a complete story', () async {
    firestore.documents.clear();
    final alice = await X25519().newKeyPair();
    final bob = await X25519().newKeyPair();
    firestore.documents['accounts_v2/alice-uid'] = {'code': 'alice'};
    firestore.documents['accounts_v2/bob-uid'] = {'code': 'bob'};
    firestore.documents['profiles_v2/alice'] = {
      'uid': 'alice-uid',
      'code': 'alice',
      'displayNameOriginal': 'Alice',
      'publicKey': base64.encode((await alice.extractPublicKey()).bytes),
    };
    firestore.documents['profiles_v2/bob'] = {
      'uid': 'bob-uid',
      'code': 'bob',
      'displayNameOriginal': 'Bob',
      'publicKey': base64.encode((await bob.extractPublicKey()).bytes),
    };
    firestore.documents['sessions_v2/room'] = {
      'participants': ['alice', 'bob'],
    };
    final auth = _Auth(firestore.app, _User('alice-uid'));
    final restore = StagedRestoreService(
      auth: auth,
      firestore: firestore,
      functions: functions,
    );
    final backup = RpStoryBackup(
      sessionId: 'old-room',
      exportedAt: DateTime.utc(2026),
      session: {
        'chapters': ['Chapter 1'],
      },
      posts: [
        StoryPost('post', {
          'authorCode': 'old-bob',
          'authorName': 'Bob before migration',
          'content': 'Story',
          'contentRuns': '[{"text":"Story","bold":true}]',
          'createdAt': Timestamp(1, 0),
        }),
      ],
    );
    await restore.stage(
      sessionId: 'room',
      reviewerCode: 'bob',
      identity: alice,
      backup: backup,
      authorCodes: {'old-bob': 'bob'},
    );
    expect(firestore.documents[statePath]!['status'], 'review');
    expect(firestore.documents['$postsPath/post']!['content'], isNot('Story'));
    await expectLater(
      restore.loadPublishedPosts(sessionId: 'room', identity: alice),
      throwsStateError,
    );
    auth.user = _User('bob-uid');
    final review = await restore.loadReview(sessionId: 'room', identity: bob);
    expect(review.posts.single.data['content'], 'Story');
    expect(
      review.posts.single.data['contentRuns'],
      '[{"text":"Story","bold":true}]',
    );
    expect(review.session['chapters'], ['Chapter 1']);
    await restore.decide(review, approve: true);
    auth.user = _User('alice-uid');
    await restore.publish(
      sessionId: 'room',
      identity: alice,
      backup: backup,
      authorCodes: {'old-bob': 'bob'},
    );
    expect(firestore.documents[statePath]!['status'], 'completed');
    expect(
      firestore.documents['sessions_v2/room/posts/post'],
      firestore.documents['$postsPath/post'],
    );
    final alicePosts = await restore.loadPublishedPosts(
      sessionId: 'room',
      identity: alice,
    );
    expect(alicePosts.single['id'], 'post');
    expect(alicePosts.single['authorCode'], 'bob');
    expect(alicePosts.single['content'], 'Story');
    expect(alicePosts.single['contentRuns'], '[{"text":"Story","bold":true}]');
    expect(alicePosts.single['createdAt'], Timestamp(1, 0));
    expect(alicePosts.single.containsKey('contentIv'), isFalse);
    final visiblePost = RPPost.fromData(alicePosts.single, 'bob');
    expect(visiblePost.content, 'Story');
    expect(visiblePost.isUser, isTrue);
    expect(visiblePost.runs.single, {'text': 'Story', 'bold': true});
    expect(visiblePost.timestamp, Timestamp(1, 0).toDate());
    auth.user = _User('bob-uid');
    final bobPosts = await restore.loadPublishedPosts(
      sessionId: 'room',
      identity: bob,
    );
    expect(bobPosts, alicePosts);
    await expectLater(
      restore.loadPublishedPosts(sessionId: 'room', identity: alice),
      throwsStateError,
    );
    final savedContent =
        firestore.documents['sessions_v2/room/posts/post']!['content'];
    firestore.documents['sessions_v2/room/posts/post']!['content'] = 'bad';
    await expectLater(
      restore.loadPublishedPosts(sessionId: 'room', identity: bob),
      throwsFormatException,
    );
    firestore.documents['sessions_v2/room/posts/post']!['content'] =
        savedContent;
    firestore.beforeQuery = (path) {
      if (path == 'sessions_v2/room/posts') auth.user = null;
    };
    await expectLater(
      restore.loadPublishedPosts(sessionId: 'room', identity: bob),
      throwsStateError,
    );
    firestore.beforeQuery = null;
  });
}
