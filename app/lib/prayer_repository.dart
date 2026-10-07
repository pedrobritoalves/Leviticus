class Prayer {
  final String id, subject, body, authorId, assignedTo, status, nextContactAt;
  final int version;
  const Prayer({
    required this.id,
    required this.subject,
    required this.body,
    required this.authorId,
    required this.assignedTo,
    this.status = 'open',
    this.nextContactAt = '',
    this.version = 1,
  });
  factory Prayer.fromMap(Map<String, dynamic> value) => Prayer(
    id: value['id'] as String,
    subject: value['subject'] as String,
    body: value['body'] as String,
    authorId: value['authorId'] as String,
    assignedTo: value['assignedTo'] as String,
    status: value['status'] as String,
    nextContactAt: value['nextContactAt'] as String? ?? '',
    version: value['version'] as int,
  );
}

abstract class PrayerRepository {
  String get currentUid;
  Future<List<Prayer>> listPrayers();
  Future<void> submitPrayer(
    String id,
    String requestId,
    String subject,
    String body,
  );
  Future<void> updatePrayer(
    Prayer prayer,
    String requestId,
    String status,
    String nextContactAt,
  );
}
