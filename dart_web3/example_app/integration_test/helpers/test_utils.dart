import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// E2E Test utilities for common testing operations.
class E2ETestUtils {
  /// Pump the widget and wait for animations to complete.
  static Future<void> pumpAndSettle(
    WidgetTester tester, {
    Duration duration = const Duration(milliseconds: 100),
  }) async {
    await tester.pumpAndSettle(duration);
  }

  /// Find and tap a widget by text.
  static Future<void> tapByText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    expect(finder, findsAtLeast(1), reason: 'Could not find text: $text');
    await tester.tap(finder.first);
    await pumpAndSettle(tester);
  }

  /// Find and tap a widget by icon.
  static Future<void> tapByIcon(WidgetTester tester, IconData icon) async {
    final finder = find.byIcon(icon);
    expect(finder, findsAtLeast(1), reason: 'Could not find icon: $icon');
    await tester.tap(finder.first);
    await pumpAndSettle(tester);
  }

  /// Find and tap a widget by key.
  static Future<void> tapByKey(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    expect(finder, findsOneWidget, reason: 'Could not find key: $key');
    await tester.tap(finder);
    await pumpAndSettle(tester);
  }

  /// Find and tap a widget by type.
  static Future<void> tapByType(WidgetTester tester, Type type) async {
    final finder = find.byType(type);
    expect(finder, findsAtLeast(1), reason: 'Could not find type: $type');
    await tester.tap(finder.first);
    await pumpAndSettle(tester);
  }

  /// Enter text into a TextField.
  static Future<void> enterText(
    WidgetTester tester,
    Finder finder,
    String text,
  ) async {
    expect(finder, findsOneWidget, reason: 'Could not find TextField');
    await tester.enterText(finder, text);
    await pumpAndSettle(tester);
  }

  /// Enter text into a TextField found by label.
  static Future<void> enterTextByLabel(
    WidgetTester tester,
    String label,
    String text,
  ) async {
    // Find TextField by its decoration label
    final finder = find.ancestor(
      of: find.text(label),
      matching: find.byType(TextField),
    );
    if (finder.evaluate().isEmpty) {
      // Try finding by hint text
      final hintFinder = find.byWidgetPredicate((widget) {
        if (widget is TextField) {
          return widget.decoration?.labelText == label ||
              widget.decoration?.hintText == label;
        }
        return false;
      });
      expect(hintFinder, findsAtLeast(1), reason: 'Could not find TextField with label: $label');
      await tester.enterText(hintFinder.first, text);
    } else {
      await tester.enterText(finder.first, text);
    }
    await pumpAndSettle(tester);
  }

  /// Verify text is present on screen.
  static void expectText(String text, {Matcher? matcher}) {
    expect(find.text(text), matcher ?? findsAtLeast(1), reason: 'Expected to find text: $text');
  }

  /// Verify widget type is present on screen.
  static void expectWidget<T>({Matcher? matcher}) {
    expect(find.byType(T), matcher ?? findsAtLeast(1), reason: 'Expected to find widget: $T');
  }

  /// Scroll until a widget is visible.
  static Future<void> scrollUntilVisible(
    WidgetTester tester,
    Finder finder, {
    double delta = -100,
  }) async {
    await tester.scrollUntilVisible(finder, delta);
    await pumpAndSettle(tester);
  }

  /// Wait for a specific duration.
  static Future<void> wait(WidgetTester tester, Duration duration) async {
    await tester.pump(duration);
  }
}

/// Matcher alias for convenience.
// ignore: non_constant_identifier_names
final findsAtLeast1 = findsAtLeast(1);
