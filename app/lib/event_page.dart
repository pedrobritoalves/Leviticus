import 'dart:convert';
import 'package:flutter/material.dart';
import 'event_repository.dart';
import 'people_repository.dart';

String formatEventTime(DateTime value) {
  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year.toString().padLeft(4, '0')} ${two(d.hour)}:${two(d.minute)}';
}

DateTime? parseEventTime(String value) {
  final m = RegExp(
    r'^(\d{2})/(\d{2})/(\d{4}) (\d{2}):(\d{2})$',
  ).firstMatch(value.trim());
  if (m == null) return null;
  final d = DateTime(
    int.parse(m[3]!),
    int.parse(m[2]!),
    int.parse(m[1]!),
    int.parse(m[4]!),
    int.parse(m[5]!),
  );
  return formatEventTime(d) == value.trim() ? d : null;
}

class EventPage extends StatefulWidget {
  final EventRepository repository;
  final List<Person> people;
  final bool demo;
  const EventPage({
    super.key,
    required this.repository,
    required this.people,
    this.demo = false,
  });
  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> {
  List<ChurchEvent> events = [];
  bool loading = true;
  String error = '', search = '', filter = 'all';
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
      events = [];
    });
    try {
      final loaded = await widget.repository.listEvents();
      loaded.sort((a, b) => a.startsAt.compareTo(b.startsAt));
      if (mounted && current == request) setState(() => events = loaded);
    } catch (_) {
      if (mounted && current == request) {
        setState(
          () => error =
              'Não foi possível carregar a agenda. Verifique seu acesso e tente novamente.',
        );
      }
    } finally {
      if (mounted && current == request) setState(() => loading = false);
    }
  }

  Future<void> edit([ChurchEvent? event]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EventDialog(
        repository: widget.repository,
        people: widget.people,
        event: event,
      ),
    );
    if (saved == true && mounted) await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final visible = events
        .where(
          (e) =>
              e.title.toLowerCase().contains(search.toLowerCase()) &&
              (filter == 'all' ||
                  (filter == 'upcoming'
                      ? e.status == 'scheduled' &&
                            e.endsAt.isAfter(DateTime.now())
                      : e.status == 'cancelled')),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda institucional'),
        actions: [
          IconButton(
            onPressed: loading ? null : refresh,
            tooltip: 'Atualizar agenda',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              if (widget.demo)
                const Card(
                  color: Color(0xffffefc5),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Demonstração: eventos fictícios em memória.'),
                  ),
                ),
              const Text(
                'Agenda da equipe administrativa e pastoral. Use somente informações institucionais; atendimentos confidenciais ficam fora desta agenda.',
              ),
              const SizedBox(height: 8),
              Text(
                'Horários no fuso local do dispositivo (${DateTime.now().timeZoneName}).',
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar evento',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => search = v),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final item in {
                    'all': 'Todos',
                    'upcoming': 'Próximos',
                    'cancelled': 'Cancelados',
                  }.entries)
                    ChoiceChip(
                      label: Text(item.value),
                      selected: filter == item.key,
                      onSelected: (_) => setState(() => filter = item.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (loading)
                const Center(child: CircularProgressIndicator())
              else if (error.isNotEmpty) ...[
                Text(error),
                TextButton(
                  onPressed: refresh,
                  child: const Text('Tentar novamente'),
                ),
              ] else if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nenhum evento encontrado.'),
                )
              else
                ...visible.map(
                  (e) => Card(
                    child: ListTile(
                      leading: Icon(
                        e.status == 'cancelled'
                            ? Icons.event_busy
                            : Icons.event_outlined,
                      ),
                      title: Text(e.title),
                      subtitle: Text(
                        '${formatEventTime(e.startsAt)} → ${formatEventTime(e.endsAt)}\n${e.status == 'cancelled' ? 'Cancelado' : 'Agendado'}${e.location.isEmpty ? '' : ' · ${e.location}'}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => edit(e),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading || error.isNotEmpty ? null : () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Criar evento'),
      ),
    );
  }
}

class EventDialog extends StatefulWidget {
  final EventRepository repository;
  final List<Person> people;
  final ChurchEvent? event;
  const EventDialog({
    super.key,
    required this.repository,
    required this.people,
    this.event,
  });
  @override
  State<EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<EventDialog> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      location = TextEditingController(),
      start = TextEditingController(),
      end = TextEditingController();
  late String id;
  String organizerId = '',
      status = 'scheduled',
      error = '',
      requestId = newId(),
      fingerprint = '';
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final e = widget.event;
    id = e?.id ?? newId();
    title.text = e?.title ?? '';
    location.text = e?.location ?? '';
    organizerId = e?.organizerId ?? '';
    status = e?.status ?? 'scheduled';
    final next = DateTime.now().add(const Duration(days: 1));
    final initial = DateTime(next.year, next.month, next.day, 19);
    start.text = formatEventTime(e?.startsAt ?? initial);
    end.text = formatEventTime(
      e?.endsAt ?? initial.add(const Duration(hours: 1)),
    );
  }

  @override
  void dispose() {
    for (final c in [title, location, start, end]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pick(TextEditingController controller) async {
    final initial = parseEventTime(controller.text) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year < 1900 ? initial.year : 1900),
      lastDate: DateTime(initial.year > 2200 ? initial.year + 1 : 2200),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted || time == null) return;
    controller.text = formatEventTime(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final startsAt = parseEventTime(start.text)!,
        endsAt = parseEventTime(end.text)!;
    if (!endsAt.isAfter(startsAt)) {
      setState(() => error = 'Término deve ser posterior ao início.');
      return;
    }
    final e = ChurchEvent(
      id: id,
      title: title.text.trim(),
      location: location.text.trim(),
      startsAt: startsAt,
      endsAt: endsAt,
      organizerId: organizerId,
      status: status,
      version: widget.event?.version ?? 0,
    );
    final current = jsonEncode(e.values);
    if (fingerprint != current) {
      requestId = newId();
      fingerprint = current;
    }
    setState(() {
      saving = true;
      error = '';
    });
    try {
      await widget.repository.saveEvent(e, requestId);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Não foi possível salvar. Verifique a conexão e seu acesso. Se outra pessoa editou, feche e atualize a agenda antes de tentar novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget dateField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'dd/mm/aaaa HH:mm',
          suffixIcon: IconButton(
            onPressed: saving ? null : () => pick(controller),
            tooltip: 'Escolher $label',
            icon: const Icon(Icons.calendar_month),
          ),
        ),
        validator: (v) => parseEventTime(v ?? '') == null
            ? 'Use uma data válida: dd/mm/aaaa HH:mm.'
            : null,
      );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(widget.event == null ? 'Criar evento' : 'Editar evento'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: AbsorbPointer(
              absorbing: saving,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Visível à equipe autorizada da igreja. Não registre informações de aconselhamento.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: title,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Título do evento',
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 2
                        ? 'Informe o título do evento.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: location,
                    maxLength: 180,
                    decoration: const InputDecoration(labelText: 'Local'),
                  ),
                  const SizedBox(height: 12),
                  dateField(start, 'Início (horário local)'),
                  const SizedBox(height: 16),
                  dateField(end, 'Término (horário local)'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: organizerId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Responsável'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Definir depois'),
                      ),
                      for (final p in widget.people)
                        DropdownMenuItem(value: p.id, child: Text(p.name)),
                      if (organizerId.isNotEmpty &&
                          !widget.people.any((p) => p.id == organizerId))
                        DropdownMenuItem(
                          value: organizerId,
                          child: const Text('Responsável indisponível'),
                        ),
                    ],
                    onChanged: (v) => setState(() => organizerId = v ?? ''),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Situação do evento',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'scheduled',
                        child: Text('Agendado'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text('Cancelado'),
                      ),
                    ],
                    onChanged: (v) => setState(() => status = v!),
                  ),
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(saving ? 'Salvando…' : 'Salvar evento'),
        ),
      ],
    ),
  );
}
