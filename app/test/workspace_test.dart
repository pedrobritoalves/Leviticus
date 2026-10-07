import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leviticus/main.dart';
import 'package:leviticus/people_repository.dart';

void main() {
  testWidgets('busca filtra pessoas e ministérios carregam', (tester) async {
    await tester.pumpWidget(LeviticusApp(repository: DemoChurchRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Ana Exemplo'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Daniel');
    await tester.pumpAndSettle();
    expect(find.text('Daniel Exemplo'), findsOneWidget);
    expect(find.text('Ana Exemplo'), findsNothing);
    await tester.tap(find.text('Ministérios'));
    await tester.pumpAndSettle();
    expect(find.text('Recepção'), findsOneWidget);
  });
  testWidgets('cadastro valida e persiste na sessão demonstrativa', (
    tester,
  ) async {
    final repo = DemoChurchRepository();
    await tester.pumpWidget(LeviticusApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cadastrar pessoa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe o nome completo.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome completo'),
      'Pessoa Nova',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(
      (await repo.listPeople()).any((p) => p.name == 'Pessoa Nova'),
      isTrue,
    );
    await tester.enterText(find.byType(TextField), 'Pessoa Nova');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Pessoa Nova'), findsOneWidget);
  });
  testWidgets('ministério pode vincular pessoa e responsável', (tester) async {
    final repo = DemoChurchRepository();
    await tester.pumpWidget(LeviticusApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ministérios'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar ministério'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome do ministério'),
      'Louvor',
    );
    await tester.tap(find.text('Ana Exemplo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    final created = (await repo.listMinistries()).firstWhere(
      (m) => m.name == 'Louvor',
    );
    expect(created.memberIds, ['demo1']);
  });

  testWidgets(
    'pedido de oração pode ser enviado e acompanhado pelo responsável',
    (tester) async {
      final repo = DemoChurchRepository();
      await tester.pumpWidget(LeviticusApp(repository: repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Oração e acompanhamento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pedir oração'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Assunto'),
        'Pedido de teste',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Como podemos orar por você?'),
        'Conteúdo fictício para verificar o fluxo.',
      );
      await tester.tap(find.text('Enviar pedido'));
      await tester.pumpAndSettle();
      expect((await repo.listPrayers()).length, 1);
      await tester.tap(find.text('Pedido de teste'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Em acompanhamento').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar acompanhamento'));
      await tester.pumpAndSettle();
      expect((await repo.listPrayers()).first.status, 'in_progress');
    },
  );
  testWidgets(
    'área administrativa não exibe acesso à oração quando não autorizado',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Workspace(
            repository: DemoChurchRepository(),
            allowPrayer: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Oração e acompanhamento'), findsNothing);
    },
  );
}
