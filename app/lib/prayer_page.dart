import 'dart:convert';
import 'package:flutter/material.dart';

import 'people_repository.dart' show newId;
import 'prayer_repository.dart';

class PrayerPage extends StatefulWidget {
  final PrayerRepository repository;
  final bool isPastor, demo;
  final VoidCallback? onSignOut;
  const PrayerPage({
    super.key,
    required this.repository,
    this.isPastor = false,
    this.demo = false,
    this.onSignOut,
  });
  @override
  State<PrayerPage> createState() => _PrayerPageState();
}

class _PrayerPageState extends State<PrayerPage> {
  List<Prayer> items = [];
  bool loading = true;
  String error = '';
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = '';
      items = [];
    });
    try {
      final result = await widget.repository.listPrayers();
      if (mounted) setState(() => items = result);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Não foi possível carregar os pedidos. Confira seu acesso.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> open([Prayer? prayer]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PrayerDialog(
        repository: widget.repository,
        prayer: prayer,
        canUpdate:
            widget.isPastor &&
            prayer?.assignedTo == widget.repository.currentUid,
      ),
    );
    if (changed == true && mounted) await refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Oração e acompanhamento'),
      actions: [
        IconButton(
          onPressed: loading ? null : refresh,
          tooltip: 'Atualizar',
          icon: const Icon(Icons.refresh),
        ),
        if (widget.onSignOut != null)
          IconButton(
            onPressed: widget.onSignOut,
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
          ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
          children: [
            if (widget.demo)
              const Card(
                color: Color(0xffffefc5),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Demonstração com pedidos fictícios em memória.'),
                ),
              ),
            const Icon(Icons.lock_outline, size: 32),
            const SizedBox(height: 12),
            const Text(
              'Cuidado com confidencialidade',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isPastor
                  ? 'Pedidos encaminhados a você e seus próprios pedidos.'
                  : 'Seus pedidos são compartilhados somente com o pastor responsável.',
            ),
            const SizedBox(height: 24),
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
            else if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhum pedido para acompanhar.'),
              )
            else
              ...items.map(
                (p) => Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const Icon(Icons.volunteer_activism_outlined),
                    title: Text(p.subject),
                    subtitle: Text(
                      '${prayerStatus[p.status] ?? p.status}${p.nextContactAt.isEmpty ? '' : ' · Contato: ${DateTime.parse(p.nextContactAt).toLocal().toString().substring(0, 16)}'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => open(p),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: loading ? null : () => open(),
      icon: const Icon(Icons.add),
      label: const Text('Pedir oração'),
    ),
  );
}

const prayerStatus = {
  'open': 'Recebido',
  'in_progress': 'Em acompanhamento',
  'closed': 'Concluído',
};

class PrayerDialog extends StatefulWidget {
  final PrayerRepository repository;
  final Prayer? prayer;
  final bool canUpdate;
  const PrayerDialog({
    super.key,
    required this.repository,
    this.prayer,
    this.canUpdate = false,
  });
  @override
  State<PrayerDialog> createState() => _PrayerDialogState();
}

class _PrayerDialogState extends State<PrayerDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController subject, body, next;
  late String status;
  final recordId = newId();
  String? requestId, lastPayload;
  bool busy = false;
  String error = '';
  @override
  void initState() {
    super.initState();
    final p = widget.prayer;
    subject = TextEditingController(text: p?.subject ?? '');
    body = TextEditingController(text: p?.body ?? '');
    next = TextEditingController(
      text: p == null || p.nextContactAt.isEmpty
          ? ''
          : DateTime.parse(
              p.nextContactAt,
            ).toLocal().toString().substring(0, 16),
    );
    status = p?.status ?? 'open';
  }

  @override
  void dispose() {
    subject.dispose();
    body.dispose();
    next.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final date = next.text.trim().isEmpty
        ? ''
        : DateTime.parse(next.text.trim()).toUtc().toIso8601String();
    final payload = jsonEncode([subject.text, body.text, status, date]);
    if (requestId == null || payload != lastPayload) {
      requestId = newId();
      lastPayload = payload;
    }
    setState(() {
      busy = true;
      error = '';
    });
    try {
      if (widget.prayer == null) {
        await widget.repository.submitPrayer(
          recordId,
          requestId!,
          subject.text.trim(),
          body.text.trim(),
        );
      } else {
        await widget.repository.updatePrayer(
          widget.prayer!,
          requestId!,
          status,
          date,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Não foi possível salvar. Confira seu acesso e a configuração do acolhimento, ou atualize o pedido.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(widget.prayer == null ? 'Pedir oração' : 'Acompanhamento'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.prayer == null) ...[
                  const Text(
                    'Visível a você e ao pastor responsável pelo acolhimento.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: subject,
                    enabled: !busy,
                    maxLength: 120,
                    decoration: const InputDecoration(labelText: 'Assunto'),
                    validator: (v) => (v?.trim().length ?? 0) < 2
                        ? 'Informe o assunto.'
                        : null,
                  ),
                  TextFormField(
                    controller: body,
                    enabled: !busy,
                    maxLength: 2000,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Como podemos orar por você?',
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 2
                        ? 'Escreva seu pedido.'
                        : null,
                  ),
                ] else ...[
                  Text(
                    widget.prayer!.subject,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  SelectableText(widget.prayer!.body),
                  const SizedBox(height: 24),
                  if (widget.canUpdate) ...[
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Situação'),
                      items: prayerStatus.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                              status = v!;
                              if (status == 'closed') next.clear();
                            }),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: next,
                      enabled: !busy && status != 'closed',
                      decoration: const InputDecoration(
                        labelText: 'Próximo contato (horário local)',
                        hintText: '2026-10-07 14:00',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final date = DateTime.tryParse(v.trim());
                        return date == null ||
                                !RegExp(
                                  r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$',
                                ).hasMatch(v.trim()) ||
                                date.toString().substring(0, 16) != v.trim()
                            ? 'Use AAAA-MM-DD HH:MM.'
                            : null;
                      },
                    ),
                  ] else
                    Text(prayerStatus[status] ?? status),
                ],
                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(error),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Fechar'),
        ),
        if (widget.prayer == null || widget.canUpdate)
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(
              busy
                  ? 'Salvando…'
                  : widget.prayer == null
                  ? 'Enviar pedido'
                  : 'Salvar acompanhamento',
            ),
          ),
      ],
    ),
  );
}
