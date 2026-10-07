import 'prayer_repository.dart';
import 'event_repository.dart';
import 'prayer_page.dart';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'people_repository.dart';
import 'main.dart' show Workspace, leviticusTheme;

const useEmulators = bool.fromEnvironment('USE_EMULATORS');
const churchId = String.fromEnvironment('CHURCH_ID');
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (churchId.isEmpty) throw StateError('CHURCH_ID ausente');
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
        appId: String.fromEnvironment('FIREBASE_APP_ID'),
        messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
        projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
        authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      ),
    );
    if (useEmulators) {
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      ).useFunctionsEmulator('localhost', 5001);
    } else {
      const siteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');
      if (siteKey.isEmpty) throw StateError('App Check não configurado');
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(siteKey),
      );
    }
    runApp(const FirebaseSessionApp());
  } catch (_) {
    runApp(
      MaterialApp(
        theme: leviticusTheme(),
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'O ambiente ainda não foi configurado. Solicite a configuração ao administrador.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FirebaseChurchRepository
    implements ChurchRepository, PrayerRepository, EventRepository {
  @override
  Future<List<ChurchEvent>> listEvents() async =>
      (await list('listEvents')).map(ChurchEvent.fromMap).toList();
  @override
  Future<void> saveEvent(ChurchEvent e, String requestId) async {
    await functions.httpsCallable('saveEvent').call({
      'churchId': churchId,
      'eventId': e.id,
      'requestId': requestId,
      'expectedVersion': e.version,
      'event': e.values,
    });
  }

  @override
  String get currentUid => FirebaseAuth.instance.currentUser!.uid;
  @override
  Future<List<Prayer>> listPrayers() async =>
      (await list('listPrayers')).map(Prayer.fromMap).toList();
  @override
  Future<void> submitPrayer(
    String id,
    String requestId,
    String subject,
    String body,
  ) async {
    await functions.httpsCallable('submitPrayer').call({
      'churchId': churchId,
      'prayerId': id,
      'requestId': requestId,
      'subject': subject,
      'body': body,
    });
  }

  @override
  Future<void> updatePrayer(
    Prayer p,
    String requestId,
    String status,
    String nextContactAt,
  ) async {
    await functions.httpsCallable('updatePrayer').call({
      'churchId': churchId,
      'prayerId': p.id,
      'requestId': requestId,
      'expectedVersion': p.version,
      'status': status,
      'nextContactAt': nextContactAt,
    });
  }

  final functions = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
  Future<List<Map<String, dynamic>>> list(String method) async {
    final result = <Map<String, dynamic>>[];
    String? cursor;
    do {
      final response = await functions.httpsCallable(method).call({
        'churchId': churchId,
        'after': cursor,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      result.addAll(
        (data['items'] as List).map((p) => Map<String, dynamic>.from(p as Map)),
      );
      cursor = data['nextCursor'] as String?;
    } while (cursor != null);
    return result;
  }

  @override
  Future<List<Person>> listPeople() async =>
      (await list('listPeople')).map(Person.fromMap).toList();
  @override
  Future<List<Ministry>> listMinistries() async =>
      (await list('listMinistries')).map(Ministry.fromMap).toList();
  @override
  Future<void> savePerson(Person p, String requestId) async {
    await functions.httpsCallable('savePerson').call({
      'churchId': churchId,
      'personId': p.id,
      'requestId': requestId,
      'expectedVersion': p.version,
      'person': p.values,
    });
  }

  @override
  Future<void> saveMinistry(Ministry m, String requestId) async {
    await functions.httpsCallable('saveMinistry').call({
      'churchId': churchId,
      'ministryId': m.id,
      'requestId': requestId,
      'expectedVersion': m.version,
      'ministry': m.values,
    });
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final email = TextEditingController(), password = TextEditingController();
  String message = '';
  bool busy = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> act(Future<void> Function() action) async {
    setState(() {
      busy = true;
      message = '';
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Não foi possível concluir. Verifique os dados e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> login() => act(() async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.text.trim(),
      password: password.text,
    );
    password.clear();
  });
  Future<void> reset() => act(() async {
    if (email.text.trim().isEmpty) {
      setState(() => message = 'Informe seu e-mail.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.text.trim(),
      );
    } catch (_) {}
    if (mounted) {
      setState(
        () => message =
            'Se houver uma conta para esse e-mail, você receberá as instruções de recuperação.',
      );
    }
  });
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final user = snapshot.data;
      if (user != null && user.emailVerified) {
        return AuthorizedWorkspace(key: ValueKey(user.uid));
      }
      if (user != null) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Confirme seu e-mail e entre novamente.'),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => act(() async {
                            await user.sendEmailVerification();
                            if (mounted) {
                              setState(() => message = 'Confirmação enviada.');
                            }
                          }),
                    child: const Text('Reenviar confirmação'),
                  ),
                  if (message.isNotEmpty) Text(message),
                  TextButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('Voltar ao login'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.church_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Leviticus',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Entre para cuidar da sua comunidade.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'E-mail'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: password,
                      enabled: !busy,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Senha'),
                      onSubmitted: busy ? null : (_) => login(),
                    ),
                    if (message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(message),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : login,
                      child: Text(busy ? 'Entrando…' : 'Entrar'),
                    ),
                    TextButton(
                      onPressed: busy ? null : reset,
                      child: const Text('Recuperar acesso'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class AuthorizedWorkspace extends StatefulWidget {
  const AuthorizedWorkspace({super.key});
  @override
  State<AuthorizedWorkspace> createState() => _AuthorizedWorkspaceState();
}

class _AuthorizedWorkspaceState extends State<AuthorizedWorkspace> {
  final repository = FirebaseChurchRepository();
  late Future<HttpsCallableResult<dynamic>> access;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    access = repository.functions.httpsCallable('getWorkspace').call({
      'churchId': churchId,
    });
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<HttpsCallableResult<dynamic>>(
        future: access,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Sem acesso à igreja ou conexão indisponível.'),
                    TextButton(
                      onPressed: () => setState(load),
                      child: const Text('Tentar novamente'),
                    ),
                    TextButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Sair'),
                    ),
                  ],
                ),
              ),
            );
          }
          final role = snapshot.data!.data['role'] as String;
          if (role == 'member') {
            return PrayerPage(
              repository: repository,
              onSignOut: () => FirebaseAuth.instance.signOut(),
            );
          }
          return Workspace(
            repository: repository,
            demo: false,
            allowPrayer: role == 'pastor',
            onSignOut: () => FirebaseAuth.instance.signOut(),
          );
        },
      );
}

// A new identity replaces the Navigator as well as its pages and dialogs.
// This prevents an open confidential dialog from surviving sign-out.
class FirebaseSessionApp extends StatelessWidget {
  const FirebaseSessionApp({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) => MaterialApp(
      key: ValueKey(snapshot.data?.uid ?? 'signed-out'),
      debugShowCheckedModeBanner: false,
      title: 'Leviticus',
      theme: leviticusTheme(),
      home: const AuthGate(),
    ),
  );
}
