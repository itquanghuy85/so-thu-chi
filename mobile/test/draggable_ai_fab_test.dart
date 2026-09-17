// Tests for the draggable "Trợ lý AI" button used by the main shell.
//
// The widget is deliberately free of Riverpod/auth dependencies so it can be
// pumped directly here — the shell only wires it to the position provider.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/shared/widgets/draggable_ai_fab.dart';

/// Mirrors DraggableAiFab's private constants: 48px button, 16px right margin,
/// and a default position 88px above the bottom edge (clear of the 56px-tall
/// `endFloat` FABs that child screens such as Giao dịch/Túi tiền render).
const double _fabRadius = 24;
const double _rightMargin = 16;
const double _defaultBottomInset = 88;

const Size _viewport = Size(400, 800);

Finder get _icon => find.byIcon(Icons.auto_awesome);

/// Available drag range along Y for the given viewport height.
double _maxTop(double height) => height - 48 - 16;

/// Pumps the button alone on a `width x height` surface, with no app bar and
/// no bottom nav, so global coordinates equal the widget's local ones.
Future<void> _pumpFab(
  WidgetTester tester, {
  Size viewport = _viewport,
  double? initialTopRatio,
  VoidCallback? onTap,
  ValueChanged<double>? onTopRatioChanged,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DraggableAiFab(
          onTap: onTap ?? () {},
          initialTopRatio: initialTopRatio,
          onTopRatioChanged: onTopRatioChanged,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the AI icon pinned to the right edge, above the child-screen FAB band', (tester) async {
    await _pumpFab(tester);

    expect(_icon, findsOneWidget);

    final center = tester.getCenter(_icon);
    expect(center.dx, closeTo(_viewport.width - _rightMargin - _fabRadius, 0.001));
    expect(center.dy, closeTo(_maxTop(_viewport.height) - _defaultBottomInset + _fabRadius, 0.001));
  });

  testWidgets('dragging up moves the button and clamps it to the top edge', (tester) async {
    final ratios = <double>[];
    await _pumpFab(tester, onTopRatioChanged: ratios.add);

    await tester.drag(_icon, const Offset(0, -1000));
    await tester.pump();

    expect(tester.getCenter(_icon).dy, closeTo(_fabRadius, 0.001));
    expect(ratios, [0.0]);
  });

  testWidgets('dragging down clamps the button to the bottom edge', (tester) async {
    final ratios = <double>[];
    await _pumpFab(tester, onTopRatioChanged: ratios.add);

    await tester.drag(_icon, const Offset(0, 1000));
    await tester.pump();

    expect(tester.getCenter(_icon).dy, closeTo(_maxTop(_viewport.height) + _fabRadius, 0.001));
    expect(ratios, [1.0]);
  });

  testWidgets('a partial drag reports the new position as a ratio of the drag range', (tester) async {
    final ratios = <double>[];
    await _pumpFab(tester, onTopRatioChanged: ratios.add);

    // Drag from the default spot (88px above the bottom) straight to the top.
    final start = _maxTop(_viewport.height) - _defaultBottomInset;
    await tester.drag(_icon, Offset(0, -start));
    await tester.pump();

    // Flutter consumes a touch slop (~18px) before the drag starts, so the
    // reported ratio is just under the theoretical 0.0 — assert it is close
    // to the top rather than exact.
    expect(ratios, hasLength(1));
    expect(ratios.single, lessThan(0.05));
    expect(tester.getCenter(_icon).dy, lessThan(_viewport.height / 2));
  });

  testWidgets('tapping (without dragging) invokes onTap', (tester) async {
    var taps = 0;
    await _pumpFab(tester, onTap: () => taps++);

    await tester.tap(_icon);
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('a saved ratio is restored on first build', (tester) async {
    await _pumpFab(tester, initialTopRatio: 0.5);

    final expectedTop = 0.5 * _maxTop(_viewport.height);
    expect(tester.getCenter(_icon).dy, closeTo(expectedTop + _fabRadius, 0.001));
  });

  testWidgets('a saved ratio arriving late never overrides a position the user already dragged to', (tester) async {
    await _pumpFab(tester);

    await tester.drag(_icon, const Offset(0, -1000));
    await tester.pump();
    expect(tester.getCenter(_icon).dy, closeTo(_fabRadius, 0.001));

    // The provider's async restore lands only now — the button must stay put.
    await _pumpFab(tester, initialTopRatio: 1.0);
    await tester.pump();

    expect(tester.getCenter(_icon).dy, closeTo(_fabRadius, 0.001));
  });

  testWidgets('a viewport shorter than the button does not throw', (tester) async {
    await _pumpFab(tester, viewport: const Size(400, 50));

    expect(tester.takeException(), isNull);
    expect(_icon, findsOneWidget);
    expect(tester.getCenter(_icon).dy, closeTo(_fabRadius, 0.001));
  });
}