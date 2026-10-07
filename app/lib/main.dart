import 'prayer_page.dart';
import 'event_page.dart';
import 'event_repository.dart';
import 'prayer_repository.dart';

import 'package:flutter/material.dart';

import 'people_repository.dart';
import 'person_dialog.dart';
import 'ministry_dialog.dart';

void main() => runApp(LeviticusApp(repository: DemoChurchRepository()));
ThemeData leviticusTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff163c5b)),
  scaffoldBackgroundColor: const Color(0xfff4f6fa),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
  ),
  appBarTheme: const AppBarTheme(backgroundColor: Colors.white),
);

class LeviticusApp extends StatelessWidget {
  final ChurchRepository repository;
  final bool demo;
  const LeviticusApp({super.key, required this.repository, this.demo = true});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Leviticus',
    theme: leviticusTheme(),
    home: Workspace(repository: repository, demo: demo),
  );
}

class Workspace extends StatefulWidget {
  final ChurchRepository repository;
  final bool demo;
  final VoidCallback? onSignOut;
  final bool allowPrayer;
  const Workspace({
    super.key,
    required this.repository,
    this.demo = true,
    this.onSignOut,
    this.allowPrayer = true,
  });
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  List<Person> people = [];
  List<Ministry> ministries = [];
  int section = 0;
  String search = '', filter = 'all', error = '';
  bool loading = true;
  int request = 0;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final current = ++request;
    setState(() {
      loading = true;
      error = '';
      people = [];
      ministries = [];
    });
    try {
      final p = await widget.repository.listPeople();
      final m = await widget.repository.listMinistries();
      if (mounted && current == request) {
        setState(() {
          people = p;
          ministries = m;
        });
      }
    } catch (_) {
      if (mounted && current == request) {
        setState(
          () => error =
              'Não foi possível carregar. Verifique seu acesso e tente novamente.',
        );
      }
    } finally {
      if (mounted && current == request) setState(() => loading = false);
    }
  }

  Future<void> editPerson([Person? person]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          PersonDialog(repository: widget.repository, person: person),
    );
    if (saved == true && mounted) await refresh();
  }

  Future<void> editMinistry([Ministry? ministry]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MinistryDialog(
        repository: widget.repository,
        people: people,
        ministry: ministry,
      ),
    );
    if (saved == true && mounted) await refresh();
  }

  void navigate(int i) => setState(() {
    section = i;
    search = '';
    filter = 'all';
  });
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final title = section == 0 ? 'Pessoas' : 'Ministérios';
    final visible = people
        .where(
          (p) =>
              p.name.toLowerCase().contains(search.toLowerCase()) &&
              (filter == 'all' || p.status == filter),
        )
        .toList();
    final groups = ministries
        .where((m) => m.name.toLowerCase().contains(search.toLowerCase()))
        .toList();
    final content = ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
      children: [
        if (widget.demo)
          const Card(
            color: Color(0xffffefc5),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Demonstração • pessoas fictícias. Alterações ficam em memória e são apagadas ao reiniciar.',
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          section == 0
              ? 'Conheça e acompanhe sua comunidade.'
              : 'Organize as equipes que servem à igreja.',
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            Chip(label: Text('${people.length} pessoas')),
            Chip(
              label: Text(
                '${people.where((p) => p.status == 'member').length} membros',
              ),
            ),
            Chip(
              label: Text(
                '${ministries.where((m) => m.active).length} ministérios ativos',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          key: ValueKey(section),
          decoration: InputDecoration(
            labelText: section == 0
                ? 'Buscar pessoa pelo nome'
                : 'Buscar ministério',
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => search = v),
        ),
        const SizedBox(height: 12),
        if (section == 0)
          Wrap(
            spacing: 8,
            children: [
              for (final e in {
                'all': 'Todos',
                'visitor': 'Visitantes',
                'member': 'Membros',
              }.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: filter == e.key,
                  onSelected: (_) => setState(() => filter = e.key),
                ),
            ],
          ),
        const SizedBox(height: 16),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (error.isNotEmpty)
          Column(
            children: [
              Text(error),
              TextButton(
                onPressed: refresh,
                child: const Text('Tentar novamente'),
              ),
            ],
          )
        else if (section == 0) ...[
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Nenhuma pessoa encontrada.'),
            ),
          ...visible.map(
            (p) => Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(p.name),
                subtitle: Text(
                  [
                    p.status == 'member' ? 'Membro' : 'Visitante',
                    if (p.congregation.isNotEmpty) p.congregation,
                    if (p.phone.isNotEmpty) p.phone,
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => editPerson(p),
              ),
            ),
          ),
        ] else ...[
          if (groups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Nenhum ministério encontrado.'),
            ),
          ...groups.map(
            (m) => Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
                title: Text(m.name),
                subtitle: Text(
                  '${m.memberIds.length} participantes · ${m.active ? 'Ativo' : 'Inativo'}',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => editMinistry(m),
              ),
            ),
          ),
        ],
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leviticus'),
        actions: [
          IconButton(
            onPressed: loading ? null : refresh,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
          ),
          if (widget.repository is EventRepository)
            IconButton(
              onPressed: loading || error.isNotEmpty
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => EventPage(
                          repository: widget.repository as EventRepository,
                          people: people,
                          demo: widget.demo,
                        ),
                      ),
                    ),
              tooltip: 'Agenda institucional',
              icon: const Icon(Icons.calendar_month_outlined),
            ),
          if (widget.allowPrayer && widget.repository is PrayerRepository)
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PrayerPage(
                    repository: widget.repository as PrayerRepository,
                    isPastor: true,
                    demo: widget.demo,
                  ),
                ),
              ),
              tooltip: 'Oração e acompanhamento',
              icon: const Icon(Icons.volunteer_activism_outlined),
            ),
          if (widget.onSignOut != null)
            IconButton(
              onPressed: widget.onSignOut,
              tooltip: 'Sair',
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: section,
              onDestinationSelected: navigate,
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  label: Text('Pessoas'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.groups_outlined),
                  label: Text('Ministérios'),
                ),
              ],
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: content,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: section,
              onDestinationSelected: navigate,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  label: 'Pessoas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  label: 'Ministérios',
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading || error.isNotEmpty
            ? null
            : () => section == 0 ? editPerson() : editMinistry(),
        icon: const Icon(Icons.add),
        label: Text(section == 0 ? 'Cadastrar pessoa' : 'Criar ministério'),
      ),
    );
  }
}
