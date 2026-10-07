import 'dart:convert';

import 'package:flutter/material.dart';

import 'people_repository.dart';

class PersonDialog extends StatefulWidget {
  final ChurchRepository repository;
  final Person? person;
  const PersonDialog({super.key, required this.repository, this.person});
  @override
  State<PersonDialog> createState() => _PersonDialogState();
}

class _PersonDialogState extends State<PersonDialog> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  late String status;
  late final String recordId;
  String? operationId, lastPayload;
  String error = '';
  bool saving = false;
  static const labels = {
    'name': 'Nome completo',
    'preferredName': 'Nome preferido',
    'email': 'E-mail',
    'phone': 'Telefone',
    'birthDate': 'Nascimento (AAAA-MM-DD)',
    'admissionDate': 'Admissão (AAAA-MM-DD)',
    'baptismDate': 'Batismo (AAAA-MM-DD)',
    'congregation': 'Congregação',
    'postalCode': 'CEP',
    'street': 'Logradouro',
    'number': 'Número',
    'complement': 'Complemento',
    'district': 'Bairro',
    'city': 'Cidade',
    'state': 'Estado/UF',
    'country': 'País',
  };
  static const addressKeys = [
    'postalCode',
    'street',
    'number',
    'complement',
    'district',
    'city',
    'state',
    'country',
  ];
  @override
  void initState() {
    super.initState();
    final p = widget.person;
    final values = p?.values ?? {};
    for (final key in labels.keys) {
      fields[key] = TextEditingController(
        text: addressKeys.contains(key)
            ? p?.address[key] ?? ''
            : values[key] as String? ?? '',
      );
    }
    status = p?.status ?? 'visitor';
    recordId = p?.id ?? newId();
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String value(String key) => fields[key]!.text.trim();
  String? validate(String key, String? raw) {
    final v = raw?.trim() ?? '';
    if (key == 'name' && v.length < 2) return 'Informe o nome completo.';
    if (key == 'email' &&
        v.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
      return 'Informe um e-mail válido.';
    }
    if (key == 'phone' &&
        v.isNotEmpty &&
        !RegExp(r'^[+\d ()-]{7,30}$').hasMatch(v)) {
      return 'Informe um telefone válido.';
    }
    if (key.endsWith('Date') && v.isNotEmpty) {
      final parsed = DateTime.tryParse(v);
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v) ||
          parsed == null ||
          parsed.toIso8601String().substring(0, 10) != v) {
        return 'Use uma data válida: AAAA-MM-DD.';
      }
      if (key == 'birthDate' && parsed.isAfter(DateTime.now())) {
        return 'Nascimento não pode estar no futuro.';
      }
    }
    return null;
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final p = Person(
      id: recordId,
      name: value('name'),
      preferredName: value('preferredName'),
      email: value('email'),
      phone: value('phone'),
      status: status,
      birthDate: value('birthDate'),
      admissionDate: value('admissionDate'),
      baptismDate: value('baptismDate'),
      congregation: value('congregation'),
      address: {for (final k in addressKeys) k: value(k)},
      version: widget.person?.version ?? 0,
    );
    final payload = jsonEncode(p.values);
    if (operationId == null || lastPayload != payload) {
      operationId = newId();
      lastPayload = payload;
    }
    setState(() {
      saving = true;
      error = '';
    });
    try {
      await widget.repository.savePerson(p, operationId!);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Não foi possível salvar. Se o cadastro foi alterado por outra pessoa, cancele e atualize a lista.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget field(String key) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: fields[key],
      enabled: !saving,
      maxLength: key == 'email'
          ? 254
          : key == 'name' || key == 'congregation'
          ? 120
          : key == 'street'
          ? 180
          : key.endsWith('Date')
          ? 10
          : key == 'phone'
          ? 30
          : 80,
      decoration: InputDecoration(labelText: labels[key], counterText: ''),
      keyboardType: key == 'email'
          ? TextInputType.emailAddress
          : key == 'phone'
          ? TextInputType.phone
          : TextInputType.text,
      validator: (v) => validate(key, v),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(widget.person == null ? 'Cadastrar pessoa' : 'Editar pessoa'),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Identificação e contato'),
                const SizedBox(height: 16),
                for (final k in [
                  'name',
                  'preferredName',
                  'email',
                  'phone',
                  'birthDate',
                ])
                  field(k),
                const SizedBox(height: 8),
                const Text('Vínculo com a igreja'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Vínculo'),
                  items: const [
                    DropdownMenuItem(
                      value: 'visitor',
                      child: Text('Visitante'),
                    ),
                    DropdownMenuItem(value: 'member', child: Text('Membro')),
                  ],
                  onChanged: saving ? null : (v) => setState(() => status = v!),
                ),
                const SizedBox(height: 16),
                for (final k in [
                  'congregation',
                  'admissionDate',
                  'baptismDate',
                ])
                  field(k),
                const Text('Endereço (opcional)'),
                const SizedBox(height: 16),
                for (final k in addressKeys) field(k),
                if (error.isNotEmpty)
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
