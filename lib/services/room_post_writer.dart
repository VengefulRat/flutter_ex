import 'dart:ui' show Color;

abstract interface class RoomPostWriter {
  Future<String?> addPost({
    required String sessionId,
    required String content,
    String? chapter,
    String? quotedPostId,
    String? quotedContent,
    String? contentRuns,
    String? quotedAuthor,
    String? characterName,
    String? locationName,
    Color? textColor,
  });

  Future<void> editPost({
    required String sessionId,
    required String postId,
    String? contentRuns,
    required String newContent,
    Color? textColor,
  });

  Future<void> deletePost({required String sessionId, required String postId});
}
