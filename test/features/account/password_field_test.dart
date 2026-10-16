import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/features/account/presentation/widgets/password_field.dart';

Widget _host(TextEditingController controller) => MaterialApp(
  home: Scaffold(body: Center(child: PasswordField(controller: controller))),
);

bool _obscured(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).obscureText;

void main() {
  testWidgets('starts hidden and the eye toggles visibility', (tester) async {
    final controller = TextEditingController(text: 'rahasia123');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));

    expect(_obscured(tester), isTrue);
    expect(find.byTooltip(PasswordField.showLabel), findsOneWidget);

    await tester.tap(find.byTooltip(PasswordField.showLabel));
    await tester.pump();
    expect(_obscured(tester), isFalse);
    expect(find.byTooltip(PasswordField.hideLabel), findsOneWidget);

    await tester.tap(find.byTooltip(PasswordField.hideLabel));
    await tester.pump();
    expect(_obscured(tester), isTrue);
  });

  testWidgets('toggle is announced and meets the 48dp target', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(controller));

    final node = tester.getSemantics(
      find.ancestor(
        of: find.byTooltip(PasswordField.showLabel),
        matching: find.byType(Semantics),
      ).first,
    );
    expect(node.label, contains(PasswordField.showLabel));
    final size = tester.getSize(find.byTooltip(PasswordField.showLabel));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    handle.dispose();
  });

  testWidgets('keeps the typed text when toggling', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    await tester.enterText(find.byType(TextFormField), 'abc12345');
    await tester.tap(find.byTooltip(PasswordField.showLabel));
    await tester.pump();
    expect(controller.text, 'abc12345');
  });
}
