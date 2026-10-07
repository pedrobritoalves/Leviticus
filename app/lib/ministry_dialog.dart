import 'dart:convert';

import 'package:flutter/material.dart';

import 'people_repository.dart';

class MinistryDialog extends StatefulWidget {
  final ChurchRepository repository;
  final List<Person> people;
  final Ministry? ministry;
  const MinistryDialog({
    super.key,
    required this.repository,
    required this.people,
    this.ministry,
  });
  @override
  State<MinistryDialog> createState() => _MinistryDialogState();
}

class _MinistryDialogState extends State<MinistryDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, description;
  late Set<String> members;
  late String leader;
  late bool active;
  late final String recordId;
  String error = '';
  String? lastPayload, operationId;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final m = widget.ministry;
    name = TextEditingController(text: m?.name ?? '');
    description = TextEditingController(text: m?.description ?? '');
    members = (m?.memberIds ?? []).toSet();
    leader = m?.leaderId ?? '';
    active = m?.active ?? true;
    recordId = m?.id ?? newId();
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final m = Ministry(
      id: recordId,
      name: name.text.trim(),
      description: description.text.trim(),
      leaderId: leader,
      memberIds: members.toList()..sort(),
      active: active,
      version: widget.ministry?.version ?? 0,
    );
    final payload = jsonEncode(m.values);
    if (operationId == null || lastPayload != payload) {
      operationId = newId();
      lastPayload = payload;
    }
    setState(() {
      saving = true;
      error = '';
    });
    try {
      await widget.repository.saveMinistry(m, operationId!);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Não foi possível salvar. Confira os participantes ou atualize a lista.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(
        widget.ministry == null ? 'Criar ministério' : 'Editar ministério',
      ),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: name,
                  enabled: !saving,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Nome do ministério',
                  ),
                  validator: (v) =>
                      (v?.trim().length ?? 0) < 2 ? 'Informe o nome.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: description,
                  enabled: !saving,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Ministério ativo'),
                  value: active,
                  onChanged: saving ? null : (v) => setState(() => active = v),
                ),
                const Divider(),
                const Text('Participantes'),
                if (widget.people.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Cadastre pessoas para formar a equipe.'),
                  ),
                for (final p in widget.people)
                  CheckboxListTile(
                    title: Text(p.name),
                    value: members.contains(p.id),
                    onChanged: saving
                        ? null
                        : (selected) => setState(() {
                            if (selected == true) {
                              members.add(p.id);
                            } else {
                              members.remove(p.id);
                              if (leader == p.id) leader = '';
                            }
                          }),
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(leader),
                  initialValue: leader,
                  decoration: const InputDecoration(labelText: 'Responsável'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Definir depois'),
                    ),
                    for (final p in widget.people.where(
                      (p) => members.contains(p.id),
                    ))
                      DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: saving
                      ? null
                      : (v) => setState(() => leader = v ?? ''),
                ),
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
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(saving ? 'Salvando…' : 'Salvar'),
        ),
      ],
    ),
  );
}
