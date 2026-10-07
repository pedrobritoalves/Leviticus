class ChurchEvent {
  final String id, title, location, organizerId, status;
  final DateTime startsAt, endsAt;
  final int version;
  const ChurchEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.location = '',
    this.organizerId = '',
    this.status = 'scheduled',
    this.version = 0,
  });
  factory ChurchEvent.fromMap(Map<String, dynamic> value) => ChurchEvent(
    id: value['id'] as String,
    title: value['title'] as String,
    location: value['location'] as String,
    organizerId: value['organizerId'] as String,
    status: value['status'] as String,
    version: value['version'] as int,
    startsAt: DateTime.parse(value['startsAt'] as String),
    endsAt: DateTime.parse(value['endsAt'] as String),
  );
  Map<String, dynamic> get values => {
    'title': title,
    'location': location,
    'organizerId': organizerId,
    'status': status,
    'startsAt': startsAt.toUtc().toIso8601String(),
    'endsAt': endsAt.toUtc().toIso8601String(),
  };
}

abstract class EventRepository {
  Future<List<ChurchEvent>> listEvents();
  Future<void> saveEvent(ChurchEvent event, String requestId);
}
