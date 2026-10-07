import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leviticus/main.dart';
import 'package:leviticus/people_repository.dart';
import 'package:leviticus/event_page.dart';
import 'package:leviticus/event_repository.dart';

void main() {
  test('data local rejeita normalização e serializa em UTC', () {
    expect(parseEventTime('30/02/2030 19:00'), isNull);
    expect(parseEventTime('13/10/2030 25:00'), isNull);
    final d = parseEventTime('13/10/2030 19:00')!;
    expect(formatEventTime(d), '13/10/2030 19:00');
    final e = ChurchEvent(
      id: 'e',
      title: 'Teste',
      startsAt: d,
      endsAt: d.add(const Duration(hours: 1)),
    );
    expect((e.values['startsAt'] as String).endsWith('Z'), isTrue);
  });
  testWidgets('agenda cria evento, edita e filtra cancelados', (tester) async {
    final repo = DemoChurchRepository();
    await tester.pumpWidget(LeviticusApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Agenda institucional'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar evento'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Título do evento'),
      'Encontro da equipe',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Início (horário local)'),
      '13/10/2030 19:00',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Término (horário local)'),
      '13/10/2030 18:00',
    );
    await tester.tap(find.text('Salvar evento'));
    await tester.pumpAndSettle();
    expect(find.text('Término deve ser posterior ao início.'), findsOneWidget);
    expect(await repo.listEvents(), isEmpty);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Término (horário local)'),
      '13/10/2030 20:00',
    );
    await tester.tap(find.text('Salvar evento'));
    await tester.pumpAndSettle();
    expect((await repo.listEvents()).single.title, 'Encontro da equipe');
    await tester.tap(find.widgetWithText(ListTile, 'Encontro da equipe'));
    await tester.pumpAndSettle();
    final status = find.widgetWithText(
      DropdownButtonFormField<String>,
      'Situação do evento',
    );
    await tester.ensureVisible(status);
    await tester.tap(status);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelado').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar evento'));
    await tester.pumpAndSettle();
    expect((await repo.listEvents()).single.status, 'cancelled');
    expect((await repo.listEvents()).single.version, 2);
    await tester.tap(find.text('Próximos'));
    await tester.pumpAndSettle();
    expect(find.text('Encontro da equipe'), findsNothing);
    await tester.tap(find.text('Cancelados'));
    await tester.pumpAndSettle();
    expect(find.text('Encontro da equipe'), findsOneWidget);
  });
}
