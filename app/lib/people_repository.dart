import 'prayer_repository.dart';

import 'dart:math';

String newId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class Person {
  final String id,
      name,
      preferredName,
      email,
      phone,
      status,
      birthDate,
      admissionDate,
      baptismDate,
      congregation;
  final Map<String, String> address;
  final int version;
  const Person({
    required this.id,
    required this.name,
    this.preferredName = '',
    this.email = '',
    this.phone = '',
    this.status = 'visitor',
    this.birthDate = '',
    this.admissionDate = '',
    this.baptismDate = '',
    this.congregation = '',
    this.address = const {},
    this.version = 0,
  });
  factory Person.fromMap(Map<String, dynamic> p) => Person(
    id: p['id'] as String,
    name: p['name'] as String,
    preferredName: p['preferredName'] as String? ?? '',
    email: p['email'] as String? ?? '',
    phone: p['phone'] as String? ?? '',
    status: p['status'] as String,
    birthDate: p['birthDate'] as String? ?? '',
    admissionDate: p['admissionDate'] as String? ?? '',
    baptismDate: p['baptismDate'] as String? ?? '',
    congregation: p['congregation'] as String? ?? '',
    address: Map<String, String>.from(p['address'] as Map? ?? {}),
    version: p['version'] as int,
  );
  Map<String, dynamic> get values => {
    'name': name,
    'preferredName': preferredName,
    'email': email,
    'phone': phone,
    'status': status,
    'birthDate': birthDate,
    'admissionDate': admissionDate,
    'baptismDate': baptismDate,
    'congregation': congregation,
    'address': address,
  };
}

class Ministry {
  final String id, name, description, leaderId;
  final List<String> memberIds;
  final bool active;
  final int version;
  const Ministry({
    required this.id,
    required this.name,
    this.description = '',
    this.leaderId = '',
    this.memberIds = const [],
    this.active = true,
    this.version = 0,
  });
  factory Ministry.fromMap(Map<String, dynamic> m) => Ministry(
    id: m['id'] as String,
    name: m['name'] as String,
    description: m['description'] as String,
    leaderId: m['leaderId'] as String,
    memberIds: List<String>.from(m['memberIds'] as List),
    active: m['active'] as bool,
    version: m['version'] as int,
  );
  Map<String, dynamic> get values => {
    'name': name,
    'description': description,
    'leaderId': leaderId,
    'memberIds': memberIds,
    'active': active,
  };
}

abstract class ChurchRepository {
  Future<List<Person>> listPeople();
  Future<void> savePerson(Person person, String requestId);
  Future<List<Ministry>> listMinistries();
  Future<void> saveMinistry(Ministry ministry, String requestId);
}

class DemoChurchRepository implements ChurchRepository, PrayerRepository {
  final _prayers = <Prayer>[];
  @override
  String get currentUid => 'demo-pastor';
  @override
  Future<List<Prayer>> listPrayers() async => List.unmodifiable(_prayers);
  @override
  Future<void> submitPrayer(
    String id,
    String requestId,
    String subject,
    String body,
  ) async {
    if (_receipts.containsKey(requestId)) return;
    _prayers.add(
      Prayer(
        id: id,
        subject: subject,
        body: body,
        authorId: currentUid,
        assignedTo: currentUid,
      ),
    );
    _receipts[requestId] = id;
  }

  @override
  Future<void> updatePrayer(
    Prayer prayer,
    String requestId,
    String status,
    String nextContactAt,
  ) async {
    if (_receipts.containsKey(requestId)) return;
    final i = _prayers.indexWhere((p) => p.id == prayer.id);
    if (i < 0 || _prayers[i].version != prayer.version) {
      throw StateError('Atualize o pedido.');
    }
    _prayers[i] = Prayer(
      id: prayer.id,
      subject: prayer.subject,
      body: prayer.body,
      authorId: prayer.authorId,
      assignedTo: prayer.assignedTo,
      status: status,
      nextContactAt: nextContactAt,
      version: prayer.version + 1,
    );
    _receipts[requestId] = prayer.id;
  }

  final _people = <Person>[
    const Person(
      id: 'demo1',
      name: 'Ana Exemplo',
      status: 'member',
      congregation: 'Sede',
      version: 1,
    ),
    const Person(
      id: 'demo2',
      name: 'Daniel Exemplo',
      status: 'visitor',
      version: 1,
    ),
  ];
  final _ministries = <Ministry>[
    const Ministry(
      id: 'demo-ministry',
      name: 'Recepção',
      description: 'Acolhimento de visitantes e membros.',
      leaderId: 'demo1',
      memberIds: ['demo1'],
      version: 1,
    ),
  ];
  final _receipts = <String, String>{};
  @override
  Future<List<Person>> listPeople() async => List.unmodifiable(_people);
  @override
  Future<List<Ministry>> listMinistries() async =>
      List.unmodifiable(_ministries);
  @override
  Future<void> savePerson(Person p, String requestId) async {
    if (_receipts.containsKey(requestId)) return;
    final index = _people.indexWhere((x) => x.id == p.id);
    if ((index < 0 ? 0 : _people[index].version) != p.version) {
      throw StateError('Atualize a lista antes de editar.');
    }
    final saved = Person.fromMap({
      ...p.values,
      'id': p.id,
      'version': p.version + 1,
    });
    if (index < 0) {
      _people.add(saved);
    } else {
      _people[index] = saved;
    }
    _receipts[requestId] = p.id;
  }

  @override
  Future<void> saveMinistry(Ministry m, String requestId) async {
    if (_receipts.containsKey(requestId)) return;
    final index = _ministries.indexWhere((x) => x.id == m.id);
    if ((index < 0 ? 0 : _ministries[index].version) != m.version) {
      throw StateError('Atualize a lista antes de editar.');
    }
    if (m.memberIds.any((id) => !_people.any((p) => p.id == id))) {
      throw StateError('Pessoa não encontrada.');
    }
    final saved = Ministry.fromMap({
      ...m.values,
      'id': m.id,
      'version': m.version + 1,
    });
    if (index < 0) {
      _ministries.add(saved);
    } else {
      _ministries[index] = saved;
    }
    _receipts[requestId] = m.id;
  }
}
